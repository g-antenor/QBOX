-- ==========================================================================
-- PROP ALIGNMENT EDITOR (MIGRATED FROM NV_SYNCITENS)
-- ==========================================================================
local isEditing = false
local propModel = "prop_amb_beer_bottle"
local animDict = "amb@world_human_drinking@coffee@male@idle_a"
local animName = "idle_c"
local boneId = 28422

local offsetX, offsetY, offsetZ = 0.0, 0.0, 0.0
local rotX, rotY, rotZ = 0.0, 0.0, 0.0

local savedAttachments = {}

-- Request database sync from server on startup
CreateThread(function()
    Wait(1000)
    TriggerServerEvent("nv_syncitens:server:requestSync")
end)

RegisterNetEvent("nv_syncitens:client:syncAttachments", function(data)
    savedAttachments = data
end)

-- Helper function to request animations
local function requestAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function saveAttachment(model, animD, animN, bone, offX, offY, offZ, rX, rY, rZ, customName)
    local data = {
        name = customName,
        animDict = animD,
        animName = animN,
        boneId = bone,
        offset = { x = offX, y = offY, z = offZ },
        rotation = { x = rX, y = rY, z = rZ }
    }
    TriggerServerEvent("nv_syncitens:server:saveAttachment", model, customName, data)
end

