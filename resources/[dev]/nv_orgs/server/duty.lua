local Ox = require '@ox_core.lib.init'

local dutyPointsCache = {}

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `nv_org_duty_points` (
            `group` VARCHAR(20) NOT NULL,
            `dutyPoint` LONGTEXT NULL,
            `servicePed` LONGTEXT NULL,
            PRIMARY KEY (`group`),
            CONSTRAINT `nv_org_duty_points_group_fk` FOREIGN KEY (`group`) REFERENCES `ox_groups` (`name`)
                ON DELETE CASCADE ON UPDATE CASCADE
        )
    ]])

    local rows = MySQL.query.await('SELECT `group`, `dutyPoint`, `servicePed` FROM `nv_org_duty_points`') or {}
    for i = 1, #rows do
        local r = rows[i]
        dutyPointsCache[r.group] = {
            dutyPoint = json.decode(r.dutyPoint or 'null'),
            servicePed = json.decode(r.servicePed or 'null')
        }
    end
end)

local function getDutyData(set)
    return dutyPointsCache[set] or {}
end

local function syncDuty(target)
    TriggerClientEvent('nv_orgs:syncDutyPoints', target or -1, dutyPointsCache)
end

lib.callback.register('nv_orgs:getDutyData', function(source, set)
    return getDutyData(set)
end)

lib.callback.register('nv_orgs:setDutyPoint', function(source, set, coords)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(coords) ~= 'table' or not tonumber(coords.x) or not tonumber(coords.y) or not tonumber(coords.z) then
        return false, 'Coordenada invalida.'
    end

    local current = getDutyData(set)
    current.dutyPoint = {
        x = coords.x + 0.0,
        y = coords.y + 0.0,
        z = coords.z + 0.0,
        w = tonumber(coords.w) or 0.0
    }
    dutyPointsCache[set] = current

    MySQL.prepare.await([[
        INSERT INTO `nv_org_duty_points` (`group`, `dutyPoint`, `servicePed`) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `dutyPoint` = VALUES(`dutyPoint`)
    ]], { set, json.encode(current.dutyPoint), json.encode(current.servicePed) })

    syncDuty(-1)
    return true
end)

lib.callback.register('nv_orgs:removeDutyPoint', function(source, set)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    local current = getDutyData(set)
    current.dutyPoint = nil
    dutyPointsCache[set] = current

    MySQL.prepare.await([[
        INSERT INTO `nv_org_duty_points` (`group`, `dutyPoint`, `servicePed`) VALUES (?, 'null', ?)
        ON DUPLICATE KEY UPDATE `dutyPoint` = 'null'
    ]], { set, json.encode(current.servicePed) })

    syncDuty(-1)
    return true
end)

lib.callback.register('nv_orgs:setServicePed', function(source, set, coords)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    if type(coords) ~= 'table' or not tonumber(coords.x) or not tonumber(coords.y) or not tonumber(coords.z) then
        return false, 'Coordenada invalida.'
    end

    local current = getDutyData(set)
    current.servicePed = {
        x = coords.x + 0.0,
        y = coords.y + 0.0,
        z = coords.z + 0.0,
        w = tonumber(coords.w) or 0.0
    }
    dutyPointsCache[set] = current

    MySQL.prepare.await([[
        INSERT INTO `nv_org_duty_points` (`group`, `dutyPoint`, `servicePed`) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `servicePed` = VALUES(`servicePed`)
    ]], { set, json.encode(current.dutyPoint), json.encode(current.servicePed) })

    syncDuty(-1)
    return true
end)

lib.callback.register('nv_orgs:removeServicePed', function(source, set)
    if not Orgs.isAdmin(source) then return false, 'Sem permissao.' end
    local current = getDutyData(set)
    current.servicePed = nil
    dutyPointsCache[set] = current

    MySQL.prepare.await([[
        INSERT INTO `nv_org_duty_points` (`group`, `dutyPoint`, `servicePed`) VALUES (?, ?, 'null')
        ON DUPLICATE KEY UPDATE `servicePed` = 'null'
    ]], { set, json.encode(current.dutyPoint) })

    syncDuty(-1)
    return true
end)

local function checkServicePedVisibility(set)
    if not set then return end
    local dutyCount = 0
    local players = Ox.GetPlayers({ groups = { [set] = 0 } })
    if players then
        for i = 1, #players do
            local pSrc = players[i].source
            if pSrc and Player(pSrc).state.duty then
                dutyCount = dutyCount + 1
            end
        end
    end
    TriggerClientEvent('nv_orgs:setServicePedVisibility', -1, set, dutyCount == 0)
end

lib.callback.register('nv_orgs:toggleDuty', function(source, set)
    local player = Ox.GetPlayer(source)
    if not player then return false, 'Jogador nao encontrado.' end

    local groups = player.getGroups()
    if not groups or groups[set] == nil then
        return false, 'Voce nao pertence a esta organizacao.'
    end

    local currentDuty = Player(source).state.duty or false
    local newDuty = not currentDuty
    Player(source).state:set('duty', newDuty, true)

    CreateThread(function()
        Wait(200)
        checkServicePedVisibility(set)
    end)

    return true, newDuty
end)

local function initPlayerOffDuty(src)
    if not src then return end
    Player(src).state:set('duty', false, true)
    CreateThread(function()
        Wait(500)
        for set, _ in pairs(dutyPointsCache) do
            checkServicePedVisibility(set)
        end
    end)
end

AddEventHandler('playerJoining', function(src)
    local pSrc = src or source
    initPlayerOffDuty(pSrc)
    TriggerClientEvent('nv_orgs:syncDutyPoints', pSrc, dutyPointsCache)
end)

RegisterNetEvent('ox:setActiveCharacter', function()
    local src = source
    initPlayerOffDuty(src)
end)

RegisterNetEvent('ox_core:playerLoaded', function()
    local src = source
    initPlayerOffDuty(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    CreateThread(function()
        Wait(500)
        for set, _ in pairs(dutyPointsCache) do
            checkServicePedVisibility(set)
        end
    end)
end)
