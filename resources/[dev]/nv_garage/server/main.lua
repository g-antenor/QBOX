--[[
    nv_garage — servidor: chaves, ignicao e trancas

    Regra da casa: a chave e um OBJETO, nao uma permissao. Quando o motor esta
    ligado a chave esta na ignicao, ou seja, fora do inventario de todo mundo.
    Desligar o motor devolve a chave a quem desligou - e por isso que entrar num
    carro ligado e desliga-lo e uma forma legitima de ficar com ele.

    O cliente nunca decide nada disso sozinho: quem mexe no inventario e quem
    escreve o statebag e este arquivo.
]]

local Ox = require '@ox_core.lib.init'

Server = {}

-- ---------------------------------------------------------------- estado --

-- Cache do estado de tranca por vin, para nao bater no banco a cada clique.
---@type table<string, boolean>
local lockCache = {}

-- ------------------------------------------------------------- schema --

--- A tabela existe?
---
--- O `sql/install.sql` era um arquivo que alguem tinha que lembrar de rodar, e
--- esquecer disso nao dava um aviso: dava um stack dump do oxmysql a cada
--- clique numa tranca. Agora o resource cria a tabela sozinho ao subir.
local schemaReady = false

CreateThread(function()
    -- A chave estrangeira e o que faz o estado morrer junto com o veiculo.
    -- Mas ela depende do schema do ox_core (a coluna `vin` precisa ser unica),
    -- e um servidor com o ox_core mais antigo falharia aqui e ficaria sem
    -- tabela nenhuma. Por isso a segunda tentativa sem FK: melhor a tabela sem
    -- cascata do que resource nenhum funcionando.
    local columns = [[
        `vin`               CHAR(17) NOT NULL,
        `locked`            TINYINT(1) NOT NULL DEFAULT 1,
        `spawn`             VARCHAR(120) NULL,
        `impounded_at`      DATETIME NULL,
        `impound_destroyed` TINYINT(1) NOT NULL DEFAULT 0,
        `impound_disappeared` TINYINT(1) NOT NULL DEFAULT 0,
        `was_out`           TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`vin`)
    ]]

    local withFk = ([[
        CREATE TABLE IF NOT EXISTS `nv_vehicle_state` (
            %s,
            CONSTRAINT `nv_vehicle_state_vin_fk`
                FOREIGN KEY (`vin`) REFERENCES `vehicles` (`vin`)
                ON DELETE CASCADE ON UPDATE CASCADE
        )
    ]]):format(columns)

    local withoutFk = ('CREATE TABLE IF NOT EXISTS `nv_vehicle_state` (%s)'):format(columns)

    if pcall(MySQL.query.await, withFk) then
        schemaReady = true
    elseif pcall(MySQL.query.await, withoutFk) then
        schemaReady = true

        lib.print.warn('nv_vehicle_state criada SEM chave estrangeira: o estado de tranca de um veiculo apagado nao sera limpo sozinho.')
    else
        return lib.print.error('Nao foi possivel criar a tabela `nv_vehicle_state`. As trancas vao funcionar so ate o veiculo ser guardado.')
    end

    -- Instalacao antiga: a tabela ja existia sem estas colunas, e o CREATE
    -- IF NOT EXISTS acima nao mexe em tabela existente. Erro aqui quase sempre
    -- significa "coluna ja esta la", por isso o pcall silencioso.
    pcall(MySQL.query.await, 'ALTER TABLE `nv_vehicle_state` ADD COLUMN `spawn` VARCHAR(120) NULL')
    pcall(MySQL.query.await, 'ALTER TABLE `nv_vehicle_state` ADD COLUMN `impounded_at` DATETIME NULL')
    pcall(MySQL.query.await, 'ALTER TABLE `nv_vehicle_state` ADD COLUMN `impound_destroyed` TINYINT(1) NOT NULL DEFAULT 0')
    pcall(MySQL.query.await, 'ALTER TABLE `nv_vehicle_state` ADD COLUMN `impound_disappeared` TINYINT(1) NOT NULL DEFAULT 0')
    pcall(MySQL.query.await, 'ALTER TABLE `nv_vehicle_state` ADD COLUMN `was_out` TINYINT(1) NOT NULL DEFAULT 0')