local function startAdjustment()
    if isEditing then return end
    isEditing = true

    lib.requestModel(propModel)
    requestAnimDict(animDict)

    local ped = cache.ped
    local coords = GetEntityCoords(ped)

    FreezeEntityPosition(ped, true)
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 51, 0, false, false, false)

    local modelHash = GetHashKey(propModel)
    local prop = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, boneId), offsetX, offsetY, offsetZ, rotX, rotY, rotZ, true, true, false, true, 1, true)

    CreateThread(function()
        while isEditing do
            Wait(0)
            local currentPed = cache.ped

            if not IsEntityPlayingAnim(currentPed, animDict, animName, 3) then
                TaskPlayAnim(currentPed, animDict, animName, 8.0, -8.0, -1, 51, 0, false, false, false)
            end

            local speedMultiplier = 1.0
            if IsControlPressed(0, 21) then -- SHIFT
                speedMultiplier = 5.0
            elseif IsControlPressed(0, 19) then -- ALT
                speedMultiplier = 0.2
            end

            local translateStep = 0.005 * speedMultiplier
            local rotateStep = 1.0 * speedMultiplier

            DisableControlAction(0, 32, true) -- W
            DisableControlAction(0, 33, true) -- S
            DisableControlAction(0, 34, true) -- A
            DisableControlAction(0, 35, true) -- D
            DisableControlAction(0, 44, true) -- Q
            DisableControlAction(0, 38, true) -- E
            DisableControlAction(0, 172, true) -- Arrow Up
            DisableControlAction(0, 173, true) -- Arrow Down
            DisableControlAction(0, 174, true) -- Arrow Left
            DisableControlAction(0, 175, true) -- Arrow Right
            DisableControlAction(0, 10, true) -- Page Up
            DisableControlAction(0, 11, true) -- Page Down
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim

            if IsDisabledControlPressed(0, 32) then offsetY = offsetY + translateStep
            elseif IsDisabledControlPressed(0, 33) then offsetY = offsetY - translateStep end

            if IsDisabledControlPressed(0, 34) then offsetX = offsetX - translateStep
            elseif IsDisabledControlPressed(0, 35) then offsetX = offsetX + translateStep end

            if IsDisabledControlPressed(0, 44) then offsetZ = offsetZ - translateStep
            elseif IsDisabledControlPressed(0, 38) then offsetZ = offsetZ + translateStep end

            if IsDisabledControlPressed(0, 172) then rotX = rotX + rotateStep
            elseif IsDisabledControlPressed(0, 173) then rotX = rotX - rotateStep end

            if IsDisabledControlPressed(0, 174) then rotY = rotY - rotateStep
            elseif IsDisabledControlPressed(0, 175) then rotY = rotY + rotateStep end

            if IsDisabledControlPressed(0, 10) then rotZ = rotZ + rotateStep
            elseif IsDisabledControlPressed(0, 11) then rotZ = rotZ - rotateStep end

            AttachEntityToEntity(prop, currentPed, GetPedBoneIndex(currentPed, boneId), offsetX, offsetY, offsetZ, rotX, rotY, rotZ, true, true, false, true, 1, true)

            local labelText = string.format(
                "| **DADOS DO PROP** | **CONTROLES DO EDITOR** |\n" ..
                "| :--- | :--- |\n" ..
                "| **Modelo:** `%s` | `W / S`: Offset Y (Frente/Trás) |\n" ..
                "| **Anim Dict:** `%s` | `A / D`: Offset X (Esq/Dir) |\n" ..
                "| **Anim Name:** `%s` | `Q / E`: Offset Z (Subir/Descer) |\n" ..
                "| **Bone ID:** `%d` | `Setas ↑ / ↓`: Rotação X |\n" ..
                "| **Pos X:** `%.4f` | `Setas ← / →`: Rotação Y |\n" ..
                "| **Pos Y:** `%.4f` | `Page Up / Down`: Rotação Z |\n" ..
                "| **Pos Z:** `%.4f` | `SHIFT`: Rápido  \\|  `ALT`: Lento |\n" ..
                "| **Rot X:** `%.1f` | [**ENTER**] Salvar  \\|  [**BACKSPACE**] Sair |\n" ..
                "| **Rot Y:** `%.1f` | |\n" ..
                "| **Rot Z:** `%.1f` | |",
                propModel, animDict, animName, boneId, offsetX, offsetY, offsetZ, rotX, rotY, rotZ
            )
            lib.showTextUI(labelText, {
                position = "bottom-center",
                style = {
                    width = '520px',
                    padding = '14px',
                    borderRadius = '6px',
                    backgroundColor = '#17161a',
                    border = '1px solid #232025',
                    color = '#e6e4e3',
                    fontSize = '11px',
                    fontFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif',
                    boxShadow = '0 10px 25px rgba(0, 0, 0, 0.65)',
                    marginBottom = '20px'
                }
            })

            if IsControlJustPressed(0, 18) or IsControlJustPressed(0, 201) then
                isEditing = false
                lib.hideTextUI()
                
                lib.setNuiFocus(true, true)
                local input = lib.inputDialog('Salvar Ajuste de Prop', {
                    { type = 'input', label = 'Nome do Registro / Identificador', placeholder = 'Ex: carregar_caixa_pesada', required = true }
                })
                lib.setNuiFocus(false, false)
                
                if input and input[1] then
                    saveAttachment(propModel, animDict, animName, boneId, offsetX, offsetY, offsetZ, rotX, rotY, rotZ, input[1])
                else
                    lib.notify({ type = 'error', description = 'Ajuste cancelado e não foi salvo.' })
                end

                DetachEntity(prop, true, true)
                DeleteEntity(prop)
                FreezeEntityPosition(currentPed, false)
                ClearPedTasks(currentPed)
                break
            end

            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) then
                isEditing = false
                lib.hideTextUI()
                DetachEntity(prop, true, true)
                DeleteEntity(prop)
                FreezeEntityPosition(currentPed, false)
                ClearPedTasks(currentPed)
                lib.notify({ type = 'info', description = 'Editor fechado.' })
                break
            end
        end
    end)
end

