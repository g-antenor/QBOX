--[[
    nv_garage — cliente: trancas, portas e lockpick

    Sobre o lockpick: a intencao ("so da para entrar pela porta que voce
    arrombou") nao tem nativo que a cumpra ao pe da letra - o jogo tranca o
    veiculo inteiro ou nada, nunca uma porta so. O que da para fazer, e o que
    esta aqui, chega perto na pratica:

      1. arrombar libera a entrada por uma janela curta (Config.Lockpick
         .entryWindow) e abre a porta em que o jogador estava;
      2. o veiculo continua TRANCADO na logica - a tranca de verdade so cai
         quando ele destranca por dentro, pelo menu;
      3. se ele sair antes disso, ou a janela expirar, tudo volta a estaca zero
         e e preciso arrombar de novo.

    O efeito para o jogador e o pedido: um arrombamento = uma entrada.
]]

-- ------------------------------------------------------ sincronizacao --

--- Servidor mudou a tranca de um veiculo: aplica no jogo.
---
--- Dois cuidados nao obvios aqui:
---
---   * o gsub devolve DOIS valores (texto, n de trocas). Sem os parenteses
---     extras o segundo vira a base do tonumber e a chamada explode;
---   * nada de `lib.waitFor`: ele lanca erro quando estoura o tempo, e este
---     handler dispara em TODOS os clientes, inclusive nos que estao longe
---     demais para a entidade existir. Seria um erro no console por veiculo.
AddStateBagChangeHandler('nvLocked', nil, function(bagName, _, value)
    local netId = tonumber((bagName:gsub('entity:', '')))
    if not netId then return end

    CreateThread(function()
        local vehicle
        local deadline = GetGameTimer() + 5000

        repeat
            local entity = NetworkGetEntityFromNetworkId(netId)

            if entity and entity ~= 0 and DoesEntityExist(entity) then
                vehicle = entity
            else
                Wait(100)
            end
        until vehicle or GetGameTimer() > deadline

        if not vehicle then return end

        -- Statebag definido significa "veiculo sob controle de alguem": a
        -- tranca automatica de NPC nao manda mais nele.
        Garage.worldLocked[vehicle] = nil

        if value ~= true then Garage.picked[vehicle] = nil end

        Garage.applyLock(vehicle)
    end)
end)

-- --------------------------------------------------------- feedback --

--- Pisca as setas e toca o bipe, como um alarme de verdade.
---@param vehicle number
---@param locked boolean
local function playLockFeedback(vehicle, locked)
    if not Config.Lock.feedback then return end

    PlaySoundFrontend(-1, locked and 'Remote_Control_Close' or 'Remote_Control_Open', 'PI_Menu_Sounds', true)

    CreateThread(function()
        for _ = 1, locked and 2 or 1 do
            SetVehicleIndicatorLights(vehicle, 0, true)
            SetVehicleIndicatorLights(vehicle, 1, true)
            Wait(180)
            SetVehicleIndicatorLights(vehicle, 0, false)
            SetVehicleIndicatorLights(vehicle, 1, false)
            Wait(120)
        end
    end)
end

--- Gesto de apontar a chave para o carro.
local function playLockAnim()
    lib.requestAnimDict('anim@mp_player_intmenu@key_fob@', 3000)

    TaskPlayAnim(cache.ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 8.0, -1, -1, 48, 0, false, false, false)
    Wait(700)
    StopAnimTask(cache.ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 1.0)
end

-- ------------------------------------------------------ trancar/abrir --

--- Pede ao servidor para trancar ou destrancar.
---@param vehicle number
---@param locked boolean
---@param animate boolean?
local function setLocked(vehicle, locked, animate)
    local netId = VehToNet(vehicle)
    local ok, err = lib.callback.await('nv_garage:setLocked', false, netId, locked)

    if not ok then
        return Garage.notify(err or 'Nao foi possivel.', 'error')
    end

    if animate then playLockAnim() end

    playLockFeedback(vehicle, locked)
    Garage.notify(locked and 'Veiculo trancado.' or 'Veiculo destrancado.', 'success')
end

-- ------------------------------------------------- menu de portas --

--- Abre ou fecha uma porta.
---@param vehicle number
---@param index number
local function toggleDoor(vehicle, index)
    if GetVehicleDoorAngleRatio(vehicle, index) > 0.0 then
        SetVehicleDoorShut(vehicle, index, false)
    else
        SetVehicleDoorOpen(vehicle, index, false, false)
    end
end

-- ------------------------------------------- painel de controle (NUI) --

--- Veiculo com o painel aberto agora. `nil` = fechado.
---@type number?
local controlling

--- Nome legivel do modelo. GetLabelText devolve 'NULL' para modelos add-on
--- sem entrada de texto, e mostrar isso no painel e pior que mostrar o nome
--- cru do modelo.
---@param vehicle number
---@return string
local function vehicleName(vehicle)
    local model = GetEntityModel(vehicle)
    local display = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(display)

    if not label or label == '' or label == 'NULL' then return display end

    return label
end

--- Retrato do veiculo para a NUI desenhar.
---@param vehicle number
---@return table
local function snapshot(vehicle)
    local doors = {}

    -- Portas que o modelo nao tem sao filtradas aqui: moto e cupe nao devem
    -- mostrar botao de porta traseira.
    for index = 0, 5 do
        if GetIsDoorValid(vehicle, index) then
            doors[#doors + 1] = {
                index = index,
                label = Config.Doors[index] or ('Porta %d'):format(index),
                open  = GetVehicleDoorAngleRatio(vehicle, index) > 0.0
            }
        end
    end

    return {
        name    = vehicleName(vehicle),
        plate   = Garage.plateOf(vehicle),
        locked  = Garage.isLocked(vehicle),
        -- Dentro do carro ninguem pede chave: quem esta no banco ja entrou.
        canLock = cache.vehicle == vehicle or Garage.hasKey(Garage.plateOf(vehicle)),
        doors   = doors
    }
end

local function sendControl(action, vehicle)
    local data = snapshot(vehicle)

    data.action = action
    SendNUIMessage(data)
end

local function closeControl()
    if not controlling then return end

    controlling = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'control:close' })