end)

-- ------------------------------------------------------------- patio --

--- Carimba a entrada de um veiculo no patio.
---
--- `COALESCE(impounded_at, NOW())` no UPDATE nao e detalhe: sem ele, qualquer
--- recarimbada zeraria o relogio e a diaria nunca passaria de zero. A data de
--- entrada e escrita UMA vez e so sai quando o veiculo e liberado.
---@param vin string
---@param destroyed boolean?
function Server.markImpounded(vin, destroyed)
    if not vin or not schemaReady then return end

    MySQL.prepare([[
        INSERT INTO `nv_vehicle_state` (`vin`, `locked`, `impounded_at`, `impound_destroyed`, `impound_disappeared`, `was_out`)
        VALUES (?, ?, NOW(), ?, 0, 0)
        ON DUPLICATE KEY UPDATE
            `impounded_at`      = COALESCE(`impounded_at`, NOW()),
            `impound_destroyed` = GREATEST(`impound_destroyed`, VALUES(`impound_destroyed`)),
            `impound_disappeared` = IF(VALUES(`impound_destroyed`) = 1, 0, `impound_disappeared`),
            `was_out` = 0
    ]], {
        vin,
        Config.Lock.defaultLocked and 1 or 0,
        destroyed and 1 or 0
    })
end

--- Dias completos no patio e se o veiculo chegou destruido.
---@param vin string
---@return number days
---@return boolean destroyed
---@return boolean disappeared
function Server.getImpoundInfo(vin)
    if not vin or not schemaReady then return 0, false, false end

    local ok, row = pcall(MySQL.single.await, [[
        SELECT TIMESTAMPDIFF(DAY, `impounded_at`, NOW()) AS days,
            `impound_destroyed` AS destroyed, `impound_disappeared` AS disappeared
        FROM `nv_vehicle_state` WHERE `vin` = ?
    ]], { vin })

    if not ok or type(row) ~= 'table' then return 0, false, false end

    return math.max(0, tonumber(row.days) or 0), row.destroyed == 1, row.disappeared == 1
end

--- Quanto custa liberar este veiculo agora.
---@param vin string
---@return number fee
---@return number days
---@return boolean destroyed
function Server.impoundFee(vin)
    local days, destroyed, disappeared = Server.getImpoundInfo(vin)
    local cfg = Config.Impound

    local fee = (cfg.baseFee or 0) + days * (cfg.dailyFee or 0)

    if destroyed then
        fee = fee + (cfg.destroyedFee or 0)
    end
    if disappeared then fee = fee + (cfg.disappearedFee or 0) end

    return fee, days, destroyed, disappeared
end

-- API usada por garagens de organizacao. A regra e o calculo continuam em um
-- unico lugar, evitando uma taxa diferente para frota e veiculo particular.
exports('GetImpoundFee', function(vin)
    return Server.impoundFee(vin)
end)

exports('ClearImpound', function(vin)
    Server.clearImpound(vin)
    return true
end)

exports('MarkOut', function(vin)
    Server.markOut(vin)
    return true
end)

--- Veiculo saiu do patio: o relogio para e a marca de destruido cai.
---@param vin string
function Server.clearImpound(vin)
    if not vin or not schemaReady then return end

    MySQL.prepare(
        'UPDATE `nv_vehicle_state` SET `impounded_at` = NULL, `impound_destroyed` = 0, `impound_disappeared` = 0, `was_out` = 1 WHERE `vin` = ?',
        { vin })
end

function Server.markOut(vin)
    if not vin or not schemaReady then return end
    MySQL.prepare([[
        INSERT INTO `nv_vehicle_state` (`vin`, `locked`, `was_out`) VALUES (?, ?, 1)
        ON DUPLICATE KEY UPDATE `was_out` = 1
    ]], { vin, Config.Lock.defaultLocked and 1 or 0 })
end

function Server.markStored(vin)
    if not vin or not schemaReady then return end
    MySQL.prepare('UPDATE `nv_vehicle_state` SET `was_out` = 0, `impound_disappeared` = 0 WHERE `vin` = ?', { vin })
end