local function openPresetsMenu()
    lib.registerContext({
        id = 'nv_syncitens_presets',
        title = 'Predefinições de Props',
        menu = 'nv_syncitens_main',
        options = {
            {
                title = 'Abastecendo (Bico de Gasolina)',
                description = 'Prop: prop_cs_fuel_nozle | Anim: timetable@gardener@filling_can',
                icon = 'fa-solid fa-gas-pump',
                onSelect = function()
                    propModel = 'prop_cs_fuel_nozle'
                    animDict = 'timetable@gardener@filling_can'
                    animName = 'gar_ig_5_filling_can'
                    boneId = 57005
                    lib.notify({ type = 'success', description = 'Preset de Abastecimento carregado!' })
                    openPresetsMenu()
                end
            },
            {
                title = 'Abastecendo (Galão de Gasolina)',
                description = 'Prop: w_am_jerrycan | Anim: weapon@w_sp_jerrycan',
                icon = 'fa-solid fa-faucet',
                onSelect = function()
                    propModel = 'w_am_jerrycan'
                    animDict = 'weapon@w_sp_jerrycan'
                    animName = 'fire'
                    boneId = 57005
                    lib.notify({ type = 'success', description = 'Preset de Galão carregado!' })
                    openPresetsMenu()
                end
            },
            {
                title = 'Parado Normal (Mãos nos Bolsos/Cintura)',
                description = 'Prop: prop_cs_fuel_nozle | Anim: amb@world_human_cop_idles@male@idle_b',
                icon = 'fa-solid fa-child',
                onSelect = function()
                    propModel = 'prop_cs_fuel_nozle'
                    animDict = 'amb@world_human_cop_idles@male@idle_b'
                    animName = 'idle_e'
                    boneId = 57005
                    lib.notify({ type = 'success', description = 'Preset de Parado Normal carregado!' })
                    openPresetsMenu()
                end
            },
            {
                title = 'Parado Normal (Gesticulando)',
                description = 'Prop: prop_cs_fuel_nozle | Anim: gestures@m@standing@casual',
                icon = 'fa-solid fa-comments',
                onSelect = function()
                    propModel = 'prop_cs_fuel_nozle'
                    animDict = 'gestures@m@standing@casual'
                    animName = 'gesture_talk_heavy_a'
                    boneId = 57005
                    lib.notify({ type = 'success', description = 'Preset de Gesticulando carregado!' })
                    openPresetsMenu()
                end
            }
        }
    })
    lib.showContext('nv_syncitens_presets')
end

local function openConfigMenu()
    lib.registerContext({
        id = 'nv_syncitens_main',
        title = 'Alinhador de Props',
        options = {
            {
                title = 'Configurações de Ajuste',
                description = string.format("Modelo: %s | Bone: %d", propModel, boneId),
                icon = 'fa-solid fa-gear',
                onSelect = function()
                    local input = lib.inputDialog('Configurar Prop', {
                        { type = 'input', label = 'Modelo do Prop', default = propModel, required = true },
                        { type = 'input', label = 'Dicionário de Animação', default = animDict, required = true },
                        { type = 'input', label = 'Nome da Animação', default = animName, required = true },
                        { type = 'number', label = 'ID do Osso (Bone ID)', default = boneId, required = true }
                    })
                    if input then
                        propModel = input[1]
                        animDict = input[2]
                        animName = input[3]
                        boneId = tonumber(input[4]) or 28422
                        lib.notify({ type = 'success', description = 'Configurações atualizadas!' })
                    end
                    openConfigMenu()
                end
            },
            {
                title = 'Carregar Predefinição (Presets)',
                description = 'Abastecimento, parado, galões e gesticulações.',
                icon = 'fa-solid fa-list',
                onSelect = function()
                    openPresetsMenu()
                end
            },
            {
                title = 'Iniciar Editor',
                description = 'Inicia a pré-visualização e ajuste do prop.',
                icon = 'fa-solid fa-play',
                onSelect = function()
                    startAdjustment()
                end
            }
        }
    })
    lib.showContext('nv_syncitens_main')
end

RegisterCommand('syncitens', function()
    -- Check admin first
    lib.callback('nv_adminmenu:server:isAdmin', false, function(allowed)
        if allowed then openConfigMenu() end
    end)
end, false)

-- Active prop handling commands
local activeProps = {}

