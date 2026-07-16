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
    local count = 0
    for model, anims in pairs(data) do
        for _ in pairs(anims) do
            count = count + 1
        end
    end
    print(string.format("[nv_syncitens] Sincronizados %d alinhamentos globais do banco de dados.", count))
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

    -- Request Model
    lib.requestModel(propModel)

    -- Request Anim Dict
    requestAnimDict(animDict)

    local ped = cache.ped
    local coords = GetEntityCoords(ped)

    -- Freeze player to prevent movement
    FreezeEntityPosition(ped, true)

    -- Play animation looping
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 51, 0, false, false, false)

    -- Spawn prop and attach
    local modelHash = GetHashKey(propModel)
    local prop = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, boneId), offsetX, offsetY, offsetZ, rotX, rotY, rotZ, true, true, false, true, 1, true)

    CreateThread(function()
        while isEditing do
            Wait(0)
            local currentPed = cache.ped

            -- Keep playing animation if stopped
            if not IsEntityPlayingAnim(currentPed, animDict, animName, 3) then
                TaskPlayAnim(currentPed, animDict, animName, 8.0, -8.0, -1, 51, 0, false, false, false)
            end

            -- Speed multiplier
            local speedMultiplier = 1.0
            if IsControlPressed(0, 21) then -- SHIFT
                speedMultiplier = 5.0
            elseif IsControlPressed(0, 19) then -- ALT
                speedMultiplier = 0.2
            end

            local translateStep = 0.005 * speedMultiplier
            local rotateStep = 1.0 * speedMultiplier

            -- Disable default movement/camera/aim controls to reuse keys
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

            -- Translations: WASD + QE
            -- Translate Y (Forward / Backward) using W / S
            if IsDisabledControlPressed(0, 32) then
                offsetY = offsetY + translateStep
            elseif IsDisabledControlPressed(0, 33) then
                offsetY = offsetY - translateStep
            end

            -- Translate X (Left / Right) using A / D
            if IsDisabledControlPressed(0, 34) then
                offsetX = offsetX - translateStep
            elseif IsDisabledControlPressed(0, 35) then
                offsetX = offsetX + translateStep
            end

            -- Translate Z (Up / Down) using Q / E
            if IsDisabledControlPressed(0, 44) then
                offsetZ = offsetZ - translateStep
            elseif IsDisabledControlPressed(0, 38) then
                offsetZ = offsetZ + translateStep
            end

            -- Rotations: Arrow Keys + PageUp/PageDown
            -- Rotate X (Pitch) using Arrow Up / Down
            if IsDisabledControlPressed(0, 172) then
                rotX = rotX + rotateStep
            elseif IsDisabledControlPressed(0, 173) then
                rotX = rotX - rotateStep
            end

            -- Rotate Y (Roll) using Arrow Left / Right
            if IsDisabledControlPressed(0, 174) then
                rotY = rotY - rotateStep
            elseif IsDisabledControlPressed(0, 175) then
                rotY = rotY + rotateStep
            end

            -- Rotate Z (Yaw) using Page Up / Down
            if IsDisabledControlPressed(0, 10) then
                rotZ = rotZ + rotateStep
            elseif IsDisabledControlPressed(0, 11) then
                rotZ = rotZ - rotateStep
            end

            -- Update attachment position
            AttachEntityToEntity(prop, currentPed, GetPedBoneIndex(currentPed, boneId), offsetX, offsetY, offsetZ, rotX, rotY, rotZ, true, true, false, true, 1, true)

            -- Format Text UI in a 2-column Markdown Table
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

            -- Confirm & Save (ENTER)
            if IsControlJustPressed(0, 18) or IsControlJustPressed(0, 201) then
                isEditing = false
                lib.hideTextUI()
                
                lib.setNuiFocus(true, true)
                local input = lib.inputDialog('Salvar Ajuste de Prop', {
                    { type = 'input', label = 'Nome do Registro / Identificador', placeholder = 'Ex: carregar_caixa_pesada', required = true }
                })
                lib.setNuiFocus(false, false)
                
                if input and input[1] and input[1] ~= "" then
                    local customName = input[1]
                    saveAttachment(propModel, animDict, animName, boneId, offsetX, offsetY, offsetZ, rotX, rotY, rotZ, customName)
                    DeleteEntity(prop)
                    FreezeEntityPosition(currentPed, false)
                    ClearPedTasks(currentPed)
                    break
                else
                    isEditing = true
                    lib.notify({ type = 'info', description = 'Identificador inválido. Voltou para a edição.' })
                end
            end

            -- Cancel & Discard (BACKSPACE/ESC)
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) then
                isEditing = false
                lib.hideTextUI()
                DeleteEntity(prop)
                FreezeEntityPosition(currentPed, false)
                ClearPedTasks(currentPed)
                lib.notify({ type = 'error', description = 'Ajuste cancelado e alterações descartadas.' })
                break
            end
        end
    end)
