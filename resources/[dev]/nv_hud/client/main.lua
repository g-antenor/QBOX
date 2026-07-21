-- ==========================================================================
-- NV_HUD - HUD customizavel
-- Coleta o estado do jogador/veiculo e envia para a NUI.
-- ==========================================================================
local settings = Settings.load()
local hudReady = false
local hudVisible = false
local panelOpen = false

-- Estado espelhado na NUI. Só enviamos o que mudou.
local state = {
    vida = 100, colete = 0, fome = 100, sede = 100, stress = 0,
    heading = 0, street = '', region = '',
    micRange = 0, micTalking = false,
    radioOn = false, radioChannel = 0, radioTalking = false,
    inVehicle = false, speed = 0, fuel = 100, gear = 'N',
    engineOn = false, engineHealth = 1000, belt = false, locked = false,
    organization = '', onDuty = false
}

local dirty = {}

local function set(key, value)
    if state[key] == value then return end

    state[key] = value
    dirty[key] = value
end

local function sendNui(action, data)
    SendNUIMessage({ action = action, data = data })
end

exports('notify', function(data)
    if type(data) ~= 'table' or not hudReady then return false end
    sendNui('notify', data)
    return true
end)

local function flush()
    if not hudReady or not next(dirty) then return end

    sendNui('state', dirty)
    dirty = {}
end

local function pushSettings()
    if not hudReady then return end

    sendNui('settings', {
        settings = settings,
        critical = Config.Critical,
        idle = Config.IdleValue,
        engine = Config.Engine,
        fuel = Config.Fuel,
        compassOnlyInVehicle = Config.CompassOnlyInVehicle,
        minimap = {
            -- A NUI precisa do `frame` de cada formato para desenhar a
            -- moldura no tamanho certo quando o jogador troca quadrado/redondo.
            shapes = {
                quadrado = Config.Minimap.shapes.quadrado.frame,
                redondo = Config.Minimap.shapes.redondo.frame
            },
            nudgeStep = Config.Minimap.nudgeStep
        }
    })
end

local function setHudVisible(visible)
    if hudVisible == visible then return end

    hudVisible = visible
    sendNui('visible', visible)
end

-- ==========================================================================
-- MINIMAPA
--
-- O radar e um scaleform do jogo: nao da para desenha-lo dentro da NUI. A HUD
-- desenha uma moldura por cima, e o radar real e posicionado por natives.
--
-- Abordagem baseada no qbx_hud (ver comentario em config.lua). O que faltava
-- nas minhas versoes anteriores:
--   * SetMinimapClipType, que e quem realmente aplica quadrado/redondo;
--   * um conjunto de valores POR FORMATO (o redondo nao e o quadrado escalado);
--   * SetBigmapActive para reconstruir o scaleform e as mudancas valerem;
--   * correcao de proporcao para telas mais largas que 16:9.
-- ==========================================================================
local MINIMAP = Config.Minimap

local maskReplaced = false
local lastApplied = nil

-- Quanto esperar (ms) o .ytd da mascara chegar, e quantas vezes reagendar o
-- reload inteiro se ele nao chegar. Sem o teto, um asset ausente do stream
-- viraria um loop de reload eterno reconstruindo o scaleform de graca.
local MASK_TIMEOUT = 5000
local MASK_RETRIES = 3

local maskAttempt = 0

local function currentShape()
    return MINIMAP.shapes[settings.minimapShape] or MINIMAP.shapes.quadrado
end

--- Em telas mais largas que 16:9 o radar precisa ser puxado para a esquerda,
--- senao ele descola da borda. Credito ao Dalrae pela formula.
local function aspectOffset()
    local defaultAspect = 1920 / 1080
    local resX, resY = GetActiveScreenResolution()

    if not resX or resY == 0 then return 0.0 end

    local aspect = resX / resY

    if aspect > defaultAspect then
        return ((defaultAspect - aspect) / 3.6) - 0.008
    end

    return 0.0
end

--- Deslocamento pedido pelo jogador (arrastando a moldura), em fracao de tela.
local function dragOffset()
    local offset = settings.minimapOffset or {}

    return tonumber(offset.x) or 0.0, tonumber(offset.y) or 0.0
