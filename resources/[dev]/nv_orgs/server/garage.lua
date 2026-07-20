--[[
    nv_orgs — servidor: estacionamento da organizacao

    Atendente (ped), vagas e frota. Retirar um veiculo debita o caixa da
    empresa; guardar devolve o carro para a garagem.

    Sobre a relacao com o nv_garage: nao ha duplicacao de mecanica. O veiculo
    criado aqui e um veiculo do ox_core com `group` preenchido, entao o
    nv_garage cuida de chave, ignicao e tranca exatamente como cuida de
    qualquer outro. O que este arquivo faz e a parte que o nv_garage nao tem:
    frota paga pelo caixa e acesso por cargo.
]]

local Ox = require '@ox_core.lib.init'

-- ------------------------------------------------------ catalogo de frota --

--- Lista de veiculos para o select da frota. Construida uma vez e guardada:
--- ler e ordenar o json do ox_core a cada abertura de dialogo seria trabalho
--- repetido para um dado que nao muda em runtime.
---@type { model: string, label: string }[]?
local catalog

--- Le o catalogo do ox_core (common/data/vehicles.json).
---@return { model: string, label: string }[]
local function catalogFromOxCore()
    local file = LoadResourceFile('ox_core', 'common/data/vehicles.json')
    local ok, decoded = pcall(json.decode, file or '')

    if not ok or type(decoded) ~= 'table' then
        lib.print.warn('nv_orgs: nao foi possivel ler common/data/vehicles.json; a frota vai cair no campo de texto.')
        return {}
    end

    local cfg = Config.Dealership
    local filterCats = cfg.categories and next(cfg.categories) ~= nil
    local list = {}

    for model, data in pairs(decoded) do
        if type(data) == 'table' then
            -- Filtro de categoria: sem `categories` no config, tudo entra.
            local category = data.category or 'land'

            if not filterCats or cfg.categories[category] then
                local name = data.name or model
                local make = data.make

                list[#list + 1] = {
                    model = model,
                    label = (make and make ~= '') and ('%s %s'):format(make, name) or name
                }
            end
        end
    end

    return list
end

--- Le o catalogo da futura dealership, se o export existir.
---@return { model: string, label: string }[]
local function catalogFromExport()
    local cfg = Config.Dealership.export

    if type(cfg) ~= 'table' or GetResourceState(cfg.resource) ~= 'started' then
        lib.print.warn(('nv_orgs: dealership "%s" nao esta rodando; a frota vai cair no campo de texto.')
            :format(cfg and cfg.resource or '?'))
        return {}
    end

    local ok, result = pcall(function()
        return exports[cfg.resource][cfg.method]()
    end)

    if not ok or type(result) ~= 'table' then return {} end

    -- Normaliza: aceita tanto { model, label } quanto { model = ... }.
    local list = {}

    for i = 1, #result do
        local entry = result[i]

        if type(entry) == 'table' and entry.model then
            list[#list + 1] = {
                model = entry.model,
                label = entry.label or entry.model
            }
        end
    end

    return list
end

--- Catalogo pronto: filtrado, ordenado e cortado no limite.
---@return { model: string, label: string }[]
local function getCatalog()
    if catalog then return catalog end

    local list = Config.Dealership.source == 'export'
        and catalogFromExport()
        or catalogFromOxCore()

    table.sort(list, function(a, b) return a.label < b.label end)

    -- Corta no teto: um select com centenas de itens fica lento, e a busca do
    -- proprio campo cobre o resto.
    local limit = Config.Dealership.limit or 600

    if #list > limit then
        for i = #list, limit + 1, -1 do
            list[i] = nil
        end
    end

    catalog = list

    return catalog
end

lib.callback.register('nv_orgs:vehicleCatalog', function(source)
    if not Orgs.isAdmin(source) then return {} end

    return getCatalog()
end)

-- --------------------------------------------------------------- helpers --

