-- ----------------------------------------- Posicionamento de Props e Spikes --

local isPlacing = false
local ghostEntity = nil

local function RotationToDirection(rotation)
    local adjustedRotation = vec3(
        (math.pi / 180.0) * rotation.x,
        (math.pi / 180.0) * rotation.y,
        (math.pi / 180.0) * rotation.z
    )
    return vec3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )
end

local function GetRaycastResult()
    local camCoords = GetGameplayCamCoords()
    local camRot = GetGameplayCamRot(2)
    local forwardVec = RotationToDirection(camRot)
    local drawCoords = camCoords + (forwardVec * 8.0)

    local handle = StartShapeTestLosProbe(
        camCoords.x, camCoords.y, camCoords.z,
        drawCoords.x, drawCoords.y, drawCoords.z,
        -1, cache.ped, 0
    )
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(handle)
    return hit, endCoords, entityHit
end

local function CleanGhost()
    if ghostEntity and DoesEntityExist(ghostEntity) then
        DeleteEntity(ghostEntity)
        ghostEntity = nil
    end
    isPlacing = false
end

local function StartPlacement(itemName)
    if isPlacing then return end

    local propData = Config.Props[itemName]
    if not propData then return end

    isPlacing = true
    lib.requestModel(propData.model)

    local playerCoords = GetEntityCoords(cache.ped)
    ghostEntity = CreateObject(propData.model, playerCoords.x, playerCoords.y, playerCoords.z, false, true, false)
    SetEntityAlpha(ghostEntity, 150, false)
    SetEntityCollision(ghostEntity, false, true)

    local rotation = vec3(0.0, 0.0, GetEntityHeading(cache.ped))

    lib.showTextUI('[Scroll / ← →] Rotacionar  \n[E] Confirmar  \n[X] Cancelar')

    CreateThread(function()
        while isPlacing do
            Wait(0)
            local hit, endCoords = GetRaycastResult()
            if hit then
                SetEntityCoords(ghostEntity, endCoords.x, endCoords.y, endCoords.z, false, false, false, false)
                SetEntityRotation(ghostEntity, rotation.x, rotation.y, rotation.z, 2, true)
            end

            DisableControlAction(0, 14, true) -- Scroll Up
            DisableControlAction(0, 15, true) -- Scroll Down

            if IsDisabledControlJustPressed(0, 14) or IsControlJustPressed(0, 174) then
                rotation = rotation + vec3(0.0, 0.0, 5.0)
            elseif IsDisabledControlJustPressed(0, 15) or IsControlJustPressed(0, 175) then
                rotation = rotation - vec3(0.0, 0.0, 5.0)
            end

            -- Confirmar [E]
            if IsControlJustPressed(0, 38) then
                lib.hideTextUI()
                local finalCoords = GetEntityCoords(ghostEntity)
                local finalRotation = GetEntityRotation(ghostEntity, 2)
                CleanGhost()

                lib.requestAnimDict('pickup_object')
                TaskPlayAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, 8.0, 1000, 48, 0, false, false, false)

                lib.callback.await('nv_police:placeProp', false, itemName, finalCoords, finalRotation)
                break
            -- Cancelar [X]
            elseif IsControlJustPressed(0, 73) then
                lib.hideTextUI()
                CleanGhost()
                break
            end
        end
    end)
end

local function useCone() StartPlacement('police_cone') end
local function useBarricade() StartPlacement('police_barricade') end
local function useSpike() StartPlacement('police_spike') end

exports('useCone', useCone)
exports('useBarricade', useBarricade)
exports('useSpike', useSpike)

-- ---------------------------------------------- Remoção via ALT (ox_target) --

CreateThread(function()
    local models = {}
    for _, cfg in pairs(Config.Props) do
        models[#models + 1] = cfg.model
    end

    exports.ox_target:addModel(models, {
        {
            name = 'nv_police_remove_prop',
            icon = 'fa-solid fa-trash',
            label = 'Remover Objeto',
            distance = 2.0,
            onSelect = function(data)
                local entity = data.entity
                if not DoesEntityExist(entity) then return end

                local netId = NetworkGetNetworkIdFromEntity(entity)

                lib.requestAnimDict('pickup_object')
                TaskPlayAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, 8.0, 1000, 48, 0, false, false, false)

                if lib.progressBar({
                    duration = 1000,
                    label = 'Recolhendo objeto...',
                    disable = { move = true, car = true, combat = true }
                }) then
                    local ok, err = lib.callback.await('nv_police:removeProp', false, netId)
                    if ok then
                        lib.notify({ type = 'success', description = 'Objeto recolhido.' })
                    else
                        lib.notify({ type = 'error', description = err or 'Não foi possível recolher.' })
                    end
                end
            end
        }
    })
end)

-- ---------------------------------- Detecção e Perfuração de Pneus (Spike) --

CreateThread(function()
    while true do
        Wait(250)
        local ped = cache.ped
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                local vehicleCoords = GetEntityCoords(vehicle)
                local spikes = GetGamePool('CObject')

                for i = 1, #spikes do
                    local obj = spikes[i]
                    if GetEntityModel(obj) == Config.Props['police_spike'].model then
                        local spikeCoords = GetEntityCoords(obj)
                        if #(vehicleCoords - spikeCoords) < 2.5 then
                            -- Furar pneus do veículo
                            for tyreIndex = 0, 7 do
                                if not IsVehicleTyreBurst(vehicle, tyreIndex, false) then
                                    SetVehicleTyreBurst(vehicle, tyreIndex, true, 1000.0)
                                end
                            end
                        end
                    end
                end
            end
        else
            Wait(750)
        end
    end
end)
