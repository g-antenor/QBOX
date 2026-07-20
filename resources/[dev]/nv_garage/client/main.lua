--[[
    nv_garage — cliente: base compartilhada

    Carregado primeiro. Declara o namespace `Garage` que keys.lua, locks.lua e
    garage.lua usam, mais os utilitarios que os tres precisam.
]]

Garage = {}

-- ------------------------------------------------------- itens do ox_inv --

--- Handlers dos itens usaveis (lockpick, alicate).
---
--- Os exports sao registrados AQUI, no primeiro arquivo do resource, e nao no
--- arquivo onde cada funcao mora. O motivo e concreto:
---
--- `exports('useLockpick', lockpick)` fica na ULTIMA linha de locks.lua. Ele so
--- roda se as ~480 linhas anteriores carregarem sem erro. Qualquer falha no
--- meio do arquivo -- uma que nem chega perto do lockpick -- impede o registro,
--- e o ox_inventory devolve "No such export useLockpick in resource nv_garage".
--- Essa mensagem aponta para o export, que e a vitima, e nao para o erro que
--- realmente aconteceu.
---
--- Com o despacho indireto o export existe sempre, porque este arquivo e curto
--- e carrega primeiro. Se o handler nao tiver sido preenchido, o jogador recebe
--- uma mensagem e o console recebe um aviso com o nome certo do problema.
---@type table<string, function>
Garage.itemHandlers = {}

---@param name string
---@return function
local function itemExport(name)
    return function()
        local handler = Garage.itemHandlers[name]

        if not handler then
            print(('[nv_garage] handler do item "%s" nao foi registrado: o arquivo que o define falhou ao carregar. Procure o erro ANTERIOR a este no console.'):format(name))

            return Garage.notify('Este item nao esta funcionando. Avise a equipe.', 'error')
        end

        return handler()
    end
end

exports('useLockpick', itemExport('lockpick'))
exports('useCutters', itemExport('cutters'))

-- --------------------------------------------------------------- estado --

--- Veiculos arrombados com lockpick e ainda logicamente trancados.
---
--- O valor e o `GetGameTimer()` do fim da janela de entrada, em milissegundos.
--- Nao use `os.time` aqui: a biblioteca `os` nao existe no runtime do cliente,
--- e a chamada estoura com "attempt to index a nil value".
---@type table<number, number>
Garage.picked = {}

--- Trava simples para nao empilhar minigames.
Garage.busy = false

--- Veiculos do mundo (transito e estacionados) trancados por este cliente.
---
--- Deliberadamente LOCAL, sem statebag: a tranca de um carro sem dono e so uma
--- regra de entrada, e cada cliente chega a mesma conclusao olhando para o
--- mesmo carro. Tentar replicar isso exigiria posse da entidade e encheria a
--- rede de mensagens para nada.
---
--- Quem preenche e a varredura em locks.lua. Ver `Config.WorldVehicles`.
---@type table<number, boolean>
Garage.worldLocked = {}

-- ------------------------------------------------------------ utilidades --

---@param message string
---@param type string?
function Garage.notify(message, type)
    lib.notify({
        title = 'Veiculo',
        description = message,
        type = type or 'inform',
        position = 'top'
    })
end

--- Placa limpa (o nativo devolve com espacos a direita).
---@param vehicle number
---@return string
function Garage.plateOf(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle) or ''

    return (plate:gsub('%s+$', ''))
end