--- "x y z heading" -> vector4
---@param text string?
---@return vector4?
local function toVec4(text)
    if type(text) ~= 'string' then return end

    local x, y, z, w = text:match('^(%S+) (%S+) (%S+) (%S+)$')

    x, y, z, w = tonumber(x), tonumber(y), tonumber(z), tonumber(w)

    if not x or not y or not z then return end

    return vec4(x, y, z, w or 0.0)
end

---@param coords table
---@param heading number?
---@return string
local function fromCoords(coords, heading)
    return ('%.3f %.3f %.3f %.2f'):format(coords.x, coords.y, coords.z, heading or 0.0)
end

--- Quantos cargos a organizacao tem.
---@param set string
---@return number
local function gradeCount(set)
    return MySQL.scalar.await(
        'SELECT COUNT(*) FROM `ox_group_grades` WHERE `group` = ?', { set }) or 0
end

-- ------------------------------------------------------ estado dos peds --

--- O que os clientes precisam para desenhar atendente e vagas.
---@type table[]
local garageCache = {}

--- Monta o pacote enviado aos clientes.
---@return table[]
local function loadGarages()
    if not Orgs.schemaReady then return {} end

    local ok, rows = pcall(MySQL.query.await, [[
        SELECT g.`group`, g.`ped`, o.`type` AS style,
               (SELECT COUNT(*) FROM `ox_group_grades` gg WHERE gg.`group` = g.`group`) AS grades
        FROM `nv_org_garages` g
        JOIN `ox_groups` o ON o.`name` = g.`group`
        WHERE g.`ped` IS NOT NULL
    ]])

    if not ok or type(rows) ~= 'table' then return {} end

    local result = {}

    for i = 1, #rows do
        local row = rows[i]
        local model, rest = row.ped:match('^(%S+) (.+)$')
        local spot = toVec4(rest)

        if model and spot then
            result[#result + 1] = {
                set     = row.group,
                model   = model,
                coords  = { x = spot.x, y = spot.y, z = spot.z },
                heading = spot.w,
                -- Job so aparece para quem e do set; organizacao estatal
                -- aparece para todo mundo (mas so membro interage). Foi o
                -- pedido, e faz sentido: delegacia tem atendente visivel, a
                -- garagem de uma empresa privada nao.
                publicPed = row.style == 'state'
            }
        end
    end

    return result
end

---@param target number?
function Orgs.syncGarages(target)
    garageCache = loadGarages()

    TriggerClientEvent('nv_orgs:garages', target or -1, garageCache)
end

CreateThread(function()
    while not Orgs.schemaReady do Wait(500) end

    Orgs.syncGarages()
end)

RegisterNetEvent('nv_orgs:requestGarages', function()
    TriggerClientEvent('nv_orgs:garages', source, garageCache)
end)

-- ------------------------------------------------------------ consultas --

lib.callback.register('nv_orgs:garage', function(source, set)
    if not Orgs.isAdmin(source) then return end
    if type(set) ~= 'string' or not Orgs.schemaReady then return end

    local row = MySQL.single.await('SELECT `ped` FROM `nv_org_garages` WHERE `group` = ?', { set })

    local spawns = MySQL.query.await(
        'SELECT `id`, `coords` FROM `nv_org_spawns` WHERE `group` = ? ORDER BY `id`', { set }) or {}

    local fleet = MySQL.query.await(
        'SELECT `id`, `model`, `label`, `price`, `minPosition` FROM `nv_org_fleet` WHERE `group` = ? ORDER BY `label`',
        { set }) or {}

    return {
        ped    = row and row.ped or nil,
        spawns = spawns,
        fleet  = fleet
    }
end)

-- ------------------------------------------------------------ atendente --

lib.callback.register('nv_orgs:saveGaragePed', function(source, set, data)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not Orgs.schemaReady then return false, 'Tabela indisponivel.' end
    if type(set) ~= 'string' or type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local model = type(data.model) == 'string' and data.model ~= '' and data.model or 's_m_y_valet_01'
    local coords = data.coords

    if type(coords) ~= 'table' or type(coords.x) ~= 'number' then
        return false, 'Coordenada invalida.'
    end

    MySQL.prepare.await([[
        INSERT INTO `nv_org_garages` (`group`, `ped`) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `ped` = VALUES(`ped`)
    ]], { set, ('%s %s'):format(model:sub(1, 24), fromCoords(coords, data.heading)) })

    Orgs.syncGarages()

    return true
end)

