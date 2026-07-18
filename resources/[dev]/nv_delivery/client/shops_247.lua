local activeJob = false
local jobTruckNet = nil
local npcPed = nil
local activeBlips = {}
local targetZones = {}

-- Helper to check if spawn position is clear
local function isSpawnClear(coords, radius)
    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        local veh = vehicles[i]
        if DoesEntityExist(veh) then
            local dist = #(coords - GetEntityCoords(veh))
            if dist < radius then
                return false
            end
        end
    end
    return true
end

-- Blip management
local function clearBlips()
    for _, blip in pairs(activeBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    activeBlips = {}
end

-- Target zone management
local function clearTargetZones()
    for _, zone in pairs(targetZones) do
        exports.ox_target:removeZone(zone)
    end
    targetZones = {}
end

-- Complete a backdoor delivery
local function deliverToShop(shopId, coords)
    local held = nil
    local items = exports.ox_inventory:GetSlotsWithItem('delivery_large_package')
    if items then
        for _, item in ipairs(items) do
            if item.metadata and item.metadata.deliveryType == 'shop' and item.metadata.shopId == shopId then
                held = item
                break
            end
        end
    end

    if not held then return end

    local slot = held.slot

    -- Animation: Crouching to place crate
    RequestAnimDict('pickup_object')
    while not HasAnimDictLoaded('pickup_object') do Wait(10) end
    TaskPlayAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 1000, 48, 0, false, false, false)
    Wait(800)

    local success = lib.callback.await('nv_delivery:completeShopDelivery', false, slot)
    if success then
        -- Spawn temporary prop at door
        local model = `prop_cs_box_step`
        lib.requestModel(model)
        local prop = CreateObject(model, coords.x, coords.y, coords.z - 0.98, true, true, false)
        PlaceObjectOnGroundProperly(prop)
        FreezeEntityPosition(prop, true)
        SetTimeout(8000, function()
            if DoesEntityExist(prop) then DeleteEntity(prop) end
        end)

        -- Clean blip and zone for this shop
        if activeBlips[shopId] then
            RemoveBlip(activeBlips[shopId])
            activeBlips[shopId] = nil
        end
        if targetZones[shopId] then
            exports.ox_target:removeZone(targetZones[shopId])
            targetZones[shopId] = nil
        end
    else
        ClearPedTasks(cache.ped)
    end
end

-- Spawn NPC and set up options
CreateThread(function()
    local npcConfig = Config.Shops247
    lib.requestModel(npcConfig.npcModel)
    npcPed = CreatePed(4, npcConfig.npcModel, npcConfig.npcCoords.x, npcConfig.npcCoords.y, npcConfig.npcCoords.z - 1.0, npcConfig.npcCoords.w, false, true)
    SetEntityInvincible(npcPed, true)
    FreezeEntityPosition(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)

    -- Play clipboard loop anim
    RequestAnimDict("amb@world_human_clipboard@male@idle_a")
    while not HasAnimDictLoaded("amb@world_human_clipboard@male@idle_a") do Wait(10) end
    TaskPlayAnim(npcPed, "amb@world_human_clipboard@male@idle_a", "idle_c", 8.0, -8.0, -1, 1, 0, false, false, false)

    exports.ox_target:addLocalEntity(npcPed, {
        {
            name = 'nv_delivery:shop_talk',
            label = 'Solicitar Entregas 24/7',
            icon = 'fa-solid fa-truck-moving',
            distance = 1.5,
            canInteract = function()
                return not activeJob
            end,
            onSelect = function()
                TaskStartScenarioInPlace(cache.ped, "WORLD_HUMAN_CLIPBOARD", 0, true)
                lib.progressBar({
                    duration = 3000,
                    label = 'Imprimindo guias de remessa...',
                    useLib = true,
                    disable = { move = true, car = true, combat = true }
                })
                ClearPedTasks(cache.ped)

                -- Check spawn spot
                local tSpawn = vec3(Config.Shops247.truckSpawn.x, Config.Shops247.truckSpawn.y, Config.Shops247.truckSpawn.z)
                if not isSpawnClear(tSpawn, 4.0) then
                    return lib.notify({
                        type = 'error',
                        description = "A vaga de spawn do caminhão está ocupada por outro veículo!"
                    })
                end

                -- Start Job
                local success, data = lib.callback.await('nv_delivery:startShopJob', false)
                if success then
                    activeJob = true
                    jobTruckNet = data.truckNet
                    clearBlips()
                    clearTargetZones()

                    -- Create Blips and Target Zones for the 3 selected stores
                    for _, loc in ipairs(data.locations) do
                        local shopId = loc.id
                        local cfg = loc.config

                        -- Blip
                        local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
                        SetBlipSprite(blip, 501) -- Delivery truck icon
                        SetBlipColour(blip, 2)   -- Green
                        SetBlipScale(blip, 0.8)
                        BeginTextCommandSetBlipName("STRING")
                        AddTextComponentString("Entrega: " .. cfg.label)
                        EndTextCommandSetBlipName(blip)
                        SetBlipRoute(blip, true)
                        activeBlips[shopId] = blip

                        -- Target sphere zone at backdoor coords
                        targetZones[shopId] = exports.ox_target:addSphereZone({
                            coords = cfg.coords,
                            radius = 1.2,
                            debug = false,
                            options = {
                                {
                                    name = 'nv_delivery:deliver_shop_crate',
                                    label = 'Descarregar Carga 24/7',
                                    icon = 'fa-solid fa-box-open',
                                    canInteract = function()
                                        if not activeJob then return false end
                                        -- Player must hold the large package for this specific shop
                                        local items = exports.ox_inventory:GetSlotsWithItem('delivery_large_package')
                                        if items then
                                            for _, item in ipairs(items) do
                                                if item.metadata and item.metadata.deliveryType == 'shop' and item.metadata.shopId == shopId then
                                                    return true
                                                end
                                            end
                                        end
                                        return false
                                    end,
                                    onSelect = function()
                                        deliverToShop(shopId, cfg.coords)
                                    end
                                }
                            }
                        })
                    end

                    lib.notify({
                        type = 'success',
                        description = "Entregas iniciadas! Carregue as caixas no caminhão Mule nos fundos."
                    })
                else
                    lib.notify({ type = 'error', description = data or "Erro ao iniciar serviço." })
                end
            end
        },
        {
            name = 'nv_delivery:shop_finish',
            label = 'Encerrar Serviço',
            icon = 'fa-solid fa-xmark',
            distance = 1.5,
            canInteract = function()
                return activeJob
            end,
            onSelect = function()
                TriggerServerEvent('nv_delivery:finishShopJob')
            end
        }
    })
end)

RegisterNetEvent('nv_delivery:shopDelivered', function(shopId)
    if activeBlips[shopId] then
        RemoveBlip(activeBlips[shopId])
        activeBlips[shopId] = nil
    end
    if targetZones[shopId] then
        exports.ox_target:removeZone(targetZones[shopId])
        targetZones[shopId] = nil
    end
end)

RegisterNetEvent('nv_delivery:cleanShopJob', function()
    activeJob = false
    jobTruckNet = nil
    clearBlips()
    clearTargetZones()
end)
