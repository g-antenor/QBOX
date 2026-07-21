local Ox = require '@ox_core.lib.init'
local ready = false

CreateThread(function()
    local sql = [[CREATE TABLE IF NOT EXISTS `nv_vehicle_mechanical` (
        `vin` CHAR(17) NOT NULL,
        `engine_wear` FLOAT NOT NULL DEFAULT 0,
        `body_wear` FLOAT NOT NULL DEFAULT 0,
        `offroad_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
        `tyres` JSON NULL,
        `rollovers` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `engine_fault` TINYINT(1) NOT NULL DEFAULT 0,
        `fire_level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`vin`)
    )]]
    ready = pcall(MySQL.query.await, sql)
    if not ready then lib.print.error('Nao foi possivel criar nv_vehicle_mechanical.') end
end)

local function resolve(netId)
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if entity == 0 or not DoesEntityExist(entity) then return end
    local vehicle = Ox.GetVehicle(entity)
    if not vehicle or not vehicle.vin then return end
    return vehicle, entity
end

local function defaults()
    return { engineWear=0, bodyWear=0, offroadSeconds=0, tyres={100,100,100,100}, rollovers=0, engineFault=false, fireLevel=0 }
end

local function sanitise(data)
    local out = defaults()
    if type(data) ~= 'table' then return out end
    out.engineWear = math.min(1000, math.max(0, tonumber(data.engineWear) or 0))
    out.bodyWear = math.min(1000, math.max(0, tonumber(data.bodyWear) or 0))
    out.offroadSeconds = math.min(Config.Offroad.criticalSeconds, math.max(0, math.floor(tonumber(data.offroadSeconds) or 0)))
    out.rollovers = math.min(255, math.max(0, math.floor(tonumber(data.rollovers) or 0)))
    out.engineFault = data.engineFault == true or out.offroadSeconds >= Config.Offroad.criticalSeconds
    out.fireLevel = math.min(3, math.max(0, math.floor(tonumber(data.fireLevel) or 0)))
    if type(data.tyres) == 'table' then
        for i=1,4 do out.tyres[i] = math.min(100, math.max(0, tonumber(data.tyres[i]) or 100)) end
    end
    return out
end

local function load(vin)
    local row = ready and MySQL.single.await('SELECT * FROM `nv_vehicle_mechanical` WHERE `vin` = ?', { vin })
    if not row then return defaults() end
    local tyres = type(row.tyres) == 'string' and json.decode(row.tyres) or row.tyres
    return sanitise({ engineWear=row.engine_wear, bodyWear=row.body_wear, offroadSeconds=row.offroad_seconds,
        tyres=tyres, rollovers=row.rollovers, engineFault=row.engine_fault == 1, fireLevel=row.fire_level })
end

-- Tambem cobre veiculos que ja estavam na rua quando o recurso reiniciou.
CreateThread(function()
    while not ready do Wait(250) end
    for _,vehicle in ipairs(Ox.GetVehicles() or {}) do
        if vehicle.entity and DoesEntityExist(vehicle.entity) and vehicle.vin then
            Entity(vehicle.entity).state:set('nvMechanical',load(vehicle.vin),true)
        end
    end
end)

local function save(vin, data)
    if not ready or not vin then return false end
    data = sanitise(data)
    MySQL.prepare.await([[INSERT INTO `nv_vehicle_mechanical`
        (`vin`,`engine_wear`,`body_wear`,`offroad_seconds`,`tyres`,`rollovers`,`engine_fault`,`fire_level`)
        VALUES (?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE
        `engine_wear`=VALUES(`engine_wear`),`body_wear`=VALUES(`body_wear`),
        `offroad_seconds`=VALUES(`offroad_seconds`),`tyres`=VALUES(`tyres`),
        `rollovers`=VALUES(`rollovers`),`engine_fault`=VALUES(`engine_fault`),`fire_level`=VALUES(`fire_level`)]],
        { vin, data.engineWear, data.bodyWear, data.offroadSeconds, json.encode(data.tyres), data.rollovers,
          data.engineFault and 1 or 0, data.fireLevel })
    return data
end

exports('SaveSnapshot', function(vin, data) return save(vin, data) end)
exports('GetSnapshot', function(vin) return load(vin) end)
exports('ApplyToEntity', function(vin, entity)
    if not vin or not entity or entity == 0 then return end
    Entity(entity).state:set('nvMechanical', load(vin), true)
end)

RegisterNetEvent('nv_mechanic:save', function(netId, data)
    local vehicle, entity = resolve(netId)
    if not vehicle then return end
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(entity)) > 12.0 then return end
    local clean = save(vehicle.vin, data)
    if clean then Entity(entity).state:set('nvMechanical', clean, true) end
end)

local function isMechanic(source)
    local player = Ox.GetPlayer(source)
    if not player then return false end
    return MySQL.scalar.await([[SELECT 1 FROM `character_groups` cg
        JOIN `nv_org_subtype` s ON s.`group`=cg.`name`
        WHERE cg.`charId`=? AND s.`subtype`=? LIMIT 1]], { player.charId, Config.MechanicSubtype }) ~= nil
end

lib.callback.register('nv_mechanic:isMechanic', function(source)
    return isMechanic(source)
end)

RegisterNetEvent('nv_mechanic:explode', function(netId)
    local vehicle, entity = resolve(netId)
    if not vehicle or NetworkGetEntityOwner(entity) ~= source then return end
    local data = load(vehicle.vin)
    if data.fireLevel < 1 then return end
    TriggerClientEvent('nv_mechanic:explodeClient', -1, netId)
end)

RegisterNetEvent('nv_mechanic:extinguish', function(netId)
    local vehicle, entity = resolve(netId)
    if not vehicle or #(GetEntityCoords(GetPlayerPed(source))-GetEntityCoords(entity)) > 4.0 then return end
    if (exports.ox_inventory:GetItemCount(source, 'fire_extinguisher') or 0) < 1 then return end
    local data=load(vehicle.vin)
    if data.fireLevel < 1 then return end
    data.fireLevel=0
    data=save(vehicle.vin,data)
    Entity(entity).state:set('nvMechanical',data,true)
    TriggerClientEvent('nv_mechanic:stopFire',-1,netId)
end)