--- Sincroniza os carimbos com a coluna `stored` do ox_core.
---
--- Existe porque o ox_core manda veiculos para o patio por caminhos que nao
--- passam por este resource -- no `saveAll` do restart do servidor, por
--- exemplo, todo carro que estava na rua vira apreendido. Sem esta varredura
--- esses veiculos ficariam sem data de entrada e a diaria seria sempre zero.
local function syncImpoundStamps()
    if not schemaReady then return end

    local impound = Config.Garage.impoundName

    -- 1. Garante que todo apreendido tenha linha na tabela.
    pcall(MySQL.query.await, [[
        INSERT IGNORE INTO `nv_vehicle_state` (`vin`, `locked`)
        SELECT `vin`, ? FROM `vehicles` WHERE `stored` = ?
    ]], { Config.Lock.defaultLocked and 1 or 0, impound })

    -- 2. Veiculo que estava na rua e reapareceu no patio foi recolhido.
    pcall(MySQL.query.await, [[
        UPDATE `nv_vehicle_state` s
        JOIN `vehicles` v ON v.`vin` = s.`vin`
        SET s.`impound_disappeared` = 1, s.`was_out` = 0
        WHERE v.`stored` = ? AND s.`was_out` = 1 AND s.`impound_destroyed` = 0
    ]], { impound })

    -- 3. Carimba quem ainda nao tem data.
    pcall(MySQL.query.await, [[
        UPDATE `nv_vehicle_state` s
        JOIN `vehicles` v ON v.`vin` = s.`vin`
        SET s.`impounded_at` = NOW()
        WHERE v.`stored` = ? AND s.`impounded_at` IS NULL
    ]], { impound })

    -- 4. Limpa quem saiu do patio por fora (comando de admin, por exemplo).
    pcall(MySQL.query.await, [[
        UPDATE `nv_vehicle_state` s
        JOIN `vehicles` v ON v.`vin` = s.`vin`
        SET s.`impounded_at` = NULL, s.`impound_destroyed` = 0, s.`impound_disappeared` = 0
        WHERE s.`impounded_at` IS NOT NULL AND (v.`stored` IS NULL OR v.`stored` <> ?)
    ]], { impound })
end

CreateThread(function()
    -- Espera o schema ficar pronto antes da primeira passada.
    while not schemaReady do Wait(500) end

    while true do
        syncImpoundStamps()
        Wait(Config.Impound.stampInterval)
    end
end)

-- ------------------------------------------------------ veiculo destruido --

--- O veiculo virou sucata?
---@param entity number
---@return boolean
local function isWrecked(entity)
    if GetEntityHealth(entity) <= 0 then return true end

    -- GetVehicleEngineHealth nem sempre existe do lado do servidor conforme a
    -- build; o pcall evita derrubar a varredura inteira por causa disso.
    local ok, health = pcall(GetVehicleEngineHealth, entity)

    return ok and type(health) == 'number' and health <= (Config.Impound.destroyedEngineHealth or 0)
end

