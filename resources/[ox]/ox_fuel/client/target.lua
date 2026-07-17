local config = require 'config'
local state  = require 'client.state'
local utils  = require 'client.utils'
local fuel   = require 'client.fuel'

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
			return not state.holdingHose and not state.isFueling and not cache.vehicle
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

-- If petrol can is enabled, add buy/refill options
if config.petrolCan.enabled then
	table.insert(pumpOptions, {
		name = 'ox_fuel:petrolcan_pump',
		distance = 2.0,
		onSelect = function(data)
			local petrolCan = config.petrolCan.enabled and GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
			local moneyAmount = utils.getMoney()

			if moneyAmount < config.petrolCan.price then
				return lib.notify({ type = 'error', description = "Você não tem dinheiro em mãos!" })
			end

			return fuel.getPetrolCan(data.coords, petrolCan)
		end,
		icon = "fas fa-faucet",
		label = "Comprar / Abastecer Galão de Combustível",
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
