local GAS = Config.GasStations
local PRICE = GAS.pricePerLiter or 1
local MAXCAP = GAS.maxFuelCapacity or 200

local activeDrivers = {}                 -- [src] = session
local stationLocks = {}                  -- [stationId] = src (one player serving a station at a time)
local eventQueue = {}                    -- [stationId] = true (stations still needing fuel this event)
local depot = { clear = true, clearedAt = 0 } -- shared yard: both spawn points must be free
local SPAWN_CLEAR_RADIUS = 6.0

-- ============================================================================
-- TEST MODE: resolve the single test station id from the fuel point
-- ============================================================================
local testStationId
do
    local test = GAS.test
    if test and test.enabled and test.fuelPoint then
        local stations = lib.load '@ox_fuel.data.stations'
        local sorted = {}
        for coords in pairs(stations) do sorted[#sorted + 1] = coords end
        table.sort(sorted, function(a, b)
            if a.x ~= b.x then return a.x < b.x end
            if a.y ~= b.y then return a.y < b.y end
            return a.z < b.z
        end)
        local best = math.huge
        for i = 1, #sorted do
            local d = #(sorted[i] - test.fuelPoint)
            if d < best then best, testStationId = d, i end
        end
        print(("^3[nv_delivery] Modo de teste ativo. Posto fixo id = %s.^0"):format(tostring(testStationId)))
    end
end

-- ============================================================================
-- HELPERS
-- ============================================================================
local function deleteSessionVehicles(session)
    if not session then return end
    if session.trailer and DoesEntityExist(session.trailer) then DeleteEntity(session.trailer) end
    if session.truck and DoesEntityExist(session.truck) then DeleteEntity(session.truck) end
    session.truck, session.trailer = nil, nil
end

local function releaseStationLock(stationId)
    if stationId then stationLocks[stationId] = nil end
end

-- A station still wants fuel and can pay for at least 1L
local function stationEligible(station)
    return station and station.fuel < MAXCAP and station.cash >= PRICE
end

local function persistStation(id, station)
    GlobalState.gasStations = GetServerStations()
    MySQL.update("UPDATE `gas_stations` SET `fuel` = ?, `cash` = ? WHERE `id` = ?", { station.fuel, station.cash, id })
end

-- ============================================================================
-- EVENT QUEUE / ACTIVATION
-- ============================================================================
local function buildQueue()
    local stations = GetServerStations()
    if not stations then return 0 end

    eventQueue = {}
    local n = 0
    for id, s in pairs(stations) do
        local inScope = s.fuel <= GAS.qualifyLevel
        if testStationId then inScope = (id == testStationId) end
        if inScope and stationEligible(s) then
            eventQueue[id] = true
            n = n + 1
        end
    end
    return n
end

local function sendPhoneNotification(target, data)
    if GetResourceState('npwd') ~= 'started' then return end
    TriggerEvent('npwd:serverCreateNotification', target, data)
end

local function activateEvent(reason, force)
    if GlobalState.gasEventActive and not force then return false end

    local n = buildQueue()
    if n == 0 then
        GlobalState.gasEventActive = false
        return false
    end

    local wasActive = GlobalState.gasEventActive
    GlobalState.gasEventActive = true

    if not wasActive then
        sendPhoneNotification(-1, {
            app = 'xero',
            title = 'Xero Gas',
            content = 'Postos precisando de combustível! Procure o Gerente de Logística para iniciar as entregas.',
            duration = 10000,
            -- Coordenadas do Gerente de Logística: clicar traça a rota no minimapa.
            coords = { x = GAS.npcCoords.x, y = GAS.npcCoords.y }
        })
    end

    print(("^3[nv_delivery] Evento ativado (%s). %d posto(s) na fila.^0"):format(reason or 'auto', n))
    return true
end

-- Drop finished/broke stations; end the event when the queue is empty
local function refreshEventEnd()
    if not GlobalState.gasEventActive then return end
    local stations = GetServerStations()
    if not stations then return end

    local remaining = 0
    for id in pairs(eventQueue) do
        local s = stations[id]
        if s and stationEligible(s) then
            remaining = remaining + 1
        else
            eventQueue[id] = nil
        end
    end

    if remaining == 0 then
        eventQueue = {}
        GlobalState.gasEventActive = false
        sendPhoneNotification(-1, {
            app = 'xero',
            title = 'Xero Gas',
            content = 'Todos os postos foram reabastecidos. Evento encerrado.',
            duration = 8000
        })
        print('^2[nv_delivery] Evento encerrado (fila vazia).^0')
    end
end

-- Most critical (lowest fuel) station that is eligible and not being served
local function pickNextStation()
    local stations = GetServerStations()
    if not stations then return nil end

    local bestId, bestFuel = nil, math.huge
    for id in pairs(eventQueue) do
        local s = stations[id]
        if s and stationEligible(s) and not stationLocks[id] and s.fuel < bestFuel then
            bestFuel, bestId = s.fuel, id
        end
    end
    return bestId
end

-- ============================================================================
-- ADMIN EVENT: empty + fund every (or the test) station, then activate
-- ============================================================================
local function startGasEvent()
    local stations = GetServerStations()
    if not stations or not next(stations) then return false, 0 end

    local affected = 0
    for id, s in pairs(stations) do
        local target = testStationId and (id == testStationId) or (not testStationId)
        if target then
            s.fuel = 0
            s.cash = math.max(s.cash or 0, MAXCAP * PRICE) -- money to request a full refill
            affected = affected + 1
            MySQL.update("UPDATE `gas_stations` SET `fuel` = ?, `cash` = ? WHERE `id` = ?", { s.fuel, s.cash, id })
        end
    end
    GlobalState.gasStations = stations

    activateEvent('admin', true)
    return true, affected
end
exports('startGasEvent', startGasEvent)

-- ============================================================================
-- AUTO MONITOR: trigger when enough stations are empty
-- ============================================================================
CreateThread(function()
    while true do
        Wait(GAS.monitorInterval or 5000)

        if GlobalState.gasEventActive then
            refreshEventEnd()
        else
            local stations = GetServerStations()
            if stations then
                local empties = 0
                if testStationId then
                    local s = stations[testStationId]
                    if s and s.fuel <= GAS.emptyLevel then empties = GAS.emptyTrigger end
                else
                    for _, s in pairs(stations) do
                        if s.fuel <= GAS.emptyLevel then empties = empties + 1 end
                    end
                end
                if empties >= GAS.emptyTrigger then
                    activateEvent(('monitor: %d vazios'):format(empties))
                end
            end
        end
    end
end)

-- ============================================================================
-- DEPOT SLOT: BOTH spawn points must be free of ANY vehicle (+10s cooldown)
-- ============================================================================
local function spawnPointsClear()
    local t = vec3(GAS.truckSpawn.x, GAS.truckSpawn.y, GAS.truckSpawn.z)
    local tr = vec3(GAS.trailerSpawn.x, GAS.trailerSpawn.y, GAS.trailerSpawn.z)
    for _, veh in ipairs(GetAllVehicles()) do
        local c = GetEntityCoords(veh)
        if #(c - t) < SPAWN_CLEAR_RADIUS or #(c - tr) < SPAWN_CLEAR_RADIUS then
            return false
        end
    end
    return true
end

-- Restart the 10s cooldown the moment both points become free
CreateThread(function()
    while true do
        Wait(1000)
        local clear = spawnPointsClear()
        if clear and not depot.clear then depot.clearedAt = os.time() end
        depot.clear = clear
    end
end)

local function depotStatus()
    if not spawnPointsClear() then return 'occupied' end
    local wait = (depot.clearedAt + (GAS.spawnCooldown or 10)) - os.time()
    if wait > 0 then return 'cooldown', wait end
    return 'ready'
end

-- ============================================================================
-- START JOB: reserve the most critical station and spawn truck + trailer
-- ============================================================================
lib.callback.register('nv_delivery:startGasJob', function(source)
    local src = source

    if activeDrivers[src] then return false, "Você já está em uma entrega de combustível!" end
    if not GlobalState.gasEventActive then return 'no_event' end

    local status, wait = depotStatus()
    if status == 'occupied' then return 'occupied' end
    if status == 'cooldown' then return 'cooldown', wait end

    local stationId = pickNextStation()
    if not stationId then
        return false, "Nenhum posto disponível agora (todos ocupados ou já cheios)."
    end

    local stations = GetServerStations()
    local station = stations[stationId]
    local need = MAXCAP - station.fuel
    local affordable = math.floor(station.cash / PRICE)
    local liters = math.floor(math.min(GAS.maxPerTrip, need, affordable))
    if liters <= 0 then
        return false, "O posto não tem caixa suficiente para pedir combustível."
    end

    -- Spawn truck
    local tSpawn = GAS.truckSpawn
    local truck = CreateVehicle(GAS.truckModel, tSpawn.x, tSpawn.y, tSpawn.z, tSpawn.w, true, true)
    local timeout = 0
    while not DoesEntityExist(truck) and timeout < 50 do Wait(100); timeout = timeout + 1 end
    if not DoesEntityExist(truck) then return false, "Erro ao instanciar o caminhão." end

    -- Spawn trailer
    local trSpawn = GAS.trailerSpawn
    local trailer = CreateVehicle(GAS.trailerModel, trSpawn.x, trSpawn.y, trSpawn.z, trSpawn.w, true, true)
    timeout = 0
    while not DoesEntityExist(trailer) and timeout < 50 do Wait(100); timeout = timeout + 1 end
    if not DoesEntityExist(trailer) then
        DeleteEntity(truck)
        return false, "Erro ao instanciar o trailer de combustível."
    end

    local truckNet = NetworkGetNetworkIdFromEntity(truck)
    local trailerNet = NetworkGetNetworkIdFromEntity(trailer)

    Entity(trailer).state:set('eventStation', stationId, true)
    Entity(trailer).state:set('tripLiters', liters, true)
    Entity(trailer).state:set('hoseHolder', nil, true)

    stationLocks[stationId] = src

    activeDrivers[src] = {
        truck = truck, trailer = trailer,
        truckNet = truckNet, trailerNet = trailerNet,
        stationId = stationId, tripLiters = liters,
        delivered = 0, earned = 0
    }

    return true, { truckNet = truckNet, trailerNet = trailerNet, stationId = stationId, liters = liters }
end)

-- ============================================================================
-- HOSE OWNERSHIP (one hose per trailer, networked via entity state)
-- ============================================================================
lib.callback.register('nv_delivery:claimHose', function(source, trailerNet)
    local trailer = trailerNet and NetworkGetEntityFromNetworkId(trailerNet)
    if not trailer or trailer == 0 or not DoesEntityExist(trailer) then return false end

    local st = Entity(trailer).state
    if not st.eventStation then return false end
    if st.hoseHolder then return false end

    st:set('hoseHolder', source, true)
    return true
end)

RegisterNetEvent('nv_delivery:releaseHose', function(trailerNet)
    local trailer = trailerNet and NetworkGetEntityFromNetworkId(trailerNet)
    if not trailer or trailer == 0 or not DoesEntityExist(trailer) then return end

    local st = Entity(trailer).state
    if st.hoseHolder == source then
        st:set('hoseHolder', nil, true)
    end
end)

-- ============================================================================
-- DELIVER FUEL (incremental): apply one tick of liters into the station
-- Returns how many liters were actually applied (0 = trip done / no cash / full)
-- ============================================================================
lib.callback.register('nv_delivery:deliverFuelTick', function(source, trailerNet, request)
    local ownerSrc, session
    for s, sess in pairs(activeDrivers) do
        if sess.trailerNet == trailerNet then ownerSrc, session = s, sess break end
    end
    if not session then return 0 end

    local stations = GetServerStations()
    local station = stations[session.stationId]
    if not station then return 0 end

    request = tonumber(request) or 0
    local remainingTrip = session.tripLiters - session.delivered
    local capacity = MAXCAP - station.fuel
    local affordable = math.floor(station.cash / PRICE)
    local applied = math.floor(math.min(request, remainingTrip, capacity, affordable))
    if applied <= 0 then return 0 end

    station.fuel = station.fuel + applied
    station.cash = station.cash - applied * PRICE
    session.delivered = session.delivered + applied
    session.earned = session.earned + applied * PRICE

    -- Publish progress so it survives storing/re-grabbing the hose
    local trailerEnt = NetworkGetEntityFromNetworkId(trailerNet)
    if trailerEnt and trailerEnt ~= 0 and DoesEntityExist(trailerEnt) then
        Entity(trailerEnt).state:set('delivered', session.delivered, true)
    end

    persistStation(session.stationId, station)

    if station.fuel >= MAXCAP then
        eventQueue[session.stationId] = nil
    end

    -- Trip finished (target liters reached or station full): tell the owner to return
    if (session.delivered >= session.tripLiters or station.fuel >= MAXCAP) and not session.tripDone then
        session.tripDone = true
        TriggerClientEvent('nv_delivery:tripComplete', ownerSrc)
        if source ~= ownerSrc then
            TriggerClientEvent('ox_lib:notify', source, {
                type = 'success',
                description = ("Você ajudou a entregar combustível no %s!"):format(station.name)
            })
        end
    end

    return applied
end)

-- ============================================================================
-- TRUCK RETURNED: remove vehicles + free the station for the next trip
-- ============================================================================
RegisterNetEvent('nv_delivery:truckReturned', function(hasTrailer)
    local src = source
    local session = activeDrivers[src]
    if not session or not session.tripDone then return end
    session.returnedWithTrailer = hasTrailer and true or false
    deleteSessionVehicles(session)
    releaseStationLock(session.stationId)
    refreshEventEnd()
    session.returned = true
end)

-- ============================================================================
-- COLLECT PAYMENT: $1/L delivered (30% if returned without the trailer)
-- ============================================================================
RegisterNetEvent('nv_delivery:collectPayment', function()
    local src = source
    local session = activeDrivers[src]
    if not session then return end

    if not session.tripDone then
        return TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = "Conclua a entrega dos litros antes de receber o pagamento."
        })
    end

    deleteSessionVehicles(session)
    releaseStationLock(session.stationId)

    local reward = session.earned or 0
    if not session.returnedWithTrailer then reward = math.floor(reward * 0.30) end
    if reward > 0 then exports.ox_inventory:AddItem(src, 'money', reward) end

    activeDrivers[src] = nil
    refreshEventEnd()

    TriggerClientEvent('ox_lib:notify', src, {
        type = session.returnedWithTrailer and 'success' or 'inform',
        description = session.returnedWithTrailer
            and ("Pagamento recebido: $%d (%d L entregues)"):format(reward, session.delivered)
            or ("Sem o trailer: pagamento reduzido a $%d (30%%)"):format(reward)
    })
end)

-- ============================================================================
-- CANCEL JOB: pay what was delivered, cleanup, free the station
-- ============================================================================
RegisterNetEvent('nv_delivery:cancelGasJob', function()
    local src = source
    local session = activeDrivers[src]
    if not session then return end

    deleteSessionVehicles(session)
    releaseStationLock(session.stationId)

    if (session.earned or 0) > 0 then
        exports.ox_inventory:AddItem(src, 'money', session.earned)
    end

    activeDrivers[src] = nil
    refreshEventEnd()

    TriggerClientEvent('ox_lib:notify', src, { type = 'info', description = "Serviço de reabastecimento cancelado." })
end)

-- ============================================================================
-- CLEANUP ON DISCONNECT
-- ============================================================================
AddEventHandler('playerDropped', function()
    local src = source
    local session = activeDrivers[src]
    if session then
        deleteSessionVehicles(session)
        releaseStationLock(session.stationId)
        activeDrivers[src] = nil
        refreshEventEnd()
    end
end)
