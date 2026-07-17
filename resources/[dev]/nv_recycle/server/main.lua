local function GetVehicleFromPlate(plate)
    local vehicles = GetAllVehicles()
    local trimmedPlate = string.lower(string.gsub(plate, "^%s*(.-)%s*$", "%1"))
    for i = 1, #vehicles do
        local veh = vehicles[i]
        local vehPlate = GetVehicleNumberPlateText(veh)
        if vehPlate then
            local trimmedVehPlate = string.lower(string.gsub(vehPlate, "^%s*(.-)%s*$", "%1"))
            if trimmedVehPlate == trimmedPlate then
                return veh
            end
        end
    end
    return nil
end

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

-- Hooks to handle trash and trash2 trunks as recycling stashes
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'ox_inventory' or resourceName == GetCurrentResourceName() then
        -- Hook openInventory to lock/unlock truck trunk access based on state
        exports.ox_inventory:registerHook('openInventory', function(payload)
            if payload.inventoryType == 'trunk' then
                local vehicle
                if payload.netId then
                    vehicle = NetworkGetEntityFromNetworkId(payload.netId)
                elseif payload.inventoryId then
                    local plate = payload.inventoryId:sub(6)
                    vehicle = GetVehicleFromPlate(plate)
                end
                if vehicle and DoesEntityExist(vehicle) then
                    local model = GetEntityModel(vehicle)
                    if model == `trash` or model == `trash2` then
                        local state = Entity(vehicle).state.recycleState or { bagsCount = 0, status = 'idle' }
                        if state.status == 'compacting' then
                            TriggerClientEvent('ox_lib:notify', payload.source, {
                                type = 'error',
                                title = 'Porta-malas Trancado',
                                description = 'O caminhão de lixo está compactando o lixo no momento!'
                            })
                            return false
                        end
                        return true
                    end
                end
            end
        end)

        -- Hook swapItems to validate trash bag placement and initiate compaction/recycle
        exports.ox_inventory:registerHook('swapItems', function(payload)
            -- 1. Check if moving item to a trunk
            if payload.toType == 'trunk' and payload.toInventory then
                local plate = payload.toInventory:sub(6)
                local vehicle = GetVehicleFromPlate(plate)
                if vehicle and DoesEntityExist(vehicle) then
                    local model = GetEntityModel(vehicle)
                    if model == `trash` or model == `trash2` then
                        -- Check item being added
                        local item = payload.fromSlot
                        local itemName = item.name
                        local isTrashBag = (itemName == 'trash_bag_black' or itemName == 'trash_bag_white') and item.metadata
                        
                        if not isTrashBag then
                            TriggerClientEvent('ox_lib:notify', payload.source, {
                                type = 'error',
                                title = 'Caminhão de Lixo',
                                description = 'Apenas sacos de lixo contendo itens podem ser colocados aqui!'
                            })
                            return false
                        end
                        
                        -- Validate that the bag actually contains items
                        local containerId = item.metadata.container
                        local itemsCount = 0
                        if containerId then
                            local containerInv = exports.ox_inventory:GetInventory(containerId)
                            if containerInv and containerInv.items then
                                for _, innerItem in pairs(containerInv.items) do
                                    itemsCount = itemsCount + innerItem.count
                                end
                            end
                        end
                        
                        if itemsCount == 0 then
                            TriggerClientEvent('ox_lib:notify', payload.source, {
                                type = 'error',
                                title = 'Caminhão de Lixo',
                                description = 'Este saco de lixo está vazio!'
                            })
                            return false
                        end
                        
                        local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
                        TriggerClientEvent('nv_recycle:client:playThrowAnim', payload.source)
                        
                        SetTimeout(1000, function()
                            if DoesEntityExist(vehicle) then
                                -- Close player's inventory
                                TriggerClientEvent('ox_inventory:closeInventory', payload.source)
                                
                                -- Visually close the trunk
                                TriggerClientEvent('nv_recycle:client:setTrunkDoor', -1, vehicleNetId, false)
                                
                                -- Update vehicle state
                                local state = Entity(vehicle).state.recycleState or { bagsCount = 0, totalItemsCount = 0, status = 'idle' }
                                local newState = {
                                    bagsCount = state.bagsCount + 1,
                                    totalItemsCount = state.totalItemsCount + itemsCount,
                                    status = 'compacting'
                                }
                                Entity(vehicle).state:set('recycleState', newState, true)
                                
                                -- Clear items inside the bag container in trunk and the trunk itself
                                local trunkInv = exports.ox_inventory:GetInventory(payload.toInventory)
                                if trunkInv and trunkInv.items then
                                    for _, trunkItem in pairs(trunkInv.items) do
                                        if (trunkItem.name == 'trash_bag_black' or trunkItem.name == 'trash_bag_white') and trunkItem.metadata then
                                            local cId = trunkItem.metadata.container
                                            if cId then
                                                local cInv = exports.ox_inventory:GetInventory(cId)
                                                if cInv and cInv.items then
                                                    for _, innerItem in pairs(cInv.items) do
                                                        exports.ox_inventory:RemoveItem(cId, innerItem.name, innerItem.count, nil, innerItem.slot)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                exports.ox_inventory:ClearInventory(payload.toInventory)
                                
                                TriggerClientEvent('ox_lib:notify', payload.source, {
                                    type = 'info',
                                    title = 'Caminhão de Lixo',
                                    description = 'Saco de lixo adicionado! Compactando... Aguarde 1 minuto.'
                                })
                                
                                -- Start 1 minute compaction timer
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
                                            
                                            -- Add the recycled_material item with the total sum of items
                                            exports.ox_inventory:AddItem(payload.toInventory, 'recycled_material', currState.totalItemsCount)
                                            
                                            -- Visually open trunk door
                                            TriggerClientEvent('nv_recycle:client:setTrunkDoor', -1, vehicleNetId, true)
                                        end
                                    end
                                end)
                            end
                        end)
                        
                        return true
                    end
                end
            end
            
            -- 2. Check if taking recycled materials out of the trunk (reset state when empty)
            if payload.fromType == 'trunk' and payload.fromInventory then
                local plate = payload.fromInventory:sub(6)
                local vehicle = GetVehicleFromPlate(plate)
                if vehicle and DoesEntityExist(vehicle) then
                    local model = GetEntityModel(vehicle)
                    if model == `trash` or model == `trash2` then
                        SetTimeout(150, function()
                            local trunkInv = exports.ox_inventory:GetInventory(payload.fromInventory)
                            local isEmpty = true
                            if trunkInv and trunkInv.items then
                                for _, item in pairs(trunkInv.items) do
                                    if item and item.count > 0 then
                                        isEmpty = false
                                        break
                                    end
                                end
                            end
                            if isEmpty then
                                -- Reset vehicle state to idle
                                local resetState = {
                                    bagsCount = 0,
                                    totalItemsCount = 0,
                                    status = 'idle'
                                }
                                Entity(vehicle).state:set('recycleState', resetState, true)
                            end
                        end)
                    end
                end
            end
        end)
    end
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