--- Dispara a sirene e registra a mesma tentativa no dispatch. O id liga o
--- alarme local ao blip remoto, permitindo encerrar ambos antes do limite.
---@param vehicle number
---@param event string?
---@param reason string
function Garage.triggerTheftAlarm(vehicle, event, reason)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local duration = math.max(1, tonumber(Config.Alarm and Config.Alarm.duration) or 60)
    local alertId = ('vehicle_%s_%d'):format(GetPlayerServerId(PlayerId()), GetGameTimer())

    SetVehicleAlarm(vehicle, true)
    SetVehicleAlarmTimeLeft(vehicle, duration * 1000)
    StartVehicleAlarm(vehicle)

    if event then
        TriggerServerEvent(event, GetEntityCoords(vehicle), {
            id = alertId,
            netId = VehToNet(vehicle),
            plate = Garage.plateOf(vehicle),
            reason = reason,
            duration = duration
        })
    end

    CreateThread(function()
        local deadline = GetGameTimer() + duration * 1000
        Wait(750)

        while DoesEntityExist(vehicle) and GetGameTimer() < deadline and IsVehicleAlarmActivated(vehicle) do
            if event then
                TriggerServerEvent('nv_garage:dispatchTheftMoved', alertId, GetEntityCoords(vehicle))
            end

            Wait(100)
        end

        TriggerServerEvent('nv_garage:dispatchTheftStopped', alertId)
    end)
end

