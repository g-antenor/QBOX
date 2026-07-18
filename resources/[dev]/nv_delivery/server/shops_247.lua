local activeShopDrivers = {}

-- Callback to start the 24/7 shop delivery job and spawn the truck
lib.callback.register('nv_delivery:startShopJob', function(source)
    local src = tonumber(source)
    if activeShopDrivers[src] then
        return false, "Você já está em uma entrega de suprimentos 24/7!"
    end

    -- Select 3 random 24/7 shop locations for this run
    local locations = {}
    local selectedIndexes = {}
    while #locations < 3 do
        local randIndex = math.random(1, #Config.Shops247.locations)
        if not selectedIndexes[randIndex] then
            selectedIndexes[randIndex] = true
            table.insert(locations, {
                id = randIndex,
                config = Config.Shops247.locations[randIndex]
            })
        end
    end

    -- Spawn delivery truck
    local truckModel = Config.Shops247.truckModel
    local tSpawn = Config.Shops247.truckSpawn
    local truck = CreateVehicle(truckModel, tSpawn.x, tSpawn.y, tSpawn.z, tSpawn.w, true, true)
    
    local timeout = 0
    while not DoesEntityExist(truck) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if not DoesEntityExist(truck) then
        return false, "Erro ao instanciar o caminhão de entrega."
    end

    local truckNetId = NetworkGetNetworkIdFromEntity(truck)

    -- Give player the 3 supply boxes (reusing delivery_large_package)
    for i, loc in ipairs(locations) do
        local metadata = {
            deliveryCoords = loc.config.coords,
            deliveryLabel = loc.config.label,
            deliveryType = 'shop',
            shopId = loc.id,
            description = "Suprimentos para: " .. loc.config.label
        }
        exports.ox_inventory:AddItem(src, 'delivery_large_package', 1, metadata)
    end

    activeShopDrivers[src] = {
        truck = truck,
        truckNet = truckNetId,
        locations = locations,
        deliveredCount = 0
    }

    return true, { truckNet = truckNetId, locations = locations }
end)

-- Callback to complete a 24/7 shop delivery
lib.callback.register('nv_delivery:completeShopDelivery', function(source, slotIndex)
    local src = tonumber(source)
    local session = activeShopDrivers[src]
    if not session then return false end

    local item = exports.ox_inventory:GetSlot(src, slotIndex)
    if not item or item.name ~= 'delivery_large_package' or (item.metadata and item.metadata.deliveryType ~= 'shop') then
        return false
    end

    local shopId = item.metadata.shopId
    local deliveryCoords = item.metadata.deliveryCoords
    if not shopId or not deliveryCoords then return false end

    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local dist = #(playerCoords - vector3(deliveryCoords.x, deliveryCoords.y, deliveryCoords.z))
    if dist > 10.0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Você não está na entrada de serviço correta!' })
        return false
    end

    -- Remove package
    if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, slotIndex) then
        -- Deduct from 24/7 shop registry cash
        local cost = Config.Shops247.deliveryCost
        MySQL.update("UPDATE `shops_247` SET `cash` = math.max(0, `cash` - ?) WHERE `id` = ?", { cost, shopId })

        -- Pay driver
        local pay = Config.Shops247.deliveryReward
        exports.ox_inventory:AddItem(src, 'money', pay)

        session.deliveredCount = session.deliveredCount + 1

        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = string.format("Carga entregue! A loja pagou $%d pela entrega. Você recebeu $%d!", cost, pay)
        })

        TriggerClientEvent('nv_delivery:shopDelivered', src, shopId)

        -- If all 3 deliveries done, complete job
        if session.deliveredCount >= 3 then
            TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = "Todas as cargas foram entregues! Dirija-se de volta ao Gerente." })
            if DoesEntityExist(session.truck) then
                DeleteEntity(session.truck)
            end
            activeShopDrivers[src] = nil
            TriggerClientEvent('nv_delivery:cleanShopJob', src)
        end

        return true
    end

    return false
end)

-- Event to cancel the 24/7 job
RegisterNetEvent('nv_delivery:finishShopJob', function()
    local src = tonumber(source)
    local session = activeShopDrivers[src]
    if not session then return end

    if DoesEntityExist(session.truck) then
        DeleteEntity(session.truck)
    end

    -- Clean up any remaining delivery boxes from their inventory
    local items = exports.ox_inventory:GetSlotsWithItem(src, 'delivery_large_package')
    if items then
        for _, item in ipairs(items) do
            if item.metadata and item.metadata.deliveryType == 'shop' then
                exports.ox_inventory:RemoveItem(src, 'delivery_large_package', item.count, nil, item.slot)
            end
        end
    end

    activeShopDrivers[src] = nil
    TriggerClientEvent('nv_delivery:cleanShopJob', src)
    TriggerClientEvent('ox_lib:notify', src, { type = 'info', description = "Serviço de entregas 24/7 encerrado." })
end)

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    local session = activeShopDrivers[src]
    if session then
        if DoesEntityExist(session.truck) then DeleteEntity(session.truck) end
        activeShopDrivers[src] = nil
    end
end)
