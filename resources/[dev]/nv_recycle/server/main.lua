local function getWeightedLoot()
    local totalWeight = 0
    for i = 1, #Config.Loot do
        totalWeight = totalWeight + Config.Loot[i].weight
    end
    
    local rand = math.random(1, totalWeight)
    local currentWeight = 0
    for i = 1, #Config.Loot do
        currentWeight = currentWeight + Config.Loot[i].weight
        if rand <= currentWeight then
            return Config.Loot[i]
        end
    end
    return Config.Loot[1]
end

RegisterNetEvent("nv_recycle:server:rewardItem", function(round, isFinalRound)
    local src = source
    local loot = getWeightedLoot()
    
    if not loot then return end
    
    local itemName = loot.item
    local itemLabel = loot.label
    
    -- Weighted item quantity roll: 1 = High (60%), 2 = Medium (30%), 3 = Low (10%)
    local count = 1
    local roll = math.random(1, 100)
    if roll <= 60 then
        count = 1
    elseif roll <= 90 then
        count = 2
    else
        count = 3
    end

    -- Clamp count between loot's defined limits
    if count > loot.max then count = loot.max end
    if count < loot.min then count = loot.min end
    
    -- If it's an assorted drink bottle, pick a random item from subItems
    if itemName == "assorted_bottle" and loot.subItems then
        itemName = loot.subItems[math.random(1, #loot.subItems)]
    end
    
    -- Give the reward item via ox_inventory
    local success = exports.ox_inventory:AddItem(src, itemName, count)
    
    if success then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            title = 'Item Encontrado',
            description = string.format("Você vasculhou e achou %dx %s!", count, itemLabel)
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            title = 'Inventário Cheio',
            description = 'Você achou algo, mas não tem espaço suficiente.'
        })
    end
    
    -- Handle final round completion bonus
    if isFinalRound then
        local roll = math.random(1, 100)
        if roll <= Config.FinalBonusLoot.chance then
            local bonusItem = Config.FinalBonusLoot.items[math.random(1, #Config.FinalBonusLoot.items)]
            local bonusSuccess = exports.ox_inventory:AddItem(src, bonusItem, 1)
            if bonusSuccess then
                Wait(800) -- Small delay for clean sequential notification
                TriggerClientEvent('ox_lib:notify', src, {
                    type = 'success',
                    title = 'Bônus de Sucesso',
                    description = 'Você vasculhou a lixeira por completo e encontrou um bônus extra!'
                })
            end
        end
    end
end)

-- Hook into openInventory to block access to garbage truck trunks
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'ox_inventory' or resourceName == GetCurrentResourceName() then
        exports.ox_inventory:registerHook('openInventory', function(payload)
            if payload.inventoryType == 'trunk' and payload.netId then
                local vehicle = NetworkGetEntityFromNetworkId(payload.netId)
                if DoesEntityExist(vehicle) then
                    local model = GetEntityModel(vehicle)
                    if model == `trash` or model == `trash2` then
                        TriggerClientEvent('ox_lib:notify', payload.source, {
                            type = 'error',
                            title = 'Porta-malas Trancado',
                            description = 'Este caminhão de lixo não permite acesso manual ao porta-malas!'
                        })
                        return false
                    end
                end
            end
        end)
    end
end)

-- Callback to throw a full bag into the garbage truck
lib.callback.register('nv_recycle:server:throwBag', function(source, vehicleNetId, itemName, slot)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return false end
    
    -- Check player inventory item
    local item = exports.ox_inventory:GetSlot(src, slot)
    if not item or item.name ~= itemName or not item.metadata or not item.metadata.isFull then
        return false
    end
    
    -- Check truck state
    local state = Entity(vehicle).state.recycleState or { bagsCount = 0, totalItemsCount = 0, status = 'idle' }
    if state.status ~= 'idle' or state.bagsCount >= 3 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            title = 'Caminhão Cheio',
            description = 'O caminhão já possui o limite de 3 sacos de lixo!'
        })
        return false
    end
    
    -- Count items in container bag
    local containerId = item.metadata.container
    local itemsCount = 0
    if containerId then
        local containerInv = exports.ox_inventory:GetInventory(containerId)
        if containerInv and containerInv.items then
            for _, innerItem in pairs(containerInv.items) do
                itemsCount = itemsCount + innerItem.count
                -- Remove from container
                exports.ox_inventory:RemoveItem(containerId, innerItem.name, innerItem.count, nil, innerItem.slot)
            end
        end
    end
    
    -- Remove the bag item from the player
    exports.ox_inventory:RemoveItem(src, itemName, 1, nil, slot)
    
    -- Update vehicle state bag
    local newState = {
        bagsCount = state.bagsCount + 1,
        totalItemsCount = state.totalItemsCount + itemsCount,
        status = 'idle'
    }
    Entity(vehicle).state:set('recycleState', newState, true)
    
    -- Visually open trunk door for everyone
    TriggerClientEvent('nv_recycle:client:setTrunkDoor', -1, vehicleNetId, true)
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        title = 'Lixo Jogado',
        description = string.format('Saco de lixo jogado na traseira. (%d/3)', newState.bagsCount)
    })
    
    return true
