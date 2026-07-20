local POINTS = {
    payment = true, truckSpawn = true, invoiceNpc = true, trailerSpawn = true,
    unload = true, preview = true, saleSpawn = true, testSpawn = true, blip = true
}

local function validBlipSprite(sprite)
    sprite = tonumber(sprite)
    for i = 1, #(Config.DealershipBlips or {}) do
        if Config.DealershipBlips[i].value == sprite then return true end
    end
    return false
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `nv_org_dealerships` (
            `group` VARCHAR(20) NOT NULL, `points` LONGTEXT NOT NULL, `categories` LONGTEXT NULL,
            PRIMARY KEY (`group`),
            CONSTRAINT `nv_org_dealerships_group_fk` FOREIGN KEY (`group`) REFERENCES `ox_groups` (`name`)
                ON DELETE CASCADE ON UPDATE CASCADE
        )
    ]])
    pcall(MySQL.query.await, 'ALTER TABLE `nv_org_dealerships` ADD COLUMN `categories` LONGTEXT NULL')
end)

local function read(set)
    if Orgs.getSubtype(set) ~= 'dealership' then return end
    local row = MySQL.single.await([[
        SELECT d.`points`, d.`categories`, g.`label` FROM `nv_org_dealerships` d
        JOIN `ox_groups` g ON g.`name` = d.`group` WHERE d.`group` = ?
    ]], { set })
    if not row then return { set = set, points = {} } end
    return { set = set, label = row.label, points = json.decode(row.points) or {},
        categories = json.decode(row.categories or 'null') or { sedan = true, suv = true, sport = true, moto = true } }
end

exports('GetDealershipConfig', read)
exports('GetDealerships', function()
    local rows = MySQL.query.await([[
        SELECT d.`group` AS `set`, d.`points`, g.`label` FROM `nv_org_dealerships` d
        JOIN `ox_groups` g ON g.`name` = d.`group`
        JOIN `nv_org_subtype` s ON s.`group` = d.`group` AND s.`subtype` = 'dealership'
    ]]) or {}
    for i = 1, #rows do rows[i].points = json.decode(rows[i].points) or {} end
    return rows
end)

lib.callback.register('nv_orgs:setDealershipCategories', function(source, set, selected)
    if not Orgs.isAdmin(source) or Orgs.getSubtype(set) ~= 'dealership' then return false, 'Sem permissao.' end
    local allowed = { sedan = true, suv = true, sport = true, moto = true }
    local current = read(set) or { points = {}, categories = {} }
    local categories = current.categories or {}
    for _, value in ipairs(type(selected) == 'table' and selected or {}) do
        if allowed[value] then categories[value] = true end
    end
    MySQL.prepare.await([[
        INSERT INTO `nv_org_dealerships` (`group`, `points`, `categories`) VALUES (?, '{}', ?)
        ON DUPLICATE KEY UPDATE `categories` = VALUES(`categories`)
    ]], { set, json.encode(categories) })
    return true
end)

lib.callback.register('nv_orgs:removeDealershipCategory', function(source, set, category)
    if not Orgs.isAdmin(source) or Orgs.getSubtype(set) ~= 'dealership' then return false, 'Sem permissao.' end
    local current = read(set) or { points = {}, categories = {} }
    current.categories = current.categories or {}
    current.categories[category] = nil
    MySQL.prepare.await([[
        INSERT INTO `nv_org_dealerships` (`group`, `points`, `categories`) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `categories` = VALUES(`categories`)
    ]], { set, json.encode(current.points or {}), json.encode(current.categories) })
    return true
end)

lib.callback.register('nv_orgs:buyDealershipTablet', function(source, set)
    if Orgs.getSubtype(set) ~= 'dealership' then return false, 'Esta organizacao nao e uma concessionaria.' end
    local Ox = require '@ox_core.lib.init'
    local player = Ox.GetPlayer(source)
    local groups = player and player.getGroups()
    if not groups or groups[set] == nil then return false, 'Voce nao pertence a esta concessionaria.' end
    if not exports.ox_inventory:CanCarryItem(source, 'dealership', 1) then
        return false, 'Sem espaco para guardar o tablet.'
    end
    if (exports.ox_inventory:GetItemCount(source, 'money') or 0) < 100 then
        return false, 'Voce precisa de $100 em dinheiro.'
    end
    if not exports.ox_inventory:RemoveItem(source, 'money', 100) then
        return false, 'Nao foi possivel efetuar o pagamento.'
    end
    local added = exports.ox_inventory:AddItem(source, 'dealership', 1)
    if not added then
        exports.ox_inventory:AddItem(source, 'money', 100)
        return false, 'Nao foi possivel entregar o tablet. O valor foi devolvido.'
    end
    return true, nil, 'Tablet adquirido por $100.'
end)

lib.callback.register('nv_orgs:dealership', function(source, set)
    if not Orgs.isAdmin(source) then return end
    return read(set)
end)

lib.callback.register('nv_orgs:setDealershipPoint', function(source, set, point, coords)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if not POINTS[point] or Orgs.getSubtype(set) ~= 'dealership' then return false, 'Unidade invalida.' end
    if type(coords) ~= 'table' or not tonumber(coords.x) or not tonumber(coords.y) or not tonumber(coords.z) then
        return false, 'Coordenada invalida.'
    end
    local current = read(set) or { points = {} }
    current.points[point] = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0,
        w = tonumber(coords.w) or 0.0 }
    MySQL.prepare.await([[
        INSERT INTO `nv_org_dealerships` (`group`, `points`) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `points` = VALUES(`points`)
    ]], { set, json.encode(current.points) })
    return true
end)

lib.callback.register('nv_orgs:setDealershipBlip', function(source, set, data)
    if not Orgs.isAdmin(source) or Orgs.getSubtype(set) ~= 'dealership' then return false, 'Sem permissao.' end
    if type(data) ~= 'table' or not validBlipSprite(data.sprite)
        or not tonumber(data.x) or not tonumber(data.y) or not tonumber(data.z) then
        return false, 'Configuracao de blip invalida.'
    end
    local current = read(set) or { points = {} }
    current.points.blip = {
        x = data.x + 0.0, y = data.y + 0.0, z = data.z + 0.0,
        sprite = tonumber(data.sprite), color = 1, scale = 0.85,
        radius = math.min(500.0, math.max(10.0, tonumber(data.radius) or 60.0)),
        label = type(data.label) == 'string' and data.label:sub(1, 50) or 'Concessionaria'
    }
    MySQL.prepare.await([[
        INSERT INTO `nv_org_dealerships` (`group`, `points`) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `points` = VALUES(`points`)
    ]], { set, json.encode(current.points) })
    TriggerClientEvent('nv_dealership:refreshBlips', -1)
    return true
end)

lib.callback.register('nv_orgs:removeDealershipPoint', function(source, set, point)
    if not Orgs.isAdmin(source) or not POINTS[point] then return false, 'Sem permissao.' end
    local current = read(set)
    if not current then return false, 'Unidade invalida.' end
    current.points[point] = nil
    MySQL.prepare.await('UPDATE `nv_org_dealerships` SET `points` = ? WHERE `group` = ?',
        { json.encode(current.points), set })
    if point == 'blip' then TriggerClientEvent('nv_dealership:refreshBlips', -1) end
    return true
end)