RegisterCommand('holditem', function(source, args)
    local model = args[1] or "prop_amb_beer_bottle"
    local anim = args[2] or "idle"
    local ped = cache.ped

    if not savedAttachments[model] or not savedAttachments[model][anim] then
        lib.notify({ type = 'error', description = 'Nenhum alinhamento salvo para este prop e animação!' })
        return
    end

    local cfg = savedAttachments[model][anim]
    if activeProps[model] then
        DetachEntity(activeProps[model], true, true)
        DeleteEntity(activeProps[model])
        activeProps[model] = nil
    end

    lib.requestModel(model)
    requestAnimDict(cfg.animDict)

    TaskPlayAnim(ped, cfg.animDict, cfg.animName, 8.0, -8.0, -1, 49, 0, false, false, false)
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(GetHashKey(model), coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, cfg.boneId), cfg.offset.x, cfg.offset.y, cfg.offset.z, cfg.rotation.x, cfg.rotation.y, cfg.rotation.z, true, true, false, true, 1, true)
    activeProps[model] = prop
end, false)

RegisterCommand('stopitem', function()
    for model, prop in pairs(activeProps) do
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
    activeProps = {}
    ClearPedTasks(cache.ped)
    lib.notify({ type = 'info', description = 'Props removidos.' })
end, false)

RegisterCommand('refreshskin', function()
    TriggerEvent('illenium-appearance:client:reloadSkin')
end, false)

RegisterCommand('savedprops', function()
    local options = {}
    for model, anims in pairs(savedAttachments) do
        for animName, val in pairs(anims) do
            table.insert(options, {
                title = string.format("%s - %s", model, animName),
                description = string.format("Rótulo: %s | Bone: %d", val.name or "N/A", val.boneId),
                onSelect = function()
                    ExecuteCommand(string.format("holditem %s %s", model, animName))
                end
            })
        end
    end
    lib.registerContext({
        id = 'nv_syncitens_saved',
        title = 'Props Salvos',
        options = options
    })
    lib.showContext('nv_syncitens_saved')
end, false)

-- Register radial menu keybind (Z Key)
lib.addKeybind({
    name = 'radial_props_menu',
    description = 'Menu Radial de Props Alinhados',
    defaultKey = 'Z',
    onPressed = function()
        lib.registerRadial({
            id = 'radial_sync_props',
            items = {
                {
                    label = 'Parar Animações',
                    icon = 'ban',
                    onSelect = function()
                        ExecuteCommand('stopitem')
                    end
                },
                {
                    label = 'Recarregar Skin',
                    icon = 'user-gear',
                    onSelect = function()
                        ExecuteCommand('refreshskin')
                    end
                },
                {
                    label = 'Props Salvos',
                    icon = 'floppy-disk',
                    onSelect = function()
                        ExecuteCommand('savedprops')
                    end
                }
            }
        })
        lib.showRadial('radial_sync_props')
    end
})

-- ==========================================================================
-- NOCLIP FEATURE
-- ==========================================================================
local noclip = false
local noclipSpeed = 1.0