end

--- Largura que deixa o componente quadrado NA TELA.
--- Fracao de largura e fracao de altura nao sao a mesma coisa: para um
--- circulo aparecer redondo, a largura precisa ser a altura dividida pela
--- proporcao da tela.
local function circularWidth(height)
    local resX, resY = GetActiveScreenResolution()

    if not resX or resY == 0 then return height / (16 / 9) end

    return height / (resX / resY)
end

--- Grava a posicao dos tres componentes do radar.
local function writeComponents()
    local shape = currentShape()
    local off = aspectOffset()
    local dx, dy = dragOffset()

    local function widthOf(part)
        return part.circular and circularWidth(part.h) or part.w
    end

    SetMinimapComponentPosition('minimap', 'L', 'B',
        shape.minimap.x + off + dx, shape.minimap.y + dy,
        widthOf(shape.minimap), shape.minimap.h)

    SetMinimapComponentPosition('minimap_mask', 'L', 'B',
        shape.mask.x + off + dx, shape.mask.y + dy,
        widthOf(shape.mask), shape.mask.h)

    SetMinimapComponentPosition('minimap_blur', 'L', 'B',
        shape.blur.x + off + dx, shape.blur.y + dy,
        widthOf(shape.blur), shape.blur.h)

    SetMinimapClipType(shape.clip)
end

--- Troca a textura de mascara, se o asset estiver disponivel.
--- Sem o .ytd streamado, o clip type sozinho ja muda o recorte; a textura
--- deixa as bordas limpas.
---
--- ATENCAO: esta funcao CEDE (Wait). So chame de dentro de uma thread.
---
--- `RequestStreamedTextureDict` e assincrono. A versao anterior pedia o dict e
--- perguntava se ele tinha carregado no MESMO frame -- o que nunca e verdade na
--- primeira chamada -- e desistia devolvendo false. Como `applyMinimap` so
--- agenda um reload quando a forma ou o offset MUDAM, a segunda tentativa so
--- acontecia quando o jogador entrava na edicao de posicao e mexia na moldura.
--- Era exatamente isso que "consertava" o minimapa: nao a edicao em si, mas o
--- reload que ela provocava.
local function applyMaskTexture()
    local shape = currentShape()

    if not HasStreamedTextureDictLoaded(shape.dict) then
        RequestStreamedTextureDict(shape.dict, false)

        local deadline = GetGameTimer() + MASK_TIMEOUT

        while not HasStreamedTextureDictLoaded(shape.dict) do
            if GetGameTimer() > deadline then return false end
            Wait(10)
        end
    end

    AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', shape.dict, 'radarmasksm')
    AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', shape.dict, 'radarmasksm')
    maskReplaced = true

    return true
end

--- Aplica tudo e reconstroi o scaleform.
---
--- O par SetBigmapActive(true) / (false) e OBRIGATORIO: SetMinimapComponentPosition
--- apenas grava os valores, e o radar so passa a usa-los quando o scaleform e
--- reconstruido. Sem isso a moldura anda e o minimapa fica parado.
local function reloadMinimap()
    CreateThread(function()
        local masked = applyMaskTexture()

        writeComponents()

        if MINIMAP.hideNorthBlip then
            SetBlipAlpha(GetNorthRadarBlip(), 0)
        end

        SetBigmapActive(true, false)
        Wait(50)
        SetBigmapActive(false, false)

        if masked then
            maskAttempt = 0
            return
        end

        -- A mascara nao chegou. Reagendar aqui e o que impede o radar de ficar
        -- preso no formato errado ate o jogador mexer em alguma coisa.
        if maskAttempt >= MASK_RETRIES then
            maskAttempt = 0

            print(('[nv_hud] textura de mascara "%s" nao carregou apos %d tentativas. O formato do radar vai depender so do clip type; confira se o .ytd esta no stream/ do resource.')
                :format(currentShape().dict, MASK_RETRIES))

            return
        end

        maskAttempt = maskAttempt + 1

        Wait(1000)
        reloadMinimap()
    end)
end

local reloadPending = false
local lastChangeAt = 0

