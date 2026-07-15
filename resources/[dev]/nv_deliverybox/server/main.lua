local activeJobSessions = {}
local completedJobRestarts = {}
local palletsState = { [1] = false, [2] = false, [3] = false }

-- Callback to start the job
lib.callback.register('nv_deliverybox:startJob', function(source)
    local src = tonumber(source)
    local identifier = GetPlayerIdentifier(src, 0)
    
    if completedJobRestarts[identifier] then
        return false, "Você já retirou suas encomendas nesta sessão do servidor e não pode iniciar novamente."
    end
    
    if activeJobSessions[src] then
        return false, "Você já tem uma entrega em andamento!"
    end
    
    -- Encontra o primeiro pallet livre de 1 a 3
    local palletId = nil
    for i = 1, #Config.Pallets do
        if not palletsState[i] then
            palletId = i
            break
        end
    end
    
    if not palletId then
        return false, "Todos os pallets estão ocupados no momento. Aguarde até que um entregador libere a área!"
    end
    
    -- Sorteia a quantidade de pacotes entre 3 e 5
    local packageCount = math.random(3, 5)
    local packages = {}
    local packageTypes = {'letter', 'small', 'large'}
    
    for i = 1, packageCount do
        local pType = packageTypes[math.random(1, 3)]
        local location = Config.DeliveryLocations[math.random(1, #Config.DeliveryLocations)]
        local hasNPC = false
        if pType ~= 'letter' then
            hasNPC = math.random(1, 100) <= 50 -- 50% de chance de ter NPC para caixas
        end
        
        packages[i] = {
            id = i,
            type = pType,
            coords = location.coords,
            label = location.label,
            hasNPC = hasNPC,
            model = Config.Models[pType],
            itemName = Config.Items[pType].name,
            itemLabel = Config.Items[pType].label
        }
    end
    
    -- Ordena as encomendas pelo tamanho para empilhar corretamente (grandes em baixo, pequenas no meio, cartas no topo)
    local sortedPackages = {}
    
    -- 1. Caixas grandes
    for _, pkg in ipairs(packages) do
        if pkg.type == 'large' then
            sortedPackages[#sortedPackages + 1] = pkg
        end
    end
    
    -- 2. Caixas pequenas
    for _, pkg in ipairs(packages) do
        if pkg.type == 'small' then
            sortedPackages[#sortedPackages + 1] = pkg
        end
    end
    
    -- 3. Cartas
    for _, pkg in ipairs(packages) do
        if pkg.type == 'letter' then
            sortedPackages[#sortedPackages + 1] = pkg
        end
    end
    
    packages = sortedPackages
    
    -- Reatribui IDs em ordem para os pacotes ordenados
    for i, pkg in ipairs(packages) do
        pkg.id = i
    end
    
    -- Ocupa o pallet
    palletsState[palletId] = src
    
    activeJobSessions[src] = {
        packages = packages,
        spawnedCount = #packages,
        deliveredCount = 0,
        palletId = palletId
    }
    
    completedJobRestarts[identifier] = true
    
    return true, { packages = packages, palletId = palletId }
end)

-- Callback para quando o jogador coleta um pacote do pallet
lib.callback.register('nv_deliverybox:pickupPackage', function(source, pkgId)
    local src = tonumber(source)
    local session = activeJobSessions[src]
    if not session then return false end
    
    local pkgIndex = nil
    local pkg = nil
    
    for i, p in ipairs(session.packages) do
        if p.id == pkgId then
            pkg = p
            pkgIndex = i
            break
        end
    end
    
    if not pkg then return false end
    
    -- Only allow carrying one package at a time
    local deliveryItems = {'delivery_letter', 'delivery_small_box', 'delivery_large_package'}
    for _, name in ipairs(deliveryItems) do
        local count = exports.ox_inventory:GetItemCount(src, name)
        if count and count > 0 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Você só pode carregar uma encomenda por vez!' })
            return false
        end
    end

    local itemConfig = Config.Items[pkg.type]
    if not exports.ox_inventory:CanCarryItem(src, itemConfig.name, 1) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Está muito pesado para carregar!' })
        return false
    end
    
    -- Adiciona o item com os metadados de entrega
    local metadata = {
        deliveryCoords = pkg.coords,
        deliveryLabel = pkg.label,
        deliveryType = pkg.type,
        hasNPC = pkg.hasNPC,
        description = "Destino: " .. pkg.label
    }
    
    exports.ox_inventory:AddItem(src, itemConfig.name, 1, metadata)
    table.remove(session.packages, pkgIndex)
    
    return true
end)

-- Callback para concluir uma entrega
lib.callback.register('nv_deliverybox:completeDelivery', function(source, slotIndex)
    local src = tonumber(source)
    print("^3[nv_deliverybox] completeDelivery called by source:", src, "slotIndex:", slotIndex)
    local session = activeJobSessions[src]
    if not session then
        print("^1[nv_deliverybox] Error: No active session for source:", src)
        return false
    end
    
    local item = exports.ox_inventory:GetSlot(src, slotIndex)
    if not item then
        print("^1[nv_deliverybox] Error: No item found in slot:", slotIndex)
        return false
    end

    local deliveryCoords = item.metadata and item.metadata.deliveryCoords
    if not deliveryCoords then
        print("^1[nv_deliverybox] Error: No delivery coordinates in metadata!")
        return false
    end
    
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local dist = #(playerCoords - vector3(deliveryCoords.x, deliveryCoords.y, deliveryCoords.z))
    if dist > 10.0 then -- Allow 10 meters distance threshold
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Você não está no local de entrega correto!' })
        return false
    end
    
    local pType = item.metadata and item.metadata.deliveryType
    print("^3[nv_deliverybox] Found item in slot:", item.name, "metadata type:", pType)
    
    local itemConfig = Config.Items[pType]
    if not itemConfig then
        print("^1[nv_deliverybox] Error: No item config for type:", tostring(pType))
        return false
    end
    
    -- Remove o item do jogador
    if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, slotIndex) then
        print("^2[nv_deliverybox] Successfully removed item:", item.name)
        -- Calculate distance from starting point (warehouse) to delivery point
        local startCoords = vector3(Config.StartNPC.coords.x, Config.StartNPC.coords.y, Config.StartNPC.coords.z)
        local endCoords = vector3(deliveryCoords.x, deliveryCoords.y, deliveryCoords.z)
        local deliveryDist = #(endCoords - startCoords)

        local baseVal = itemConfig.payoutMin or 100
        local maxVal = itemConfig.payoutMax or 500
        local pay = baseVal

        if deliveryDist <= 1000.0 then
            pay = baseVal
        elseif deliveryDist >= 5000.0 then
            pay = maxVal
        else
            local fraction = (deliveryDist - 1000.0) / 4000.0
            pay = math.floor(baseVal + (maxVal - baseVal) * fraction)
        end

        exports.ox_inventory:AddItem(src, 'money', pay)
        
        session.deliveredCount = session.deliveredCount + 1
        
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = string.format("Encomenda entregue com sucesso! Recebido: $%d", pay) })
        
        -- Verifica se todas as encomendas foram entregues
        if session.deliveredCount >= session.spawnedCount then
            print("^2[nv_deliverybox] All deliveries completed for source:", src)
            TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = "Parabéns! Você concluiu todas as entregas!" })
            
            -- Libera o pallet
            if session.palletId then
                palletsState[session.palletId] = false
            end
            
            activeJobSessions[src] = nil
            TriggerClientEvent('nv_deliverybox:cleanJobState', src)
        end
        
        return true
    else
        print("^1[nv_deliverybox] Error: Failed to remove item from slot:", slotIndex)
    end
    
    return false
end)

-- Evento para cancelar o serviço
RegisterNetEvent('nv_deliverybox:cancelJob', function(deleteHandItem)
    local src = tonumber(source)
    local session = activeJobSessions[src]
    if not session then return end
    
    -- Libera o pallet
    if session.palletId then
        palletsState[session.palletId] = false
    end
    
    activeJobSessions[src] = nil
    
    -- Se solicitado, remove os itens de entrega da mão/inventário do jogador
    if deleteHandItem then
        for _, itemConfig in pairs(Config.Items) do
            local items = exports.ox_inventory:GetSlotsWithItem(src, itemConfig.name)
            if items then
                for _, item in ipairs(items) do
                    exports.ox_inventory:RemoveItem(src, itemConfig.name, item.count, nil, item.slot)
                end
            end
        end
    end
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'info', description = "Serviço de entregas cancelado." })
    TriggerClientEvent('nv_deliverybox:cleanJobState', src)
end)

-- Limpeza de entidades caso o jogador desconecte
AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    local session = activeJobSessions[src]
    if session then
        if session.palletId then
            palletsState[session.palletId] = false
        end
        activeJobSessions[src] = nil
    end
end)