end)

-- Callback to start compacting the garbage truck
lib.callback.register('nv_recycle:server:compactTrunk', function(source, vehicleNetId)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return false end
    
    local state = Entity(vehicle).state.recycleState or { bagsCount = 0, totalItemsCount = 0, status = 'idle' }
    if state.status ~= 'idle' or state.bagsCount < 1 then
        return false
    end
    
    -- Set status to compacting
    local newState = {
        bagsCount = state.bagsCount,
        totalItemsCount = state.totalItemsCount,
        status = 'compacting'
    }
    Entity(vehicle).state:set('recycleState', newState, true)
    
    -- Visually close trunk door for everyone
    TriggerClientEvent('nv_recycle:client:setTrunkDoor', -1, vehicleNetId, false)
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'info',
        title = 'Compactação Iniciada',
        description = 'Compactando o lixo. Aguarde 1 minuto.'
    })
    
    -- 1 minute compacting timer
    SetTimeout(60000, function()
        if DoesEntityExist(vehicle) then
            local currState = Entity(vehicle).state.recycleState
            if currState and currState.status == 'compacting' then
                local finalState = {
                    bagsCount = currState.bagsCount,
                    totalItemsCount = currState.totalItemsCount,
                    status = 'ready_to_collect'
                }
                Entity(vehicle).state:set('recycleState', finalState, true)
                
                -- Visually open trunk door
                TriggerClientEvent('nv_recycle:client:setTrunkDoor', -1, vehicleNetId, true)
            end
        end
    end)
    
    return true
end)

-- Callback to collect recycled materials from the truck
lib.callback.register('nv_recycle:server:collectRecycle', function(source, vehicleNetId)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return false end
    
    local state = Entity(vehicle).state.recycleState
    if not state or state.status ~= 'ready_to_collect' then
        return false
    end
    
    local totalItems = state.totalItemsCount or 0
    if totalItems > 0 then
        local success = exports.ox_inventory:AddItem(src, 'recycled_material', totalItems)
        if not success then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                title = 'Inventário Cheio',
                description = 'Você não tem espaço suficiente para carregar os materiais reciclados!'
            })
            return false
        end
    end
    
    -- Reset state to idle
    local resetState = {
        bagsCount = 0,
        totalItemsCount = 0,
        status = 'idle'
    }
    Entity(vehicle).state:set('recycleState', resetState, true)
    
    -- Visually close trunk door
    TriggerClientEvent('nv_recycle:client:setTrunkDoor', -1, vehicleNetId, false)
    
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        title = 'Materiais Coletados',
        description = string.format('Coletado %dx Material reciclável do caminhão!', totalItems)
    })
    
    return true
end)

-- Callback to directly pick up a dropped trash bag
lib.callback.register('nv_recycle:server:pickupBagDrop', function(source, dropId)
    local src = source
    local dropInv = exports.ox_inventory:GetInventory(dropId)
    if not dropInv or dropInv.type ~= 'drop' then return false end
    
    -- Ensure player is close to the drop coordinates
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    if #(playerCoords - dropInv.coords) > 5.0 then return false end
    
    -- Check items in the drop inventory and add them to the player
    local items = dropInv.items
    if items then
        for _, item in pairs(items) do
            local success = exports.ox_inventory:AddItem(src, item.name, item.count, item.metadata)
            if not success then
                TriggerClientEvent('ox_lib:notify', src, {
                    type = 'error',
                    title = 'Sem Espaço',
                    description = 'Seu inventário está muito pesado para pegar o item!'
                })
                return false
            end
        end
    end
    
    -- Remove the drop inventory (deletes the physical prop and drop stash)
    exports.ox_inventory:RemoveInventory(dropId)
    return true
end)