--- Arrastar dispara dezenas de mudancas por segundo; sem esperar o valor
--- assentar, o radar piscaria a cada quadro.
local function scheduleReload()
    lastChangeAt = GetGameTimer()

    if reloadPending then return end

    reloadPending = true

    CreateThread(function()
        while GetGameTimer() - lastChangeAt < 120 do Wait(30) end

        reloadPending = false
        reloadMinimap()
    end)
end

local function applyMinimap(force)
    NativeHud.radar = settings.visible.minimap

    local dx, dy = dragOffset()
    local key = ('%s/%.4f/%.4f'):format(settings.minimapShape or 'quadrado', dx, dy)

    -- Reescrever os componentes e barato; reconstruir o scaleform nao e.
    writeComponents()

    if force or key ~= lastApplied then
        lastApplied = key
        scheduleReload()
    end
end

--- Aplica o minimapa durante a entrada do jogador.
---
--- Uma chamada unica no `ox:playerLoaded` nao basta. Nesse instante o jogo
--- ainda esta montando a HUD e redefine os componentes do radar DEPOIS de nos;
--- como `SetMinimapComponentPosition` so passa a valer quando o scaleform e
--- reconstruido, um reload que acontece cedo demais e simplesmente perdido, e
--- o jogador cai no mundo com o radar no formato padrao do GTA.
---
--- Reaplicar em intervalos crescentes cobre a janela inteira do carregamento
--- (tela preta, spawn, primeira troca de camera) sem precisar adivinhar quando
--- ela termina. Sao quatro reconstrucoes em 3 segundos, invisiveis no meio do
--- fade-in.
local function applyMinimapOnLoad()
    CreateThread(function()
        for _, delay in ipairs({ 0, 500, 1500, 3000 }) do
            if delay > 0 then Wait(delay) end

            -- `force`: o valor nao mudou entre as tentativas, entao sem isto a
            -- comparacao com `lastApplied` engoliria todas menos a primeira --
            -- que e justamente a que tem mais chance de se perder.
            applyMinimap(true)
        end
    end)
end

-- O jogo redefine os componentes do radar sozinho em varias situacoes
-- (entrar/sair de veiculo, respawn, abrir o mapa grande). Sem reaplicar, o
-- minimapa escapa da posicao e do tamanho configurados. Barato o bastante
-- para rodar a cada meio segundo.
CreateThread(function()
    while true do
        Wait(500)

        if hudVisible and settings.visible.minimap then
            applyMinimap()
        end
    end
end)

-- Esconde a HUD enquanto o menu de pausa estiver aberto.
if Config.DefaultHud.hideOnPauseMenu then
    CreateThread(function()
        local hiddenByPause = false

        while true do
            local paused = IsPauseMenuActive()

            if paused ~= hiddenByPause then
                hiddenByPause = paused
                sendNui('paused', paused)
            end

            Wait(200)
        end
    end)
end

-- ==========================================================================
-- STATUS DO JOGADOR (vida / colete / fome / sede / stress)
-- ==========================================================================
local statuses = { hunger = 0, thirst = 0, stress = 0 }

AddEventHandler('ox:statusTick', function(data)
    if type(data) ~= 'table' then return end

    for name, value in pairs(data) do statuses[name] = value end
end)

CreateThread(function()
    while true do
        Wait(Config.Tick.status)

        if hudVisible then
            local ped = cache.ped
            local maxHealth = GetPedMaxHealth(ped) - 100
            local health = GetEntityHealth(ped) - 100

            set('vida', maxHealth > 0 and math.floor(math.max(health, 0) / maxHealth * 100 + 0.5) or 0)
            set('colete', math.floor(GetPedArmour(ped) + 0.5))

            -- No ox_core fome/sede sobem conforme o jogador tem fome/sede,
            -- entao invertemos para exibir saciedade.
            set('fome', math.floor(100 - (statuses.hunger or 0) + 0.5))
            set('sede', math.floor(100 - (statuses.thirst or 0) + 0.5))
            set('stress', math.floor((statuses.stress or 0) + 0.5))

            flush()
        end
    end
end)