--- Carro explodido vai para o patio marcado como destruido - e e essa marca
--- que cobra o acrescimo de conserto na liberacao.
CreateThread(function()
    local Ox = require '@ox_core.lib.init'

    while true do
        Wait(Config.Impound.scanInterval)

        local vehicles = Ox.GetVehicles() or {}

        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            local entity = vehicle.entity

            -- Sem dono nao ha para quem cobrar, e sem entidade nao ha o que
            -- olhar.
            if entity and DoesEntityExist(entity) and (vehicle.owner or vehicle.group) then
                if isWrecked(entity) then
                    exports.nv_garage:RemoveVehicleBlocker(NetworkGetNetworkIdFromEntity(entity))
                    Server.markImpounded(vehicle.vin, true)

                    pcall(function()
                        vehicle:setStored(Config.Garage.impoundName, true)
                    end)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------- vaga salva --

--- Onde o veiculo foi deixado. Guardado como texto ("x y z heading") em vez
--- de quatro colunas: e um dado que so este resource le, sempre inteiro.
---@param vin string
---@param coords vector3
---@param heading number
function Server.setParkedSpot(vin, coords, heading)
    if not vin or not schemaReady then return end

    -- INSERT ... ON DUPLICATE, e nao UPDATE: um veiculo que nunca teve a
    -- tranca mexida ainda nao tem linha aqui, e o UPDATE nao acertaria nada.
    MySQL.prepare([[
        INSERT INTO `nv_vehicle_state` (`vin`, `locked`, `spawn`) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `spawn` = VALUES(`spawn`)
    ]], {
        vin,
        Config.Lock.defaultLocked and 1 or 0,
        ('%.3f %.3f %.3f %.2f'):format(coords.x, coords.y, coords.z, heading or 0.0)
    })
end

--- A vaga onde o veiculo foi deixado, se houver.
---@param vin string
---@return vector4?
function Server.getParkedSpot(vin)
    if not vin or not schemaReady then return end

    local ok, spot = pcall(MySQL.scalar.await,
        'SELECT `spawn` FROM `nv_vehicle_state` WHERE `vin` = ?', { vin })

    if not ok or type(spot) ~= 'string' then return end

    local x, y, z, w = spot:match('^(%S+) (%S+) (%S+) (%S+)$')

    x, y, z, w = tonumber(x), tonumber(y), tonumber(z), tonumber(w)

    if not x or not y or not z then return end

    return vec4(x, y, z, w or 0.0)
end

--- Le o estado de tranca persistido de um veiculo do ox_core.
---@param vin string
---@return boolean
function Server.getLockState(vin)
    local cached = lockCache[vin]
    if cached ~= nil then return cached end

    local locked

    -- Banco indisponivel nao pode virar erro no meio de um clique: sem a
    -- tabela o veiculo apenas cai no padrao do config.
    if schemaReady then
        local ok, result = pcall(MySQL.scalar.await,
            'SELECT `locked` FROM `nv_vehicle_state` WHERE `vin` = ?', { vin })

        if ok then locked = result end
    end

    -- Sem registro = veiculo novo. Nasce como o config mandar.
    if locked == nil then
        locked = Config.Lock.defaultLocked and 1 or 0
    end

    lockCache[vin] = locked == 1

    return lockCache[vin]
end

--- Persiste o estado de tranca. Chamado ao trancar, destrancar e ao guardar.
---@param vin string
---@param locked boolean
function Server.setLockState(vin, locked)
    if not vin then return end

    lockCache[vin] = locked

    if not schemaReady then return end

    MySQL.prepare('INSERT INTO `nv_vehicle_state` (`vin`, `locked`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `locked` = VALUES(`locked`)', {
        vin, locked and 1 or 0
    })
end

-- ------------------------------------------------------------- veiculos --

--- Resolve um netId para tudo que o resto do arquivo precisa saber.
--- Veiculo de NPC nao tem vin: o estado dele vive so no statebag da sessao.
---@param netId number
---@return { entity: number, plate: string, vin: string?, ox: table? }?
local function resolveVehicle(netId)
    if type(netId) ~= 'number' then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    local ox = Ox.GetVehicleFromNetId(netId)
    local plate = ox and ox.plate or GetVehicleNumberPlateText(entity)

    if not plate then return end

    return {
        entity = entity,
        plate  = plate:gsub('%s+$', ''),
        vin    = ox and ox.vin or nil,
        ox     = ox
    }
end

--- O jogador esta perto o suficiente para agir sobre este veiculo?
--- Barreira minima contra quem chama o callback direto pelo console.
---@param source number
---@param entity number
---@param maxDistance number
---@return boolean
local function isNearby(source, entity, maxDistance)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end

    return #(GetEntityCoords(ped) - GetEntityCoords(entity)) <= maxDistance
end

-- --------------------------------------------------------------- chaves --

--- Quantas chaves desta placa o jogador tem.
---@param source number
---@param plate string
---@return number
function Server.countKeys(source, plate)
    local count = exports.ox_inventory:Search(source, 'count', Config.Items.key, { plate = plate })

    return count or 0
end

--- Entrega uma chave da placa. Idempotente: nao empilha copias.
---@param source number
---@param plate string
---@param label string?
---@return boolean
function Server.giveKey(source, plate, label)
    if Server.countKeys(source, plate) > 0 then return true end

    local success,response=exports.ox_inventory:AddItem(source, Config.Items.key, 1, {
        plate       = plate,
        label       = label,
        description = ('Placa: %s'):format(plate)
    })

    return success==true,response
end

--- Entregar chave a partir de outro resource (o job de entrega, por exemplo).
--- Sem isto, cada resource que precisa dar um veiculo a alguem acabaria
--- criando o proprio item de chave, com metadata levemente diferente -- e
--- entao a chave de um nao abriria o carro do outro.
exports('GiveKey', function(source, plate, label)
    source=tonumber(source)
    if not source or plate==nil then return false,'invalid_source_or_plate' end
    plate=tostring(plate):gsub('^%s+',''):gsub('%s+$','')
    if plate=='' then return false,'invalid_plate' end

    return Server.giveKey(source,plate,label and tostring(label) or nil)
end)

--- Tira uma chave da placa do inventario (ela foi para a ignicao).
---
--- O ultimo argumento (`strict = false`) NAO e opcional aqui. Por padrao o
--- RemoveItem compara o metadata inteiro com `table.matches`, e a chave guarda
--- `label` e `description` alem da placa - com strict ligado o filtro
--- `{ plate = ... }` nunca casaria e a chave jamais sairia do inventario.
--- Com false ele usa `table.contains`, que e a busca por subconjunto que a
--- gente quer.
---@param source number
---@param plate string
---@return boolean
local function takeKey(source, plate)
    return exports.ox_inventory:RemoveItem(source, Config.Items.key, 1, { plate = plate }, nil, false, false)
end

exports('RemoveKey', function(source, plate)
    if type(source) ~= 'number' or type(plate) ~= 'string' then return false end

    return takeKey(source, (plate:gsub('%s+$', '')))
end)

--- Este modelo dispensa chave? (viaturas, taxi da cidade, etc.)
---@param entity number
---@return boolean
local function modelIsKeyless(entity)
    local model = GetEntityModel(entity)

    for name in pairs(Config.Ignition.noKeyModels) do
        if GetHashKey(name) == model then return true end
    end

    return false
end

--- O jogador pode operar este veiculo agora?
--- Chave na mao, ligacao direta ja feita ou modelo liberado.
---@param source number
---@param vehicle table
---@return boolean
local function canOperate(source, vehicle)
    if modelIsKeyless(vehicle.entity) then return true end
    if Entity(vehicle.entity).state.nvHotwired then return true end

    return Server.countKeys(source, vehicle.plate) > 0
end

Server.canOperate = canOperate
Server.resolveVehicle = resolveVehicle
Server.isNearby = isNearby

-- -------------------------------------------------------------- ignicao --

--- Liga ou desliga o motor.
---
--- Ligar consome a chave (ela fica na ignicao). Desligar devolve. Se o
--- inventario estiver cheio na hora de devolver, o motor CONTINUA LIGADO -
--- caso contrario a chave sumiria do mundo.
lib.callback.register('nv_garage:toggleEngine', function(source, netId, desired)
    local vehicle = resolveVehicle(netId)
    if not vehicle then return false, 'Veiculo nao encontrado.' end
    if not isNearby(source, vehicle.entity, 10.0) then return false, 'Voce esta longe demais.' end

    local state = Entity(vehicle.entity).state

    if desired then
        if not canOperate(source, vehicle) then
            return false, 'Voce nao tem a chave deste veiculo.'
        end

        -- Modelo liberado ou ja em ligacao direta: nao ha chave para consumir.
        if not modelIsKeyless(vehicle.entity) and not state.nvHotwired then
            if not takeKey(source, vehicle.plate) then
                return false, 'Voce nao tem a chave deste veiculo.'
            end
        end

        state:set('nvEngine', true, true)

        return true
    end

    -- Desligando: a chave sai da ignicao e vai para o bolso de quem desligou.
    if not modelIsKeyless(vehicle.entity) and not state.nvHotwired then
        local label = vehicle.ox and Server.displayName and Server.displayName(vehicle.ox.model) or nil

        if not Server.giveKey(source, vehicle.plate, label) then
            return false, 'Sem espaco no inventario para guardar a chave.'
        end
    end

    state:set('nvEngine', false, true)

    -- A ligacao direta morre com o motor.
    --
    -- Antes, `nvHotwired` durava ate o veiculo despawnar: bastava vencer o
    -- minigame uma vez e o carro virava um veiculo sem chave para sempre --
    -- podia desligar, sair, voltar horas depois e ligar no Z. O roubo tinha
    -- custo uma vez e beneficio permanente.
    --
    -- Agora os fios so seguem ligados enquanto o motor segue ligado. Desligou,
    -- refaz -- com o alicate na mao e o minigame de novo. E o que torna "deixar
    -- o carro ligado" uma decisao de verdade para quem roubou.
    if state.nvHotwired then
        state:set('nvHotwired', false, true)
    end

    return true
end)

-- ------------------------------------------------------- ligacao direta --

--- Confere o alicate ANTES do minigame, para nao gastar o tempo do jogador.
--- Qual item cada ferramenta de ignicao usa.
---
--- Moto nao tem porta: o lockpick nela nao arromba nada, vence a trava do
--- contato. E a ligacao direta da moto, e por isso ele entra aqui em vez de
--- entrar no fluxo de arrombamento.
---@param tool string?
---@return string item
---@return string erro
local function ignitionTool(tool)
    if tool == 'lockpick' then
        return Config.Items.lockpick, 'Voce precisa de um lockpick.'
    end

    return Config.Items.cutters, 'Voce precisa de um alicate de corte.'
end

lib.callback.register('nv_garage:canHotwire', function(source, netId, tool)
    local vehicle = resolveVehicle(netId)
    if not vehicle then return false, 'Veiculo nao encontrado.' end

    if Entity(vehicle.entity).state.isDealershipPreview then
        return false, 'Este veiculo e uma previa de exposicao da concessionaria.'
    end

    if Server.countKeys(source, vehicle.plate) > 0 then
        return false, 'Voce tem a chave deste veiculo.'
    end

    local item, missing = ignitionTool(tool)
    local count = exports.ox_inventory:GetItemCount(source, item)

    if (count or 0) < 1 then
        return false, missing
    end

    return true
end)

--- Minigame vencido. Marca o veiculo como ligado na direta: dali em diante ele
--- liga sem chave, ate despawnar.
lib.callback.register('nv_garage:hotwire', function(source, netId, tool)
    local vehicle = resolveVehicle(netId)
    if not vehicle then return false end
    if not isNearby(source, vehicle.entity, 10.0) then return false end

    local item = ignitionTool(tool)
    local count = exports.ox_inventory:GetItemCount(source, item)
    if (count or 0) < 1 then return false end

    if tool == 'lockpick' then
        -- Forcar contato de moto gasta o lockpick como qualquer outro uso.
        -- Chamada direta, e nao TriggerEvent: o handler do evento le `source`
        -- do contexto de rede, que nao existe quando quem dispara e o servidor.
        local amount = Config.Lockpick.wear and Config.Lockpick.wear.success

        if amount then
            Server.wearLockpick(source, amount)
        end
    elseif Config.Hotwire.consumeCutters then
        exports.ox_inventory:RemoveItem(source, Config.Items.cutters, 1)
    end

    local state = Entity(vehicle.entity).state

    state:set('nvHotwired', true, true)
    state:set('nvEngine', true, true)
    state:set('nvLocked', false, true)

    return true
end)

-- -------------------------------------------------------------- trancas --

--- Tranca/destranca. So passa quem tem a chave.
--- Tranca/destranca.
---
--- A chave so e exigida de FORA. Quem esta sentado no banco alcanca o botao da
--- porta com a mao: nao faz sentido pedir chave para isso, e e o que fecha o
--- ciclo do lockpick (arromba, entra, destranca por dentro).
---
--- Estar dentro tambem dispensa a checagem de distancia, que fica trivialmente
--- satisfeita.
lib.callback.register('nv_garage:setLocked', function(source, netId, locked)
    local vehicle = resolveVehicle(netId)
    if not vehicle then return false, 'Veiculo nao encontrado.' end

    local ped = GetPlayerPed(source)
    local inside = ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) == vehicle.entity

    if not inside then
        if not isNearby(source, vehicle.entity, Config.Lock.distance + 4.0) then
            return false, 'Voce esta longe demais.'
        end

        if not canOperate(source, vehicle) then
            return false, 'Voce nao tem a chave deste veiculo.'
        end
    end

    Entity(vehicle.entity).state:set('nvLocked', locked, true)

    -- Veiculo do ox_core guarda o estado; carro de NPC nao tem onde guardar.
    if vehicle.vin then
        Server.setLockState(vehicle.vin, locked)
    end

    return true
end)