end

--- Abre o painel para um veiculo.
---@param vehicle number
local function openControl(vehicle)
    if controlling or not DoesEntityExist(vehicle) then return end

    controlling = vehicle
    SetNuiFocus(true, true)
    sendControl('control:open', vehicle)
end

--- Enquanto o painel estiver aberto, o estado real do carro pode mudar sem
--- passar por ele: outro jogador abre a porta, o servidor tranca. Sem esse
--- acompanhamento o painel mostraria o retrato do momento em que abriu.
CreateThread(function()
    while true do
        if controlling then
            local vehicle = controlling

            if not DoesEntityExist(vehicle) then
                closeControl()
            else
                -- Saiu de perto (ou o carro saiu de perto dele): fecha.
                local distance = #(GetEntityCoords(cache.ped) - GetEntityCoords(vehicle))

                if cache.vehicle ~= vehicle and distance > Config.Lock.distance then
                    closeControl()
                    Garage.notify('Voce se afastou do veiculo.', 'error')
                else
                    sendControl('control:update', vehicle)
                end
            end

            Wait(400)
        else
            Wait(500)
        end
    end
end)

-- ------------------------------------------------------ NUI -> cliente --

RegisterNUICallback('control:close', function(_, cb)
    closeControl()
    cb(1)
end)

RegisterNUICallback('control:door', function(data, cb)
    local vehicle = controlling
    local index = tonumber(type(data) == 'table' and data.index)

    if vehicle and index and DoesEntityExist(vehicle) and GetIsDoorValid(vehicle, index) then
        toggleDoor(vehicle, index)
    end

    cb(1)
end)

