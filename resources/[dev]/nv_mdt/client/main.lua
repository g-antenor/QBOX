--[[
    nv_mdt — cliente

    Ponte fina: abre a tela, repassa cliques, devolve respostas. Nenhuma
    validacao mora aqui -- a tela existir nao autoriza nada, e todo callback do
    servidor reconfere o acesso pelo subtipo da organizacao.
]]

local open = false

---@param message string
---@param type string?
local function notify(message, type)
    lib.notify({
        title = 'MDT',
        description = message,
        type = type or 'inform',
        position = 'top'
    })
end

local function close()
    if not open then return end

    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openMdt()
    if open then return end

    local data = lib.callback.await('nv_mdt:open', false)

    -- Sem departamento nenhum: nao e "erro", e falta de acesso. Dizer isso e
    -- melhor do que abrir uma tela vazia.
    if not data or not data.tabs or #data.tabs == 0 then
        return notify('Voce nao tem acesso ao MDT.', 'error')
    end

    open = true
    data.action = 'open'

    SetNuiFocus(true, true)
    SendNUIMessage(data)
end

RegisterCommand(Config.Command, openMdt, false)

if Config.Keybind then
    lib.addKeybind({
        name = 'nv_mdt',
        description = 'Abrir o MDT',
        defaultKey = Config.Keybind,
        onPressed = openMdt
    })
end

exports('open', openMdt)

-- ------------------------------------------------------ ponte generica --

