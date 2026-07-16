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

local recyclingTrunks = {}

-- Hook into openInventory to block access while recycling
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'ox_inventory' or resourceName == GetCurrentResourceName() then
        exports.ox_inventory:registerHook('openInventory', function(payload)
            if recyclingTrunks[payload.inventoryId] then
                TriggerClientEvent('ox_lib:notify', payload.source, {
                    type = 'error',
                    title = 'Caminhão Bloqueado',
                    description = 'Este caminhão está ocupado processando reciclagem!'
                })
                return false
            end
        end)
    end
end)

-- Callback to check if trunk contains full bags
lib.callback.register('nv_recycle:server:checkTrunkForBags', function(source, trunkId)
    local inventory = exports.ox_inventory:GetInventory(trunkId)
    if not inventory or not inventory.items then return false end
    
    for _, item in pairs(inventory.items) do
        if (item.name == 'trash_bag_black' or item.name == 'trash_bag_white') and item.metadata and item.metadata.isFull then
            return true
        end
    end
    return false
end)

-- Event to process recycling (locks inventory, waits 1 minute, rewards recycled materials)
RegisterNetEvent('nv_recycle:server:recycleTrunk', function(trunkId, vehicleNetId)
    local src = source
    if recyclingTrunks[trunkId] then return end
    
    local inventory = exports.ox_inventory:GetInventory(trunkId)
    if not inventory or not inventory.items then return end
    
    -- Check if there are any full bags inside
    local hasFullBags = false
    for _, item in pairs(inventory.items) do
        if (item.name == 'trash_bag_black' or item.name == 'trash_bag_white') and item.metadata and item.metadata.isFull then
            hasFullBags = true
            break
        end
    end
    
    if not hasFullBags then return end
    
    -- Lock trunk inventory globally
    recyclingTrunks[trunkId] = true
    
    -- Force close the inventory for any player currently viewing it
    if inventory.openedBy then
        for playerId, _ in pairs(inventory.openedBy) do
            local playerInv = exports.ox_inventory:GetInventory(playerId)
            if playerInv then
                playerInv:closeInventory()
                TriggerClientEvent('ox_lib:notify', playerId, {
                    type = 'info',
                    title = 'Processo de Reciclagem',
                    description = 'Caminhão de lixo começou a reciclar. Inventário bloqueado por 1 minuto.'
                })
            end
        end
    end
    
    -- 1 minute recycling processing timer (60 seconds)
    SetTimeout(60000, function()
        -- Fetch refreshed inventory
        local freshInv = exports.ox_inventory:GetInventory(trunkId)
        if not freshInv or not freshInv.items then
            recyclingTrunks[trunkId] = nil
            return
        end
        
        local totalItemsCount = 0
        local bagsRemoved = {}
        
        -- Process bags and count internal items
        for _, item in pairs(freshInv.items) do
            if (item.name == 'trash_bag_black' or item.name == 'trash_bag_white') and item.metadata and item.metadata.isFull then
                local containerId = item.metadata.container
                if containerId then
                    local containerInv = exports.ox_inventory:GetInventory(containerId)
                    if containerInv and containerInv.items then
                        for _, innerItem in pairs(containerInv.items) do
                            totalItemsCount = totalItemsCount + innerItem.count
                            -- Remove items from container stash slot-by-slot
                            exports.ox_inventory:RemoveItem(containerId, innerItem.name, innerItem.count, nil, innerItem.slot)
                        end
                    end
                end
                table.insert(bagsRemoved, { name = item.name, count = item.count, slot = item.slot })
            end
        end
        
        -- Remove the full trash bag containers from the trunk
        for _, bag in ipairs(bagsRemoved) do
            exports.ox_inventory:RemoveItem(trunkId, bag.name, bag.count, nil, bag.slot)
        end
        
        -- Reward the "Material reciclável" items inside the trunk inventory
        if totalItemsCount > 0 then
            exports.ox_inventory:AddItem(trunkId, 'recycled_material', totalItemsCount)
        end
        
        -- Unlock trunk inventory
        recyclingTrunks[trunkId] = nil
        
        -- Notify the player who initiated it
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            title = 'Reciclagem Concluída',
            description = string.format("Reciclagem finalizada! Gerado %dx Material reciclável no caminhão.", totalItemsCount)
        })
    end)
end)
