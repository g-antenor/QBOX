local activeDrops = {}
local isPlacing = false
local ghostEntity = nil

RegisterNetEvent('nv_props:syncDrops', function(drops)
    activeDrops = drops
end)

-- Math helper: convert rotation vector to direction vector
local function RotationToDirection(rotation)
    local adjustedRotation = vec3(
        (math.pi / 180.0) * rotation.x,
        (math.pi / 180.0) * rotation.y,
        (math.pi / 180.0) * rotation.z
    )
    local direction = vec3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )
    return direction
end

-- Raycast to map exact coordinate offsets on surfaces (walls, floors, shelves)
local function GetRaycastResult()
    local camCoords = GetGameplayCamCoords()
    local camRot = GetGameplayCamRot(2)
    local forwardVec = RotationToDirection(camRot)
    local drawCoords = camCoords + (forwardVec * 8.0) -- maximum placement range 8m

    local handle = StartShapeTestLosProbe(
        camCoords.x, camCoords.y, camCoords.z,
        drawCoords.x, drawCoords.y, drawCoords.z,
        -1, cache.ped, 0
    )
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(handle)
    return hit, endCoords, entityHit
end

local function CleanGhost()
    if ghostEntity then
        DeleteEntity(ghostEntity)
        ghostEntity = nil
    end
    isPlacing = false
end

local function StartPlacement(itemName)
    if isPlacing then return end
    isPlacing = true

    local model = Config.Items[itemName] or Config.DefaultModel
    lib.requestModel(model)

    local playerCoords = GetEntityCoords(cache.ped)
    ghostEntity = CreateObject(model, playerCoords.x, playerCoords.y, playerCoords.z, false, true, false)
    SetEntityAlpha(ghostEntity, 150, false)
    SetEntityCollision(ghostEntity, false, true)

    local rotation = vec3(0.0, 0.0, GetEntityHeading(cache.ped))

    lib.showTextUI('[Scroll / ← →] Rotacionar  \n[E] Confirmar  \n[X] Cancelar')

    CreateThread(function()
        while isPlacing do
            Wait(0)
            local hit, endCoords, _ = GetRaycastResult()
            if hit then
                SetEntityCoords(ghostEntity, endCoords.x, endCoords.y, endCoords.z, false, false, false, false)
                SetEntityRotation(ghostEntity, rotation.x, rotation.y, rotation.z, 2, true)
            end

            -- Block normal scroll inputs during placement
            DisableControlAction(0, 14, true) -- Scroll Wheel Up
            DisableControlAction(0, 15, true) -- Scroll Wheel Down

            if IsDisabledControlJustPressed(0, 14) or IsControlJustPressed(0, 174) then -- Scroll Up / Arrow Left
                rotation = rotation + vec3(0.0, 0.0, 5.0)
            elseif IsDisabledControlJustPressed(0, 15) or IsControlJustPressed(0, 175) then -- Scroll Down / Arrow Right
                rotation = rotation - vec3(0.0, 0.0, 5.0)
            end

            -- Confirm placement
            if IsControlJustPressed(0, 38) then -- E
                lib.hideTextUI()
                local finalCoords = GetEntityCoords(ghostEntity)
                local finalRotation = GetEntityRotation(ghostEntity, 2)
                CleanGhost()
                TriggerServerEvent('nv_props:placeItem', itemName, finalCoords, finalRotation)
                break
            -- Cancel placement
            elseif IsControlJustPressed(0, 73) then -- X
                lib.hideTextUI()
                CleanGhost()
                break
            end
        end
    end)
end

-- Hook alt-key interaction using ox_target
CreateThread(function()
    exports.ox_target:addGlobalObject({
        {
            name = 'pickup_prop_drop',
            icon = 'fa-solid fa-hand',
            label = 'Pegar Item',
            distance = 1.0,
            canInteract = function(entity, distance, coords, name, bone)
                if not DoesEntityExist(entity) then return false end
                local netId = NetworkGetNetworkIdFromEntity(entity)
                if not netId or netId == 0 then return false end
                return lib.callback.await('nv_props:checkIfDrop', false, netId)
            end,
            onSelect = function(data)
                local netId = NetworkGetNetworkIdFromEntity(data.entity)
                
                -- Play pickup progress bar
                lib.requestAnimDict('pickup_object')
                TaskPlayAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, 8.0, 1000, 48, 0, false, false, false)
                
                if lib.progressBar({
                    duration = 1000,
                    label = 'Recolhendo...',
                    useLib = true,
                    disable = { move = true, car = true, combat = true }
                }) then
                    local itemName = lib.callback.await('nv_props:pickupItem', false, netId)
                    if not itemName then
                        ClearPedTasks(cache.ped)
                    end
                else
                    ClearPedTasks(cache.ped)
                end
            end
        }
    })
end)

-- Command to initiate placement mode
RegisterCommand('placeitem', function(source, args)
    local itemName = args[1]
    if not itemName then 
        lib.notify({ type = 'error', description = 'Especifique o nome do item! Ex: /placeitem water' })
        return 
    end
    
    local hasItem = lib.callback.await('nv_props:hasItem', false, itemName)
    if hasItem then
        StartPlacement(itemName)
    else
        lib.notify({ type = 'error', description = 'Você não possui este item!' })
    end
end, false)

-- Thread to ensure spawned drop entities have gravity, dynamics and physics active so they fall to the ground
CreateThread(function()
    local initializedDrops = {}
    while true do
        Wait(1000)
        -- Cleanup initializedDrops for drops that no longer exist
        for dropId in pairs(initializedDrops) do
            if not activeDrops[dropId] then
                initializedDrops[dropId] = nil
            end
        end

        for dropId, drop in pairs(activeDrops) do
            if not initializedDrops[dropId] then
                if NetworkDoesNetworkIdExist(drop.netId) then
                    local entity = NetworkGetEntityFromNetworkId(drop.netId)
                    if DoesEntityExist(entity) then
                        if not drop.frozen then
                            SetEntityDynamic(entity, true)
                            SetEntityHasGravity(entity, true)
                            ActivatePhysics(entity)
                            -- Apply a tiny downward force to kickstart physics
                            ApplyForceToEntity(entity, 1, 0.0, 0.0, -0.1, 0.0, 0.0, 0.0, 0, true, true, true, true, true)
                        end
                        initializedDrops[dropId] = true
                    end
                end
            end
        end
    end
end)
