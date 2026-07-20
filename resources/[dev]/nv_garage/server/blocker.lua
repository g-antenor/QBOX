local Ox = require '@ox_core.lib.init'
local blockers = {}
local blockerPlates = {}

RegisterNetEvent('nv_garage:dispatchTheft', function(coords, data)
    if GetResourceState('nv_dispatch') == 'started' then
        exports.nv_dispatch:VehicleTheft(source, coords, data)
    end
end)

RegisterNetEvent('nv_garage:dispatchTheftMoved', function(alertId, coords)
    if GetResourceState('nv_dispatch') == 'started' then
        exports.nv_dispatch:MoveVehicleTheft(source, alertId, coords)
    end
end)

RegisterNetEvent('nv_garage:dispatchTheftStopped', function(alertId)
    if GetResourceState('nv_dispatch') == 'started' then
        exports.nv_dispatch:StopVehicleTheft(source, alertId)
    end
end)

local function identity(netId)
    netId = tonumber(netId)
    if not netId then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then return end
    local vehicle = Ox.GetVehicleFromNetId(netId)
    local plate = vehicle and vehicle.plate or GetVehicleNumberPlateText(entity)
    if not plate then return end
    plate = plate:gsub('^%s+', ''):gsub('%s+$', ''):upper()
    return (vehicle and vehicle.vin) or ('plate:' .. plate), plate, entity
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `nv_vehicle_jammers` (
            `vehicleId` VARCHAR(80) NOT NULL,
            `plate` VARCHAR(12) NOT NULL,
            `durability` TINYINT UNSIGNED NOT NULL DEFAULT 100,
            `installedAt` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`vehicleId`),
            KEY `nv_vehicle_jammers_plate` (`plate`)
        )
    ]])
    pcall(MySQL.query.await, 'ALTER TABLE `nv_vehicle_jammers` ADD COLUMN `durability` TINYINT UNSIGNED NOT NULL DEFAULT 100')
    local rows = MySQL.query.await('SELECT `vehicleId`, `plate`, `durability` FROM `nv_vehicle_jammers`') or {}
    for i = 1, #rows do
        local durability = math.max(0, tonumber(rows[i].durability) or 100)
        blockers[rows[i].vehicleId] = durability
        blockerPlates[rows[i].plate] = durability
    end
end)

local function installed(value)
    if type(value) == 'number' then
        local vehicleId = identity(value)
        return vehicleId and blockers[vehicleId] ~= nil or false
    end
    if type(value) ~= 'string' then return false end
    local plate = value:gsub('^%s+', ''):gsub('%s+$', ''):upper()
    return blockerPlates[plate] ~= nil
end

local function active(value)
    if type(value) == 'number' then
        local vehicleId = identity(value)
        return vehicleId and (blockers[vehicleId] or 0) > 0 or false
    end
    if type(value) ~= 'string' then return false end
    local plate = value:gsub('^%s+', ''):gsub('%s+$', ''):upper()
    return (blockerPlates[plate] or 0) > 0
end

local function remove(netId)
    local vehicleId, plate = identity(netId)
    if not vehicleId or blockers[vehicleId] == nil then return false end
    MySQL.prepare.await('DELETE FROM `nv_vehicle_jammers` WHERE `vehicleId` = ?', { vehicleId })
    blockers[vehicleId] = nil
    blockerPlates[plate] = nil
    return true
end

exports('IsVehicleBlocked', active)
exports('IsBlockerInstalled', installed)
exports('RemoveVehicleBlocker', remove)

local function context(source, netId)
    local vehicleId, plate, entity = identity(netId)
    local ped = GetPlayerPed(source)
    if not vehicleId or ped == 0 or GetVehiclePedIsIn(ped, false) ~= entity
        or GetPedInVehicleSeat(entity, -1) ~= ped then
        return nil, 'Entre no banco do motorista para instalar ou retirar.'
    end
    if (exports.ox_inventory:GetItemCount(source, Config.Blocker.cutter) or 0) < 1 then
        return nil, 'Voce precisa de um alicate de corte.'
    end
    return { vehicleId = vehicleId, plate = plate,
        action = blockers[vehicleId] ~= nil and 'remove' or 'install' }
end

local function wearCutter(source, amount)
    local slots = exports.ox_inventory:Search(source, 'slots', Config.Blocker.cutter) or {}
    local target
    for _, slot in pairs(slots) do
        if not target or (tonumber(slot.metadata and slot.metadata.durability) or 100)
            < (tonumber(target.metadata and target.metadata.durability) or 100) then target = slot end
    end
    if not target then return end
    local durability = tonumber(target.metadata and target.metadata.durability) or 100
    exports.ox_inventory:SetDurability(source, target.slot, math.max(0, durability - (tonumber(amount) or 0)))
