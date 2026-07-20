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

-- Predefinicoes do alinhador. Viraram DADOS em vez de um menu do ox_lib: a
-- mesma lista alimenta a aba "Props" do painel, e acrescentar um preset e
-- acrescentar uma linha aqui -- nao um bloco de menu novo.
local propPresets = {
    {
        label = 'Abastecendo (bico de gasolina)',
        model = 'prop_cs_fuel_nozle',
        dict  = 'timetable@gardener@filling_can',
        anim  = 'gar_ig_5_filling_can',
        bone  = 57005
    },
    {
        label = 'Abastecendo (galão)',
        model = 'w_am_jerrycan',
        dict  = 'weapon@w_sp_jerrycan',
        anim  = 'fire',
        bone  = 57005
    },
    {
        label = 'Parado (mãos na cintura)',
        model = 'prop_cs_fuel_nozle',
        dict  = 'amb@world_human_cop_idles@male@idle_b',
        anim  = 'idle_e',
        bone  = 57005
    },
    {
        label = 'Parado (gesticulando)',
        model = 'prop_cs_fuel_nozle',
        dict  = 'gestures@m@standing@casual',
        anim  = 'gesture_talk_heavy_a',
        bone  = 57005
    }
}

--- Estado atual do alinhador, para o painel desenhar os campos preenchidos.
local function getPropConfig()
    return {
        model    = propModel,
        dict     = animDict,
        anim     = animName,
        bone     = boneId,
        presets  = propPresets
    }
end

--- Aplica o que o painel digitou. Campo vazio mantem o valor anterior: o
--- formulario e parcial de proposito, e apagar tudo por engano nao deve
--- zerar uma configuracao que ja estava certa.
---@param data table
local function setPropConfig(data)
    if type(data) ~= 'table' then return end

    if type(data.model) == 'string' and data.model ~= '' then propModel = data.model end
    if type(data.dict) == 'string' and data.dict ~= '' then animDict = data.dict end
    if type(data.anim) == 'string' and data.anim ~= '' then animName = data.anim end

    local bone = tonumber(data.bone)
    if bone then boneId = math.floor(bone) end
end

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

--- Lista achatada dos alinhamentos salvos, para a aba "Props" do painel.
local function getSavedProps()
    local list = {}

    for model, anims in pairs(savedAttachments) do
        for anim, val in pairs(anims) do
            list[#list + 1] = {
                model = model,
                anim  = anim,
                dict  = val.animDict,
                label = val.name or model,
                bone  = val.boneId
            }
        end
    end

    table.sort(list, function(a, b) return a.label < b.label end)

    return list
end

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
-- COORDS OVERLAY (LEITURA AO VIVO)
-- ==========================================================================
--
-- Substitui o menu de duas opcoes que existia aqui. O menu obrigava a fechar,
-- andar ate o ponto, reabrir o menu e so entao copiar -- e nesse caminho voce
-- nao via o numero mudando. O overlay fica na tela enquanto voce anda:
--
--   [ENTER]     copia vec4 (com heading) -- formato de spawn
--   [TAB]       copia vec3
--   [BACKSPACE] fecha
--
local coordsOverlay = false

