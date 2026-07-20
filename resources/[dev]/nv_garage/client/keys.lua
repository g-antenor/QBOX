--[[
    nv_garage — cliente: ignicao e ligacao direta

    O GTA liga o motor sozinho assim que o jogador senta no banco do motorista.
    Nao existe nativo para "desativar a partida automatica" de uma vez, entao a
    unica saida e reafirmar `SetVehicleEngineOn(false, ..., true)` a cada frame
    enquanto o carro devia estar desligado. E por isso que a thread abaixo roda
    em Wait(0) - so nessa condicao.
]]

-- --------------------------------------------------- roubo nativo OFF --

--- Desliga a partida automatica do GTA.
---
--- O jogo tem um roubo de carro proprio: ao entrar num veiculo sem chave, o
--- ped faz sozinho a ligacao direta e o motor pega. Isso concorre com o
--- hotwire daqui (alicate + minigame) e sempre ganha, porque acontece de
--- graca e antes.
---
--- A flag 429 (`_PED_FLAG_DISABLE_STARTING_VEH_ENGINE`) e o que desliga esse
--- comportamento. Ela vive no PED, nao no jogador: troca de ped (respawn,
--- mudanca de modelo, /skin) zera tudo, por isso reaplicamos a cada troca em
--- vez de so uma vez no start.
local function blockNativeHotwire(ped)
    if not ped or ped == 0 then return end

    SetPedConfigFlag(ped, 429, true)
end

CreateThread(function()
    blockNativeHotwire(cache.ped)
end)

lib.onCache('ped', blockNativeHotwire)

AddEventHandler('playerSpawned', function()
    blockNativeHotwire(PlayerPedId())
end)