-- ==========================================================================
-- BUSSOLA (direcao da camera + nome da rua)
-- ==========================================================================
CreateThread(function()
    while true do
        Wait(Config.Tick.compass)

        if hudVisible and settings.visible.compass then
            local camRot = GetGameplayCamRot(2)
            local heading = (360.0 - (camRot.z % 360.0)) % 360.0

            set('heading', math.floor(heading + 0.5) % 360)

            local coords = GetEntityCoords(cache.ped)
            local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)

            set('street', GetStreetNameFromHashKey(streetHash))

            -- GetNameOfZone devolve o codigo da zona (ex.: "VINE"); o label
            -- traduz para o nome exibivel ("Vinewood").
            set('region', GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)))

            flush()
        end
    end
end)

-- ==========================================================================
-- MICROFONE (pma-voice)
-- ==========================================================================
CreateThread(function()
    while true do
        Wait(200)

        if hudVisible and settings.visible.mic then
            -- O pma-voice publica o modo de voz atual ("Sussurro", "Normal",
            -- "Grito") no state bag. A UI dele fica desligada via convar
            -- voice_enableUi; quem mostra o alcance agora e a nossa HUD.
            local proximity = LocalPlayer.state.proximity
            local isTable = type(proximity) == 'table'

            -- index 1/2/3 = perto/medio/longe, usado pelas barrinhas.
            set('micRange', isTable and (tonumber(proximity.index) or 0) or 0)

            -- MumbleIsPlayerTalking devolve 1/0, nao booleano. Comparar com
            -- `true` nunca dava certo (e comparar com truthy tambem nao serve:
            -- em Lua o proprio 0 e truthy). O pma-voice usa `== 1`.
            set('micTalking', MumbleIsPlayerTalking(PlayerId()) == 1)

            flush()
        end
    end
end)

-- ==========================================================================
-- RADIO
-- Quem liga, sintoniza e entra no canal do pma-voice e o nv_radio. Aqui a HUD
-- so EXIBE o que ele informar — por isso nao ha comando /radio nem chamada ao
-- pma-voice neste arquivo (os dois concorreriam com o aparelho).
-- ==========================================================================
local function setRadioFrequency(frequency)
    frequency = tonumber(frequency) or 0
    if frequency < 0 then frequency = 0 end

    set('radioFreq', frequency)
    set('radioOn', frequency > 0)
    flush()
end

exports('SetRadioFrequency', setRadioFrequency)

--- Compatibilidade: canal inteiro do pma-voice (125) vira frequência (12.5).
exports('SetRadioChannel', function(channel)
    setRadioFrequency((tonumber(channel) or 0) / 10)
end)

AddEventHandler('pma-voice:radioActive', function(active)
    set('radioTalking', active == true)
    flush()
end)

-- ==========================================================================
-- VEICULO (velocimetro, marcha, combustivel, motor, cinto, tranca)
-- ==========================================================================
local belted = false

local function applySeatbelt()
    -- Flag 32 = PED_FLAG_CAN_FLY_THRU_WINDSCREEN
    SetPedConfigFlag(cache.ped, 32, not belted)
end