RegisterNUICallback('control:lock', function(_, cb)
    local vehicle = controlling

    -- cb primeiro: `setLocked` espera o servidor, e segurar o callback
    -- congelava a NUI durante a ida e volta.
    cb(1)

    if not vehicle or not DoesEntityExist(vehicle) then return end

    local locked = Garage.isLocked(vehicle)

    -- Dentro do carro a chave nao entra na conversa: a mao alcanca o botao da
    -- porta. De fora, sim. O servidor aplica a mesma regra -- este teste aqui
    -- so evita a ida ate la para dar erro.
    --
    -- E isto que fecha o ciclo do lockpick: arromba, entra, destranca por
    -- dentro. O `Garage.picked` e limpo pelo handler de statebag quando o
    -- servidor confirma `nvLocked = false`.
    if cache.vehicle ~= vehicle and not Garage.hasKey(Garage.plateOf(vehicle)) then
        return Garage.notify('Voce nao tem a chave deste veiculo.', 'error')
    end

    setLocked(vehicle, not locked)
end)

-- ------------------------------------------------------------ keybinds --

lib.addKeybind({
    name = 'nv_garage_lock',
    description = 'Trancar veiculo / abrir controle de portas',
    defaultKey = Config.Keybinds.lock,
    onPressed = function()
        if Garage.busy then return end

        -- Painel aberto: a mesma tecla fecha.
        if controlling then return closeControl() end

        -- Dentro do veiculo: painel de controle.
        if cache.vehicle then
            return openControl(cache.vehicle)
        end

        -- Fora: tranca/destranca direto o mais proximo que responda a sua
        -- chave. Abrir um painel para um clique so seria um passo a mais no
        -- gesto mais repetido do jogo.
        local vehicle = Garage.nearestVehicle(Config.Lock.distance)

        if not vehicle then
            return Garage.notify('Nenhum veiculo por perto.', 'error')
        end

        if not Garage.hasKey(Garage.plateOf(vehicle)) then
            return Garage.notify('Voce nao tem a chave deste veiculo.', 'error')
        end

        setLocked(vehicle, not Garage.isLocked(vehicle), true)
    end
})

--- Painel de fora do carro: e por aqui que se abre o porta-malas.
lib.addKeybind({
    name = 'nv_garage_control',
    description = 'Abrir o controle do veiculo (portas, capo, porta-malas)',
    defaultKey = Config.Keybinds.control,
    onPressed = function()
        if Garage.busy then return end
        if controlling then return closeControl() end

        local vehicle = cache.vehicle

        if not vehicle then
            local nearest = Garage.nearestVehicle(Config.Lock.distance)

            if not nearest then
                return Garage.notify('Nenhum veiculo por perto.', 'error')
            end

            if not Garage.hasKey(Garage.plateOf(nearest)) then
                return Garage.notify('Voce nao tem a chave deste veiculo.', 'error')
            end

            vehicle = nearest
        end

        openControl(vehicle)
    end
})

-- O foco da NUI sobrevive ao resource: sem isto, um restart com o painel
-- aberto deixa o jogador com o cursor preso e sem controle.
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and controlling then
        SetNuiFocus(false, false)
    end
end)

-- ----------------------------------------------------------- lockpick --

--- De que porta o jogador esta mais perto.
--- Heuristica pelo referencial do veiculo: x negativo = lado esquerdo,
--- y positivo = frente. Se a traseira nao existir (cupe, moto), cai na
--- dianteira do mesmo lado.
---@param vehicle number
---@return number
local function nearestDoor(vehicle)
    local coords = GetEntityCoords(cache.ped)
    local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, coords.x, coords.y, coords.z)

    local left = offset.x < 0
    local front = offset.y > -0.2

    local index = front and (left and 0 or 1) or (left and 2 or 3)

    if not GetIsDoorValid(vehicle, index) then
        index = left and 0 or 1
    end

    return index
end

