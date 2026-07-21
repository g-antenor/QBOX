--[[
    nv_orgs — servidor: fechaduras e baus

    As duas coisas sao guardadas de formas propositalmente diferentes:

    FECHADURAS nao tem tabela aqui. Elas vivem no `ox_doorlock`, e o vinculo com
    a organizacao e o PREFIXO DO NOME (`nv_orgs:<set>:<n>`). Guardar o id numa
    tabela nossa criaria duas fontes de verdade, e elas sairiam de sincronia na
    primeira vez que alguem editasse a porta pelo /doorlock. O prefixo nao tem
    como dessincronizar: ou a porta existe com aquele nome, ou nao existe.

    BAUS precisam de tabela. `RegisterStash` do ox_inventory so escreve em
    memoria, entao sem persistencia todo restart apagaria os baus de todas as
    organizacoes -- com os itens presos num stash que ninguem mais consegue
    abrir.
]]

local Ox = require '@ox_core.lib.init'

-- ------------------------------------------------------------ fechaduras --

--- Prefixo do nome das portas de uma organizacao.
---@param set string
---@return string
local function doorPrefix(set)
    return ('nv_orgs:%s:'):format(set)
end

--- Portas que pertencem a uma organizacao.
---@param set string
---@return table[]
local function orgDoors(set)
    local prefix = doorPrefix(set)
    local result = {}

    local ok, doors = pcall(function() return exports.ox_doorlock:getAllDoors() end)

    if not ok or type(doors) ~= 'table' then return result end

    for id, door in pairs(doors) do
        if type(door) == 'table' and type(door.name) == 'string'
            and door.name:sub(1, #prefix) == prefix
        then
            -- `getAllDoors` devolve uma projecao (id, name, coords, groups,
            -- items, maxDistance) e NAO inclui `doors`, o array de porta
            -- dupla. Nao da para saber daqui se a fechadura e simples ou
            -- dupla, entao nao mostramos esse dado -- exibir um palpite seria
            -- pior do que omitir.
            result[#result + 1] = {
                id = door.id or id,
                name = door.name,
                label = door.name:sub(#prefix + 1),
                coords = door.coords
            }
        end
    end

    table.sort(result, function(a, b) return a.name < b.name end)

    return result
end

lib.callback.register('nv_orgs:doors', function(source, set)
    if not Orgs.isAdmin(source) then return end
    if type(set) ~= 'string' then return end

    return orgDoors(set)
end)

--- Nome completo e livre para uma fechadura nova.
---
--- O admin escolhe o rotulo ("Sala do Chefe"); o prefixo e adicionado aqui,
--- porque e ele que amarra a porta a organizacao. Se o rotulo ja existir,
--- ganha um sufixo -- dois "Cela" viram "Cela" e "Cela 2".
lib.callback.register('nv_orgs:doorName', function(source, set, desired)
    if not Orgs.isAdmin(source) then return end
    if type(set) ~= 'string' then return end

    local label = type(desired) == 'string' and desired:gsub('^%s+', ''):gsub('%s+$', '') or ''

    if label == '' then label = 'Fechadura' end

    -- `ox_doorlock`.`name` e VARCHAR(50) e o prefixo ja come parte disso.
    local prefix = doorPrefix(set)
    local room = 50 - #prefix

    if room < 4 then return end

    label = label:sub(1, room)

    local taken = {}
    local doors = orgDoors(set)

    for i = 1, #doors do taken[doors[i].name] = true end

    local candidate = prefix .. label

    if not taken[candidate] then return candidate end

    for n = 2, 99 do
        local suffix = (' %d'):format(n)
        local trimmed = label:sub(1, room - #suffix)

        candidate = prefix .. trimmed .. suffix

        if not taken[candidate] then return candidate end
    end
end)

--- Renomeia uma fechadura.
---
--- `editDoor` do ox_doorlock funciona do servidor e ja avisa os clientes; ao
--- contrario da criacao e da exclusao, aqui nao e preciso passar pelo net
--- event com ACE.
lib.callback.register('nv_orgs:renameDoor', function(source, set, id, desired)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' or type(id) ~= 'number' then return false, 'Dados invalidos.' end

    local prefix = doorPrefix(set)
    local label = type(desired) == 'string' and desired:gsub('^%s+', ''):gsub('%s+$', '') or ''

    if label == '' then return false, 'Informe um nome.' end

    local room = 50 - #prefix
    label = label:sub(1, room)

    -- A porta precisa ser desta organizacao: sem esta checagem daria para
    -- renomear (e portanto sequestrar) a porta de qualquer outra.
    local doors = orgDoors(set)
    local found

    for i = 1, #doors do
        if doors[i].id == id then found = doors[i] break end
    end

    if not found then return false, 'Fechadura nao encontrada nesta organizacao.' end

    local ok = pcall(function()
        exports.ox_doorlock:editDoor(id, { name = prefix .. label })
    end)

    if not ok then return false, 'O ox_doorlock recusou a edicao.' end

    return true
end)

--- Grade minimo que abre as portas da organizacao.
---
--- Fechadura nao tem acao propria na lista: quem e da organizacao entra. Por
--- isso o menor grade existente (1), e nao um grade derivado de permissao.
lib.callback.register('nv_orgs:doorGroups', function(source, set)
    if not Orgs.isAdmin(source) then return end
    if type(set) ~= 'string' then return end

    return { [set] = 1 }
end)

-- ------------------------------------------------------------- chave --

--- O jogador e membro desta organizacao?
---@param source number
---@param set string
---@return boolean
local function isMember(source, set)
    local player = Ox.GetPlayer(source)
    if not player then return false end

    local ok, groups = pcall(function() return player.getGroups() end)

    return ok and type(groups) == 'table' and groups[set] ~= nil
end

--- O jogador tem uma chave desta organizacao na mao?
--- `Search` com `{ set = set }` casa por subconjunto, entao ignora os outros
--- campos do metadata (org, description) -- mesma ideia da chave de veiculo.
---@param source number
---@param set string
---@return boolean
local function hasKey(source, set)
    local count = exports.ox_inventory:Search(source, 'count', Config.Keys.item, { set = set })

    return (count or 0) > 0
end

--- Gera uma chave da organizacao para o admin distribuir.
lib.callback.register('nv_orgs:generateKey', function(source, set)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' then return false, 'Dados invalidos.' end

    local org = MySQL.single.await('SELECT `label` FROM `ox_groups` WHERE `name` = ?', { set })
    if not org then return false, 'Organizacao nao encontrada.' end

    local given = exports.ox_inventory:AddItem(source, Config.Keys.item, 1, {
        set         = set,
        org         = org.label,
        description = ('Chave: %s'):format(org.label)
    })

    if not given then return false, 'Sem espaco no inventario.' end

    return true, nil, org.label
end)

--- Usa a chave: tranca ou destranca a porta mais proxima da organizacao.
---
--- Aqui mora a regra "so membros": ter a chave nao basta, e preciso ser
--- membro. Um nao-membro que ache ou roube a chave nao consegue nada -- que e
--- o ponto de o acesso ser da GANG, e nao do objeto.
lib.callback.register('nv_orgs:useKey', function(source, set)
    if type(set) ~= 'string' then return false end

    -- Anti-spoof: o callback e chamavel pelo console, entao a posse da chave e
    -- reconferida aqui e nao so no cliente.
    if not hasKey(source, set) then
        return false, 'Voce nao tem a chave desta organizacao.'
    end

    if not isMember(source, set) then
        return false, 'Esta chave so funciona para membros da organizacao.'
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end

    local coords = GetEntityCoords(ped)
    local prefix = doorPrefix(set)

    -- Porta mais proxima DESTA organizacao dentro do alcance.
    local ok, doors = pcall(function() return exports.ox_doorlock:getAllDoors() end)
    if not ok or type(doors) ~= 'table' then return false, 'Sistema de portas indisponivel.' end

    local nearest, nearestDistance

    for _, door in pairs(doors) do
        if type(door) == 'table' and type(door.name) == 'string'
            and door.name:sub(1, #prefix) == prefix and door.coords
        then
            local distance = #(coords - vector3(door.coords.x, door.coords.y, door.coords.z))

            if distance <= Config.Keys.distance and (not nearestDistance or distance < nearestDistance) then
                nearest, nearestDistance = door, distance
            end
        end
    end

    if not nearest then
        return false, 'Nenhuma porta da organizacao por perto.'
    end

    -- Alterna: 1 = trancada, 0 = destrancada. `setDoorState` chamado do
    -- servidor (sem `source`) pula a autorizacao do ox_doorlock -- a
    -- autorizacao de verdade e a checagem de membro logo acima.
    local newState = nearest.state == 1 and 0 or 1

    exports.ox_doorlock:setDoorState(nearest.id, newState)

    return true, nil, newState == 1 and 'trancada' or 'destrancada'
end)

-- ------------------------------------------------------------------ baus --

--- Nome do stash no ox_inventory. Deterministico: o mesmo set e o mesmo slot
--- sempre dao o mesmo nome, entao reabrir depois do restart acha os itens.
---@param set string
---@param slot string
---@return string
local function stashName(set, slot)
    return ('org_%s_%s'):format(set, slot)
end

--- Registra um bau no ox_inventory e devolve o que os clientes precisam para
--- desenhar o target.
---@param row table
---@return table?
local function applyStash(row)
    local x, y, z = row.coords:match('^(%S+) (%S+) (%S+)$')

    x, y, z = tonumber(x), tonumber(y), tonumber(z)

    if not x or not y or not z then
        lib.print.warn(('Bau %s/%s tem coordenada invalida e foi ignorado.'):format(row.group, row.slot))
        return
    end

    local total = tonumber(row.total) or 0

    -- `minPosition` guarda "os N cargos do topo". O grade equivalente depende
    -- de quantos cargos a organizacao tem AGORA, entao e calculado aqui e
    -- nunca gravado: senao, adicionar um cargo mudaria silenciosamente quem
    -- abre o bau.
    local position = math.max(1, math.min(tonumber(row.minPosition) or 1, math.max(total, 1)))

    -- Organizacao sem cargo nenhum nao deve abrir bau para ninguem. Grade 0
    -- nao serve (0 = sem grupo), entao um teto inalcancavel.
    local minGrade = total > 0 and Orgs.positionToGrade(position, total) or 255

    local name = stashName(row.group, row.slot)

    pcall(function()
        -- owner = nil: o bau e da organizacao, nao de um personagem.
        exports.ox_inventory:RegisterStash(
            name, row.label, row.slots, row.maxWeight, nil,
            { [row.group] = minGrade }, vec3(x, y, z))
    end)

    return {
        set         = row.group,
        slot        = row.slot,
        name        = name,
        label       = row.label,
        coords      = { x = x, y = y, z = z },
        minGrade    = minGrade,
        minPosition = position,
        management  = Orgs.truthy(row.management)
    }
end

--- Todos os baus, ja registrados. Serve para o boot e para reenviar aos
--- clientes depois de qualquer mudanca.
---@return table[]
local function loadStashes()
    if not Orgs.schemaReady then return {} end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT s.`group`, s.`slot`, s.`label`, s.`coords`, s.`slots`, s.`maxWeight`,
               s.`minPosition`, s.`management`,
               (SELECT COUNT(*) FROM `ox_group_grades` g WHERE g.`group` = s.`group`) AS total
        FROM `nv_org_stashes` s
    ]])

    if not ok or type(rows) ~= 'table' then return {} end

    local result = {}

    for i = 1, #rows do
        local entry = applyStash(rows[i])

        if entry then result[#result + 1] = entry end
    end

    return result
end

--- Cache do que foi enviado aos clientes, para nao reconsultar o banco a cada
--- jogador que entra.
local stashCache = {}

--- Reaplica tudo e avisa os clientes.
---@param target number? so um jogador, ou nil para todos
function Orgs.syncStashes(target)
    stashCache = loadStashes()

    TriggerClientEvent('nv_orgs:stashes', target or -1, stashCache)
end

CreateThread(function()
    -- Espera o schema; sem tabela nao ha o que registrar.
    while not Orgs.schemaReady do Wait(500) end

    Orgs.syncStashes()
    lib.print.info(('nv_orgs: %d bau(s) registrado(s).'):format(#stashCache))
end)

--- Cliente pronto: manda a lista so para ele.
RegisterNetEvent('nv_orgs:requestStashes', function()
    TriggerClientEvent('nv_orgs:stashes', source, stashCache)
end)

-- ------------------------------------------------------- baus: callbacks --

lib.callback.register('nv_orgs:stashes', function(source, set)
    if not Orgs.isAdmin(source) then return end
    if type(set) ~= 'string' then return end
    if not Orgs.schemaReady then return {} end

    local rows = MySQL.query.await([[
        SELECT `slot`, `label`, `coords`, `slots`, `maxWeight`, `minPosition`, `management`
        FROM `nv_org_stashes` WHERE `group` = ?
        ORDER BY `management` DESC, `minPosition`, `label`
    ]], { set }) or {}

    for i = 1, #rows do
        rows[i].management = Orgs.truthy(rows[i].management)
    end

    return rows
end)

--- Identificador livre para um bau novo dentro da organizacao.
---@param set string
---@return string
local function nextSlot(set)
    local taken = {}

    local rows = MySQL.query.await(
        'SELECT `slot` FROM `nv_org_stashes` WHERE `group` = ?', { set }) or {}

    for i = 1, #rows do taken[rows[i].slot] = true end

    for n = 1, 99 do
        local slot = ('s%d'):format(n)

        if not taken[slot] then return slot end
    end

    return ('s%d'):format(math.random(100, 999))
end

lib.callback.register('nv_orgs:saveStash', function(source, set, data)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not Orgs.schemaReady then return false, 'Tabela de baus indisponivel.' end
    if type(set) ~= 'string' or type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local exists = MySQL.scalar.await('SELECT `name` FROM `ox_groups` WHERE `name` = ?', { set })
    if not exists then return false, 'Organizacao nao encontrada.' end

    local coords = data.coords

    if type(coords) ~= 'table' or type(coords.x) ~= 'number'
        or type(coords.y) ~= 'number' or type(coords.z) ~= 'number'
    then
        return false, 'Coordenada invalida.'
    end

    local total = MySQL.scalar.await(
        'SELECT COUNT(*) FROM `ox_group_grades` WHERE `group` = ?', { set }) or 0

    if total == 0 then return false, 'Crie os cargos antes de criar um bau.' end

    local label = type(data.label) == 'string' and data.label ~= '' and data.label:sub(1, 50)
        or 'Bau'

    local position = math.floor(tonumber(data.minPosition) or 1)
    position = math.max(1, math.min(total, position))

    local management = data.management == true

    local slots = math.floor(tonumber(data.slots) or Config.Stash.defaultSlots)
    local weight = math.floor(tonumber(data.maxWeight) or Config.Stash.defaultWeight)

    slots = math.max(1, math.min(Config.Stash.maxSlots, slots))
    weight = math.max(1000, math.min(Config.Stash.maxWeight, weight))

    -- Slot existente = edicao; sem slot = bau novo.
    local slot = type(data.slot) == 'string' and data.slot ~= '' and data.slot or nextSlot(set)

    -- Gerencia e um so por organizacao: "qual e o bau de gerencia" nao tem
    -- resposta no plural. Marcar um desmarca os outros.
    if management then
        MySQL.query.await('UPDATE `nv_org_stashes` SET `management` = 0 WHERE `group` = ?', { set })
    end

    MySQL.prepare.await([[
        INSERT INTO `nv_org_stashes`
            (`group`, `slot`, `label`, `coords`, `slots`, `maxWeight`, `minPosition`, `management`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            `label` = VALUES(`label`), `coords` = VALUES(`coords`),
            `slots` = VALUES(`slots`), `maxWeight` = VALUES(`maxWeight`),
            `minPosition` = VALUES(`minPosition`), `management` = VALUES(`management`)
    ]], {
        set, slot, label,
        ('%.3f %.3f %.3f'):format(coords.x, coords.y, coords.z),
        slots, weight, position, management and 1 or 0
    })

    Orgs.syncStashes()

    return true
end)

lib.callback.register('nv_orgs:deleteStash', function(source, set, slot)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not Orgs.schemaReady then return false, 'Tabela de baus indisponivel.' end
    if type(set) ~= 'string' or type(slot) ~= 'string' then return false, 'Dados invalidos.' end

    MySQL.query.await('DELETE FROM `nv_org_stashes` WHERE `group` = ? AND `slot` = ?', { set, slot })

    -- O ox_inventory nao tem "desregistrar stash". O que se pode fazer e parar
    -- de desenhar o target, o que este sync faz. Os itens continuam guardados:
    -- recriar o bau com o mesmo slot devolve o mesmo stash, com o conteudo
    -- intacto. E o comportamento seguro -- apagar itens por engano nao tem
    -- desfazer.
    Orgs.syncStashes()

    return true
end)


-- -------------------------------------------------------------- contato --

--- Numero de 10 digitos, sem zero na frente.
---@return string
local function rollNumber()
    local digits = { tostring(math.random(1, 9)) }

    for _ = 2, Config.Contact.digits do
        digits[#digits + 1] = tostring(math.random(0, 9))
    end

    return table.concat(digits)
end

--- Um numero que ninguem esta usando.
---
--- Confere DUAS tabelas: a nossa e `characters.phoneNumber`. Colidir com o
--- telefone de um personagem tornaria o numero ambiguo para qualquer
--- integracao de celular que venha depois -- e ai o conserto seria trocar o
--- numero de alguem, o que ninguem quer.
---@return string?
local function freeNumber()
    for _ = 1, Config.Contact.maxAttempts do
        local number = rollNumber()

        local takenByOrg = MySQL.scalar.await(
            'SELECT 1 FROM `nv_org_contacts` WHERE `number` = ?', { number })

        local takenByPlayer = MySQL.scalar.await(
            'SELECT 1 FROM `characters` WHERE `phoneNumber` = ?', { number })

        if not takenByOrg and not takenByPlayer then return number end
    end
end

--- Exibicao no formato do npwd: XXX XXX XXXX.
---@param number string
---@return string
local function formatNumber(number)
    if #number ~= 10 then return number end

    return ('%s %s %s'):format(number:sub(1, 3), number:sub(4, 6), number:sub(7, 10))
end

Orgs.formatNumber = formatNumber

lib.callback.register('nv_orgs:contacts', function(source, set)
    if not Orgs.isAdmin(source) then return end
    if type(set) ~= 'string' then return end
    if not Orgs.schemaReady then return {} end

    local rows = MySQL.query.await([[
        SELECT `id`, `number`, `active`, DATE_FORMAT(`created`, '%d/%m/%Y') AS created
        FROM `nv_org_contacts` WHERE `group` = ?
        ORDER BY `active` DESC, `created` DESC
    ]], { set }) or {}

    for i = 1, #rows do
        rows[i].display = formatNumber(rows[i].number)
        rows[i].active = Orgs.truthy(rows[i].active)
    end

    return rows
end)

--- Gera um numero novo, aposenta o anterior e entrega o papel.
lib.callback.register('nv_orgs:newContact', function(source, set)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not Orgs.schemaReady then return false, 'Tabela de contatos indisponivel.' end
    if type(set) ~= 'string' then return false, 'Dados invalidos.' end

    local org = MySQL.single.await('SELECT `label` FROM `ox_groups` WHERE `name` = ?', { set })
    if not org then return false, 'Organizacao nao encontrada.' end

    local number = freeNumber()

    if not number then
        return false, 'Nao foi possivel gerar um numero livre. Tente de novo.'
    end

    -- O papel sai ANTES do banco mudar. Se o inventario estiver cheio, o
    -- numero antigo continua ativo e nada foi perdido -- o contrario deixaria
    -- a organizacao com um contato ativo que nao existe em papel nenhum.
    local given = exports.ox_inventory:AddItem(source, Config.Contact.item, 1, {
        org         = org.label,
        set         = set,
        number      = number,
        description = ('%s\nTelefone: %s'):format(org.label, formatNumber(number))
    })

    if not given then
        return false, 'Sem espaco no inventario para o papel.'
    end

    -- So um ativo por organizacao. Os antigos viram historico, nao somem:
    -- saber que um papel velho circulando ja nao vale e informacao util.
    MySQL.query.await('UPDATE `nv_org_contacts` SET `active` = 0 WHERE `group` = ?', { set })

    MySQL.prepare.await(
        'INSERT INTO `nv_org_contacts` (`group`, `number`, `active`) VALUES (?, ?, 1)',
        { set, number })

    return true, nil, formatNumber(number)
end)

--- A organizacao dona de um numero ATIVO.
---
--- Existe para quem vier depois: um resource de telefone consegue perguntar
--- "de quem e este numero?" sem conhecer nada do nv_orgs por dentro. Numero
--- aposentado devolve nil de proposito.
---@param number string
---@return { set: string, label: string }?
local function orgFromNumber(number)
    if type(number) ~= 'string' or not Orgs.schemaReady then return end

    -- Aceita o numero formatado ou cru: quem chama nao deveria precisar saber
    -- como guardamos.
    number = number:gsub('%D', '')

    return MySQL.single.await([[
        SELECT c.`group` AS `set`, g.`label`
        FROM `nv_org_contacts` c
        JOIN `ox_groups` g ON g.`name` = c.`group`
        WHERE c.`number` = ? AND c.`active` = 1
    ]], { number })
end

exports('GetOrgByNumber', orgFromNumber)

--- Mudou cargo ou acao? O grade minimo dos baus pode ter mudado junto.
---@param set string
function Orgs.refreshStashAccess(set)
    if not Orgs.schemaReady then return end

    Orgs.syncStashes()
end

local function ensureCraftTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nv_crafting_projects` (`orgSet` VARCHAR(20) NOT NULL,`label` VARCHAR(80) NOT NULL,
        `x` DOUBLE NOT NULL,`y` DOUBLE NOT NULL,`z` DOUBLE NOT NULL,`heading` FLOAT NOT NULL DEFAULT 0,
        `prop` TINYINT(1) NOT NULL DEFAULT 0,`propModel` VARCHAR(80) NULL,PRIMARY KEY (`orgSet`))]])
end

lib.callback.register('nv_orgs:craftProject',function(source,set)
    if not Orgs.isAdmin(source) or Orgs.getSubtype(set)~='mecanica' then return end
    ensureCraftTable();return MySQL.single.await('SELECT `orgSet` AS `set`,`label`,`x`,`y`,`z`,`heading`,`prop`,`propModel` FROM `nv_crafting_projects` WHERE `orgSet`=?',{set})
end)

lib.callback.register('nv_orgs:saveCraftProject',function(source,set,data)
    if not Orgs.isAdmin(source) or Orgs.getSubtype(set)~='mecanica' then return false,'Disponivel apenas para mecanicas.' end
    if type(data)~='table' or not tonumber(data.x) then return false,'Posicao invalida.' end
    ensureCraftTable();MySQL.prepare.await([[INSERT INTO `nv_crafting_projects` (`orgSet`,`label`,`x`,`y`,`z`,`heading`,`prop`,`propModel`)
        VALUES (?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE `label`=VALUES(`label`),`x`=VALUES(`x`),`y`=VALUES(`y`),`z`=VALUES(`z`),
        `heading`=VALUES(`heading`),`prop`=VALUES(`prop`),`propModel`=VALUES(`propModel`)]],{set,tostring(data.label or 'Bancada da oficina'):sub(1,80),data.x,data.y,data.z,data.heading or 0,data.prop and 1 or 0,'prop_tool_box_04'})
    TriggerEvent('nv_crafting:reloadProjects');return true
end)

lib.callback.register('nv_orgs:deleteCraftProject',function(source,set)
    if not Orgs.isAdmin(source) or Orgs.getSubtype(set)~='mecanica' then return false,'Sem permissao.' end
    ensureCraftTable();MySQL.update.await('DELETE FROM `nv_crafting_projects` WHERE `orgSet`=?',{set});TriggerEvent('nv_crafting:reloadProjects');return true
end)
