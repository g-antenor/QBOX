--[[
    nv_garage — servidor: a garagem em si

    Listar / retirar / guardar. Nada de transferencia: o veiculo pertence a
    quem o `owner` do ox_core diz que pertence, e ponto.
]]

local Ox = require '@ox_core.lib.init'

-- Catalogo do ox_core, para exibir "Grotti Itali GTO" em vez de "italigto".
---@type table<string, table>
local catalog = {}

do
    local file = LoadResourceFile('ox_core', 'common/data/vehicles.json')
    local ok, decoded = pcall(json.decode, file or '')

    if ok and type(decoded) == 'table' then
        catalog = decoded
    else
        lib.print.warn('Nao foi possivel ler common/data/vehicles.json do ox_core; os veiculos vao aparecer pelo nome do modelo.')
    end
end

-- Nomes das classes de veiculo do GTA (indice = coluna `class`).
local CLASS_NAMES = {
    [0] = 'Compacto', [1] = 'Sedan', [2] = 'SUV', [3] = 'Cupe',
    [4] = 'Muscle', [5] = 'Esportivo Classico', [6] = 'Esportivo',
    [7] = 'Super', [8] = 'Moto', [9] = 'Off-road', [10] = 'Industrial',
    [11] = 'Utilitario', [12] = 'Van', [13] = 'Bicicleta', [14] = 'Barco',
    [15] = 'Helicoptero', [16] = 'Aviao', [17] = 'Servico',
    [18] = 'Emergencia', [19] = 'Militar', [20] = 'Comercial', [21] = 'Trem'
}

---@param model string
---@return string
local function displayName(model)
    local entry = catalog[model]
    if not entry then return model:upper() end

    local name = entry.name or model

    return entry.make ~= '' and entry.make and ('%s %s'):format(entry.make, name) or name
end

-- main.lua tambem precisa disso para nomear a chave, e ele carrega antes deste
-- arquivo. Os callbacks so rodam depois que tudo subiu, entao expor aqui basta.
Server.displayName = displayName

---@param model string
---@param class number?
---@return string
local function classLabel(model, class)
    local entry = catalog[model]
    local index = class or (entry and entry.class)

    return CLASS_NAMES[index] or 'Veiculo'
end

--- Converte 0-1000 (vida de motor/lataria) para 0-100.
---@param value number?
---@param fallback number
---@return number
local function toPercent(value, fallback)
    if type(value) ~= 'number' then return fallback end

    return math.floor(math.max(0, math.min(1000, value)) / 10 + 0.5)
end

--- O ox_core guarda as propriedades dentro de `data.properties`. Versoes
--- antigas da base gravavam a tabela diretamente, portanto aceitamos os dois
--- formatos durante a migracao.
---@param raw string?
---@return table
local function decodeProperties(raw)
    local ok, data = pcall(json.decode, raw or '{}')
    if not ok or type(data) ~= 'table' then return {} end

    return type(data.properties) == 'table' and data.properties or data
end

--- Parte das propriedades que representa avaria. Ela fica num state bag
--- persistente para ser reaplicada sempre que a entidade voltar ao streaming
--- de um cliente; o state bag temporario do ox_lib e limpo no primeiro apply.
---@param properties table
---@return table
local function damageSnapshot(properties)
    return {
        bodyHealth = properties.bodyHealth,
        engineHealth = properties.engineHealth,
        tankHealth = properties.tankHealth,
        dirtLevel = properties.dirtLevel,
        windows = properties.windows or {},
        doors = properties.doors or {},
        tyres = properties.tyres or {}
    }
end

-- --------------------------------------------------------- garagem mais --
--                                                            proxima      --

--- Nome da garagem mais proxima de um ponto (ou de um jogador).
---
--- Existe para outros resources -- o nv_adminmenu usa ao registrar um veiculo
--- no nome de alguem, para o carro nascer na garagem que faz sentido para
--- aquele jogador em vez de sempre na mesma.
---
---@param target number|vector3 id de jogador no servidor, ou coordenadas
---@return string?  chave de Config.Garages
---@return number?  distancia em metros
local function nearestGarage(target)
    local coords = target

    if type(target) == 'number' then
        local ped = GetPlayerPed(target)

        if not ped or ped == 0 then return end

        coords = GetEntityCoords(ped)
    end

    if type(coords) ~= 'vector3' then return end

    local closest, closestDistance

    for name, garage in pairs(Config.Garages) do
        local distance = #(coords - garage.ped)

        if not closestDistance or distance < closestDistance then
            closest, closestDistance = name, distance
        end
    end

    return closest, closestDistance