--- Tira do VEICULO a marca de "precisa ser ligado na raca".
---
--- A flag 429 do ped impede o motor de pegar, mas nao apaga a encenacao: quem
--- decide se ha animacao de ligacao direta ao entrar e o proprio veiculo, pela
--- marca que `SetVehicleNeedsToBeHotwired` controla. Sem limpar isso o jogador
--- entrava, assistia o ped mexer nos fios, e no fim o motor nao pegava -- o
--- pior dos dois mundos.
---
--- `SetVehicleIsStolen(false)` entra junto porque carro marcado como roubado
--- volta a pedir hotwire por conta propria.
---@param vehicle number
local function clearHotwireFlag(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleIsStolen(vehicle, false)
end

--- A marca precisa cair ANTES de o ped sentar, senao a animacao ja comecou.
--- Por isso olhamos para o veiculo em que ele esta ENTRANDO, e nao para o que
--- ele ja ocupa: quando `cache.vehicle` muda, e tarde.
CreateThread(function()
    while true do
        local wait = 500
        local entering = GetVehiclePedIsEntering(cache.ped)

        if entering and entering ~= 0 then
            -- Enquanto a entrada acontece vale cada frame: o jogo reafirma a
            -- marca durante a sequencia de entrada.
            wait = 0
            clearHotwireFlag(entering)

            -- A foto do motor tem que ser tirada AGORA, antes de o ped sentar:
            -- e o unico instante em que o estado do jogo ainda nao pode ter
            -- sido contaminado por uma partida automatica.
            Garage.captureEngine(entering)
        elseif cache.vehicle then
            -- Cobre quem entrou por teleporte (admin, spawn) e nunca passou
            -- pelo estado "entrando".
            clearHotwireFlag(cache.vehicle)
            Garage.captureEngine(cache.vehicle)
        end

        Wait(wait)
    end
end)

-- ------------------------------------------------------------ ignicao --

--- Estamos no banco do motorista de um veiculo valido?
---@return number?
local function drivingVehicle()
    local vehicle = cache.vehicle

    if not vehicle or cache.seat ~= -1 then return end
    if not DoesEntityExist(vehicle) then return end

    return vehicle
end

--- Mantem o motor desligado enquanto a logica disser que ele esta desligado.
CreateThread(function()
    while true do
        local wait = 500
        local vehicle = drivingVehicle()

        if vehicle then
            -- A ordem local recem dada tem prioridade sobre o statebag, que
            -- pode estar alguns frames atrasado.
            local on = Garage.pendingEngine(vehicle)

            if on == nil then on = Garage.engineOn(vehicle) end

            if not on then
                wait = 0
                SetVehicleEngineOn(vehicle, false, true, true)
            end
        end

        Wait(wait)
    end
end)

--- Saiu do carro sem desligar? O carro FICA ligado.
---
--- O GTA desliga o motor sozinho na animacao de saida, e era isso que
--- acontecia: o statebag continuava dizendo "ligado" (a chave seguia na
--- ignicao, fora do inventario) enquanto o carro morria na tela. Estado logico
--- e estado visivel discordando.
---
--- Quem decide se o motor para e o jogador, apertando a tecla de ignicao - e
--- so isso devolve a chave. Deixar o carro ligado na rua e uma escolha, com a
--- consequencia de qualquer um poder entrar e sair dirigindo.
---
--- Os ~2.5s de reafirmacao cobrem a animacao de saida; depois dela o jogo nao
--- desliga mais nada sozinho.
lib.onCache('vehicle', function(value, previous)
    if value or not previous then return end
    if not DoesEntityExist(previous) then return end
    if not Garage.engineOn(previous) then return end

    CreateThread(function()
        local deadline = GetGameTimer() + 2500

        while GetGameTimer() < deadline do
            if not DoesEntityExist(previous) then return end

            -- Alguem desligou de verdade no meio do caminho: respeita.
            if not Garage.engineOn(previous) then return end

            SetVehicleEngineOn(previous, true, true, true)
            Wait(0)
        end
    end)
end)

--- Liga ou desliga o motor do veiculo em que o jogador esta.
---@param desired boolean
local function toggleEngine(desired)
    local vehicle = drivingVehicle()

    if not vehicle then
        return Garage.notify('Voce precisa estar no banco do motorista.', 'error')
    end

    if Garage.busy then return end

    if desired then
        local state = Entity(vehicle).state
        local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
        local keyless = Config.Ignition.noKeyModels[model] == true

        -- A verificacao local acontece antes da barra. O servidor continua
        -- validando de verdade depois, mas apertar a tecla sem chave fica mudo.
        if not keyless and not state.nvHotwired and not Garage.hasKey(Garage.plateOf(vehicle)) then
            return Garage.hotwire and Garage.hotwire('cutters')
        end
    end

    local netId = VehToNet(vehicle)

    -- Partida: pequena espera para o motor "pegar". Desligar e instantaneo.
    if desired and Config.Ignition.startTime > 0 then
        Garage.busy = true

        local completed = lib.progressBar({
            duration = Config.Ignition.startTime,
            label = 'Dando partida...',
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, combat = true }
        })

        Garage.busy = false

        if not completed then return end
        if drivingVehicle() ~= vehicle then return end
    end

    local ok, err = lib.callback.await('nv_garage:toggleEngine', false, netId, desired)

    if not ok then
        return Garage.notify(err or 'Nao foi possivel.', 'error')
    end

    -- O terceiro argumento (`instantly`) precisa ser TRUE, e isso nao e
    -- cosmetico: com `false` o nativo pede ao PED que execute a ignicao, e a
    -- flag 429 que ligamos ali em cima para matar o roubo nativo proibe
    -- exatamente isso. O resultado era a chave sair do inventario, o servidor
    -- marcar o motor como ligado e o carro nao pegar.
    --
    -- Perder a animacao de partida nao custa nada aqui: a barra de progresso
    -- "Dando partida..." ja e a encenacao.
    SetVehicleEngineOn(vehicle, desired, true, true)

    -- O statebag do servidor viaja separado da resposta deste callback. Ate
    -- ele chegar, `Garage.engineOn` ainda devolve o valor antigo - e a thread
    -- de cima desligaria o motor que acabamos de ligar. O override local cobre
    -- essa janela.
    Garage.setPendingEngine(vehicle, desired)

    -- Ordem legitima: e o unico jeito de um carro sem dono passar a contar
    -- como ligado. Sem isto a thread de cima desligaria o motor de volta.
    Garage.authorizeEngine(vehicle, desired)

    Garage.notify(desired and 'Motor ligado.' or 'Motor desligado. Chave no bolso.', 'success')
end

lib.addKeybind({
    name = 'nv_garage_ignition',
    description = 'Ligar / desligar o motor',
    defaultKey = Config.Keybinds.ignition,
    onPressed = function()
        local vehicle = drivingVehicle()
        if not vehicle then return end

        toggleEngine(not Garage.engineOn(vehicle))
    end
})

-- ------------------------------------------------------ ligacao direta --