---@param vehicle number
function Garage.stopTheftAlarm(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    SetVehicleAlarmTimeLeft(vehicle, 0)
    SetVehicleAlarm(vehicle, false)
end

--- O jogador tem a chave desta placa no inventario?
--- Consulta local do ox_inventory: sem ida ao servidor, serve para decidir o
--- que MOSTRAR. Quem autoriza de verdade e o servidor.
---@param plate string
---@return boolean
function Garage.hasKey(plate)
    local count = exports.ox_inventory:Search('count', Config.Items.key, { plate = plate })

    return (count or 0) > 0
end

--- Este veiculo esta logicamente trancado?
---
--- O statebag manda quando existe: se ele esta definido, o veiculo ja passou
--- pelas maos de alguem e a decisao e do servidor. So na ausencia dele vale a
--- tranca automatica dos veiculos do mundo.
---@param vehicle number
---@return boolean
function Garage.isLocked(vehicle)
    local state = Entity(vehicle).state.nvLocked

    if state ~= nil then return state == true end

    return Garage.worldLocked[vehicle] == true
end

-- ------------------------------------------------------- motor pendente --

--- Ordem de ignicao ja dada, mas cujo statebag ainda nao voltou do servidor.
---
--- A resposta do callback e a replicacao do statebag sao dois caminhos
--- diferentes e nao chegam em ordem garantida. Sem este override, a thread que
--- forca "motor desligado" lia o valor antigo e desligava o carro no instante
--- seguinte ao de ligar.
---@type table<number, { value: boolean, expires: number }>
local pendingEngine = {}

---@param vehicle number
---@param value boolean
function Garage.setPendingEngine(vehicle, value)
    pendingEngine[vehicle] = { value = value, expires = GetGameTimer() + 3000 }
end

--- O que vale para este veiculo agora: a ordem local recente, se houver, senao
--- nada (e quem decide passa a ser o statebag).
---@param vehicle number
---@return boolean?
function Garage.pendingEngine(vehicle)
    local entry = pendingEngine[vehicle]
    if not entry then return end

    -- Statebag alcancou a ordem: o override cumpriu o papel e sai de cena.
    if Entity(vehicle).state.nvEngine == entry.value then
        pendingEngine[vehicle] = nil
        return
    end

    -- Prazo estourado sem o statebag confirmar. Segurar mais tempo esconderia
    -- um problema de sincronia em vez de resolve-lo.
    if GetGameTimer() > entry.expires then
        pendingEngine[vehicle] = nil
        return
    end

    return entry.value
end

--- Motor autorizado dos veiculos SEM statebag (carro de rua).
---
--- Existe porque a checagem antiga se mordia: `engineOn` caia em
--- `IsVehicleEngineOn`, e a thread que segura o motor desligado so corrige
--- quando `engineOn` diz "desligado". Ou seja, ela lia como verdade exatamente
--- o que deveria estar controlando. Bastava o motor pegar por um frame -- e o
--- roubo nativo do GTA faz isso -- para o estado travar em "ligado" para
--- sempre, porque carro de rua nunca ganha statebag para desmentir.
---
--- Aqui o valor e gravado uma vez, quando o jogador COMECA A ENTRAR no carro,
--- e so muda por uma ordem legitima (ignicao com chave ou ligacao direta). O
--- motor nao consegue mais se autorizar sozinho.
---@type table<number, boolean>
Garage.authorizedEngine = {}

--- Fotografa o motor de um veiculo sem dono no momento da entrada.
---
--- Carro que JA estava rodando continua rodando: roubar um carro em movimento
--- e mecanica, nao brecha. O que fecha e o contrario -- entrar num carro
--- desligado e ele pegar sozinho.
---@param vehicle number
function Garage.captureEngine(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    -- Statebag manda: veiculo com dono nao usa esta tabela.
    if Entity(vehicle).state.nvEngine ~= nil then return end
    if Garage.authorizedEngine[vehicle] ~= nil then return end

    Garage.authorizedEngine[vehicle] = IsVehicleEngineOn(vehicle)
end

--- Registra uma ordem legitima de ignicao (chave ou ligacao direta).
---@param vehicle number
---@param value boolean
function Garage.authorizeEngine(vehicle, value)
    Garage.authorizedEngine[vehicle] = value
end

--- O veiculo esta com o motor ligado na nossa contabilidade?
---@param vehicle number
---@return boolean
function Garage.engineOn(vehicle)
    local state = Entity(vehicle).state.nvEngine

    if state ~= nil then return state == true end

    local authorized = Garage.authorizedEngine[vehicle]

    if authorized ~= nil then return authorized end

    -- Nunca visto de perto (carro passando ao longe): o estado do jogo serve.
    -- A foto e tirada na entrada, antes de qualquer chance de dar partida.
    return IsVehicleEngineOn(vehicle)
end

--- O veiculo mais proximo do jogador dentro do raio.
---@param maxDistance number
---@return number?, number?
function Garage.nearestVehicle(maxDistance)
    local coords = GetEntityCoords(cache.ped)
    local vehicles = lib.getNearbyVehicles(coords, maxDistance, true)

    local closest, closestDistance

    for i = 1, #vehicles do
        local entry = vehicles[i]
        local distance = #(coords - entry.coords)

        if not closestDistance or distance < closestDistance then
            closest, closestDistance = entry.vehicle, distance
        end
    end

    return closest, closestDistance
end

--- Um veiculo tem NPC ao volante?
---@param vehicle number
---@return boolean
function Garage.hasNpcDriver(vehicle)
    local driver = GetPedInVehicleSeat(vehicle, -1)

    if not driver or driver == 0 or not DoesEntityExist(driver) then return false end
    if IsPedAPlayer(driver) then return false end

    return not IsEntityDead(driver)
end

--- Veiculo sem fechadura de porta (moto, bicicleta)?
---@param vehicle number
---@return boolean
function Garage.isDoorless(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    return Config.Doorless[GetVehicleClass(vehicle)] == true
end

--- Aplica no jogo o estado de tranca que a logica diz que vale.
--- Exceto quando o jogador arrombou o carro e a janela ainda esta aberta -
--- nesse caso a entrada dele continua liberada localmente.
---@param vehicle number
function Garage.applyLock(vehicle)
    if not DoesEntityExist(vehicle) then return end

    -- Moto fica SEMPRE destravada fisicamente, mesmo com `nvLocked` ligado.
    -- Nao ha porta para trancar: travar so impediria de subir, e ai nao
    -- existiria roubo de moto no servidor. A protecao dela e a ignicao, que
    -- continua exigindo a chave.
    if Garage.isDoorless(vehicle) then
        SetVehicleDoorsLocked(vehicle, 1)
        return
    end

    local locked = Garage.isLocked(vehicle)

    if locked and Garage.picked[vehicle] then
        if GetGameTimer() < Garage.picked[vehicle] then
            SetVehicleDoorsLocked(vehicle, 1)
            return
        end

        -- Janela expirou: a tranca volta.
        Garage.picked[vehicle] = nil
    end

    -- Estado 10 e nao 2. Os dois deixam o carro "trancado", mas o 2 e a tranca
    -- comum do GTA: o jogo oferece quebrar o vidro e entrar, e isso passa por
    -- cima do lockpick inteiro -- minigame, tempo, alicate, tudo. O 10 e
    -- "trancado e nao arrombavel", que e a unica forma de a entrada ficar
    -- exclusivamente com o fluxo daqui.
    SetVehicleDoorsLocked(vehicle, locked and Config.Lock.lockedState or 1)
end

-- ------------------------------------------------------------- limpeza --

--- Entidades somem; a tabela `picked` nao pode crescer para sempre.
CreateThread(function()
    while true do
        Wait(30000)

        local now = GetGameTimer()

        for entity, expiry in pairs(Garage.picked) do
            if not DoesEntityExist(entity) or now >= expiry then
                Garage.picked[entity] = nil
            end
        end

        for entity in pairs(Garage.worldLocked) do
            if not DoesEntityExist(entity) then
                Garage.worldLocked[entity] = nil
            end
        end

        for entity in pairs(Garage.authorizedEngine) do
            if not DoesEntityExist(entity) then
                Garage.authorizedEngine[entity] = nil
            end
        end
    end
end)

-- ---------------------------------------------------------- ferramentas --

--- Diz quais arquivos do cliente carregaram ate o fim.
---
--- Cada arquivo registra seu handler/marca na ultima linha, entao um "NAO" aqui
--- significa "aquele arquivo abortou no meio" - e o erro de verdade esta no
--- console, antes de qualquer reclamacao sobre export faltando.
RegisterCommand('nvgaragecheck', function()
    local checks = {
        { 'client/keys.lua  (alicate)',  Garage.itemHandlers.cutters ~= nil },
        { 'client/locks.lua (lockpick)', Garage.itemHandlers.lockpick ~= nil },
        { 'client/garage.lua (garagem)', Garage.garageLoaded == true }
    }

    print('[nv_garage] --- carga do cliente ---')

    local allOk = true

    for i = 1, #checks do
        local label, ok = checks[i][1], checks[i][2]

        if not ok then allOk = false end

        print(('[nv_garage] %-30s %s'):format(label, ok and 'OK' or 'NAO CARREGOU'))
    end

    Garage.notify(allOk and 'Todos os arquivos carregaram.' or 'Algum arquivo falhou - veja o console (F8).',
        allOk and 'success' or 'error')
end, false)

--- Captura a posicao atual, para preencher `Config.Garages` sem chutar.
---
--- Abre o overlay de coordenadas do nv_adminmenu: leitura ao vivo no topo da
--- tela, ENTER copia vec4 (a vaga), TAB copia vec3 (o ped), BACKSPACE fecha.
--- Marcar uma garagem e andar de vaga em vaga copiando, e o overlay e o unico
--- formato em que da para ver o numero mudando enquanto se anda.
---
--- A implementacao vive la de proposito: duas copias da mesma thread em
--- resources diferentes sairiam de sincronia na primeira mudanca de tecla. O
--- fallback abaixo existe para o comando nao morrer quando o admin menu nao
--- esta rodando -- ele e uma ferramenta de dev, nao uma dependencia real.
RegisterCommand('nvgaragecoords', function()
    local ok = pcall(function()
        return exports.nv_adminmenu:CoordsOverlay()
    end)

    if ok then return end

    local coords = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)

    local ped = ('vec3(%.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z)
    local spawn = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(coords.x, coords.y, coords.z, heading)

    print(('[nv_garage] ped    = %s'):format(ped))
    print(('[nv_garage] spawn  = %s'):format(spawn))

    lib.setClipboard(spawn)
    Garage.notify('nv_adminmenu fora do ar: coordenadas no console e na area de transferencia.', 'success')
end, false)
