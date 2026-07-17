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

			return fuel.getPetrolCan(data.coords, true)
		end,
		icon = "fas fa-gas-pump",
		label = "Abastecer Galão de Combustível",
		canInteract = function(entity)
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

			return fuel.getPetrolCan(data.coords, false)
		end,
		icon = "fas fa-shopping-basket",
		label = "Comprar Galão de Combustível",
		canInteract = function(entity)
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