end

lib.callback.register('nv_garage:blockerAction', function(source, netId, expectedAction)
    local ctx, err = context(source, netId)
    if not ctx then return false, err end
    if expectedAction ~= 'install' and expectedAction ~= 'remove' then return false, 'Acao invalida.' end
    if ctx.action ~= expectedAction then
        return false, expectedAction == 'remove' and 'noop' or 'Este veiculo ja possui um bloqueador.'
    end
    if expectedAction == 'install' and (exports.ox_inventory:GetItemCount(source, Config.Blocker.item) or 0) < 1 then
        return false, 'Voce nao tem um bloqueador.'
    end
    return true, nil, ctx.action
end)

lib.callback.register('nv_garage:useBlocker', function(source, netId, expectedAction, taskSuccess)
    local cfg = Config.Blocker
    local ctx, err = context(source, netId)
    if not ctx then return false, err end
    if ctx.action ~= expectedAction then return false, 'O estado do bloqueador mudou.' end

    if not taskSuccess then
        wearCutter(source, expectedAction == 'remove' and cfg.cutterWear.removeFail or cfg.cutterWear.installFail)
        return false, expectedAction == 'remove' and 'Voce errou ao retirar o bloqueador.'
            or 'Voce errou ao instalar o bloqueador.'
    end

    if expectedAction == 'remove' then
        local durability = blockers[ctx.vehicleId] or 0
        if durability > 0 and not exports.ox_inventory:CanCarryItem(source, cfg.item, 1) then
            return false, 'Sem espaco para guardar o bloqueador.'
        end
        wearCutter(source, cfg.cutterWear.removeSuccess)
        remove(netId)
        if durability <= 0 then return true, nil, false, 'broken' end
        exports.ox_inventory:AddItem(source, cfg.item, 1, { durability = durability })
        return true, nil, false, 'removed'
    end

    local slots = exports.ox_inventory:Search(source, 'slots', cfg.item) or {}
    local blocker
    for _, slot in pairs(slots) do blocker = slot break end
    if not blocker or not exports.ox_inventory:RemoveItem(source, cfg.item, 1, nil, blocker.slot) then
        return false, 'Nao foi possivel usar o bloqueador.'
    end
    local durability = math.max(0, tonumber(blocker.metadata and blocker.metadata.durability) or 100)
    local ok = pcall(MySQL.prepare.await, [[
        INSERT INTO `nv_vehicle_jammers` (`vehicleId`, `plate`, `durability`) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `plate` = VALUES(`plate`), `durability` = VALUES(`durability`)
    ]], { ctx.vehicleId, ctx.plate, durability })
    if not ok then
        exports.ox_inventory:AddItem(source, cfg.item, 1, { durability = durability })
        return false, 'Nao foi possivel instalar o bloqueador.'
    end
    blockers[ctx.vehicleId] = durability
    blockerPlates[ctx.plate] = durability
    return true, nil, true, 'installed'
end)

lib.callback.register('nv_garage:isBlocked', function(_, netId)
    return active(netId)
end)

RegisterNetEvent('nv_garage:blockerSignalLost', function(coords, data)
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return end
    local ped = GetPlayerPed(source)
    local entity = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    local netId = entity ~= 0 and NetworkGetNetworkIdFromEntity(entity) or 0
    if not active(netId) then return end
    local actual = GetEntityCoords(ped)
    local given = vec3(tonumber(coords.x) or 0, tonumber(coords.y) or 0, tonumber(coords.z) or 0)
    if #(actual - given) > 30.0 then return end

    local vehicleId, plate = identity(netId)
    local durability = blockers[vehicleId]
    local angle, distance = math.random() * math.pi * 2, math.sqrt(math.random()) * Config.Blocker.blur
    if GetResourceState('nv_dispatch') == 'started' then
        exports.nv_dispatch:Send('perda_sinal', vec3(
            given.x + math.cos(angle) * distance, given.y + math.sin(angle) * distance, given.z), {
            detail = ('Rastreamento do veiculo %s interrompido'):format(plate), plate = plate
        })
    end
    durability = math.max(0, durability - Config.Blocker.signalWear)
    blockers[vehicleId], blockerPlates[plate] = durability, durability
    MySQL.prepare('UPDATE `nv_vehicle_jammers` SET `durability` = ? WHERE `vehicleId` = ?', { durability, vehicleId })
end)
