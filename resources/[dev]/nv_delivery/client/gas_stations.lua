local GAS = Config.GasStations

-- ============================================================================
-- STATION ID <-> COORDS (shared with ox_fuel data)
-- ============================================================================
local sortedStations = {}
local function initStations()
    local stations = lib.load '@ox_fuel.data.stations'
    for coords in pairs(stations) do
        sortedStations[#sortedStations + 1] = coords
    end
    table.sort(sortedStations, function(a, b)
        if a.x ~= b.x then return a.x < b.x end
        if a.y ~= b.y then return a.y < b.y end
        return a.z < b.z
    end)
end
initStations()

local function stationCoords(id)
    return sortedStations[id]
end

local function closestStationId(coords)
    local id, best = nil, math.huge
    for i = 1, #sortedStations do
        local d = #(coords - sortedStations[i])
        if d < best then best, id = d, i end
    end
    return id
end

-- ============================================================================
-- MISSION STATE (job owner only)
-- ============================================================================
local job = {
    active = false,
    stage = nil,            -- 'truck' | 'trailer' | 'station' | 'return' | 'payment'
    truck = 0,
    trailer = 0,
    truckNet = nil,
    trailerNet = nil,
    stationId = nil,
    routeBlip = nil,
}

local npcPed = nil

-- ============================================================================
-- ROUTE BLIPS (personal GPS markers)
-- ============================================================================
local function clearRoute()
    if job.routeBlip and DoesBlipExist(job.routeBlip) then RemoveBlip(job.routeBlip) end
    job.routeBlip = nil
end

local function setRoute(coords, label, sprite, colour)
    clearRoute()
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 1)
    SetBlipColour(blip, colour or 5)
    SetBlipScale(blip, 0.9)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, colour or 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Destino')
    EndTextCommandSetBlipName(blip)
    job.routeBlip = blip
end

-- ============================================================================
-- EVENT WORLD BLIPS (fire icon + pulsing yellow circle)
-- ============================================================================
local eventBlips = { fire = nil, radius = nil }
local eventPulse = false