local function toggleNoclip()
    noclip = not noclip
    local ped = cache.ped
    if noclip then
        SetEntityInvincible(ped, true)
        SetEntityVisible(ped, false, false)
        SetEntityCollision(ped, false, false)
        FreezeEntityPosition(ped, true)
        lib.notify({ type = 'success', description = 'Noclip Ativado!' })
        
        CreateThread(function()
            while noclip do
                Wait(0)
                local currentPed = cache.ped
                local coords = GetEntityCoords(currentPed)
                local camRot = GetGameplayCamRot(2)
                
                local multiplier = noclipSpeed
                if IsControlPressed(0, 21) then -- Shift
                    multiplier = multiplier * 5.0
                elseif IsControlPressed(0, 19) then -- Alt
                    multiplier = multiplier * 0.2
                end
                
                local speed = 0.5 * multiplier
                
                local pitch = math.rad(camRot.x)
                local yaw = math.rad(camRot.z)
                
                local forwardX = -math.sin(yaw) * math.cos(pitch)
                local forwardY = math.cos(yaw) * math.cos(pitch)
                local forwardZ = math.sin(pitch)
                
                local rightX = math.cos(yaw)
                local rightY = math.sin(yaw)
                
                local newCoords = coords
                
                if IsControlPressed(0, 32) then -- W
                    newCoords = newCoords + vec3(forwardX * speed, forwardY * speed, forwardZ * speed)
                elseif IsControlPressed(0, 33) then -- S
                    newCoords = newCoords - vec3(forwardX * speed, forwardY * speed, forwardZ * speed)
                end
                
                if IsControlPressed(0, 34) then -- A
                    newCoords = newCoords - vec3(rightX * speed, rightY * speed, 0.0)
                elseif IsControlPressed(0, 35) then -- D
                    newCoords = newCoords + vec3(rightX * speed, rightY * speed, 0.0)
                end
                
                if IsControlPressed(0, 44) then -- Q (Go Up)
                    newCoords = newCoords + vec3(0.0, 0.0, speed)
                elseif IsControlPressed(0, 38) then -- E (Go Down)
                    newCoords = newCoords - vec3(0.0, 0.0, speed)
                end
                
                SetEntityCoordsNoOffset(currentPed, newCoords.x, newCoords.y, newCoords.z, true, true, true)
            end
        end)
    else
        SetEntityInvincible(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
        lib.notify({ type = 'error', description = 'Noclip Desativado!' })
    end
end

-- ==========================================================================
-- HELPER FUNCTIONS FOR SELECTION
-- ==========================================================================
local function RotationToDirection(rotation)
    local adjustedRotation = vec3(
        (math.pi / 180) * rotation.x,
        (math.pi / 180) * rotation.y,
        (math.pi / 180) * rotation.z
    )
    local direction = vec3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )
    return direction
end

-- Synchronous camera raycast to get entity looking at
local function RaycastGameplayCamera(distance)
    local cameraCoords = GetGameplayCamCoord()
    local cameraRotation = GetGameplayCamRot(2)
    local direction = RotationToDirection(cameraRotation)
    local destination = cameraCoords + direction * (distance or 25.0)
    
    local ped = cache.ped
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        cameraCoords.x, cameraCoords.y, cameraCoords.z,
        destination.x, destination.y, destination.z,
        511,
        ped,
        4
    )
    
    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(handle)
    return hit, entityHit, endCoords
end

-- ==========================================================================
-- PROP SELECTION TOOL (LASER/RAYCAST)
-- ==========================================================================
local isSelectingProp = false

local function startPropSelection()
    if isSelectingProp then return end
    isSelectingProp = true
    lib.showTextUI('[Clique Esquerdo] Copiar Nome do Prop  \n[ESC] Fechar e Sair', { position = 'left-center' })
    
    CreateThread(function()
        while isSelectingProp do
            Wait(0)
            
            -- Disable attack control (LMB) to prevent punching/shooting
            DisableControlAction(0, 24, true)
            DisablePlayerFiring(cache.ped, true)
            
            local hit, entity, coords = RaycastGameplayCamera(25.0)
            local entExists = hit and entity > 0 and DoesEntityExist(entity)
            local entityType = entExists and GetEntityType(entity) or 0
            
            if entityType == 3 then
                local modelHash = GetEntityModel(entity)
                local modelName = "Desconhecido"
                
                -- Check our mapping of prop hashes to names
                for _, val in ipairs(Config.PropList or {}) do
                    if GetHashKey(val) == modelHash then
                        modelName = tostring(val)
                        break
                    end
                end
                if modelName == "Desconhecido" then
                    modelName = tostring(modelHash)
                end
                
                -- Draw a stable sphere marker at the center of the entity
                local entCoords = GetEntityCoords(entity)
                DrawMarker(28, entCoords.x, entCoords.y, entCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 0, 255, 0, 150, false, true, 2, nil, nil, false)
                
                -- Display help text details
                SetTextComponentFormat('STRING')
                AddTextComponentString(('~g~Prop:~w~ %s\n~g~Hash:~w~ %s\n~g~Clique Esquerdo~w~ para copiar'):format(modelName, modelHash))
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                
                -- Detect Left Click
                if IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 24) then
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    lib.setClipboard(tostring(modelName))
                    lib.notify({ type = 'success', description = ('Copiado: %s'):format(modelName) })
                    Wait(300) -- Debounce
                end
            end
            
            -- Cancel controls: Only ESC (control 177 / 200 / 322)
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then
                PlaySoundFrontend(-1, "QUIT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                isSelectingProp = false
                break
            end
        end
        lib.hideTextUI()
    end)