end

-- Main config menu using ox_lib
local function openConfigMenu()
    lib.registerContext({
        id = 'nv_syncitens_main',
        title = 'Ajustador de Props',
        options = {
            {
                title = 'Selecionar Animação',
                description = ('Atual: %s (%s)'):format(animDict, animName),
                icon = 'fa-solid fa-person-running',
                onSelect = function()
                    local input = lib.inputDialog('Animação', {
                        {
                            type = 'select',
                            label = 'Animação Predefinida',
                            options = {
                                { value = 'comer', label = 'Comer (Hambúrguer)' },
                                { value = 'beber', label = 'Beber (Café)' },
                                { value = 'fumar', label = 'Fumar (Cigarro)' },
                                { value = 'telefone', label = 'Telefone' },
                                { value = 'caixa', label = 'Carregar Caixa' },
                                { value = 'custom', label = 'Personalizada (Digitar Dict/Anim)' }
                            },
                            default = 'custom'
                        },
                        { type = 'input', label = 'Animation Dict (Para Personalizada)', placeholder = 'ex: mp_player_inteat@burger' },
                        { type = 'input', label = 'Animation Name (Para Personalizada)', placeholder = 'ex: mp_player_int_eat_burger' }
                    })

                    if not input then return openConfigMenu() end

                    local selection = input[1]
                    if selection == 'comer' then
                        animDict = 'mp_player_inteat@burger'
                        animName = 'mp_player_int_eat_burger'
                        boneId = 60309
                    elseif selection == 'beber' then
                        animDict = 'amb@world_human_drinking@coffee@male@idle_a'
                        animName = 'idle_c'
                        boneId = 28422
                    elseif selection == 'fumar' then
                        animDict = 'amb@world_human_smoking@male@male_a@idle_a'
                        animName = 'idle_a'
                        boneId = 28422
                    elseif selection == 'telefone' then
                        animDict = 'cellphone@'
                        animName = 'cellphone_text_in'
                        boneId = 28422
                    elseif selection == 'caixa' then
                        animDict = 'anim@heists@box_carry@'
                        animName = 'idle'
                        boneId = 60309
                    else
                        if input[2] ~= '' and input[3] ~= '' then
                            animDict = input[2]
                            animName = input[3]
                        end
                    end
                    openConfigMenu()
                end
            },
            {
                title = 'Selecionar Modelo do Prop',
                description = ('Atual: %s'):format(propModel),
                icon = 'fa-solid fa-box-open',
                onSelect = function()
                    local input = lib.inputDialog('Modelo do Prop', {
                        { type = 'input', label = 'Nome do Prop (Model Name)', default = propModel }
                    })
                    if input and input[1] ~= '' then
                        propModel = input[1]
                    end
                    openConfigMenu()
                end
            },
            {
                title = 'Selecionar Bone ID',
                description = ('Atual: %d'):format(boneId),
                icon = 'fa-solid fa-bone',
                onSelect = function()
                    local input = lib.inputDialog('Bone ID', {
                        {
                            type = 'select',
                            label = 'Escolher Bone',
                            options = {
                                { value = 60309, label = 'Mão Esquerda (60309)' },
                                { value = 57005, label = 'Mão Direita (57005)' },
                                { value = 28422, label = 'Mão Direita Weapon (28422)' },
                                { value = 18905, label = 'Coluna / Costas (18905)' },
                                { value = 0, label = 'Outro (Digitar ID)' }
                            },
                            default = boneId
                        },
                        { type = 'number', label = 'Bone ID (Se escolheu Outro)', placeholder = 'ex: 57005' }
                    })

                    if not input then return openConfigMenu() end

                    local boneOption = input[1]
                    if boneOption == 0 then
                        if input[2] then
                            boneId = tonumber(input[2])
                        end
                    else
                        boneId = boneOption
                    end
                    openConfigMenu()
                end
            },
            {
                title = 'Iniciar Ajuste',
                description = 'Inicia a visualização e edição ao vivo da posição do prop.',
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
    openConfigMenu()
end, false)

-- ==========================================================================
-- TEST COMMAND FOR OX_LIB REDESIGN UI
-- ==========================================================================

local function testNotifications()
    lib.notify({ type = 'success', title = 'Sucesso', description = 'Ação realizada com êxito! (Redesign)' })
    Wait(1000)
    lib.notify({ type = 'error', title = 'Erro', description = 'Um erro foi encontrado durante o processo.' })
    Wait(1000)
    lib.notify({ type = 'warning', title = 'Aviso', description = 'Atenção! Verifique as informações fornecidas.' })
    Wait(1000)
    lib.notify({ type = 'info', title = 'Informação', description = 'Esta é uma notificação informativa do sistema.' })
end

local function testLinearProgress()
    lib.progressBar({
        duration = 4000,
        label = 'Progresso Linear (Redesign)',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true }
    })
end

local function testCircularProgress()
    lib.progressCircle({
        duration = 4000,
        label = 'Progresso Circular (Redesign)',
        position = 'middle',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true }
    })
end

local function testInputDialog()
    local input = lib.inputDialog('Configurar Teste', {
        { type = 'input', label = 'Nome do Carro', placeholder = 'Ex: Cheburek', required = true },
        { type = 'number', label = 'Quantidade', default = 1, min = 0, max = 10 },
        { type = 'checkbox', label = 'Deseja Trancar?', checked = true },
        { type = 'select', label = 'Cor Principal', options = {
            { value = 'red', label = 'Vermelho' },
            { value = 'blue', label = 'Azul' },
            { value = 'black', label = 'Preto' }
        }, default = 'red' },
        { type = 'slider', label = 'Volume', min = 0, max = 100, default = 60 }
    })
    
    if input then
        lib.notify({
            type = 'success',
            title = 'Formulário Confirmado',
            description = string.format('Nome: %s | Qtd: %d | Trancado: %s', input[1], input[2], tostring(input[3]))
        })
    else
        lib.notify({ type = 'error', description = 'Formulário cancelado.' })
    end
end

local function testAlertDialog()
    local alert = lib.alertDialog({
        header = 'Remover Item?',
        content = 'Essa ação não pode ser desfeita. O item será removido permanentemente do inventário.',
        centered = true,
        cancel = true,
        labels = { cancel = 'Cancelar', confirm = 'Remover' }
    })
    
    if alert == 'confirm' then
        lib.notify({ type = 'success', description = 'Item removido com sucesso.' })
    else
        lib.notify({ type = 'info', description = 'Ação cancelada.' })
    end
end

local isTextUIActive = false
local function testTextUI()
    if isTextUIActive then
        lib.hideTextUI()
        isTextUIActive = false
        lib.notify({ type = 'info', description = 'Text UI ocultado.' })
    else
        lib.showTextUI('[E] Testar Ação | [G] Outra Opção\nText UI minimalista redesenhado com keycaps!')
        isTextUIActive = true
        lib.notify({ type = 'info', description = 'Text UI exibido. Digite /testlib novamente para alternar.' })
    end
end

local function testSimpleMenu()
    lib.registerMenu({
        id = 'test_simple_menu',
        title = 'Selecionar Opção',
        position = 'top-right',
        options = {
            { label = 'Opção 1', description = 'Executar primeira ação de teste' },
            { label = 'Opção 2', description = 'Executar segunda ação de teste' },
            { label = 'Opção 3', description = 'Executar terceira ação de teste' }
        }
    }, function(selected, scrollIndex, args)
        lib.notify({ type = 'info', description = 'Selecionou opção: ' .. selected })
    end)
    lib.showMenu('test_simple_menu')
end

local function testSkillCheck()
    local success = lib.skillCheck({'easy', 'medium', 'hard'}, {'w', 'a', 's', 'd'})
    if success then
        lib.notify({ type = 'success', description = 'Sucesso no Skill Check!' })
    else
        lib.notify({ type = 'error', description = 'Falhou no Skill Check.' })
    end
end

local function openTestMenu()
    lib.registerContext({
        id = 'test_oxlib_redesign',
        title = 'ox_lib — Redesign Test',
        options = {
            {
                title = 'Notificações',
                description = 'Testa os 4 tipos de toasts com borda colorida',
                icon = 'fa-solid fa-bell',
                onSelect = testNotifications
            },
            {
                title = 'Progresso Linear',
                description = 'Testa a barra de progresso horizontal fina',
                icon = 'fa-solid fa-bars-progress',
                onSelect = testLinearProgress
            },
            {
                title = 'Progresso Circular',
                description = 'Testa a animação de progresso redonda',
                icon = 'fa-solid fa-circle-notch',
                onSelect = testCircularProgress
            },
            {
                title = 'Input Dialog',
                description = 'Abre o formulário redesenhado',
                icon = 'fa-solid fa-keyboard',
                onSelect = testInputDialog
            },
            {
                title = 'Alert Dialog',
                description = 'Abre o modal de confirmação minimalista',
                icon = 'fa-solid fa-triangle-exclamation',
                onSelect = testAlertDialog
            },
            {
                title = 'Text UI (Alternar)',
                description = 'Exibe ou oculta a caixa de ajuda de teclado',
                icon = 'fa-solid fa-comment-dots',
                onSelect = testTextUI
            },
            {
                title = 'Menu Simples',
                description = 'Abre o menu listado tradicional',
                icon = 'fa-solid fa-list',
                onSelect = testSimpleMenu
            },
            {
                title = 'Skill Check',
                description = 'Testa a área de acerto dinâmica redesenhada',
                icon = 'fa-solid fa-gauge',
                onSelect = testSkillCheck
            },
            {
                title = 'Menu Radial (Dica)',
                description = 'Pressione a tecla [Z] para abrir o Menu Radial de teste',
                icon = 'fa-solid fa-compass',
                onSelect = function()
                    lib.notify({ type = 'info', description = 'Feche este menu e pressione a tecla [Z] para testar o Menu Radial!' })
                end
            }
        }
    })
    lib.showContext('test_oxlib_redesign')
end

RegisterCommand('testlib', function()
    openTestMenu()
end, false)

-- Register some mock items for the radial menu so it is testable by pressing the Z keybind
CreateThread(function()
    lib.addRadialItem({
        {
            id = 'test_item_weapons',
            label = 'Armas',
            icon = 'fa-solid fa-gun',
            onSelect = function()
                lib.notify({ type = 'success', description = 'Selecionou radial: Armas' })
            end
        },
        {
            id = 'test_item_vehicle',
            label = 'Veículo',
            icon = 'fa-solid fa-car',
            onSelect = function()
                lib.notify({ type = 'success', description = 'Selecionou radial: Veículo' })
            end
        },
        {
            id = 'test_item_settings',
            label = 'Configurar',
            icon = 'fa-solid fa-gear',
            onSelect = function()
                lib.notify({ type = 'success', description = 'Selecionou radial: Configurar' })
            end
        }
    })
end)

-- ==========================================================================
-- SAVE CONSUMPTION (HOLD & RELEASE ACTIONS + EXPORTS)
-- ==========================================================================

local activeAttachedProp = nil
local activeAttachedModel = nil

local function startHoldingProp(model, animN)
    if activeAttachedProp then
        DeleteEntity(activeAttachedProp)
        activeAttachedProp = nil
        activeAttachedModel = nil
        ClearPedTasks(cache.ped)
    end
    
    local modelData = savedAttachments[model]
    if not modelData then
        lib.notify({ type = 'error', description = string.format("Nenhum ajuste salvo para o prop '%s'. Ajuste primeiro!", model) })
        return
    end
    
    local config = nil
    if animN and animN ~= "" then
        config = modelData[animN]
    else
        -- Pick the first available animation configuration
        for name, val in pairs(modelData) do
            config = val
            animN = name
            break
        end
    end
    
    if not config then
        lib.notify({ type = 'error', description = string.format("Nenhum ajuste para o prop '%s' com a animação '%s'.", model, animN or "") })
        return
    end
    
    lib.requestModel(model)
    
    -- Load animation
    RequestAnimDict(config.animDict)
    while not HasAnimDictLoaded(config.animDict) do
        Wait(10)
    end
    
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    
    -- Play animation
    TaskPlayAnim(ped, config.animDict, config.animName, 8.0, -8.0, -1, 51, 0, false, false, false)
    
    -- Spawn prop
    local modelHash = GetHashKey(model)
    local prop = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(
        prop, ped, GetPedBoneIndex(ped, config.boneId), 
        config.offset.x, config.offset.y, config.offset.z, 
        config.rotation.x, config.rotation.y, config.rotation.z, 
        true, true, false, true, 1, true
    )
    
    activeAttachedProp = prop
    activeAttachedModel = model
    
    lib.notify({ type = 'success', description = string.format("Segurando o item '%s' (%s). /stopitem para soltar.", model, animN) })
end

local function stopHoldingProp()
    if activeAttachedProp then
        DeleteEntity(activeAttachedProp)
        activeAttachedProp = nil
        activeAttachedModel = nil
        ClearPedTasks(cache.ped)
        lib.notify({ type = 'info', description = "Item solto e animação parada." })
    else
        lib.notify({ type = 'error', description = "Você não está segurando nenhum item." })
    end
end

-- Commands for testing segurar/soltar prop
RegisterCommand('holditem', function(source, args)
    local model = args[1]
    local animN = args[2]
    if not model or model == '' then
        lib.notify({ type = 'error', description = "Uso: /holditem [modelo] [opcional: nome_animacao]" })
        return
    end
    startHoldingProp(model, animN)
end, false)

RegisterCommand('stopitem', function()
    stopHoldingProp()
end, false)

local function cleanPlayerProps()
    local ped = PlayerPedId()
    local objects = GetGamePool('CObject')
    local count = 0
    for i = 1, #objects do
        local object = objects[i]
        if DoesEntityExist(object) and IsEntityAttachedToEntity(object, ped) then
            DetachEntity(object, true, true)
            SetEntityAsMissionEntity(object, true, true)
            DeleteEntity(object)
            count = count + 1
        end
    end
    return count
end

local function reloadPlayerSkinAndCleanProps()
    if activeAttachedProp then
        DeleteEntity(activeAttachedProp)
        activeAttachedProp = nil
        activeAttachedModel = nil
    end

    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)

    local deletedCount = cleanPlayerProps()

    TriggerEvent("illenium-appearance:client:reloadSkin", true)

    lib.notify({
        type = 'success',
        title = 'Aparência Atualizada',
        description = string.format("Skin recarregada! %d objeto(s) removido(s) do corpo.", deletedCount)
    })