--- Arromba a tranca de um veiculo.
local function lockpick()
    if Garage.busy then return end

    -- Em cima de uma moto o lockpick muda de funcao: nao ha porta para
    -- arrombar, e o que ele vence e a trava do contato. Vira a ligacao direta
    -- da moto, sem alicate.
    if cache.vehicle and cache.seat == -1 and Garage.isDoorless(cache.vehicle) then
        return Garage.hotwire('lockpick')
    end

    if cache.vehicle then
        return Garage.notify('Saia do veiculo para arrombar a tranca.', 'error')
    end

    local vehicle, distance = Garage.nearestVehicle(Config.Lock.distance)

    if not vehicle or (distance or 99) > 3.0 then
        return Garage.notify('Chegue mais perto do veiculo.', 'error')
    end

    if Entity(vehicle).state.isDealershipPreview then
        return Garage.notify('Este veiculo e uma previa de exposicao da concessionaria.', 'error')
    end

    -- De fora, numa moto, o lockpick nao tem o que fazer.
    if Garage.isDoorless(vehicle) then
        return Garage.notify('Suba na moto e use o lockpick para forcar o contato.', 'error')
    end

    if not Garage.isLocked(vehicle) then
        return Garage.notify('Este veiculo ja esta destrancado.', 'error')
    end

    -- Atalho: evita a ida ao servidor no caso obvio. Nao e a barreira de
    -- verdade - o dono de um carro ligado nao tem a chave no bolso (ela esta
    -- na ignicao) e passaria por aqui. Quem decide isso e o servidor abaixo,
    -- que olha o dono registrado em vez do inventario.
    if Garage.hasKey(Garage.plateOf(vehicle)) then
        return Garage.notify('Voce tem a chave deste veiculo.', 'error')
    end

    local allowed, reason = lib.callback.await('nv_garage:canLockpick', false, VehToNet(vehicle))

    if not allowed then
        return Garage.notify(reason or 'Nao foi possivel.', 'error')
    end

    local door = nearestDoor(vehicle)

    Garage.busy = true

    -- Vigia o carro durante a barra: se ele arrancar, aborta. Sem isso dava
    -- para ficar pendurado arrombando um carro que ja saiu dirigindo.
    -- O primeiro Wait vem ANTES do teste de proposito: a thread comeca a rodar
    -- antes do progressCircle existir, e cancelar nesse instante nao faria
    -- nada.
    local moved = false
    local watching = true

    CreateThread(function()
        while watching do
            Wait(100)

            if not watching then return end

            if not DoesEntityExist(vehicle) or GetEntitySpeed(vehicle) > Config.Lockpick.moveSpeed then
                moved = true
                lib.cancelProgress()
                return
            end
        end
    end)

    local completed = lib.progressBar({
        duration = Config.Lockpick.duration,
        label = 'Arrombando a tranca...',
        position = 'bottom',
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = { dict = 'veh@break_in@0h@p_m_one@', clip = 'low_force_entry_ds' }
    })

    watching = false

    if not completed then
        Garage.busy = false

        -- Desistir por conta propria nao custa nada; ser interrompido pelo
        -- carro arrancando, sim - a ferramenta ficou presa na fechadura.
        if moved then
            TriggerServerEvent('nv_garage:lockpickWear', 'interrupted')
            Garage.notify('O veiculo se moveu e voce perdeu o encaixe.', 'error')
        end

        return
    end

    local success = exports.nv_minigames:Start(Config.Lockpick.minigame)

    -- A sirene nunca antecipa o resultado visual da task.
    if math.random(100) <= Config.Lockpick.alertChance then
        Garage.triggerTheftAlarm(vehicle, Config.Lockpick.alertEvent, 'Tentativa de arrombamento')
    end

    Garage.busy = false

    if not success then
        TriggerServerEvent('nv_garage:lockpickWear', 'fail')
        Garage.notify('A tranca resistiu.', 'error')

        return
    end

    TriggerServerEvent('nv_garage:lockpickWear', 'success')

    if not DoesEntityExist(vehicle) then return end

    local ok, err = lib.callback.await('nv_garage:unlockLockpicked', false, VehToNet(vehicle))

    if ok then
        Garage.notify('Tranca arrombada. Veiculo destrancado.', 'success')
    else
        Garage.notify(err or 'Nao foi possivel destrancar o veiculo.', 'error')
    end