--- Uma linha de texto do jogo, centralizada em `x`.
---@param text string
---@param x number
---@param y number
---@param scale number
local function drawCentredText(text, x, y, scale)
    SetTextFont(4)
    SetTextScale(0.0, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    -- Contorno: o texto fica sobre o mundo, e sem ele some em cenario claro.
    SetTextOutline()

    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

--- Abre a leitura de coordenadas no topo da tela.
---
--- Exportado porque o nv_garage tambem precisa dele (/nvgaragecoords): duas
--- copias desta thread em resources diferentes sairiam de sincronia na
--- primeira mudanca de tecla.
local function startCoordsOverlay()
    if coordsOverlay then return end
    coordsOverlay = true

    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    CreateThread(function()
        while coordsOverlay do
            Wait(0)

            local coords = GetEntityCoords(cache.ped)
            local heading = GetEntityHeading(cache.ped)

            local vec3Text = ('vec3(%.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z)
            local vec4Text = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(coords.x, coords.y, coords.z, heading)

            -- TAB abre a roda de armas: enquanto o overlay estiver aberto ela
            -- nao pode responder, senao copiar o vec3 troca a arma junto.
            DisableControlAction(0, 37, true)

            -- Fundo escuro atras do bloco inteiro, para o texto sobreviver a
            -- um ceu claro ou a uma parede branca. A altura cobre da linha do
            -- titulo (0.038) ate a base da linha de teclas (~0.146), e a
            -- largura acomoda um vec4 com coordenada negativa de 4 digitos,
            -- que e a string mais larga que este bloco chega a desenhar.
            DrawRect(0.5, 0.090, 0.38, 0.130, 0, 0, 0, 160)

            drawCentredText('~y~COORDENADAS', 0.5, 0.038, 0.42)
            drawCentredText(vec3Text, 0.5, 0.068, 0.45)
            drawCentredText(vec4Text, 0.5, 0.096, 0.45)
            drawCentredText('~g~[ENTER]~w~ vec4   ~g~[TAB]~w~ vec3   ~r~[BACKSPACE]~w~ fechar', 0.5, 0.126, 0.34)

            -- ENTER (INPUT_FRONTEND_ACCEPT): vec4, o formato de vaga/spawn.
            if IsControlJustPressed(0, 201) then
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                lib.setClipboard(vec4Text)
                lib.notify({ type = 'success', description = ('Copiado: %s'):format(vec4Text) })
            end

            -- TAB (INPUT_SELECT_WEAPON), desabilitado acima -- por isso a
            -- leitura tem que ser a versao `Disabled`.
            if IsDisabledControlJustPressed(0, 37) then
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                lib.setClipboard(vec3Text)
                lib.notify({ type = 'success', description = ('Copiado: %s'):format(vec3Text) })
            end

            -- BACKSPACE (INPUT_FRONTEND_CANCEL).
            if IsControlJustPressed(0, 177) then
                PlaySoundFrontend(-1, "QUIT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                coordsOverlay = false
            end
        end
    end)
end

--- Nunca deixar o overlay preso na tela se o resource cair no meio.
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        coordsOverlay = false
    end
end)

exports('CoordsOverlay', startCoordsOverlay)

-- ==========================================================================
-- INTERFACE DO MENU
-- ==========================================================================

--[[ MENUS DO OX_LIB REMOVIDOS

    O menu de contexto (`lib.registerContext`) era a interface deste resource:
    principal, jogadores, acoes de jogador, eventos e o dialogo de veiculo.
    Tudo isso agora vive no painel -- html/panel.js + client/panel.lua.

    O motivo de nao manter as duas portas: elas divergem. Cada acao nova teria
    que ser escrita duas vezes, e a copia esquecida vira o bug que so aparece
    para quem usou o caminho antigo.

    O que sobrou de ox_lib aqui sao NOTIFICACOES (`lib.notify`), o texto de
    tela do editor de props (`lib.showTextUI`) e UM `lib.inputDialog` -- o que
    pede o nome ao salvar um alinhamento, que acontece no meio da edicao em
    mundo, com o painel fechado.
]]

--- Abre o painel de organizações (resource nv_orgs).
---
--- Chamado por export e não por evento: assim, se o nv_orgs estiver parado ou
--- tiver falhado ao carregar, o administrador recebe uma mensagem em vez de um
--- clique que não faz nada. Um evento seria engolido em silêncio.
local function openOrgsPanel()
    if GetResourceState('nv_orgs') ~= 'started' then
        return lib.notify({
            type = 'error',
            description = 'O nv_orgs não está rodando.'
        })
    end

    local ok = pcall(function() exports.nv_orgs:open() end)

    if not ok then
        lib.notify({
            type = 'error',
            description = 'O nv_orgs está rodando mas não respondeu. Veja o console (F8).'
        })
    end
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

--- `/adminmenu` continua existindo -- so que agora abre o painel.
---
--- `AdminTools.openPanel` e preenchido pelo client/panel.lua, que carrega
--- depois deste arquivo. Por isso a checagem: se o painel falhar ao carregar,
--- o comando diz isso em vez de nao fazer nada.
RegisterNetEvent('nv_adminmenu:client:openMenu', function()
    if AdminTools and AdminTools.openPanel then return AdminTools.openPanel() end

    lib.notify({
        type = 'error',
        description = 'O painel não carregou. Veja o console (F8).'
    })
end)

-- ==========================================================================
-- PONTE PARA O PAINEL (client/panel.lua)
--
-- As funcoes acima sao locais deste arquivo, e o painel precisa das mesmas
-- acoes. Em vez de duplicar o codigo -- o que garantiria que uma das copias
-- ficaria para tras na proxima mudanca -- elas sao publicadas aqui.
--
-- `openPanel` vai no sentido contrario: e o panel.lua que preenche, para que
-- o comando /adminmenu aqui em cima alcance a tela.
-- ==========================================================================
AdminTools = {
    toggleNoclip       = toggleNoclip,
    noclipActive       = function() return noclip end,
    startPropSelection = startPropSelection,
    startCoordsOverlay = startCoordsOverlay,
    startPropAlign     = startAdjustment,
    getPropConfig      = getPropConfig,
    setPropConfig      = setPropConfig,
    getSavedProps      = getSavedProps,
    openOrgs           = openOrgsPanel,
    openPanel          = nil
}