lib.callback.register('nv_orgs:deleteGaragePed', function(source, set)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' then return false, 'Dados invalidos.' end

    MySQL.query.await('DELETE FROM `nv_org_garages` WHERE `group` = ?', { set })
    Orgs.syncGarages()

    return true
end)

-- ---------------------------------------------------------------- vagas --

lib.callback.register('nv_orgs:addSpawn', function(source, set, data)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not Orgs.schemaReady then return false, 'Tabela indisponivel.' end
    if type(set) ~= 'string' or type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local coords = data.coords

    if type(coords) ~= 'table' or type(coords.x) ~= 'number' then
        return false, 'Coordenada invalida.'
    end

    MySQL.prepare.await('INSERT INTO `nv_org_spawns` (`group`, `coords`) VALUES (?, ?)',
        { set, fromCoords(coords, data.heading) })

    return true
end)

lib.callback.register('nv_orgs:deleteSpawn', function(source, set, id)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' or type(id) ~= 'number' then return false, 'Dados invalidos.' end

    MySQL.query.await('DELETE FROM `nv_org_spawns` WHERE `id` = ? AND `group` = ?', { id, set })

    return true
end)

-- ---------------------------------------------------------------- frota --

lib.callback.register('nv_orgs:saveFleet', function(source, set, data)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not Orgs.schemaReady then return false, 'Tabela indisponivel.' end
    if type(set) ~= 'string' or type(data) ~= 'table' then return false, 'Dados invalidos.' end

    local model = type(data.model) == 'string' and data.model:lower():gsub('%s', '') or ''

    if model == '' then return false, 'Informe o modelo do veiculo.' end
    if #model > 20 then return false, 'Nome de modelo longo demais.' end

    local total = gradeCount(set)
    if total == 0 then return false, 'Crie os cargos antes de montar a frota.' end

    local label = type(data.label) == 'string' and data.label ~= '' and data.label:sub(1, 50)
        or model:upper()

    local price = math.max(0, math.floor(tonumber(data.price) or 0))
    local position = math.max(1, math.min(total, math.floor(tonumber(data.minPosition) or total)))

    if data.id then
        MySQL.query.await([[
            UPDATE `nv_org_fleet` SET `model` = ?, `label` = ?, `price` = ?, `minPosition` = ?
            WHERE `id` = ? AND `group` = ?
        ]], { model, label, price, position, data.id, set })
    else
        MySQL.prepare.await([[
            INSERT INTO `nv_org_fleet` (`group`, `model`, `label`, `price`, `minPosition`)
            VALUES (?, ?, ?, ?, ?)
        ]], { set, model, label, price, position })
    end

    return true
end)

lib.callback.register('nv_orgs:deleteFleet', function(source, set, id)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(set) ~= 'string' or type(id) ~= 'number' then return false, 'Dados invalidos.' end

    MySQL.query.await('DELETE FROM `nv_org_fleet` WHERE `id` = ? AND `group` = ?', { id, set })

    return true
end)

-- ------------------------------------------------------- uso pelo membro --

