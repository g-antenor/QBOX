local config = require 'config'
local state  = require 'client.state'
local utils  = require 'client.utils'
local fuel   = require 'client.fuel'

-- Coordinate-to-ID mapping logic for gas stations
local sortedStations = {}
local function initStations()
	local stations = lib.load 'data.stations'
	for coords in pairs(stations) do
		table.insert(sortedStations, coords)
	end
	table.sort(sortedStations, function(a, b)
		if a.x ~= b.x then return a.x < b.x end
		if a.y ~= b.y then return a.y < b.y end
		return a.z < b.z
	end)
end
initStations()

local function GetStationIdFromCoords(coords)
	local closestId = nil
	local minDist = 99999.0
	for id, sCoords in ipairs(sortedStations) do
		local dist = #(coords - sCoords)
		if dist < minDist then
			minDist = dist
			closestId = id
		end
	end
	return closestId
end

-- Station fuel check: hide pump targets when the station is dry
local function pumpHasFuel(entity)
	local stationId = GetStationIdFromCoords(GetEntityCoords(entity))
	if stationId and GlobalState.gasStations and GlobalState.gasStations[stationId] then
		return GlobalState.gasStations[stationId].fuel > 0
	end
	return true
end

-- Pump Target Options
local pumpOptions = {
	{
		name = 'ox_fuel:pickup_hose',
		distance = 2.5,
		onSelect = function(data)
			fuel.pickupHose(data.coords, data.entity)
		end,
		icon = "fas fa-hand-holding",
		label = "Pegar Mangueira",
		canInteract = function(entity)
			return pumpHasFuel(entity) and not state.holdingHose and not state.isFueling and not cache.vehicle
		end
	},
	{
		name = 'ox_fuel:drop_hose',
		distance = 2.5,
		onSelect = function()
			fuel.dropHose()
		end,
		icon = "fas fa-box-archive",
		label = "Guardar Mangueira",
		canInteract = function(entity)
			return state.holdingHose and not state.isFueling and not cache.vehicle
		end
	}
}

-- Helper functions to check petrol can status in inventory
local function hasEmptyPetrolCan()
	local items = exports.ox_inventory:Search('slots', 'WEAPON_PETROLCAN')
	if not items then return false end
	for _, item in pairs(items) do
		local ammo = item.metadata and item.metadata.ammo or 0
		if ammo < 100 then
			return true
		end
	end
	return false
end

local function hasFullPetrolCanOrNone()
	local items = exports.ox_inventory:Search('slots', 'WEAPON_PETROLCAN')
	if not items or #items == 0 then return true end
	for _, item in pairs(items) do
		local ammo = item.metadata and item.metadata.ammo or 0
		if ammo >= 100 then
			return true
		end
	end
	return false
end

-- If petrol can is enabled, add buy/refill options
if config.petrolCan.enabled then
	table.insert(pumpOptions, {
		name = 'ox_fuel:petrolcan_pump_refill',
		distance = 2.0,
		onSelect = function(data)
			local equipped = GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
			if not equipped then
				return lib.notify({ type = 'error', description = "Você precisa equipar o galão de combustível vazio para reabastecê-lo!" })
			end

			local moneyAmount = utils.getMoney()
			if moneyAmount < config.petrolCan.refillPrice then
				return lib.notify({ type = 'error', description = "Você não tem dinheiro suficiente em mãos para reabastecer!" })
			end

			local stationId = GetStationIdFromCoords(data.coords)
			return fuel.getPetrolCan(data.coords, true, stationId)
		end,
		icon = "fas fa-gas-pump",
		label = "Abastecer Galão de Combustível",
		canInteract = function(entity)
			local coords = GetEntityCoords(entity)
			local stationId = GetStationIdFromCoords(coords)
			if stationId and GlobalState.gasStations and GlobalState.gasStations[stationId] then
				if GlobalState.gasStations[stationId].fuel <= 0 then
					return false
				end
			end
			return hasEmptyPetrolCan()
		end
	})

	table.insert(pumpOptions, {
		name = 'ox_fuel:petrolcan_pump_buy',
		distance = 2.0,
		onSelect = function(data)
			local moneyAmount = utils.getMoney()
			if moneyAmount < config.petrolCan.price then
				return lib.notify({ type = 'error', description = "Você não tem dinheiro suficiente em mãos para comprar!" })
			end

			local stationId = GetStationIdFromCoords(data.coords)
			return fuel.getPetrolCan(data.coords, false, stationId)
		end,
		icon = "fas fa-shopping-basket",
		label = "Comprar Galão de Combustível",
		canInteract = function(entity)
			if not pumpHasFuel(entity) then return false end
			local coords = GetEntityCoords(entity)
			local stationId = GetStationIdFromCoords(coords)
			if stationId and GlobalState.gasStations and GlobalState.gasStations[stationId] then
				if GlobalState.gasStations[stationId].jerry_cans <= 0 then
					return false
				end
			end
			return hasFullPetrolCanOrNone()
		end
	})
end

exports.ox_target:addModel(config.pumpModels, pumpOptions)

-- Vehicle Target Options (Refuel with Hose & Refuel with Petrol Can)
local vehicleOptions = {
	{
		name = 'ox_fuel:refuel_vehicle_hose',
		bones = { 'petrolcap', 'petroltank', 'petroltank_l', 'wheel_lr' },
		distance = 1.2,
		onSelect = function(data)
			fuel.startFuelingVehicle(data.entity)
		end,
		icon = "fas fa-gas-pump",
		label = "Abastecer Veículo (Mangueira)",
		canInteract = function(entity)
			return state.holdingHose and not state.isFueling and not cache.vehicle and DoesVehicleUseFuel(entity)
		end
	}
}

if config.petrolCan.enabled then
	table.insert(vehicleOptions, {
		name = 'ox_fuel:refuel_vehicle_can',
		bones = { 'petrolcap', 'petroltank', 'petroltank_l', 'wheel_lr' },
		distance = 1.2,
		onSelect = function(data)
			if not state.petrolCan then
				return lib.notify({ type = 'error', description = "Você precisa equipar o galão de combustível!" })
			end

			if state.petrolCan.metadata.ammo <= config.durabilityTick then
				return lib.notify({
					type = 'error',
					description = "O galão está sem combustível!"
				})
			end

			fuel.startFueling(data.entity)
		end,
		icon = "fas fa-gas-pump",
		label = "Abastecer Veículo (Galão)",
		canInteract = function(entity)
			if state.isFueling or cache.vehicle or lib.progressActive() or not DoesVehicleUseFuel(entity) then
				return false
			end
			return state.petrolCan and config.petrolCan.enabled
		end
	})
end

exports.ox_target:addGlobalVehicle(vehicleOptions)

-- Draw "sem combustível" over a station that is empty; removed once fuel > 0
CreateThread(function()
	while true do
		local sleep = 1000
		local pedCoords = GetEntityCoords(cache.ped)
		local id = GetStationIdFromCoords(pedCoords)

		if id then
			local sCoords = sortedStations[id]
			if sCoords and #(pedCoords - sCoords) < 25.0 then
				local sd = GlobalState.gasStations and GlobalState.gasStations[id]
				if sd and sd.fuel <= 0 then
					sleep = 0
					utils.draw3DText(sCoords + vec3(0.0, 0.0, 1.0), "POSTO SEM COMBUSTIVEL")
				end
			end
		end

		Wait(sleep)
	end
end)
