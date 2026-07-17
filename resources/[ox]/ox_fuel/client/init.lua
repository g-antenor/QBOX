local config = require 'config'

if not config then return end

SetFuelConsumptionState(true)
SetFuelConsumptionRateMultiplier(config.globalFuelConsumptionRate)

AddTextEntry('fuelHelpText', locale('fuel_help'))
AddTextEntry('petrolcanHelpText', locale('petrolcan_help'))
AddTextEntry('fuelLeaveVehicleText', locale('leave_vehicle'))
AddTextEntry('ox_fuel_station', locale('fuel_station_blip'))

local utils = require 'client.utils'
local state = require 'client.state'
local fuel  = require 'client.fuel'

require 'client.stations'

local function startDrivingVehicle()
	local vehicle = cache.vehicle

	if not DoesVehicleUseFuel(vehicle) then return end

	local vehState = Entity(vehicle).state

	if not vehState.fuel then
		TriggerServerEvent('ox_fuel:setFuel', GetVehicleFuelLevel(vehicle))
		while not vehState.fuel do Wait(0) end
	end

	SetVehicleFuelLevel(vehicle, vehState.fuel)

	local fuelTick = 0

	while cache.seat == -1 do
		if GetIsVehicleEngineRunning(vehicle) then
			if not DoesEntityExist(vehicle) then return end
			SetFuelConsumptionRateMultiplier(config.globalFuelConsumptionRate)

			local fuelAmount = tonumber(vehState.fuel)
			local newFuel = GetVehicleFuelLevel(vehicle)
			if fuelAmount > 0 then
				if GetVehiclePetrolTankHealth(vehicle) < 700 then
					newFuel -= math.random(10, 20) * 0.01
				end

				if fuelAmount ~= newFuel then
					if fuelTick == 15 then
						fuelTick = 0
					end

					fuel.setFuel(vehState, vehicle, newFuel, fuelTick == 0)
					fuelTick += 1
				end
			end
		else
			if not DoesEntityExist(vehicle) then return end
			SetFuelConsumptionRateMultiplier(0.0)
		end
		Wait(1000)
	end

	fuel.setFuel(vehState, vehicle, vehState.fuel, true)
end

if cache.seat == -1 then CreateThread(startDrivingVehicle) end

lib.onCache('seat', function(seat)
	if cache.vehicle then
		state.lastVehicle = cache.vehicle
	end

	if seat == -1 then
		SetTimeout(0, startDrivingVehicle)
	end
end)

return require 'client.target'