-- `nv_garage:unlockFromInside` foi removido: agora que o `setLocked` acima
-- dispensa a chave para quem esta dentro, ele era o mesmo callback com um nome
-- diferente e cobrindo so metade dos casos (destrancar, nunca trancar).

-- ------------------------------------------------------------- lockpick --

--- Confere o lockpick antes do minigame.
--- Confere o lockpick e, principalmente, se o veiculo nao e do proprio
--- jogador.
---
--- O cliente ja barra quem tem a chave no bolso, mas isso deixava passar o
--- caso mais comum: o SEU carro com o motor ligado. Nesse estado a chave esta
--- na ignicao, fora do inventario, entao `hasKey` da false e o dono conseguia
--- arrombar o proprio veiculo. Aqui a pergunta e outra e nao depende do
--- inventario: quem e o dono registrado?
lib.callback.register('nv_garage:canLockpick', function(source, netId)
    local count = exports.ox_inventory:GetItemCount(source, Config.Items.lockpick)

    if (count or 0) < 1 then
        return false, 'Voce precisa de um lockpick.'
    end

    local vehicle = resolveVehicle(netId)
    if vehicle and vehicle.entity and Entity(vehicle.entity).state.isDealershipPreview then
        return false, 'Este veiculo e uma previa de exposicao da concessionaria.'
    end

    -- Carro de NPC nao tem registro no ox_core: nao ha dono a respeitar.
    if not vehicle then return true end

    if vehicle.ox then
        local player = Ox.GetPlayer(source)

        if player then
            if vehicle.ox.owner and vehicle.ox.owner == player.charId then
                return false, 'Este veiculo e seu. Use a chave.'
            end

            -- Veiculo de organizacao conta como proprio para quem e do grupo.
            if vehicle.ox.group then
                local ok, groups = pcall(function() return player.getGroups() end)

                if ok and type(groups) == 'table' and groups[vehicle.ox.group] then
                    return false, 'Este veiculo e da sua organizacao. Use a chave.'
                end
            end
        end
    end

    -- Mesma regra do cliente, agora com autoridade.
    if Server.countKeys(source, vehicle.plate) > 0 then
        return false, 'Voce tem a chave deste veiculo.'
    end

    return true
end)