end

--- Chamado pelo ox_inventory quando o jogador usa o lockpick.
-- O export em si vive em main.lua; aqui so preenchemos o handler. Ver o
-- comentario de `Garage.itemHandlers` para o porque.
Garage.itemHandlers.lockpick = lockpick

-- ---------------------------------------------- veiculos do mundo --

--- Trancas automaticas dos carros que nao tem dono registrado.
---
--- Existe por um motivo so: enquanto o nv_garage nao disser nada sobre um
--- veiculo, quem manda na tranca dele e o GTA -- e a tranca do GTA (estado 2)
--- e a que oferece "quebrar o vidro e entrar". Esse roubo nativo acontece de
--- graca, sem lockpick, sem alicate e sem minigame, e portanto atropela o
--- fluxo inteiro deste resource. Deixar carro estacionado de fora da varredura
--- era o que mantinha essa porta aberta.
---
--- Agora todo veiculo sem statebag e trancado com `Config.Lock.lockedState`
--- (10 = trancado e NAO arrombavel pelo jogo). A entrada volta a ser
--- exclusivamente lockpick -> ligacao direta.
CreateThread(function()
    local cfg = Config.WorldVehicles

    if not cfg.enabled then return end

    local ignore = {}

    for model in pairs(cfg.ignoreModels) do
        ignore[GetHashKey(model)] = true
    end

    -- Carro que dispensa chave nao pode ficar trancado contra o jogador: seria
    -- uma porta que nenhuma ferramenta do resource abre.
    for model in pairs(Config.Ignition.noKeyModels) do
        ignore[GetHashKey(model)] = true
    end

    while true do
        Wait(cfg.interval)

        local coords = GetEntityCoords(cache.ped)
        local nearby = lib.getNearbyVehicles(coords, cfg.radius, false)

        for i = 1, #nearby do
            local vehicle = nearby[i].vehicle

            -- Statebag definido = veiculo de jogador, ja tem dono da decisao.
            local untracked = Entity(vehicle).state.nvLocked == nil

            -- Moto nunca entra: nao ha porta para trancar, e travar so
            -- impediria de subir. O que segura o roubo dela e a ignicao.
            if untracked and not ignore[GetEntityModel(vehicle)] and not Garage.isDoorless(vehicle) then
                local npcDriven = cfg.lockNpcDriven
                    and Garage.hasNpcDriver(vehicle)
                    and (not cfg.requireEngineOn or IsVehicleEngineOn(vehicle))

                -- `lockUntracked` cobre o resto: parado, vazio, abandonado.
                -- E o caso que antes caia na tranca nativa.
                local shouldLock = npcDriven or cfg.lockUntracked

                if shouldLock then
                    Garage.worldLocked[vehicle] = true
                    Garage.applyLock(vehicle)
                elseif Garage.worldLocked[vehicle] and not Garage.picked[vehicle] then
                    -- Só chega aqui com `lockUntracked` desligado: o motorista
                    -- saiu e a tranca de NPC perdeu o sentido.
                    Garage.worldLocked[vehicle] = nil
                    SetVehicleDoorsLocked(vehicle, 1)
                end
            end
        end
    end
end)

-- ------------------------------------------------- saiu sem destrancar --

--- Arrombou, entrou, mas nao destrancou por dentro? Ao sair, a tranca volta.
lib.onCache('vehicle', function(value, previous)
    if value or not previous then return end
    if not DoesEntityExist(previous) then return end

    if Garage.picked[previous] then
        Garage.picked[previous] = nil
        Garage.applyLock(previous)
    end
end)