--- A frota que ESTE jogador pode retirar, com o saldo do caixa.
---
--- Diferente dos callbacks acima: aqui quem chama e um membro qualquer, nao um
--- admin. A autorizacao e o cargo dele na organizacao.
lib.callback.register('nv_orgs:fleetFor', function(source, set)
    if type(set) ~= 'string' or not Orgs.schemaReady then return end

    local player = Ox.GetPlayer(source)
    if not player then return end

    local ok, groups = pcall(function() return player.getGroups() end)
    if not ok or type(groups) ~= 'table' then return end

    local grade = groups[set]
    if not grade then return end

    local total = gradeCount(set)
    if total == 0 then return end

    local position = Orgs.gradeToPosition(grade, total)

    local rows = MySQL.query.await(
        'SELECT `id`, `model`, `label`, `price`, `minPosition` FROM `nv_org_fleet` WHERE `group` = ? ORDER BY `label`',
        { set }) or {}

    local fleet = {}

    for i = 1, #rows do
        -- `minPosition` = "a partir do cargo N". Posicao menor = mais alto.
        if position <= rows[i].minPosition then
            fleet[#fleet + 1] = rows[i]
        end
    end

    local balance

    pcall(function()
        local account = Ox.GetGroupAccount(set)

        balance = account and account.balance or nil
    end)

    return { fleet = fleet, balance = balance }
end)

--- Retira um veiculo da frota, debitando o caixa.
lib.callback.register('nv_orgs:takeFleetVehicle', function(source, set, fleetId)
    if type(set) ~= 'string' or type(fleetId) ~= 'number' then return false, 'Dados invalidos.' end
    if not Orgs.schemaReady then return false, 'Indisponivel.' end

    local player = Ox.GetPlayer(source)
    if not player then return false, 'Personagem nao carregado.' end

    local ok, groups = pcall(function() return player.getGroups() end)
    if not ok or type(groups) ~= 'table' then return false, 'Sem permissao.' end

    local grade = groups[set]
    if not grade then return false, 'Voce nao e desta organizacao.' end

    local total = gradeCount(set)
    if total == 0 then return false, 'Organizacao sem cargos.' end

    local row = MySQL.single.await(
        'SELECT `model`, `label`, `price`, `minPosition` FROM `nv_org_fleet` WHERE `id` = ? AND `group` = ?',
        { fleetId, set })

    if not row then return false, 'Veiculo nao encontrado na frota.' end

    if Orgs.gradeToPosition(grade, total) > row.minPosition then
        return false, 'Seu cargo nao libera este veiculo.'
    end

    -- Vaga livre. Sem isso o carro nasce em cima do anterior e os dois saem
    -- voando.
    local spawns = MySQL.query.await(
        'SELECT `coords` FROM `nv_org_spawns` WHERE `group` = ? ORDER BY `id`', { set }) or {}

    if #spawns == 0 then return false, 'Esta organizacao nao tem vagas configuradas.' end

    local spot = toVec4(spawns[1].coords)
    if not spot then return false, 'Vaga com coordenada invalida.' end

    -- A cobranca vem ANTES do spawn: se o veiculo nascesse primeiro e o debito
    -- falhasse, sairia frota de graca.
    if row.price > 0 then
        local account

        local gotAccount = pcall(function() account = Ox.GetGroupAccount(set) end)

        if not gotAccount or not account then
            return false, 'A organizacao nao tem caixa configurado.'
        end

        -- Duas checagens, e nao uma: o `removeBalance` pode lancar (pcall pega)
        -- OU devolver um resultado falso quando o saldo nao cobre. Confiar so
        -- no pcall deixaria passar o segundo caso -- e ai sairia frota de
        -- graca.
        local charged, result = pcall(function()
            return account.removeBalance({
                amount = row.price,
                message = ('Frota: %s'):format(row.label)
            })
        end)

        if not charged or result == false then
            return false, ('Saldo insuficiente no caixa (precisa de $%d).'):format(row.price)
        end
    end

    local vehicle

    local spawned = pcall(function()
        -- `group = set` faz o veiculo pertencer a organizacao: o nv_garage
        -- passa a trata-lo como qualquer veiculo com dono, e o painel de
        -- garagem do jogador nao o mostra como pessoal.
        vehicle = Ox.CreateVehicle({ model = row.model, group = set },
            vec3(spot.x, spot.y, spot.z), spot.w)
    end)

    if not spawned or not vehicle then
        return false, 'Nao foi possivel criar o veiculo. Confira o nome do modelo.'
    end

    -- Chave na mao de quem retirou, seguindo a mecanica do nv_garage.
    pcall(function()
        exports.nv_garage:GiveKey(source, vehicle.plate, row.label)
    end)

    return true, nil, row.label
end)