--- Gasta durabilidade do lockpick que o jogador tem na mao.
---
--- Sempre o slot de MENOR durabilidade: assim ele termina de gastar o lockpick
--- ja usado antes de comecar a estragar o novo, que e o que qualquer um faria
--- com ferramenta de verdade.
---@param source number
---@param amount number
---@return number? durabilidade restante
function Server.wearLockpick(source, amount)
    local slots = exports.ox_inventory:Search(source, 'slots', Config.Items.lockpick)

    if type(slots) ~= 'table' then return end

    local target, lowest

    for i = 1, #slots do
        local slot = slots[i]
        local durability = slot.metadata and slot.metadata.durability or 100

        if not lowest or durability < lowest then
            target, lowest = slot, durability
        end
    end

    if not target then return end

    local remaining = math.max(0, lowest - amount)

    -- Em zero o ox_inventory remove o item sozinho, porque o lockpick esta
    -- marcado com `decay` no items.lua.
    exports.ox_inventory:SetDurability(source, target.slot, remaining)

    return remaining
end

--- Desgaste apos uma tentativa. `outcome` decide o quanto.
RegisterNetEvent('nv_garage:lockpickWear', function(outcome)
    local source = source

    if type(outcome) ~= 'string' then return end

    local amount = Config.Lockpick.wear[outcome]
    if not amount then return end

    local remaining = Server.wearLockpick(source, amount)

    if remaining == 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Seu lockpick quebrou.'
        })
    end
end)

-- --------------------------------------------------------------- limpeza --

--- Veiculo apagado do banco nao deve deixar linha orfa. A FK ja cobre o
--- DELETE, mas o cache em memoria precisa ser invalidado na mao.
AddEventHandler('ox:vehicleDeleted', function(_, vin)
    if vin then lockCache[vin] = nil end
end)