end

RegisterCommand('refreshskin', function()
    reloadPlayerSkinAndCleanProps()
end, false)

local function openPropDetailMenu(model, animN, data)
    lib.registerContext({
        id = 'saved_prop_detail_' .. model .. '_' .. animN,
        title = string.format("Ajuste: %s", model),
        menu = 'saved_props_list',
        options = {
            {
                title = 'Segurar Item',
                description = string.format("Equipa o prop e inicia a animação '%s'", animN),
                icon = 'fa-solid fa-hand-holding',
                onSelect = function()
                    startHoldingProp(model, animN)
                end
            },
            {
                title = 'Copiar Código (F8 Console)',
                description = 'Imprime os vetores no console F8',
                icon = 'fa-solid fa-copy',
                onSelect = function()
                    local formatStr = [[
^2====================================================
Modelo = "%s"
AnimDict = "%s"
AnimName = "%s"
Bone = %d
Offset = vec3(%.4f, %.4f, %.4f),
Rotation = vec3(%.4f, %.4f, %.4f)
^2====================================================]]
                    local code = string.format(formatStr, model, data.animDict, data.animName, data.boneId, data.offset.x, data.offset.y, data.offset.z, data.rotation.x, data.rotation.y, data.rotation.z)
                    print(code)
                    lib.notify({ type = 'success', description = 'Código impresso no console F8!' })
                end
            },
            {
                title = 'Dados Técnicos',
                description = string.format("Anim: %s\nBone: %d\nOffset: vec3(%.4f, %.4f, %.4f)\nRot: vec3(%.4f, %.4f, %.4f)", 
                    animN, data.boneId, data.offset.x, data.offset.y, data.offset.z, data.rotation.x, data.rotation.y, data.rotation.z),
                icon = 'fa-solid fa-circle-info',
                readOnly = true
            }
        }
    })
    lib.showContext('saved_prop_detail_' .. model .. '_' .. animN)
