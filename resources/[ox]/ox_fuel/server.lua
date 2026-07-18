local config = require 'config'

if not config then return end

if config.versionCheck then lib.versionCheck('overextended/ox_fuel') end

local ox_inventory = exports.ox_inventory

-- Debug do fluxo de pagamento do abastecimento (defina como false para desativar)
local DEBUG_FUEL = true
local MAX_STATION_FUEL = 200 -- deve bater com Config.GasStations.maxFuelCapacity do nv_delivery

---@param vehicle number
---@param fuel number
---@param reduceOnly? boolean Don't allow fuel to be increased, unless fuel state has not been initialised.
local function setFuelState(vehicle, fuel, reduceOnly)
	if vehicle == 0 or GetEntityType(vehicle) ~= 2 then
		return
	end

	local state = Entity(vehicle).state
	fuel = math.clamp(fuel, 0, reduceOnly and state.fuel or 100)

	state:set('fuel', fuel, true)
end

---@param playerId number
---@param price number
---@return boolean?
local function defaultPaymentMethod(playerId, price)
	local success = ox_inventory:RemoveItem(playerId, 'money', price)

	if success then return true end

	local money = ox_inventory:GetItemCount(playerId, 'money')

	TriggerClientEvent('ox_lib:notify', playerId, {
		type = 'error',
		description = 'Você não tem dinheiro suficiente em mãos!'
	})
end

local payMoney = defaultPaymentMethod

exports('setPaymentMethod', function(fn)
	payMoney = fn or defaultPaymentMethod
end)

RegisterNetEvent('ox_fuel:pay', function(price, fuel, netid, stationId, litersFilled)
	assert(type(price) == 'number', ('Price expected a number, received %s'):format(type(price)))
	local source = source
	if not payMoney(source, price) then return end

	fuel = math.floor(fuel)
	setFuelState(NetworkGetEntityFromNetworkId(netid), fuel)

	-- Save to gas station database if nv_delivery is running
	if stationId and GetResourceState('nv_delivery') == 'started' then
		exports.nv_delivery:addStationCash(stationId, price)
		if litersFilled and litersFilled > 0 then
			exports.nv_delivery:deductStationFuel(stationId, litersFilled)
		end

		if DEBUG_FUEL then
			local stations = GlobalState.gasStations
			local st = stations and stations[stationId]
			if st then
				local totalAll = 0
				for _, s in pairs(stations) do totalAll = totalAll + (s.cash or 0) end
				local pct = (st.fuel / MAX_STATION_FUEL) * 100

				print('^3=============== [ox_fuel] DEBUG PAGAMENTO ===============^0')
				print(('^3Jogador: %s (id %s)^0'):format(GetPlayerName(source), source))
				print(('^2Posto: %s (id %s)^0'):format(st.name, stationId))
				print(('^2Pagamento indo para o banco (posto): $%s^0'):format(price))
				print(('^2Total abastecido nesta transação: %.2f L^0'):format(litersFilled or 0))
				print(('^2Caixa TOTAL do posto: $%s^0'):format(st.cash))
				print(('^2Caixa TOTAL de todos os postos: $%s^0'):format(totalAll))
				print(('^2Combustível no posto: %.1f / %d L (%.1f%%)^0'):format(st.fuel, MAX_STATION_FUEL, pct))
				print('^3========================================================^0')
			end
		end
	end

	TriggerClientEvent('ox_lib:notify', source, {
		type = 'success',
		description = locale('fuel_success', fuel, price)
	})
end)

RegisterNetEvent('ox_fuel:fuelCan', function(hasCan, price, stationId)
	local source = source
	if hasCan then
		local item = ox_inventory:GetCurrentWeapon(source)

		if not item or item.name ~= 'WEAPON_PETROLCAN' or not payMoney(source, price) then return end

		item.metadata.durability = 100
		item.metadata.ammo = 100

		ox_inventory:SetMetadata(source, item.slot, item.metadata)

		if stationId and GetResourceState('nv_delivery') == 'started' then
			exports.nv_delivery:addStationCash(stationId, price)
		end

		TriggerClientEvent('ox_lib:notify', source, {
			type = 'success',
			description = locale('petrolcan_refill', price)
		})
	else
		-- Server stock validation check
		if stationId and GetResourceState('nv_delivery') == 'started' then
			local cans = exports.nv_delivery:getStationJerryCans(stationId)
			if cans <= 0 then
				return TriggerClientEvent('ox_lib:notify', source, {
					type = 'error',
					description = 'Não há galões de combustível em estoque!'
				})
			end
		end

		if not ox_inventory:CanCarryItem(source, 'WEAPON_PETROLCAN', 1) then
			return TriggerClientEvent('ox_lib:notify', source, {
				type = 'error',
				description = locale('petrolcan_cannot_carry')
			})
		end

		if not payMoney(source, price) then return end

		ox_inventory:AddItem(source, 'WEAPON_PETROLCAN', 1)

		if stationId and GetResourceState('nv_delivery') == 'started' then
			exports.nv_delivery:addStationCash(stationId, price)
			exports.nv_delivery:deductStationJerryCan(stationId)
		end

		TriggerClientEvent('ox_lib:notify', source, {
			type = 'success',
			description = locale('petrolcan_buy', price)
		})
	end
end)

RegisterNetEvent('ox_fuel:updateFuelCan', function(durability, netid, fuel)
	local source = source
	local item = ox_inventory:GetCurrentWeapon(source)

	if item and durability > 0 then
		durability = math.floor(item.metadata.durability - durability)
		item.metadata.durability = durability
		item.metadata.ammo = durability

		ox_inventory:SetMetadata(source, item.slot, item.metadata)
		setFuelState(NetworkGetEntityFromNetworkId(netid), fuel)
	end

	-- player is sus?
end)

RegisterNetEvent('ox_fuel:setFuel', function(fuel)
	local playerPed = GetPlayerPed(source)
	local handle = GetVehiclePedIsIn(playerPed, false)

	setFuelState(handle, fuel, true)
end)

-- Fine for walking too far with the hose and blowing up the pump ($500 from the bank)
RegisterNetEvent('ox_fuel:hosePenalty', function()
	local source = source
	local amount = 500

	-- Debita do banco do jogador (fallback para dinheiro em mãos)
	local ok = pcall(function()
		return exports['money']:removeMoney(source, 'bank', amount)
	end)
	if not ok then
		ox_inventory:RemoveItem(source, 'money', amount)
	end

	TriggerClientEvent('ox_lib:notify', source, {
		type = 'error',
		description = ('A bomba explodiu! Multa de $%d debitada do banco.'):format(amount)
	})
end)