--- Encaminha um callback NUI para um callback do servidor.
---
--- A tela manda `{ endpoint, args }` e recebe o retorno cru. Sem isto seriam
--- ~20 blocos identicos de RegisterNUICallback, e cada um seria mais um lugar
--- para esquecer um `cb`.
RegisterNUICallback('call', function(data, cb)
    if type(data) ~= 'table' or type(data.endpoint) ~= 'string' then
        return cb(false)
    end

    -- Whitelist por prefixo: a NUI so alcanca callbacks deste resource.
    if data.endpoint:sub(1, 7) ~= 'nv_mdt:' then return cb(false) end

    local args = data.args or {}

    -- O tamanho vem da NUI (data.n) e conta os argumentos de verdade: um valor
    -- nulo no meio deixa buraco no array decodificado, e o operador # pararia
    -- de contar ali -- o argumento seguinte sumiria em silencio.
    cb(lib.callback.await(data.endpoint, false, table.unpack(args, 1, data.n or #args)))
end)

--- Igual ao de cima, mas para acoes: mostra a notificacao de erro/sucesso.
RegisterNUICallback('action', function(data, cb)
    if type(data) ~= 'table' or type(data.endpoint) ~= 'string' then
        return cb({ ok = false })
    end

    if data.endpoint:sub(1, 7) ~= 'nv_mdt:' then return cb({ ok = false }) end

    local args = data.args or {}
    local ok, err, extra = lib.callback.await(data.endpoint, false, table.unpack(args, 1, data.n or #args))

    if not ok then
        notify(err or 'Nao foi possivel concluir.', 'error')
        return cb({ ok = false, error = err })
    end

    if data.success then notify(data.success, 'success') end

    cb({ ok = true, value = extra })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(1)
end)

-- ---------------------------------------------------------- live map --

--- Converte coordenada do mundo para porcentagem no mapa da tela.
---
--- Limites calibrados para o map.jpeg do ps-mdt. Assim o fundo e os marcadores
--- usam a mesma projecao, em vez de apenas aproximar os bairros.
RegisterNUICallback('mapBounds', function(_, cb)
    cb({ minX = -5690.93, maxX = 6723.76, minY = -4050.18, maxY = 8388.60 })
end)

--- Marca um chamado no mapa e fecha o MDT.
---
--- Fechar faz parte da acao: o motivo de tracar a rota e ir ate la, e deixar o
--- terminal aberto por cima do para-brisa obrigaria a um segundo gesto que so
--- existe porque a tela nao entendeu o que voce pediu.
RegisterNUICallback('markMap', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    local x, y = tonumber(data.x), tonumber(data.y)

    if not x or not y then
        return notify('Este chamado nao tem posicao registrada.', 'error')
    end

    close()
    SetNewWaypoint(x, y)

    notify('Rota tracada.', 'success')
end)

-- ----------------------------------------------------- rastrear veiculo --

local vehicleTrackToken = 0
local vehicleTrackBlip

local function stopVehicleTracking()
    vehicleTrackToken = vehicleTrackToken + 1
    if vehicleTrackBlip and DoesBlipExist(vehicleTrackBlip) then RemoveBlip(vehicleTrackBlip) end
    vehicleTrackBlip = nil
end

RegisterNUICallback('trackVehicle', function(data, cb)
    local plate = type(data) == 'table' and type(data.plate) == 'string' and data.plate or nil
    if not plate then return cb({ ok = false }) end

    local first = lib.callback.await('nv_mdt:police:trackVehicle', false, plate)
    if not first or first.unavailable then
        return cb({ ok = false, error = 'Veiculo fora da rede de rastreamento.' })
    end
    if first.blocked then
        return cb({ ok = false, error = 'Sinal bloqueado neste veiculo.' })
    end

    cb({ ok = true })
    close()
    stopVehicleTracking()

    local token = vehicleTrackToken
    vehicleTrackBlip = AddBlipForCoord(first.x, first.y, first.z)
    SetBlipSprite(vehicleTrackBlip, 225)
    SetBlipColour(vehicleTrackBlip, 3)
    SetBlipScale(vehicleTrackBlip, 0.9)
    SetBlipAsShortRange(vehicleTrackBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Rastreamento %s'):format(plate))
    EndTextCommandSetBlipName(vehicleTrackBlip)
    notify(('Rastreando o veiculo %s.'):format(plate), 'success')

    CreateThread(function()
        local current = vec3(first.x, first.y, first.z)
        local deadline = GetGameTimer() + 300000

        while vehicleTrackToken == token and GetGameTimer() < deadline do
            local nextPosition = lib.callback.await('nv_mdt:police:trackVehicle', false, plate)

            if not nextPosition or nextPosition.blocked or nextPosition.unavailable then
                notify(nextPosition and nextPosition.blocked and 'Rastreamento interrompido: perda de sinal.'
                    or 'Rastreamento interrompido: veiculo indisponivel.', 'error')
                break
            end

            local target = vec3(nextPosition.x, nextPosition.y, nextPosition.z)
            local started = GetGameTimer()

            while vehicleTrackToken == token and GetGameTimer() - started < 400 do
                local progress = math.min(1.0, (GetGameTimer() - started) / 400)
                local position = current + (target - current) * progress
                SetBlipCoords(vehicleTrackBlip, position.x, position.y, position.z)
                Wait(0)
            end

            current = target
        end

        if vehicleTrackToken == token then stopVehicleTracking() end
    end)
end)

-- ----------------------------------------------------------- cameras --

local activeCamera

local function stopCamera()
    if activeCamera and DoesCamExist(activeCamera) then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(activeCamera, false)
    end

    activeCamera = nil
end

RegisterNUICallback('viewCamera', function(data, cb)
    cb(1)

    local selected
    local cameras = Config.Police.cameras or {}

    for i = 1, #cameras do
        if cameras[i].id == data.id then selected = cameras[i] break end
    end

    if not selected then return notify('Camera indisponivel.', 'error') end

    close()
    stopCamera()

    activeCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(activeCamera, selected.coords.x, selected.coords.y, selected.coords.z)
    SetCamRot(activeCamera, selected.rotation.x, selected.rotation.y, selected.rotation.z, 2)
    SetCamFov(activeCamera, selected.fov or 55.0)
    RenderScriptCams(true, false, 0, true, true)
    notify(('Camera: %s. ESC para sair.'):format(selected.label), 'inform')

    CreateThread(function()
        local camera = activeCamera

        while activeCamera == camera and DoesCamExist(camera) do
            DisableAllControlActions(0)
            EnableControlAction(0, 200, true)
            EnableControlAction(0, 322, true)

            if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 322) then
                stopCamera()
            end

            Wait(0)
        end
    end)
end)

-- ------------------------------------------------------------- prisao --

local jailToken = 0

RegisterNetEvent('nv_mdt:client:jail', function(duration)
    local jail = Config.Police.jail
    duration = math.max(1, math.floor(tonumber(duration) or 1))

    if not jail or not jail.coords or not jail.release then return end

    jailToken = jailToken + 1
    local token = jailToken
    local ped = PlayerPedId()
    local center = vec3(jail.coords.x, jail.coords.y, jail.coords.z)

    SetEntityCoords(ped, center.x, center.y, center.z, false, false, false, false)
    SetEntityHeading(ped, jail.coords.w or 0.0)
    notify(('Prisao aplicada por %d minuto(s).'):format(math.ceil(duration / 60)), 'error')

    CreateThread(function()
        local deadline = GetGameTimer() + duration * 1000

        while jailToken == token and GetGameTimer() < deadline do
            ped = PlayerPedId()

            if #(GetEntityCoords(ped) - center) > 35.0 then
                SetEntityCoords(ped, center.x, center.y, center.z, false, false, false, false)
            end

            Wait(1000)
        end

        if jailToken ~= token then return end

        SetEntityCoords(PlayerPedId(), jail.release.x, jail.release.y, jail.release.z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), jail.release.w or 0.0)
        notify('Pena cumprida. Voce foi liberado.', 'success')
    end)
end)

-- ---------------------------------------------------------- retratos --

--[[
    FOTO DO EFETIVO

    E o mesmo retrato que o GTA usa no menu de pausa: `RegisterPedheadshot`
    renderiza o ped num txd, e a NUI consegue exibi-lo por `nui-img`.

    DUAS LIMITACOES, e as duas sao reais:

    1. So funciona para peds carregados no mundo. Um colega do outro lado do
       mapa nao esta em streaming, e nao ha retrato para ele -- a tela cai nas
       iniciais, que e melhor do que um quadrado vazio.

    2. O jogo tem um numero pequeno de handles simultaneos. Por isso o lote
       anterior e liberado antes de pedir um novo: sem isso, depois de algumas
       aberturas do MDT o registro passa a falhar em silencio e ninguem tem
       foto nenhuma.
]]
---@type number[]
local headshots = {}

local function releaseHeadshots()
    for i = 1, #headshots do
        if IsPedheadshotValid(headshots[i]) then
            UnregisterPedheadshot(headshots[i])
        end
    end

    headshots = {}
end

RegisterNUICallback('headshots', function(data, cb)
    local result = {}

    if type(data) ~= 'table' or type(data.ids) ~= 'table' then return cb(result) end

    releaseHeadshots()

    for i = 1, math.min(#data.ids, 12) do
        local serverId = tonumber(data.ids[i])
        local index = serverId and GetPlayerFromServerId(serverId) or -1

        if index ~= -1 then
            local ped = GetPlayerPed(index)

            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local handle = RegisterPedheadshot(ped)

                -- Deadline curto: o retrato e um enfeite util, nao um dado que
                -- justifique segurar a tela.
                local deadline = GetGameTimer() + 1500

                while not IsPedheadshotReady(handle) and GetGameTimer() < deadline do
                    Wait(0)
                end

                if IsPedheadshotReady(handle) and IsPedheadshotValid(handle) then
                    local txd = GetPedheadshotTxdString(handle)

                    result[tostring(serverId)] = ('https://nui-img/%s/%s'):format(txd, txd)
                    headshots[#headshots + 1] = handle
                else
                    UnregisterPedheadshot(handle)
                end
            end
        end
    end

    cb(result)
end)

-- ------------------------------------------------------------ fechar --

CreateThread(function()
    while true do
        if open then
            if IsControlJustReleased(0, 322) then close() end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    releaseHeadshots()
    stopCamera()
    stopVehicleTracking()

    if open then SetNuiFocus(false, false) end
end)