end

-- ==========================================================================
-- ADMIN MENU CORE UI
-- ==========================================================================

local function openCoordsMenu()
    lib.registerContext({
        id = 'nv_adminmenu_coords',
        title = 'Copiar Coordenadas',
        menu = 'nv_adminmenu_main',
        options = {
            {
                title = 'Copiar Vector3',
                description = 'Copia em formato vec3(x, y, z)',
                icon = 'fa-solid fa-copy',
                onSelect = function()
                    local coords = GetEntityCoords(cache.ped)
                    local str = string.format("vec3(%.2f, %.2f, %.2f)", coords.x, coords.y, coords.z)
                    lib.setClipboard(str)
                    lib.notify({ type = 'success', description = 'Vector3 copiado!' })
                end
            },
            {
                title = 'Copiar Vector4',
                description = 'Copia em formato vec4(x, y, z, h)',
                icon = 'fa-solid fa-copy',
                onSelect = function()
                    local coords = GetEntityCoords(cache.ped)
                    local heading = GetEntityHeading(cache.ped)
                    local str = string.format("vec4(%.2f, %.2f, %.2f, %.2f)", coords.x, coords.y, coords.z, heading)
                    lib.setClipboard(str)
                    lib.notify({ type = 'success', description = 'Vector4 copiado!' })
                end
            }
        }
    })
    lib.showContext('nv_adminmenu_coords')
end

-- List of server events an admin can trigger from the Eventos menu.
-- Add new entries here to expose more events in-game.
local serverEvents = {
    {
        title = 'Evento: Postos de Gasolina',
        description = 'Coloca os postos em nível crítico e avisa os jogadores para iniciar as entregas de combustível',
        icon = 'fa-solid fa-gas-pump',
        event = 'nv_adminmenu:server:startGasEvent'
    }
}

local function openEventsMenu()
    local options = {}
    for _, ev in ipairs(serverEvents) do
        table.insert(options, {
            title = ev.title,
            description = ev.description,
            icon = ev.icon,
            arrow = true,
            onSelect = function()
                TriggerServerEvent(ev.event)
            end
        })
    end
    if #options == 0 then
        table.insert(options, {
            title = 'Nenhum evento disponível',
            disabled = true
        })
    end
    lib.registerContext({
        id = 'nv_adminmenu_events',
        title = 'Eventos',
        menu = 'nv_adminmenu_main',
        options = options
    })
    lib.showContext('nv_adminmenu_events')
end

local function openPlayerActionMenu(targetPlayer)
    lib.registerContext({
        id = 'nv_adminmenu_player_actions',
        title = targetPlayer.name,
        menu = 'nv_adminmenu_players',
        options = {
            {
                title = 'Tornar Administrador',
                description = 'Concede privilégios de administrador',
                icon = 'fa-solid fa-user-shield',
                onSelect = function()
                    TriggerServerEvent('nv_adminmenu:server:makeAdmin', targetPlayer.id)
                end
            },
            {
                title = 'Reviver',
                description = 'Ressuscita e cura o jogador',
                icon = 'fa-solid fa-heart-pulse',
                onSelect = function()
                    TriggerServerEvent('nv_adminmenu:server:revivePlayer', targetPlayer.id)
                end
            },
            {
                title = 'Puxar Jogador',
                description = 'Teleporta o jogador até você',
                icon = 'fa-solid fa-arrow-down-long',
                onSelect = function()
                    TriggerServerEvent('nv_adminmenu:server:pullPlayer', targetPlayer.id)
                end
            },
            {
                title = 'Dar Pedmenu',
                description = 'Abre o criador de peds/roupas para o jogador',
                icon = 'fa-solid fa-shirt',
                onSelect = function()
                    TriggerServerEvent('nv_adminmenu:server:givePedMenu', targetPlayer.id)
                end
            }
        }
    })
    lib.showContext('nv_adminmenu_player_actions')