end

Server.nearestGarage = nearestGarage

exports('NearestGarage', nearestGarage)

--- Ha espaco para nascer um veiculo neste ponto?
---
--- Conferido no SERVIDOR de proposito: o cliente que pede a retirada nem
--- sempre enxerga o carro que ja esta na vaga (streaming), e nascer dentro de
--- outro veiculo manda os dois pelos ares.
---@param coords vector3
---@param radius number?
---@return boolean
function Server.spotIsFree(coords, radius)
    radius = radius or 2.5

    -- GetAllVehicles nao existe em builds antigas do FXServer. Sem ele, damos
    -- a vaga por livre: e o mesmo comportamento de antes desta funcao.
    if not GetAllVehicles then return true end

    local vehicles = GetAllVehicles()

    for i = 1, #vehicles do
        local entity = vehicles[i]

        if DoesEntityExist(entity) and #(GetEntityCoords(entity) - coords) <= radius then
            return false
        end
    end

    return true
end

-- ------------------------------------------------------------- listagem --

--- Monta a linha que a NUI desenha para um veiculo.
---@param row table
---@param spawned table<string, table>
---@return table
local function buildEntry(row, spawned)
    local properties = decodeProperties(row.data)

    local live = spawned[row.vin]
    local mechanical
    if GetResourceState('nv_mechanic') == 'started' then
        mechanical = exports.nv_mechanic:GetSnapshot(row.vin)
    end
    local tyreMetric = 100
    if mechanical and type(mechanical.tyres) == 'table' then
        local total = 0
        for i = 1, 4 do total = total + (tonumber(mechanical.tyres[i]) or 100) end
        tyreMetric = math.floor(total / 4 + 0.5)
    end

    -- `stored` NULL significa "fora da garagem". O ox_core usa a string
    -- 'impound' para o patio.
    local status = 'out'

    if row.stored == Config.Garage.impoundName then
        status = 'impound'
    elseif row.stored then
        status = 'stored'
    end

    -- Nome legivel de onde o carro esta. Sem isto a NUI so tinha a chave crua
    -- (`legion`) e acabava desenhando o nome da garagem ABERTA no lugar do nome
    -- da garagem onde o carro realmente esta -- o painel afirmava com todas as
    -- letras que o carro estava ali, estivesse ele onde estivesse.
    local storedGarage = status == 'stored' and Config.Garages[row.stored] or nil
    local impoundGarage = status == 'impound' and (Config.Garages['patio'] or Config.Garages[Config.Garage.impoundName] or Config.Impound) or nil
    local coords = nil
    if live and live.coords then
        coords = live.coords
    elseif storedGarage and storedGarage.ped then
        coords = { x = storedGarage.ped.x, y = storedGarage.ped.y, z = storedGarage.ped.z }
    elseif impoundGarage and impoundGarage.ped then
        coords = { x = impoundGarage.ped.x, y = impoundGarage.ped.y, z = impoundGarage.ped.z }
    else
        local parked = Server.getParkedSpot and Server.getParkedSpot(row.vin)
        if parked then
            coords = { x = parked.x, y = parked.y, z = parked.z }
        end
    end

    local hasBlocker = false
    if exports.nv_garage and exports.nv_garage.IsVehicleBlocked then
        hasBlocker = exports.nv_garage:IsVehicleBlocked(row.plate) or (row.id and exports.nv_garage:IsVehicleBlocked(row.id)) or false
    end

    return {
        id      = row.id,
        vin     = row.vin,
        plate   = row.plate,
        model   = row.model,
        name    = displayName(row.model),
        class   = classLabel(row.model, row.class),
        status  = status,
        garage  = row.stored,
        garageLabel = storedGarage and storedGarage.label or (row.stored == Config.Garage.impoundName and 'Pátio de Apreensão' or (row.stored or nil)),
        coords  = coords,
        hasBlocker = hasBlocker,
        -- Veiculo na rua tem estado ao vivo; guardado mostra o ultimo salvo.
        fuel    = live and live.fuel or math.floor((properties.fuelLevel or 100) + 0.5),
        engine  = live and live.engine or toPercent(properties.engineHealth, 100),
        body    = live and live.body or toPercent(properties.bodyHealth, 100),
        tyres   = live and live.tyres or tyreMetric
    }
end

