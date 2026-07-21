local openProject
local spawnedProps = {}
local targetZones = {}
local runtimeProjects = {}

local function closeCrafting()
    if not openProject then return end
    if lib.progressActive() then lib.cancelProgress() end
    openProject = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openCrafting(projectId)
    if openProject then return end
    local payload, err = lib.callback.await('nv_crafting:open', false, projectId)
    if not payload then
        return lib.notify({ type = 'error', description = err or 'Bancada indisponivel.' })
    end

    openProject = projectId
    payload.action = 'open'
    payload.imagePath = Config.InventoryImagePath
    SetNuiFocus(true, true)
    SendNUIMessage(payload)
end

RegisterNUICallback('close', function(_, cb)
    closeCrafting()
    cb(1)
end)

RegisterNUICallback('craft', function(data, cb)
    if not openProject or type(data) ~= 'table' then
        return cb({ ok = false, error = 'Projeto invalido.' })
    end

    -- Guarda o id antes de fechar: a fabricacao e a animacao acontecem com a
    -- NUI fechada e o resultado permanece na bancada para retirada posterior.
    local projectId = openProject
    closeCrafting()

    local ok, result = lib.callback.await('nv_crafting:craft', false, projectId, data.recipe, data.quantity)
    if not ok then
        lib.notify({ type = 'error', description = result or 'Nao foi possivel fabricar.' })
        return cb({ ok = false, error = result })
    end

    lib.notify({
        type = 'success',
        title = 'Fabricacao concluida',
        description = 'O item esta pronto para retirada na bancada.'
    })

    cb({ ok = true, inventory = result.inventory })
end)

RegisterNUICallback('takeOutput', function(data, cb)
    if not openProject then return cb({ ok = false, error = 'Bancada fechada.' }) end
    local ok, result = lib.callback.await('nv_crafting:takeOutput', false, openProject, data.id)
    if not ok then return cb({ ok = false, error = result }) end
    cb({ ok = true, inventory = result.inventory, outputs = result.outputs })
end)

RegisterNUICallback('takeAllOutputs', function(_, cb)
    if not openProject then return cb({ ok = false, error = 'Bancada fechada.' }) end
    local ok, result = lib.callback.await('nv_crafting:takeAllOutputs', false, openProject)
    if not ok then return cb({ ok = false, error = result }) end
    cb({ ok = true, inventory = result.inventory, outputs = result.outputs, taken = result.taken })
end)

RegisterNUICallback('refreshOutputs', function(_, cb)
    if not openProject then return cb({ ok = false }) end
    local ok, result = lib.callback.await('nv_crafting:getOutputs', false, openProject)
    cb({ ok = ok == true, outputs = ok and result or nil })
end)

lib.callback.register('nv_crafting:progress', function(duration, label)
    local completed = lib.progressBar({
        duration = duration,
        label = ('Fabricando %s'):format(label),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }
    })
    return completed
end)

local function clearProjects()
    for _,zone in ipairs(targetZones) do exports.ox_target:removeZone(zone) end
    for _,entity in ipairs(spawnedProps) do if DoesEntityExist(entity) then DeleteEntity(entity) end end
    targetZones={};spawnedProps={}
end

local function buildProjects()
    clearProjects()
    local list=lib.callback.await('nv_crafting:projects',false) or Config.Projects
    runtimeProjects=list
    for i = 1, #list do
        local project = list[i]
        local entity

        if project.prop and project.prop.enabled then
            local hash = joaat(project.prop.model or 'prop_tool_box_04')
            if lib.requestModel(hash, 5000) then
                local offset = project.prop.offset or vec3(0.0, 0.0, 0.0)
                entity = CreateObject(hash, project.coords.x + offset.x, project.coords.y + offset.y,
                    project.coords.z + offset.z, false, false, false)
                SetEntityHeading(entity, project.heading or 0.0)
                FreezeEntityPosition(entity, true)
                SetEntityInvincible(entity, true)
                SetModelAsNoLongerNeeded(hash)
                spawnedProps[#spawnedProps + 1] = entity
            end
        end

        local option = {
            name = ('nv_crafting:%s'):format(project.id),
            label = 'Abrir bancada de crafting',
            icon = 'fa-solid fa-screwdriver-wrench',
            distance = Config.InteractionDistance,
            groups = not project.public and project.access and { [project.access.set] = project.access.minGrade or 0 } or nil,
            onSelect = function() openCrafting(project.id) end
        }

        -- A interacao fica sempre nas coordenadas. Props pequenos (como a
        -- caixa de ferramentas) possuem hitbox dificil de mirar e nao podem
        -- ser a unica forma de abrir a bancada.
        targetZones[#targetZones + 1] = exports.ox_target:addSphereZone({
            name = ('nv_crafting_zone:%s'):format(project.id),
            coords = project.coords,
            radius = 1.25,
            debug = false,
            drawSprite = false,
            options = { option }
        })
    end
end

CreateThread(buildProjects)
RegisterNetEvent('nv_crafting:refreshProjects',buildProjects)

-- Marcador visivel mesmo antes de ativar o terceiro olho do ox_target.
CreateThread(function()
    while true do
        local wait = 1000
        local pedCoords = GetEntityCoords(cache.ped)

        local visibleProjects=runtimeProjects
        for i = 1, #visibleProjects do
            local project = visibleProjects[i]
            local marker = project.marker

            if marker ~= false then
                marker = type(marker) == 'table' and marker or Config.Marker

                if marker and marker.enabled ~= false then
                    local distance = #(pedCoords - project.coords)

                    if distance <= (marker.drawDistance or 25.0) then
                        wait = 0
                        local scale = marker.scale or vec3(0.55, 0.55, 0.18)
                        local color = marker.color or { r = 229, g = 43, b = 67, a = 155 }

                        DrawMarker(marker.type or 1,
                            project.coords.x, project.coords.y, project.coords.z + (marker.zOffset or -0.92),
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            scale.x, scale.y, scale.z,
                            color.r, color.g, color.b, color.a,
                            false, false, 2, false, nil, nil, false)
                    end
                end
            end
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if openProject then SetNuiFocus(false, false) end
    for i = 1, #targetZones do
        pcall(function() exports.ox_target:removeZone(targetZones[i]) end)
    end
    for i = 1, #spawnedProps do
        if DoesEntityExist(spawnedProps[i]) then DeleteEntity(spawnedProps[i]) end
    end
end)