-- Com o cinto colocado, impede a saida imediata do veiculo.
CreateThread(function()
    while true do
        if belted and cache.vehicle then
            DisableControlAction(0, 75, true)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

local function toggleSeatbelt()
    if not cache.vehicle then return end

    belted = not belted
    applySeatbelt()
    set('belt', belted)
    flush()

    -- O clique da lingueta. Vem antes da notificacao de proposito: o som e a
    -- confirmacao imediata, o texto e o registro.
    local click = belted and Config.SeatbeltBeep.buckle or Config.SeatbeltBeep.unbuckle

    if click then
        PlaySoundFrontend(-1, click.name, click.set, true)
    end

    lib.notify({
        title = belted and 'Cinto colocado' or 'Cinto removido',
        type = belted and 'success' or 'error',
        duration = 1500
    })
end

if Config.SeatbeltKey then
    lib.addKeybind({
        name = 'nv_hud_seatbelt',
        description = 'Colocar/remover o cinto de seguranca',
        defaultKey = Config.SeatbeltKey,
        onPressed = toggleSeatbelt
    })
end

-- --------------------------------------------------------- aviso de cinto --

--- O motorista esta andando sem cinto agora?
---
--- As tres condicoes de parada pedidas nao precisam de tratamento separado:
--- parar o carro derruba a velocidade, desligar derruba o motor e o cinto
--- derruba o `belted`. Cada uma sozinha ja e suficiente para o aviso cessar.
---@return boolean
local function shouldWarnSeatbelt()
    if belted then return false end

    local vehicle = cache.vehicle

    -- So o motorista: quem esta no banco de tras nao "anda com o carro".
    if not vehicle or cache.seat ~= -1 then return false end
    if Config.SeatbeltBeep.ignoreClasses[GetVehicleClass(vehicle)] then return false end
    if not GetIsVehicleEngineRunning(vehicle) then return false end

    return GetEntitySpeed(vehicle) * 3.6 >= Config.SeatbeltBeep.minSpeed
end

CreateThread(function()
    if not Config.SeatbeltBeep.enabled then return end

    local sound = Config.SeatbeltBeep.sound

    while true do
        if shouldWarnSeatbelt() then
            SendNUIMessage({
                action = 'seatbeltChime',
                data = {
                    duration = sound.duration or 1500,
                    volume = sound.volume or 0.12
                }
            })

            -- O intervalo e a espera: assim o primeiro bipe sai no instante em
            -- que o carro passa dos 2 km/h, e nao no fim de um ciclo.
            Wait(Config.SeatbeltBeep.interval)
        else
            Wait(500)
        end
    end
end)

--- Eletricos tem caixa de uma marcha so no handling; carros a combustao tem
--- varias. E o dado do proprio veiculo, entao nao precisamos de lista de
--- modelos: qualquer carro eletrico adicionado depois ja entra certo.
local function isSingleSpeed(vehicle)
    local gears = GetVehicleHandlingInt(vehicle, 'CHandlingData', 'nInitialDriveGears')

    return not gears or gears <= 1
end

local function currentGear(vehicle, speed, engineOn)
    if not engineOn then return 'P' end

    if GetEntitySpeedVector(vehicle, true).y < -0.5 then return 'R' end

    -- Eletrico: nao ha marcha para mostrar, entao segue P/R/N/D.
    if isSingleSpeed(vehicle) then
        return speed < 1 and 'N' or 'D'
    end

    -- Combustao: marcha real da transmissao.
    local gear = GetVehicleCurrentGear(vehicle)

    if gear == 0 or speed < 1 then return 'N' end

    return tostring(gear)
end

lib.onCache('vehicle', function(vehicle)
    set('inVehicle', vehicle ~= nil and vehicle ~= false)

    if not vehicle then
        belted = false
        set('belt', false)
    end

    applySeatbelt()
    flush()
end)

CreateThread(function()
    while true do
        local vehicle = cache.vehicle

        if hudVisible and vehicle and settings.visible.vehicle then
            local speed = GetEntitySpeed(vehicle) * 3.6
            local engineOn = GetIsVehicleEngineRunning(vehicle)
            local fuel = Entity(vehicle).state.fuel or GetVehicleFuelLevel(vehicle)

            set('speed', math.floor(speed + 0.5))
            set('fuel', math.floor(math.min(math.max(fuel, 0), 100) + 0.5))
            set('gear', currentGear(vehicle, speed, engineOn))
            set('engineOn', engineOn)
            set('engineHealth', math.floor(GetVehicleEngineHealth(vehicle)))
            set('locked', GetVehicleDoorLockStatus(vehicle) >= 2)
            set('belt', belted)

            flush()

            Wait(Config.Tick.vehicle)
        else
            Wait(500)
        end
    end
end)

-- ==========================================================================
-- PAINEL DE CONTROLE (NUI)
-- ==========================================================================
local function setPanel(open)
    panelOpen = open

    SetNuiFocus(open, open)
    sendNui('panel', open)
end

-- Com o painel aberto, o ESC e tratado pela NUI (volta/fecha), entao
-- bloqueamos o menu de pausa do jogo.
CreateThread(function()
    while true do
        if panelOpen then
            DisableControlAction(0, 200, true) -- INPUT_FRONTEND_PAUSE
            DisableControlAction(0, 199, true) -- INPUT_FRONTEND_PAUSE_ALTERNATE
            Wait(0)
        else
            Wait(250)
        end
    end
end)

local function openSettings()
    if not hudVisible then
        return lib.notify({ title = 'A HUD nao esta ativa', type = 'error' })
    end

    setPanel(true)
end

RegisterCommand(Config.SettingsCommand, openSettings, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.SettingsCommand, 'Abre o painel de controle da HUD')

RegisterNUICallback('saveSettings', function(data, cb)
    if type(data) == 'table' then
        settings = data
        Settings.save(settings)
        applyMinimap()
    end

    cb(1)
end)

RegisterNUICallback('resetSettings', function(_, cb)
    settings = Settings.reset()
    applyMinimap()
    pushSettings()
    cb(1)
end)

-- Sliders do painel: aplicam no radar ao vivo, para o jogador enxergar o
-- resultado enquanto arrasta o controle.
-- Arrasto da moldura: o deslocamento chega em fracao de tela e vai direto
-- para os componentes do radar.
RegisterNUICallback('minimapOffset', function(data, cb)
    if type(data) == 'table' then
        settings.minimapOffset = {
            x = tonumber(data.x) or 0.0,
            y = tonumber(data.y) or 0.0
        }

        applyMinimap()
    end

    cb(1)
end)

RegisterNUICallback('close', function(_, cb)
    setPanel(false)
    cb(1)
end)

RegisterNUICallback('ready', function(_, cb)
    hudReady = true
    pushSettings()
    sendNui('visible', hudVisible)
    dirty = {}

    for key, value in pairs(state) do dirty[key] = value end

    flush()
    cb(1)
end)

-- ==========================================================================
-- CICLO DE VIDA
-- ==========================================================================
AddEventHandler('ox:playerLoaded', function()
    applyMinimapOnLoad()
    setHudVisible(true)
end)

-- Exibe a organizacao no canto superior direito. O grupo ativo representa o
-- servico; fora dele mantemos o primeiro grupo operacional do personagem.
CreateThread(function()
    local Ox = require '@ox_core.lib.init'
    local player = Ox.GetPlayer()

    while true do
        local active = player:get('activeGroup')
        local groups = player.getGroups and player.getGroups() or {}
        local activeData = active and Ox.GetGroup(active)
        local selected = activeData
            and (activeData.type == 'state' or activeData.type == 'job' or activeData.type == 'gang')
            and active or nil

        if not selected and type(groups) == 'table' then
            for name in pairs(groups) do
                local group = Ox.GetGroup(name)
                if group and (group.type == 'state' or group.type == 'job' or group.type == 'gang') then
                    selected = name
                    break
                end
            end
        end

        local group = selected and Ox.GetGroup(selected)
        set('organization', group and (group.label or selected) or '')
        set('onDuty', selected ~= nil and active == selected)
        flush()
        Wait(1000)
    end
end)

AddEventHandler('ox:playerLogout', function()
    setHudVisible(false)

    if panelOpen then setPanel(false) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)
    DisplayHud(true)
    DisplayRadar(true)

    -- Nunca deixar o jogador preso em bigmap se o resource cair no meio de um
    -- refresh.
    SetRadarBigmapEnabled(false, false)

    if maskReplaced then
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm')
    end
end)

-- Rede de seguranca: `ox:playerLoaded` pode ter sido disparado antes deste
-- resource carregar (restart em sessao). Em vez de checar uma unica vez,
-- consultamos o ox_core ate o personagem estar carregado.
CreateThread(function()
    while true do
        if not hudVisible then
            local ok, player = pcall(function() return exports.ox_core:GetPlayer() end)

            if ok and type(player) == 'table' and player.charId then
                applyMinimapOnLoad()
                setHudVisible(true)
            end
        end

        Wait(1000)
    end
end)

-- ==========================================================================
-- DIAGNOSTICO
-- ==========================================================================
RegisterCommand('hudstatus', function()
    local ok, player = pcall(function() return exports.ox_core:GetPlayer() end)

    print(('[nv_hud] nui=%s hud=%s painel=%s charId=%s radar=%s forma=%s'):format(
        hudReady, hudVisible, panelOpen,
        (ok and type(player) == 'table') and tostring(player.charId) or 'erro',
        settings.visible.minimap, settings.minimapShape
    ))
end, false)
