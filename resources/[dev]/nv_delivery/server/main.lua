local serverStations = {}

-- Helper to update all clients via GlobalState
local function syncStations()
    GlobalState.gasStations = serverStations
end

-- ============================================================================
-- DATABASE INITIALIZATION AND SEEDING
-- ============================================================================
CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(100)
    end

    -- Create gas_stations table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `gas_stations` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(50) NOT NULL,
            `fuel` INT NOT NULL DEFAULT 200,
            `cash` INT NOT NULL DEFAULT 0,
            `jerry_cans` INT NOT NULL DEFAULT 5
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Create shops_247 table
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `shops_247` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(50) NOT NULL,
            `cash` INT NOT NULL DEFAULT 5000
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Seed gas stations if empty
    local count = MySQL.scalar.await("SELECT COUNT(*) FROM `gas_stations`")
    if count == 0 then
        local stations = lib.load '@ox_fuel.data.stations'
        local sortedStations = {}
        for coords in pairs(stations) do
            table.insert(sortedStations, coords)
        end
        table.sort(sortedStations, function(a, b)
            if a.x ~= b.x then return a.x < b.x end
            if a.y ~= b.y then return a.y < b.y end
            return a.z < b.z
        end)

        for id, coords in ipairs(sortedStations) do
            MySQL.query.await("INSERT INTO `gas_stations` (id, name, fuel, cash, jerry_cans) VALUES (?, ?, ?, ?, ?)", {
                id, "Posto LS/BC/PB " .. id, 200, 0, 5
            })
        end
        print("^2[nv_delivery] Seeded " .. #sortedStations .. " gas stations in the database.^0")
    end

    -- Seed shops_247 if empty
    local shopCount = MySQL.scalar.await("SELECT COUNT(*) FROM `shops_247`")
    if shopCount == 0 then
        for i, shop in ipairs(Config.Shops247.locations) do
            MySQL.query.await("INSERT INTO `shops_247` (id, name, cash) VALUES (?, ?, ?)", {
                i, shop.label, 5000
            })
        end
        print("^2[nv_delivery] Seeded " .. #Config.Shops247.locations .. " 24/7 shops in the database.^0")
    end

    -- Load gas stations into memory and sync
    local results = MySQL.query.await("SELECT * FROM `gas_stations`")
    if results then
        for _, row in ipairs(results) do
            serverStations[row.id] = {
                id = row.id,
                name = row.name,
                fuel = row.fuel,
                cash = row.cash,
                jerry_cans = row.jerry_cans
            }
        end
        syncStations()
    end
end)

-- ============================================================================
-- PUBLIC EXPORTS FOR STATIONS AND SHOPS
-- ============================================================================
local function addStationCash(stationId, amount)
    if not serverStations[stationId] then return end
    serverStations[stationId].cash = serverStations[stationId].cash + amount
    syncStations()
    MySQL.update("UPDATE `gas_stations` SET `cash` = ? WHERE `id` = ?", { serverStations[stationId].cash, stationId })
end
exports('addStationCash', addStationCash)

local function deductStationFuel(stationId, liters)
    if not serverStations[stationId] then return end
    serverStations[stationId].fuel = math.max(0, serverStations[stationId].fuel - liters)
    syncStations()
    MySQL.update("UPDATE `gas_stations` SET `fuel` = ? WHERE `id` = ?", { serverStations[stationId].fuel, stationId })
end
exports('deductStationFuel', deductStationFuel)

local function deductStationJerryCan(stationId)
    if not serverStations[stationId] then return end
    serverStations[stationId].jerry_cans = math.max(0, serverStations[stationId].jerry_cans - 1)
    syncStations()
    MySQL.update("UPDATE `gas_stations` SET `jerry_cans` = ? WHERE `id` = ?", { serverStations[stationId].jerry_cans, stationId })
end
exports('deductStationJerryCan', deductStationJerryCan)

local function getStationFuel(stationId)
    if not serverStations[stationId] then return 0 end
    return serverStations[stationId].fuel
end
exports('getStationFuel', getStationFuel)

local function getStationJerryCans(stationId)
    if not serverStations[stationId] then return 0 end
    return serverStations[stationId].jerry_cans
end
exports('getStationJerryCans', getStationJerryCans)

local function addShopCash(shopId, amount)
    MySQL.update("UPDATE `shops_247` SET `cash` = `cash` + ? WHERE `id` = ?", { amount, shopId })
end
exports('addShopCash', addShopCash)

local function deductShopCash(shopId, amount)
    MySQL.update("UPDATE `shops_247` SET `cash` = `cash` - ? WHERE `id` = ?", { amount, shopId })
end
exports('deductShopCash', deductShopCash)

-- Helper to check fuel levels for delivery logic
function GetServerStations()
    return serverStations
end