-- ==========================================================================
-- RECYCLABLE MATERIAL SELLING SYSTEM
-- ==========================================================================
local sellPrices = {}

local function generateSellPrices()
    for _, cfg in ipairs(Config.SellableItems or {}) do
        local price = 1
        local roll = math.random(1, 100)
        if roll <= 5 then
            price = 3
        else
            price = math.random(1, 2)
        end
        sellPrices[cfg.item] = price
    end
end

-- Generate prices on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        generateSellPrices()
        local logged = {}
        for item, price in pairs(sellPrices) do
            table.insert(logged, string.format("%s: $%d", item, price))
        end
        print("^2[nv_recycle] Preços de venda de recicláveis gerados: " .. table.concat(logged, ", ") .. "^7")
    end
end)

-- Callback to retrieve prices
lib.callback.register('nv_recycle:server:getSellPrices', function(source)
    return sellPrices
end)

-- Event to sell a single item type
RegisterNetEvent('nv_recycle:server:sellItem', function(itemName)
    local src = source
    local price = sellPrices[itemName]
    if not price then return end
    
    local count = exports.ox_inventory:GetItem(src, itemName, nil, true)
    if not count or count <= 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Você não possui este item!' })
        return
    end
    
    local totalPayout = count * price
    
    if exports.ox_inventory:RemoveItem(src, itemName, count) then
        exports.ox_inventory:AddItem(src, 'money', totalPayout)
        TriggerClientEvent('ox_lib:notify', src, { 
            type = 'success', 
            description = string.format('Vendido %dx por $%d!', count, totalPayout) 
        })
    end
end)

-- Event to sell all items in Config.SellableItems
RegisterNetEvent('nv_recycle:server:sellAll', function()
    local src = source
    local totalPayout = 0
    local soldAny = false
    
    for _, cfg in ipairs(Config.SellableItems or {}) do
        local price = sellPrices[cfg.item]
        if price then
            local count = exports.ox_inventory:GetItem(src, cfg.item, nil, true)
            if count and count > 0 then
                local itemTotal = count * price
                if exports.ox_inventory:RemoveItem(src, cfg.item, count) then
                    totalPayout = totalPayout + itemTotal
                    soldAny = true
                end
            end
        end
    end
    
    if soldAny then
        exports.ox_inventory:AddItem(src, 'money', totalPayout)
        TriggerClientEvent('ox_lib:notify', src, { 
            type = 'success', 
            description = string.format('Todos os seus recicláveis foram vendidos por $%d!', totalPayout) 
        })
    else
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Nenhum item reciclável no inventário para vender!' })
    end
end)