end

local function openPlayersMenu()
    lib.callback('nv_adminmenu:server:getOnlinePlayers', false, function(players)
        local options = {}
        for _, player in ipairs(players) do
            table.insert(options, {
                title = string.format("[%d] %s", player.id, player.name),
                description = 'Clique para ações rápidas',
                icon = 'fa-solid fa-user',
                onSelect = function()
                    openPlayerActionMenu(player)
                end
            })
        end
        if #options == 0 then
            table.insert(options, {
                title = 'Nenhum jogador encontrado',
                disabled = true
            })
        end
        lib.registerContext({
            id = 'nv_adminmenu_players',
            title = 'Jogadores Online',
            menu = 'nv_adminmenu_main',
            options = options
        })
        lib.showContext('nv_adminmenu_players')
    end)
end

local function openAdminMenu()
    lib.registerContext({
        id = 'nv_adminmenu_main',
        title = 'Menu de Administrador',
        options = {
            {
                title = 'Modo Noclip',
                description = 'Voe pelo mapa (Ativar/Desativar)',
                icon = 'fa-solid fa-plane-set',
                onSelect = function()
                    toggleNoclip()
                end
            },
            {
                title = 'Menu de Ped / Roupas',
                description = 'Abre o editor de peds e roupas',
                icon = 'fa-solid fa-shirt',
                onSelect = function()
                    TriggerEvent('illenium-appearance:client:openClothingShopMenu', true)
                end
            },
            {
                title = 'Selecionar Prop (Copiar Nome)',
                description = 'Ativa a mira laser para selecionar e copiar props',
                icon = 'fa-solid fa-crosshairs',
                onSelect = function()
                    startPropSelection()
                end
            },
            {
                title = 'Copiar Coordenadas',
                description = 'Copia suas coordenadas em formato vector3/4',
                icon = 'fa-solid fa-location-crosshairs',
                onSelect = function()
                    openCoordsMenu()
                end
            },
            {
                title = 'Alinhador de Props (SyncItens)',
                description = 'Alinha objetos em ossos de animação',
                icon = 'fa-solid fa-screwdriver-wrench',
                onSelect = function()
                    openConfigMenu()
                end
            },
            {
                title = 'Jogadores Online',
                description = 'Reviver, Puxar, Tornar Admin ou dar Pedmenu',
                icon = 'fa-solid fa-users',
                onSelect = function()
                    openPlayersMenu()
                end
            },
            {
                title = 'Eventos',
                description = 'Aciona eventos do servidor (postos de gasolina, etc.)',
                icon = 'fa-solid fa-bolt',
                onSelect = function()
                    openEventsMenu()
                end
            }
        }
    })
    lib.showContext('nv_adminmenu_main')
end

-- NetEvents for target triggers
RegisterNetEvent('nv_adminmenu:client:revive', function()
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    TriggerEvent('hospital:client:Revive')
    TriggerEvent('qbx_medical:client:revive')
    
    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    end
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    lib.notify({ type = 'success', description = 'Você foi revivido pelo Administrador!' })
end)

RegisterNetEvent('nv_adminmenu:client:teleport', function(coords)
    local ped = cache.ped
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    lib.notify({ type = 'info', description = 'Você foi teleportado pelo Administrador!' })
end)

RegisterNetEvent('nv_adminmenu:client:openPedMenu', function()
    TriggerEvent('illenium-appearance:client:openClothingShopMenu', true)
end)

RegisterNetEvent('nv_adminmenu:client:openMenu', function()
    openAdminMenu()
end)
