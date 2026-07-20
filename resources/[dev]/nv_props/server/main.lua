local activeDrops = {}
print("^2[nv_props] Server script loaded successfully!^7")

local function LoadDrops()
    -- No persistence
end

local function SaveDrops()
    -- No persistence
end

local function GetDropByNetId(netId)
    for dropId, drop in pairs(activeDrops) do
        if drop.netId == netId then
            return drop
        end
    end
    return nil
end

local function SpawnDrop(itemName, count, coords, rotation, metadata, frozen)
    local model = Config.Items[itemName]
    if not model then return nil end
    
    if itemName == 'trash_bag_black' or itemName == 'trash_bag_white' then
        if not metadata or not metadata.isFull then
            model = Config.DefaultModel
        end
    end
    local modelHash = model
    
    local entity = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z, true, true, true)

    -- Rede de seguranca: se o modelo mapeado nao existir, cai no DefaultModel
    -- em vez de o item simplesmente sumir sem prop.
    if (not entity or entity == 0) and modelHash ~= Config.DefaultModel then
        print(("^3[nv_props] Modelo %s (item: %s) falhou ao spawnar; usando DefaultModel.^7"):format(modelHash, itemName))
        modelHash = Config.DefaultModel
        entity = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z, true, true, true)
    end

    if not entity or entity == 0 then
        print(("^1[nv_props] Error: CreateObjectNoOffset returned 0 for model %s (item: %s). Check if Onesync is enabled and model exists.^7"):format(modelHash, itemName))
        return nil
    end
    
    if frozen then
        FreezeEntityPosition(entity, true)
    end
    
    SetEntityRotation(entity, rotation.x, rotation.y, rotation.z, 2, true)
    
    local dropId = 'prop_' .. tostring(math.random(100000, 999999))
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId == 0 then
        print("^1[nv_props] Error: Failed to get network ID for entity!^7")
        DeleteEntity(entity)
        return nil
    end
    
    activeDrops[dropId] = {
        id = dropId,
        netId = netId,
        itemName = itemName,
        count = count,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        rotation = { x = rotation.x, y = rotation.y, z = rotation.z },
        metadata = metadata or {},
        model = model,
        frozen = frozen
    }
    
    SaveDrops()
    TriggerClientEvent('nv_props:syncDrops', -1, activeDrops)
    return dropId
end

exports('SpawnDrop', SpawnDrop)

-- Intercept default inventory drops using ox_inventory hooks
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'ox_inventory' or resourceName == GetCurrentResourceName() then
        Wait(1000) -- Wait for ox_inventory to initialize exports
        exports.ox_inventory:registerHook('swapItems', function(payload)
            if payload.action == 'drop' or payload.toInventory == 'newdrop' then
                local itemName = payload.fromSlot.name
                
                local isTrashBag = (itemName == 'trash_bag_black' or itemName == 'trash_bag_white')
                local hasMappedModel = Config.Items[itemName]
                if isTrashBag then
                    hasMappedModel = false
                end
                
                if hasMappedModel then
                    local source = tonumber(payload.fromInventory)
                    if not source then return end
                    
                    local ped = GetPlayerPed(source)
                    if not DoesEntityExist(ped) then return end
                    
                    local coords = GetEntityCoords(ped)
                    local heading = GetEntityHeading(ped)
                    local rad = math.rad(heading)
                    local forward = vec3(-math.sin(rad), math.cos(rad), 0.0)
                    local spawnCoords = vec3(coords.x + (forward.x * 0.8), coords.y + (forward.y * 0.8), coords.z - 0.9)
                    
                    -- Spawn dynamic prop drop with physics
                    local rotation = GetEntityRotation(ped)
                    local dropId = SpawnDrop(itemName, payload.count, spawnCoords, rotation, payload.fromSlot.metadata, false)
                    
                    if dropId then
                        -- Remove the item from player inventory slot
                        exports.ox_inventory:RemoveItem(source, itemName, payload.count, nil, payload.fromSlot.slot)
                        
                        -- Return false to abort ox_inventory's default drop container creation
                        return false
                    end
                else
                    -- Fallback to default ox_inventory floor stash
                    return true
                end
            end
        end)
    end
end)

-- Spawn persistently saved drops on startup (No persistence, so we do nothing here)
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- No persistence, so we do not load/recreate drops
    end
end)

-- Clean up props on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, drop in pairs(activeDrops) do
            local entity = NetworkGetEntityFromNetworkId(drop.netId)
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end
    end
end)

-- Callback to check if targeted object is a drop
lib.callback.register('nv_props:checkIfDrop', function(source, netId)
    return GetDropByNetId(netId) ~= nil
end)

-- Callback to check if player possesses an item
lib.callback.register('nv_props:hasItem', function(source, itemName)
    local item = exports.ox_inventory:GetItem(source, itemName, nil, false)
    return item and item.count > 0 or false
end)

-- Handle precise placement requests from clients
RegisterNetEvent('nv_props:placeItem', function(itemName, coords, rotation)
    local source = source
    local item = exports.ox_inventory:GetItem(source, itemName, nil, false)
    if item and item.count > 0 then
        -- Remove 1 quantity of the item
        if exports.ox_inventory:RemoveItem(source, itemName, 1, nil, item.slot) then
            -- Spawn dynamic prop drop
            SpawnDrop(itemName, 1, coords, rotation, item.metadata, false)
        end
    end
end)

-- Callback to collect/pick up a dropped item
lib.callback.register('nv_props:pickupItem', function(source, netId)
    local drop = GetDropByNetId(netId)
    if not drop then return false end
    
    -- Check if player can carry the item
    if not exports.ox_inventory:CanCarryItem(source, drop.itemName, drop.count) then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Seu inventário está muito pesado!' })
        return false
    end
    
    -- Delete the object
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
    
    -- Add the item back to the player
    exports.ox_inventory:AddItem(source, drop.itemName, drop.count, drop.metadata)
    
    -- Clear from active drops list and save
    activeDrops[drop.id] = nil
    SaveDrops()
    TriggerClientEvent('nv_props:syncDrops', -1, activeDrops)
    
    return drop.itemName
end)

-- Command to spawn items manually for admins
RegisterCommand('spawnprop', function(source, args)
    if source ~= 0 then
        -- Check permission (group.admin or command.spawnprop)
        if not IsPlayerAceAllowed(source, 'command.spawnprop') then
            TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Sem permissão!' })
            return
        end
        
        local itemName = args[1]
        local count = tonumber(args[2]) or 1
        if not itemName then return end
        
        local ped = GetPlayerPed(source)
        local coords = GetEntityCoords(ped)
        local forward = GetEntityForwardVector(ped)
        local spawnCoords = coords + (forward * 1.0)
        local rotation = GetEntityRotation(ped)
        
        SpawnDrop(itemName, count, spawnCoords, rotation, {}, false)
    end
end, false)