--- Choque ao encostar no fio errado.
---
--- Ragdoll + tremida de tela + perda de vida com piso: `Config.Hotwire.shock`.
--- O piso existe porque o choque e punicao, nao causa de morte — perder o
--- carro para a policia com 10 de vida ja e ruim o bastante sem morrer no
--- banco do motorista.
local function shock()
    local cfg = Config.Hotwire.shock

    if not cfg or not cfg.enabled then return end

    local ped = cache.ped

    SetPedToRagdoll(ped, cfg.ragdoll, cfg.ragdoll, 0, false, false, false)

    -- Efeito de tela curto: o feedback visual e o que faz o choque ser lido
    -- como choque, e nao como "o minigame bugou".
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.35)
    StartScreenEffect('DeathFailMpDark', 800, false)

    CreateThread(function()
        Wait(800)
        StopScreenEffect('DeathFailMpDark')
    end)

    local health = GetEntityHealth(ped)
    local damage = math.random(cfg.damage[1], cfg.damage[2])

    -- Ja abaixo do piso: leva o tranco, nao leva o dano.
    if health <= cfg.floor then return end

    SetEntityHealth(ped, math.max(cfg.floor, health - damage))
end

--- Minigame da ligacao direta.
---
--- Serve a duas ferramentas. `'cutters'` (o padrao) e o alicate no carro;
--- `'lockpick'` e a moto, onde nao ha porta para arrombar e o que se vence e a
--- trava do contato. O fluxo e o mesmo, muda o item cobrado e o texto.
---@param tool string? 'cutters' | 'lockpick'
local function hotwire(tool)
    tool = tool == 'lockpick' and 'lockpick' or 'cutters'

    local vehicle = drivingVehicle()

    if not vehicle then
        return Garage.notify('Voce precisa estar no banco do motorista.', 'error')
    end

    if Garage.engineOn(vehicle) then
        return Garage.notify('O motor ja esta ligado.', 'error')
    end

    if Garage.busy then return end

    local netId = VehToNet(vehicle)

    -- Confere a ferramenta antes de gastar o tempo do jogador.
    local allowed, reason = lib.callback.await('nv_garage:canHotwire', false, netId, tool)

    if not allowed then
        return Garage.notify(reason or 'Nao foi possivel.', 'error')
    end

    Garage.busy = true

    local completed = lib.progressBar({
        duration = Config.Hotwire.duration,
        label = tool == 'lockpick' and 'Forcando a trava do contato...' or 'Fazendo ligacao direta...',
        position = 'bottom',
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
    })

    if not completed then
        Garage.busy = false
        return
    end

    local success = exports.nv_minigames:Start(Config.Hotwire.minigame)

    -- O alarme so pode reagir depois que a task/minigame terminou.
    local jammed = lib.callback.await('nv_garage:isBlocked', false, netId) == true
    local alertChance = jammed and Config.Hotwire.jammedAlertChance or Config.Hotwire.alertChance
    local alarmTriggered = math.random(100) <= alertChance

    if alarmTriggered then
        Garage.triggerTheftAlarm(vehicle, jammed and nil or Config.Hotwire.alertEvent,
            'Tentativa de ligação direta')
    end

    Garage.busy = false

    if not success then
        shock()

        Garage.notify(tool == 'lockpick'
            and 'A trava do contato resistiu e voce tomou um choque.'
            or 'Voce encostou no fio errado e tomou um choque.', 'error')

        -- Falhar com o lockpick gasta a ferramenta, igual ao arrombamento.
        if tool == 'lockpick' then
            TriggerServerEvent('nv_garage:lockpickWear', 'fail')
        end

        return
    end

    if drivingVehicle() ~= vehicle then return end

    if not lib.callback.await('nv_garage:hotwire', false, netId, tool) then
        return Garage.notify('Nao foi possivel.', 'error')
    end

    -- `instantly = true` pelo mesmo motivo da ignicao normal: a flag 429 impede
    -- o ped de dar a partida.
    SetVehicleEngineOn(vehicle, true, true, true)
    Garage.setPendingEngine(vehicle, true)
    Garage.authorizeEngine(vehicle, true)

    if jammed then
        if alarmTriggered then Garage.stopTheftAlarm(vehicle) end
        TriggerServerEvent('nv_garage:blockerSignalLost', GetEntityCoords(vehicle), {
            plate = Garage.plateOf(vehicle)
        })
    end

    -- O texto avisa que a ligacao nao persiste. Dizer "liga sem chave agora",
    -- como dizia antes, era uma promessa que o servidor nao cumpre mais:
    -- desligar o motor desfaz os fios.
    Garage.notify(tool == 'lockpick'
        and 'Contato forcado. Se desligar, tera de forcar de novo.'
        or 'Ligacao direta feita. Se desligar o motor, tera de refaze-la.', 'success')
end

--- locks.lua chama isto quando o lockpick e usado em cima de uma moto.
Garage.hotwire = hotwire

--- Chamado pelo ox_inventory quando o jogador usa o alicate de corte.
--- O export vive em main.lua; ver `Garage.itemHandlers`.
Garage.itemHandlers.cutters = hotwire