local function startEventBlips()
    if eventBlips.fire then return end
    local c = GAS.npcCoords

    local fire = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(fire, GAS.blips.event)
    SetBlipColour(fire, 5)       -- amarelo
    SetBlipScale(fire, 1.0)
    SetBlipAsShortRange(fire, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Evento: Postos de Gasolina')
    EndTextCommandSetBlipName(fire)
    eventBlips.fire = fire

    local radius = AddBlipForRadius(c.x, c.y, c.z, 60.0)
    SetBlipColour(radius, 5)     -- amarelo
    SetBlipAlpha(radius, 128)
    eventBlips.radius = radius

    eventPulse = true
    CreateThread(function()
        local alpha, dir = 80, 1
        while eventPulse and eventBlips.radius and DoesBlipExist(eventBlips.radius) do
            alpha = alpha + dir * 6
            if alpha >= 180 then alpha, dir = 180, -1
            elseif alpha <= 60 then alpha, dir = 60, 1 end
            SetBlipAlpha(eventBlips.radius, alpha)
            Wait(50)
        end
    end)
end

local function stopEventBlips()
    eventPulse = false
    if eventBlips.fire and DoesBlipExist(eventBlips.fire) then RemoveBlip(eventBlips.fire) end
    if eventBlips.radius and DoesBlipExist(eventBlips.radius) then RemoveBlip(eventBlips.radius) end
    eventBlips.fire, eventBlips.radius = nil, nil
end

AddStateBagChangeHandler('gasEventActive', 'global', function(_, _, value)
    if value then startEventBlips() else stopEventBlips() end
end)

CreateThread(function()
    Wait(1000)
    if GlobalState.gasEventActive then startEventBlips() end
end)

-- ============================================================================
-- EVENT HOSE (independent from ox_fuel, networked, one per trailer)
--   - state.eventStation : station id assigned to that trailer (set by server)
--   - state.hoseHolder   : server id of the player currently holding the hose
-- ============================================================================
local heldHose = nil    -- { trailer, trailerNet, station, nozzle, rope }
local isFueling = false

local function getClosestPump(coords)
    local closest, best = nil, 4.0
    for i = 1, #GAS.pumpModels do
        local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 4.0, GAS.pumpModels[i], false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then
            local d = #(coords - GetEntityCoords(obj))
            if d < best then closest, best = obj, d end
        end
    end
    return closest
end

local function dropHose(silent)
    if not heldHose then return end
    local h = heldHose
    heldHose = nil
    isFueling = false

    if h.rope then DeleteRope(h.rope) end
    if h.nozzle and DoesEntityExist(h.nozzle) then DeleteEntity(h.nozzle) end
    if h.anchorProp and DoesEntityExist(h.anchorProp) then DeleteEntity(h.anchorProp) end

    TriggerServerEvent('nv_delivery:releaseHose', h.trailerNet)
end

-- Hazards while holding the hose:
--   * wander > hoseMaxDistance (8m) from where you grabbed  -> explode the TRAILER
--   * drive off in a vehicle for 10s in movement            -> remove hose + explode the TRAILER
local function explosionWatcher()
    CreateThread(function()
        local movingSince = nil
        while heldHose do
            Wait(200)
            if heldHose then
                local trailer = heldHose.trailer
                if not DoesEntityExist(trailer) then
                    dropHose(true)
                    break
                end

                if cache.vehicle then
                    -- Drove off with the hose: after 10s IN MOVEMENT, remove the
                    -- hose/nozzle and explode the trailer.
                    if GetEntitySpeed(cache.vehicle) > 1.0 then
                        if not movingSince then movingSince = GetGameTimer() end
                        if GetGameTimer() - movingSince >= 10000 then
                            dropHose(true)
                            if DoesEntityExist(trailer) then
                                local tc = GetEntityCoords(trailer)
                                AddExplosion(tc.x, tc.y, tc.z, 2, 5.0, true, false, 1.0)
                            end
                            break
                        end
                    else
                        movingSince = nil
                    end
                else
                    movingSince = nil

                    -- On foot: too far from where you grabbed -> explode the trailer
                    if not isFueling then
                        local pedCoords = GetEntityCoords(cache.ped)
                        if #(pedCoords - heldHose.origin) > (GAS.hoseMaxDistance or 8.0) then
                            local tc = GetEntityCoords(trailer)
                            AddExplosion(tc.x, tc.y, tc.z, 2, 5.0, true, false, 1.0)
                            dropHose(true)
                            break
                        end
                    end
                end
            end
        end
    end)
end

-- Trip fully delivered? (based on the networked state so it works for any player)
local function tripDoneFor(trailer)
    if not (trailer and DoesEntityExist(trailer)) then return false end
    local st = Entity(trailer).state
    local tl = st.tripLiters or 0
    return tl > 0 and (st.delivered or 0) >= tl
end

-- Progressbar refuel. A parallel thread commits ~fuelRate L/s to the server so a
-- CANCEL saves the partial liters delivered; a COMPLETE tops up the remainder.
-- The trip only finishes (server tripComplete) once the full liters are delivered.
local function dischargeAtPump(pump)
    if isFueling or not heldHose then return end

    local trailer = heldHose.trailer
    local tripLiters = (DoesEntityExist(trailer) and Entity(trailer).state.tripLiters) or 0
    local delivered = (DoesEntityExist(trailer) and Entity(trailer).state.delivered) or 0
    if tripLiters <= 0 or delivered >= tripLiters then return end

    isFueling = true

    -- Connect the nozzle to the pump if one is nearby
    if pump and DoesEntityExist(pump) then
        DetachEntity(heldHose.nozzle, true, true)
        AttachEntityToEntity(heldHose.nozzle, pump, 0, 0.0, 0.0, 1.2, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    end

    local rate = GAS.fuelRate or 4
    local remaining = tripLiters - delivered
    local duration = math.ceil(remaining / rate) * 1000

    -- Commit liters while the bar runs (so a cancel keeps what was inserted)
    CreateThread(function()
        while isFueling and heldHose do
            local applied = lib.callback.await('nv_delivery:deliverFuelTick', false, heldHose.trailerNet, rate)
            if not applied or applied <= 0 then break end
            Wait(1000)
        end
    end)

    local ok = lib.progressBar({
        duration = duration,
        label = ('Abastecendo o posto (%d L)...'):format(remaining),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'timetable@gardener@filling_can', clip = 'gar_ig_5_filling_can', flags = 49 }
    })

    isFueling = false -- stop the commit thread

    -- On completion, top up any remainder so the trip finishes server-side
    if ok and heldHose then
        lib.callback.await('nv_delivery:deliverFuelTick', false, heldHose.trailerNet, tripLiters)
    end

    if heldHose and DoesEntityExist(heldHose.nozzle) then
        AttachEntityToEntity(heldHose.nozzle, cache.ped, GetPedBoneIndex(cache.ped, 18905), 0.1, 0.02, 0.02, 90.0, 40.0, 170.0, true, true, false, true, 1, true)
    end
    ClearPedTasks(cache.ped)
end

-- Normal mode only: keypress prompt to refuel near a pump of the assigned station.
-- (Test mode uses the ox_target zone + the persistent marker thread below.)
local function startFuelPromptThread()
    if GAS.test and GAS.test.enabled then return end
    CreateThread(function()
        while heldHose do
            local sleep = 500
            if not isFueling then
                local pedCoords = GetEntityCoords(cache.ped)
                local sc = stationCoords(heldHose.station)
                if sc and #(pedCoords - sc) < 25.0 then
                    local pump = getClosestPump(pedCoords)
                    if pump and closestStationId(GetEntityCoords(pump)) == heldHose.station then
                        sleep = 0
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('Pressione ~INPUT_CONTEXT~ para abastecer o posto')
                        EndTextCommandDisplayHelp(0, false, true, -1)
                        if IsControlJustPressed(0, 51) then -- E
                            dischargeAtPump(pump)
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

local function grabHose(trailer)
    if heldHose then return end
    local station = Entity(trailer).state.eventStation
    if not station then return end
    local trailerNet = NetworkGetNetworkIdFromEntity(trailer)

    CreateThread(function()
        local ok = lib.callback.await('nv_delivery:claimHose', false, trailerNet)
        if not ok then return end

        -- Nozzle prop in the player's right hand
        lib.requestModel(GAS.hoseProp)
        local ped = cache.ped
        local nozzle = CreateObject(GAS.hoseProp, 0.0, 0.0, 0.0, true, true, false)
        SetEntityCollision(nozzle, false, false)
        AttachEntityToEntity(nozzle, ped, GetPedBoneIndex(ped, 18905), 0.1, 0.02, 0.02, 90.0, 40.0, 170.0, true, true, false, true, 1, true)

        -- Frozen, invisible anchor prop at the middle-bottom of the trailer. The rope
        -- pulls on THIS (which never moves) instead of on the trailer, so the trailer
        -- is never flung/removed and the nozzle stays in the hand.
        local anchorPos = GetOffsetFromEntityInWorldCoords(trailer, 0.0, 0.0, -0.5)
        lib.requestModel(GAS.hoseProp)
        local anchorProp = CreateObject(GAS.hoseProp, anchorPos.x, anchorPos.y, anchorPos.z, false, false, false)
        SetEntityCollision(anchorProp, false, false)
        SetEntityVisible(anchorProp, false, false)
        FreezeEntityPosition(anchorProp, true)

        Wait(100)
        RopeLoadTextures()
        while not RopeAreTexturesLoaded() do Wait(0) end

        local rope = AddRope(anchorPos.x, anchorPos.y, anchorPos.z, 0.0, 0.0, 0.0, GAS.hoseMaxDistance or 8.0, 4, 3.0, 0.5, 1.0, false, false, false, 1.0, true)
        local nozzlePos = GetOffsetFromEntityInWorldCoords(nozzle, 0.0, -0.033, -0.195)
        AttachEntitiesToRope(rope, anchorProp, nozzle, anchorPos.x, anchorPos.y, anchorPos.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, 0.0, false, false, nil, nil)
        StartRopeUnwindingFront(rope)
        StopRopeWinding(rope)
        ActivatePhysics(rope)

        heldHose = {
            trailer = trailer,
            trailerNet = trailerNet,
            station = station,
            nozzle = nozzle,
            anchorProp = anchorProp,
            rope = rope,
            origin = GetEntityCoords(ped), -- ponto inicial (onde pegou, junto ao trailer)
        }
        explosionWatcher()
        startFuelPromptThread()
    end)
end

-- Hose targets live on the trailer MODEL so every player can use the trailer
-- they are physically at (gated by the trailer's own state).
CreateThread(function()
    exports.ox_target:addModel(GAS.trailerModel, {
        {
            name = 'nv_delivery:grab_hose',
            label = 'Puxar Mangueira',
            icon = 'fa-solid fa-hand',
            distance = 1.2,
            canInteract = function(entity)
                if heldHose or cache.vehicle then return false end
                local st = Entity(entity).state
                if not st.eventStation then return false end
                if st.hoseHolder then return false end
                return true
            end,
            onSelect = function(data) grabHose(data.entity) end
        },
        {
            name = 'nv_delivery:return_hose',
            label = 'Devolver Mangueira',
            icon = 'fa-solid fa-box-archive',
            distance = 1.2,
            canInteract = function(entity)
                return heldHose ~= nil and heldHose.trailer == entity and not isFueling
            end,
            onSelect = function() dropHose() end
        }
    })
end)

-- Refuel point target (test mode): target at the fuel point
CreateThread(function()
    local test = GAS.test
    if not (test and test.enabled and test.fuelPoint) then return end

    exports.ox_target:addSphereZone({
        coords = test.fuelPoint,
        radius = 1.2,
        options = {
            {
                name = 'nv_delivery:fuel_point',
                label = 'Abastecer Posto',
                icon = 'fa-solid fa-gas-pump',
                distance = 1.5,
                canInteract = function()
                    return heldHose ~= nil and not isFueling and not tripDoneFor(heldHose.trailer)
                end,
                onSelect = function()
                    dischargeAtPump(getClosestPump(test.fuelPoint))
                end
            }
        }
    })
end)

-- Persistent refuel marker (test mode): visible while driving to the station
-- (stage 'station') and while holding the hose, so it can be seen from the truck.
CreateThread(function()
    local test = GAS.test
    if not (test and test.enabled and test.fuelPoint) then return end
    local p = test.fuelPoint

    while true do
        local show = (heldHose ~= nil and not tripDoneFor(heldHose.trailer)) or (job.active and job.stage == 'station')
        if show then
            DrawMarker(1, p.x, p.y, p.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.0, 255, 200, 0, 120, false, true, 2, false, nil, nil, false)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ============================================================================
-- RETURN SEQUENCE (press E at the yard) — job owner only
-- ============================================================================
local function finishReturn()
    clearRoute()
    local ped = cache.ped

    -- Whether the truck still has the trailer decides full vs 30% payment
    local hasTrailer = IsVehicleAttachedToTrailer(job.truck)

    TaskLeaveVehicle(ped, job.truck, 0)
    Wait(1500)

    local tc = 0
    while not NetworkHasControlOfEntity(job.truck) and tc < 20 do
        NetworkRequestControlOfEntity(job.truck)
        Wait(50)
        tc = tc + 1
    end

    lib.requestModel(GAS.returnNpcModel)
    local s = GAS.returnNpcSpawn
    local driver = CreatePed(4, GAS.returnNpcModel, s.x, s.y, s.z, s.w, false, true)
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetEntityInvincible(driver, true)

    TaskEnterVehicle(driver, job.truck, 10000, -1, 2.0, 1, 0)
    local t = 0
    while not IsPedInVehicle(driver, job.truck, false) and t < 60 do Wait(100); t = t + 1 end
    if not IsPedInVehicle(driver, job.truck, false) then
        SetPedIntoVehicle(driver, job.truck, -1)
    end

    TaskVehicleDriveWander(driver, job.truck, 15.0, 786603)
    Wait(5000)

    if DoesEntityExist(driver) then DeleteEntity(driver) end
    TriggerServerEvent('nv_delivery:truckReturned', hasTrailer)
    job.truck, job.trailer = 0, 0

    job.stage = 'payment'
    setRoute(GAS.npcCoords, 'Receber Pagamento', GAS.blips.payment, 2)
end

local function startReturnWatcher()
    CreateThread(function()
        while job.active and job.stage == 'return' do
            local sleep = 500
            if job.truck ~= 0 and cache.vehicle == job.truck then
                local dist = #(GetEntityCoords(cache.ped) - GAS.returnPoint)
                if dist < 8.0 then
                    sleep = 0
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Pressione ~INPUT_PICKUP~ para entregar o caminhão')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustPressed(0, 38) then -- E
                        job.stage = 'finishing'
                        finishReturn()
                        break
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

-- Fired by the server when the trip's liters are fully delivered (by anyone)
RegisterNetEvent('nv_delivery:tripComplete', function()
    if not job.active then return end
    job.stage = 'return'
    setRoute(GAS.returnPoint, 'Devolver Caminhão', GAS.blips.ret, 5)
    startReturnWatcher()
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================
local function cleanupJob()
    clearRoute()
    if heldHose and heldHose.trailerNet == job.trailerNet then
        dropHose(true)
    end
    job.active = false
    job.stage = nil
    job.truck, job.trailer = 0, 0
    job.truckNet, job.trailerNet = nil, nil
    job.stationId = nil
    job.tripLiters = nil
end

-- ============================================================================
-- STAGE MACHINE (GPS routing) — job owner only
-- ============================================================================
local function startStageThread()
    CreateThread(function()
        while job.active do
            Wait(300)

            if job.truck == 0 and job.truckNet then job.truck = NetToVeh(job.truckNet) end
            if job.trailer == 0 and job.trailerNet then job.trailer = NetToVeh(job.trailerNet) end

            local stage = job.stage
            if stage == 'truck' then
                if job.truck ~= 0 and cache.vehicle == job.truck then
                    job.stage = 'trailer'
                    setRoute(GAS.trailerSpawn, 'Pegue o Trailer de Combustível', GAS.blips.trailer, 5)
                end
            elseif stage == 'trailer' then
                if job.truck ~= 0 and IsVehicleAttachedToTrailer(job.truck) then
                    job.stage = 'station'
                    local sc = stationCoords(job.stationId)
                    if sc then setRoute(sc, 'Entregar Combustível no Posto', GAS.blips.station, 1) end
                end
            end
        end
    end)
end

-- ============================================================================
-- JOB CONTROL (start / cancel / payment)
-- ============================================================================
local function startJob()
    if job.active then return end

    lib.callback('nv_delivery:startGasJob', false, function(result, data)
        if result == 'occupied' then
            return lib.notify({ type = 'error', description = "O pátio está ocupado. Libere os pontos de spawn do caminhão e do trailer." })
        elseif result == 'cooldown' then
            return lib.notify({ type = 'error', description = ("Aguarde, estou preparando outro caminhão (%ds)."):format(data or 0) })
        elseif result ~= true then
            return
        end

        job.active = true
        job.stage = 'truck'
        job.truckNet = data.truckNet
        job.trailerNet = data.trailerNet
        job.stationId = data.stationId
        job.tripLiters = data.liters
        job.truck = NetToVeh(data.truckNet)
        job.trailer = NetToVeh(data.trailerNet)

        setRoute(GAS.truckSpawn, 'Pegue o Caminhão', GAS.blips.truck, 5)
        startStageThread()
        lib.notify({ type = 'success', description = ("Serviço iniciado! Pegue o caminhão marcado no GPS (entregar %d L)."):format(data.liters or 0) })
    end)
end

local function cancelJob()
    if not job.active then return end
    TriggerServerEvent('nv_delivery:cancelGasJob')
    cleanupJob()
end

local function collectPayment()
    if job.stage ~= 'payment' then return end
    TriggerServerEvent('nv_delivery:collectPayment')
    cleanupJob()
end

-- ============================================================================
-- LOGISTICS MANAGER NPC
-- ============================================================================
CreateThread(function()
    local c = GAS.npcCoords
    lib.requestModel(GAS.npcModel)
    npcPed = CreatePed(4, GAS.npcModel, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityInvincible(npcPed, true)
    FreezeEntityPosition(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)

    RequestAnimDict("amb@world_human_clipboard@male@idle_a")
    while not HasAnimDictLoaded("amb@world_human_clipboard@male@idle_a") do Wait(10) end
    TaskPlayAnim(npcPed, "amb@world_human_clipboard@male@idle_a", "idle_c", 8.0, -8.0, -1, 1, 0, false, false, false)

    exports.ox_target:addLocalEntity(npcPed, {
        {
            name = 'nv_delivery:start_job',
            label = 'Iniciar Entrega de Combustível',
            icon = 'fa-solid fa-clipboard-list',
            distance = 2.0,
            canInteract = function()
                return not job.active and job.stage ~= 'payment'
            end,
            onSelect = function() startJob() end
        },
        {
            name = 'nv_delivery:cancel_job',
            label = 'Cancelar Trabalho',
            icon = 'fa-solid fa-ban',
            distance = 2.0,
            canInteract = function()
                return job.active and job.stage ~= 'payment'
            end,
            onSelect = function() cancelJob() end
        },
        {
            name = 'nv_delivery:collect_payment',
            label = 'Receber Pagamento',
            icon = 'fa-solid fa-hand-holding-dollar',
            distance = 2.0,
            canInteract = function()
                return job.stage == 'payment'
            end,
            onSelect = function() collectPayment() end
        }
    })
end)

-- ============================================================================
-- CLEANUP ON RESOURCE STOP
-- ============================================================================
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    dropHose(true)
    clearRoute()
    stopEventBlips()
    if npcPed and DoesEntityExist(npcPed) then DeleteEntity(npcPed) end
end)