--- Estado ao vivo dos veiculos deste dono que estao spawnados agora.
---@param charId number
---@return table<string, table>
local function liveState(charId)
    local result = {}
    local vehicles = Ox.GetVehicles({ owner = charId }) or {}

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local entity = vehicle.entity

        if entity and DoesEntityExist(entity) then
            result[vehicle.vin] = {
                fuel   = math.floor((Entity(entity).state.fuel or 100) + 0.5),
                engine = toPercent(GetVehicleEngineHealth(entity), 100),
                body   = toPercent(GetVehicleBodyHealth(entity), 100),
                tyres  = (function()
                    local mechanical = Entity(entity).state.nvMechanical
                    if not mechanical or type(mechanical.tyres) ~= 'table' then return 100 end
                    local total = 0
                    for tyre = 1, 4 do total = total + (tonumber(mechanical.tyres[tyre]) or 100) end
                    return math.floor(total / 4 + 0.5)
                end)()
            }
        end
    end

    return result
end

lib.callback.register('nv_garage:list', function(source, garageName)
    local garage = Config.Garages[garageName]
    if not garage then return end

    local player = Ox.GetPlayer(source)
    if not player then return end

    local charId = player.charId

    local rows = MySQL.query.await(
        'SELECT `id`, `plate`, `vin`, `model`, `class`, `data`, `stored` FROM `vehicles` WHERE `owner` = ? ORDER BY `id`',
        { charId }
    ) or {}

    local spawned = liveState(charId)
    local list = {}

    for i = 1, #rows do
        local entry = buildEntry(rows[i], spawned)
        local belongs

        if garage.impound then
            -- O patio mostra SO o que esta nele. Carro guardado ou na rua nao
            -- tem nada que aparecer aqui: a lista e o inventario do patio, nao
            -- a lista de veiculos do jogador.
            belongs = entry.status == 'impound'
        elseif entry.status == 'impound' then
            -- E o contrario tambem vale: apreendido some das garagens comuns,
            -- porque de la nao ha nada que o dono possa fazer com ele.
            belongs = false
        else
            -- Com `strictReturn`, uma garagem so mostra o que esta nela (mais
            -- o que esta na rua, que interessa em qualquer uma).
            belongs = not Config.Garage.strictReturn
                or entry.status ~= 'stored'
                or entry.garage == garageName
        end

        if belongs then
            -- "Esta nesta garagem?" e a pergunta que a UI precisa responder, e
            -- so o servidor sabe qual garagem foi aberta.
            entry.here = entry.status == 'stored' and entry.garage == garageName
            -- A taxa e POR VEICULO, nao da garagem: ela depende de ha quantos
            -- dias aquele carro especifico esta parado e de ter chegado
            -- destruido ou nao.
            if entry.status == 'impound' then
                entry.fee = Server.impoundFee(entry.vin)
            end

            list[#list + 1] = entry
        end
    end

    return {
        garage  = garageName,
        label   = garage.label,
        list    = list,
        impound = garage.impound or false,
        -- A NUI precisa disto para nao oferecer "Retirar" num carro que o
        -- servidor vai recusar tres linhas depois. Mostrar um botao que sempre
        -- falha e pior do que nao mostrar botao nenhum.
        strict  = Config.Garage.strictReturn or false
    }
end)

-- -------------------------------------------------------------- retirar --

lib.callback.register('nv_garage:takeOut', function(source, garageName, dbId, spawnIndex)
    local garage = Config.Garages[garageName]
    if not garage then return false, 'Garagem invalida.' end

    local spawn = garage.spawns[spawnIndex] or garage.spawns[1]
    if not spawn then return false, 'Esta garagem nao tem ponto de saida configurado.' end

    local player = Ox.GetPlayer(source)
    if not player then return false, 'Personagem nao carregado.' end

    -- O menu so abre na garagem, mas o callback e chamavel de qualquer lugar.
    local ped = GetPlayerPed(source)

    if not ped or ped == 0 or #(GetEntityCoords(ped) - garage.ped) > Config.Garage.storeDistance then
        return false, 'Voce nao esta na garagem.'
    end

    local row = MySQL.single.await(
        'SELECT `id`, `vin`, `plate`, `model`, `owner`, `stored`, `data` FROM `vehicles` WHERE `id` = ?',
        { dbId }
    )

    if not row then return false, 'Veiculo nao encontrado.' end
    if row.owner ~= player.charId then return false, 'Este veiculo nao e seu.' end

    local impounded = row.stored == Config.Garage.impoundName

    if not row.stored then
        return false, 'Este veiculo ja esta fora da garagem.'
    end

    if garage.impound then
        if not impounded then
            return false, 'Este veiculo nao esta apreendido.'
        end

        -- A taxa sai ANTES do spawn. Se o carro nascesse primeiro e a cobranca
        -- falhasse, o jogador sairia dirigindo de graca.
        --
        -- E recalculada aqui, e nao aceita da NUI: o valor que o cliente
        -- mostrou e so informativo. Entre abrir o menu e clicar pode ter virado
        -- o dia, e de qualquer forma nada que venha do cliente decide preco.
        local fee = Server.impoundFee(row.vin)

        if fee > 0 then
            local item = Config.Impound.moneyItem or 'money'

            if (exports.ox_inventory:GetItemCount(source, item) or 0) < fee then
                return false, ('Voce precisa de $%d em dinheiro para liberar o veiculo.'):format(fee)
            end

            if not exports.ox_inventory:RemoveItem(source, item, fee) then
                return false, 'Nao foi possivel cobrar a taxa.'
            end
        end

        -- Pago: o relogio da diaria para aqui.
        Server.clearImpound(row.vin)
    else
        if impounded then
            return false, 'Este veiculo esta apreendido no patio.'
        end

        if Config.Garage.strictReturn and row.stored ~= garageName then
            return false, 'Este veiculo esta em outra garagem.'
        end

        -- Vaga exata onde o carro foi deixado. So vale se ainda estiver livre
        -- e for desta garagem: guardar em Pillbox e retirar no Motel nao pode
        -- teletransportar o carro de volta para Pillbox.
        --
        -- No patio isto nao se aplica: o carro chegou de guincho, e sai de uma
        -- vaga do patio.
        local parked = Server.getParkedSpot(row.vin)

        if parked
            and #(vec3(parked.x, parked.y, parked.z) - garage.ped) <= Config.Garage.storeDistance
            and Server.spotIsFree(vec3(parked.x, parked.y, parked.z))
        then
            spawn = parked
        end
    end

    local vehicle = Ox.SpawnVehicle(dbId, vec3(spawn.x, spawn.y, spawn.z), spawn.w)
    if not vehicle then return false, 'Nao foi possivel liberar o veiculo.' end

    local entity = vehicle.entity
    local state = Entity(entity).state

    -- Sai da garagem como entrou: trancado se foi guardado trancado.
    local locked = Server.getLockState(row.vin)

    state:set('nvLocked', locked, true)
    state:set('nvEngine', false, true)  -- sempre desligado; ligar e com a chave
    state:set('nvHotwired', false, true)

    -- Diferente de ox_lib:setVehicleProperties, este valor nao e apagado
    -- depois da primeira aplicacao. Isso impede portas, vidros e pneus de
    -- voltarem inteiros quando o jogador sai da area e retorna.
    state:set('nvGarageDamage', damageSnapshot(decodeProperties(row.data)), true)

    -- Desgaste que nao existe nas propriedades nativas (terra, durabilidade
    -- individual e risco de incendio) volta junto com o mesmo VIN. O cliente
    -- aplica pneus/avaria assim que recebe o state bag.
    if GetResourceState('nv_mechanic') == 'started' then
        exports.nv_mechanic:ApplyToEntity(row.vin, entity)
    end

    -- O dono recebe a chave. `giveKey` nao duplica se ele ja tiver uma.
    Server.giveKey(source, row.plate, displayName(row.model))
    Server.markOut(row.vin)

    return true, nil, NetworkGetNetworkIdFromEntity(entity)
end)

-- -------------------------------------------------------------- guardar --

lib.callback.register('nv_garage:store', function(source, garageName, netId, properties, mechanical)
    local garage = Config.Garages[garageName]
    if not garage then return false, 'Garagem invalida.' end

    if garage.impound then
        return false, 'O patio de apreensao nao guarda veiculos.'
    end

    local player = Ox.GetPlayer(source)
    if not player then return false, 'Personagem nao carregado.' end

    local resolved = Server.resolveVehicle(netId)
    if not resolved or not resolved.ox then
        return false, 'Este veiculo nao pode ser guardado.'
    end

    local vehicle = resolved.ox

    if vehicle.owner ~= player.charId then
        return false, 'Este veiculo nao e seu.'
    end

    if exports.nv_garage:IsBlockerInstalled(netId) then
        return false, 'Retire o bloqueador de sinal antes de guardar o veiculo.'
    end

    -- O jogador precisa estar no veiculo, ou ao lado dele.
    if not Server.isNearby(source, resolved.entity, 6.0) then
        return false, 'Aproxime-se do veiculo.'
    end

    -- ...e o veiculo precisa estar na garagem.
    local distance = #(GetEntityCoords(resolved.entity) - garage.ped)

    if distance > Config.Garage.storeDistance then
        return false, 'Traga o veiculo ate a garagem.'
    end

    -- Guarda o estado de tranca ANTES de despawnar: depois o statebag some
    -- junto com a entidade e a informacao se perde.
    if resolved.vin then
        Server.setLockState(resolved.vin, Entity(resolved.entity).state.nvLocked or false)
    end

    -- Estado do veiculo (portas e capo arrancados, vidros, pneus, lataria,
    -- mods, cor, sujeira). Isto TEM que ser feito aqui, a mao:
    --
    -- o ox_core nunca le as propriedades da entidade sozinho -- o `#properties`
    -- dele fica com o que veio no spawn e so muda por `setProperties`. Sem esta
    -- chamada, o que ele salva ao guardar e um `{}`, e o carro volta da garagem
    -- zero-bala por mais amassado que tenha entrado.
    --
    -- As propriedades vem do cliente (as natives sao client-side), entao sao
    -- dado NAO CONFIAVEL: dao para forjar mods e cor. E o mesmo nivel de
    -- confianca que qualquer garagem de FiveM tem; se isso virar problema, o
    -- caminho e comparar contra o ultimo estado salvo, nao confiar mais.
    if type(properties) == 'table' then
        vehicle.setProperties(properties)
        Entity(resolved.entity).state:set('nvGarageDamage', damageSnapshot(properties), true)
    end

    -- Salva no mesmo fluxo e antes do despawn: nao ha janela em que o estado
    -- visual seja guardado e o desgaste avancado se perca.
    if resolved.vin and type(mechanical) == 'table' and GetResourceState('nv_mechanic') == 'started' then
        exports.nv_mechanic:SaveSnapshot(resolved.vin, mechanical)
    end

    -- Guarda a vaga exata antes de despawnar: depois a entidade nao existe
    -- mais e a posicao se perde.
    if resolved.vin then
        local coords = GetEntityCoords(resolved.entity)

        Server.setParkedSpot(resolved.vin, coords, GetEntityHeading(resolved.entity))
    end

    -- `setStored(nome, true)` grava o local e remove a entidade salvando as
    -- propriedades atuais (combustivel, lataria, motor).
    --
    -- PONTO com o ox_core, nao dois-pontos. O `__index` do OxVehicle ja
    -- devolve a funcao com o `self` amarrado; chamar com `:` manda o self de
    -- novo como primeiro argumento e ele acaba virando o valor de `stored` no
    -- UPDATE -- o erro e um SQL com o objeto do veiculo inteiro no lugar do
    -- nome da garagem.
    vehicle.setStored(garageName, true)

    if resolved.vin then Server.markStored(resolved.vin) end

    return true
end)

--- Retorna a lista completa de veículos do jogador com status, rótulos de garagem e coordenadas para o celular (NPWD).
---@param source number
---@return table
local function getPlayerVehicles(source)
    local player = Ox.GetPlayer(source)
    if not player then return {} end

    local rows = MySQL.query.await(
        'SELECT `id`, `plate`, `vin`, `model`, `class`, `data`, `stored` FROM `vehicles` WHERE `owner` = ? ORDER BY `id`',
        { player.charId }
    ) or {}

    -- Cruzar com veículos do ox_core na memória para sincronia instantânea ao guardar/retirar
    local oxVehicles = (Ox.GetVehicles and Ox.GetVehicles({ owner = player.charId })) or {}
    local oxByVin = {}
    for i = 1, #oxVehicles do
        local ov = oxVehicles[i]
        if ov and ov.vin then
            oxByVin[ov.vin] = ov
        end
    end

    local spawned = liveState(player.charId)
    local list = {}

    for i = 1, #rows do
        local row = rows[i]
        local ov = oxByVin[row.vin]
        if ov and ov.stored ~= nil then
            row.stored = ov.stored
        end
        list[#list + 1] = buildEntry(row, spawned)
    end

    return list
end

lib.callback.register('nv_garage:getPlayerVehicles', function(source)
    return getPlayerVehicles(source)
end)

exports('GetPlayerVehicles', getPlayerVehicles)