end

RegisterCommand('savedprops', function()
    local options = {}
    
    for model, anims in pairs(savedAttachments) do
        local count = 0
        local singleAnimName = nil
        local singleData = nil
        
        for name, data in pairs(anims) do
            count = count + 1
            singleAnimName = name
            singleData = data
        end
        
        if count > 1 then
            -- Multiple animations
            table.insert(options, {
                title = model,
                description = string.format("%d animações salvas para este prop", count),
                icon = 'fa-solid fa-boxes-stacked',
                arrow = true,
                onSelect = function()
                    local subOptions = {}
                    for name, data in pairs(anims) do
                        table.insert(subOptions, {
                            title = name,
                            description = string.format("Dict: %s | Bone: %d", data.animDict, data.boneId),
                            icon = 'fa-solid fa-person-running',
                            arrow = true,
                            onSelect = function()
                                openPropDetailMenu(model, name, data)
                            end
                        })
                      end
                      
                      lib.registerContext({
                          id = 'saved_prop_anims_' .. model,
                          title = model .. ' - Animações',
                          menu = 'saved_props_list',
                          options = subOptions
                      })
                      lib.showContext('saved_prop_anims_' .. model)
                end
            })
        elseif count == 1 then
            -- Exactly one animation
            table.insert(options, {
                title = model,
                description = string.format("Anim: %s | Bone: %d", singleAnimName, singleData.boneId),
                icon = 'fa-solid fa-box',
                arrow = true,
                onSelect = function()
                    openPropDetailMenu(model, singleAnimName, singleData)
                end
            })
        end
    end
    
    if #options == 0 then
        lib.notify({ type = 'error', description = 'Nenhum prop foi ajustado e salvo ainda.' })
        return
    end
    
    lib.registerContext({
        id = 'saved_props_list',
        title = 'Props Ajustados',
        options = options
    })
    
    lib.showContext('saved_props_list')
end, false)

-- Exports for other resources to consume the saved offset data
exports('getAttachment', function(model, animName)
    if savedAttachments[model] then
        if animName then
            return savedAttachments[model][animName]
        else
            -- Return first available animation setup
            for _, data in pairs(savedAttachments[model]) do
                return data
            end
        end
    end
    return nil
end)

exports('getAttachments', function()
    return savedAttachments
end)
