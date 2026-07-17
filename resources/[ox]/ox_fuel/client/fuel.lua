local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local fuel = {}

-- Active ropes rendered for other players nearby
local activeRopes = {}

-- ==========================================================================
-- VEHICLE HELPERS
-- ==========================================================================

local function getClosestVehicle(coords)
	local vehicles = GetGamePool('CVehicle')
	local closestVehicle = nil
	local minDistance = 15.0 -- 15m search radius

	for i = 1, #vehicles do
		local vehicle = vehicles[i]
		if DoesEntityExist(vehicle) then
			local dist = #(coords - GetEntityCoords(vehicle))
			if dist < minDistance then
				minDistance = dist
				closestVehicle = vehicle
			end
		end
	end

	return closestVehicle
end

---@param vehState StateBag
---@param vehicle integer
---@param amount number
---@param replicate? boolean
function fuel.setFuel(vehState, vehicle, amount, replicate)
	if DoesEntityExist(vehicle) then
		amount = math.clamp(amount, 0, 100)

		SetVehicleFuelLevel(vehicle, amount)
		vehState.fuel = amount

		if replicate and NetworkGetEntityIsNetworked(vehicle) then TriggerServerEvent('ox_fuel:setFuel', amount) end
	end
end

function fuel.getPetrolCan(coords, refuel)
	TaskTurnPedToFaceCoord(cache.ped, coords.x, coords.y, coords.z, config.petrolCan.duration)
	Wait(500)

	if lib.progressCircle({
			duration = config.petrolCan.duration,
			useWhileDead = false,
			canCancel = true,
			disable = {
				move = true,
				car = true,
				combat = true,
			},
			anim = {
				dict = 'timetable@gardener@filling_can',
				clip = 'gar_ig_5_filling_can',
				flags = 49,
			}
		}) then
		if refuel and exports.ox_inventory:GetItemCount('WEAPON_PETROLCAN') then
			return TriggerServerEvent('ox_fuel:fuelCan', true, config.petrolCan.refillPrice)
		end

		TriggerServerEvent('ox_fuel:fuelCan', false, config.petrolCan.price)
	end

	ClearPedTasks(cache.ped)
end

-- ==========================================================================
-- HOSE HOLDING & SILENT COUNTDOWN SYSTEM (WITH PHYSICAL ROPE HOSE)
-- ==========================================================================

function fuel.pickupHose(pumpCoords, pumpEntity)
	if state.holdingHose then return end
	state.holdingHose = true
	state.pumpCoords = pumpCoords
	state.pumpEntity = pumpEntity

	-- Spawn and attach nozzle prop to right hand (SKEL_R_Hand - 57005)
	lib.requestModel('prop_cs_fuel_nozle')
	local ped = cache.ped
	local nozle = CreateObject(`prop_cs_fuel_nozle`, 0.0, 0.0, 0.0, true, true, false)
	SetEntityCollision(nozle, false, false)
	AttachEntityToEntity(nozle, ped, GetPedBoneIndex(ped, 18905), 0.1, 0.02, 0.02, 90.0, 40.0, 170.0, true, true, false, true, 1, true)
	state.nozleEntity = nozle

	-- Replicate state to all players via State Bags
	local pumpNetId = NetworkGetEntityIsNetworked(pumpEntity) and NetworkGetNetworkIdFromEntity(pumpEntity) or nil
	local nozzleNetId = ObjToNet(nozle)
	SetNetworkIdCanMigrate(nozzleNetId, false)
	LocalPlayer.state:set('fuelHose', {
		pumpNetId = pumpNetId,
		nozzleNetId = nozzleNetId,
		pumpCoords = pumpCoords
	}, true)

	-- Wait 100ms for object to register in physics engine before attaching rope
	Wait(100)

	-- Spawn physical rope hose locally for local player
	RopeLoadTextures()
	while not RopeAreTexturesLoaded() do
		Wait(0)
	end
	local rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z + 1.5, 0.0, 0.0, 0.0, 10.0, 4, 3.0, 0.5, 1.0, false, false, false, 1.0, false)
	
	if pumpEntity and DoesEntityExist(pumpEntity) then
		AttachEntitiesToRope(rope, nozle, pumpEntity, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 3.0, false, false, 0, 0)
	else
		AttachRopeToEntity(rope, nozle, 0.0, 0.0, 0.0, false)
	end

	StartRopeUnwindingFront(rope)
	StopRopeWinding(rope)
	ActivatePhysics(rope)
	state.ropeId = rope

	lib.notify({ type = 'success', description = "Você pegou a mangueira da bomba!" })

	-- Hose stretch checks (Silent countdown, leaks gas in last 3 seconds)
	CreateThread(function()
		local countdown = 10
		local leaking = false
		while state.holdingHose do
			Wait(1000)
			if not state.holdingHose then break end

			if not state.isFueling then
				local pedCoords = GetEntityCoords(cache.ped)
				local dist = #(pedCoords - state.pumpCoords)

				if dist > 5.0 then
					countdown = countdown - 1

					-- Start leaking gas in the last 3 seconds
					if countdown <= 3 then
						if not leaking then
							leaking = true
							local vehicle = getClosestVehicle(pedCoords) or state.lastVehicle
							if vehicle and DoesEntityExist(vehicle) then
								SetVehicleCanLeakPetrol(vehicle, true)
								SetVehiclePetrolTankHealth(vehicle, 500.0)
								state.leakingVehicle = vehicle
							end
						end
					end

					if countdown <= 0 then
						-- Trigger explosion at fuel leaking vehicle and player
						local vehicle = state.leakingVehicle or getClosestVehicle(pedCoords) or state.lastVehicle
						if vehicle and DoesEntityExist(vehicle) then
							local vehCoords = GetEntityCoords(vehicle)
							AddExplosion(vehCoords.x, vehCoords.y, vehCoords.z, 2, 5.0, true, false, 1.0)
						end
						AddExplosion(pedCoords.x, pedCoords.y, pedCoords.z, 2, 5.0, true, false, 1.0)

						fuel.dropHose()
						break
					end
				else
					if countdown < 10 then
						countdown = 10
						if leaking then
							leaking = false
							local vehicle = state.leakingVehicle or getClosestVehicle(pedCoords) or state.lastVehicle
							if vehicle and DoesEntityExist(vehicle) then
								SetVehicleCanLeakPetrol(vehicle, false)
								SetVehiclePetrolTankHealth(vehicle, 1000.0)
							end
							state.leakingVehicle = nil
						end
					end
				end
			end
		end
	end)
end

function fuel.dropHose()
	state.holdingHose = false
	
	-- Clear networked state bag
	LocalPlayer.state:set('fuelHose', nil, true)

	if state.nozleEntity and DoesEntityExist(state.nozleEntity) then
		DeleteEntity(state.nozleEntity)
		state.nozleEntity = nil
	end
	if state.ropeId then
		DeleteRope(state.ropeId)
		state.ropeId = nil
	end

	-- Insure leak stops on whatever was leaking
	local vehicle = state.leakingVehicle or state.lastVehicle or getClosestVehicle(GetEntityCoords(cache.ped))
	if vehicle and DoesEntityExist(vehicle) then
		SetVehicleCanLeakPetrol(vehicle, false)
		SetVehiclePetrolTankHealth(vehicle, 1000.0)
	end
	state.leakingVehicle = nil

	state.pumpCoords = nil
	state.pumpEntity = nil
	lib.notify({ type = 'info', description = "Mangueira guardada com sucesso." })
end

-- ==========================================================================
-- VEHICLE REFUEL WITH HOSE (LEFT REAR SIDE)
-- ==========================================================================

function fuel.startFuelingVehicle(vehicle)
	local vehState = Entity(vehicle).state
	local fuelAmount = vehState.fuel or GetVehicleFuelLevel(vehicle)
	local maxFuelLiters = 65.0
	local currentLiters = (fuelAmount / 100.0) * maxFuelLiters
	local moneyAmount = utils.getMoney()

	if fuelAmount >= 99.9 then
		return lib.notify({ type = 'error', description = "O veículo já está completamente cheio!" })
	end

	if moneyAmount < config.priceTick then
		return lib.notify({ type = 'error', description = "Você não tem dinheiro em mãos!" })
	end

	-- Enforce single point: left rear side (between rear door and trunk)
	local capCoords = GetOffsetFromEntityInWorldCoords(vehicle, -0.9, -1.3, -0.1)

	local pedCoords = GetEntityCoords(cache.ped)
	local distToCap = #(pedCoords - capCoords)
	if distToCap > 1.8 then
		return lib.notify({
			type = 'error',
			description = "Você deve se posicionar do lado correto da tampa de combustível (atrás da porta traseira esquerda)!"
		})
	end

	state.isFueling = true
	local price = 0

	-- Play Refueling Animation Loop
	lib.requestAnimDict('timetable@gardener@filling_can')
	TaskPlayAnim(cache.ped, 'timetable@gardener@filling_can', 'gar_ig_5_filling_can', 8.0, -8.0, -1, 49, 0.0, false, false, false)

	-- 3D Text above gas pump thread & Key monitoring (No screen Text UI modal)
	CreateThread(function()
		while state.isFueling do
			Wait(0)
			if not state.isFueling then break end

			if state.pumpEntity and DoesEntityExist(state.pumpEntity) then
				local pumpCoords = GetEntityCoords(state.pumpEntity)
				local text = string.format(
					"~g~BOMBA DE COMBUSTÍVEL~w~\n" ..
					"Abastecendo...\n" ..
					"Litros: ~y~%.1f / %.1f L~w~\n" ..
					"Total: ~g~$%d~w~\n" ..
					"~r~Pressione [X] para parar",
					(fuelAmount / 100.0) * maxFuelLiters,
					maxFuelLiters,
					price
				)
				utils.draw3DText(pumpCoords + vec3(0.0, 0.0, 1.2), text)
			end

			-- Cancel refuel strictly with the X key (control 73) checked every frame
			if IsControlJustPressed(0, 73) then
				state.isFueling = false
				break
			end
		end
	end)

	-- Refill tick logic loop
	CreateThread(function()
		while state.isFueling do
			Wait(config.refillTick)
			if not state.isFueling then break end

			moneyAmount = utils.getMoney()
			if moneyAmount < config.priceTick then
				lib.notify({ type = 'error', description = "Você não tem dinheiro em mãos!" })
				state.isFueling = false
				break
			end

			price = price + config.priceTick
			fuelAmount = fuelAmount + config.refillValue

			if fuelAmount >= 100.0 then
				fuelAmount = 100.0
				state.isFueling = false
				lib.notify({ type = 'success', description = "Abastecimento concluído!" })
				break
			end

			SetVehicleFuelLevel(vehicle, fuelAmount)
			vehState.fuel = fuelAmount

			-- Dist checking during fueling
			local currentCapCoords = GetOffsetFromEntityInWorldCoords(vehicle, -0.9, -1.3, -0.1)
			if #(GetEntityCoords(cache.ped) - currentCapCoords) > 2.2 then
				lib.notify({ type = 'error', description = "Você se afastou da tampa de combustível!" })
				state.isFueling = false
				break
			end
		end

		ClearPedTasks(cache.ped)
		state.isFueling = false

		if price > 0 then
			TriggerServerEvent('ox_fuel:pay', price, fuelAmount, NetworkGetNetworkIdFromEntity(vehicle))
		end
	end)
end

-- ==========================================================================
-- JERRYCAN/PETROLCAN REFUELING (ORIGINAL)
-- ==========================================================================

function fuel.startFueling(vehicle)
	local vehState = Entity(vehicle).state
	local fuelAmount = vehState.fuel or GetVehicleFuelLevel(vehicle)
	local duration = math.ceil((100 - fuelAmount) / config.refillValue) * config.refillTick
	local durability = 0

	if 100 - fuelAmount < config.refillValue then
		return lib.notify({ type = 'error', description = locale('tank_full') })
	end

	if not state.petrolCan then
		return lib.notify({ type = 'error', description = locale('petrolcan_not_equipped') })
	elseif state.petrolCan.metadata.ammo <= config.durabilityTick then
		return lib.notify({
			type = 'error',
			description = locale('petrolcan_not_enough_fuel')
		})
	end

	state.isFueling = true

	TaskTurnPedToFaceEntity(cache.ped, vehicle, duration)
	Wait(500)

	CreateThread(function()
		lib.progressCircle({
			duration = duration,
			useWhileDead = false,
			canCancel = true,
			disable = {
				move = true,
				car = true,
				combat = true,
			},
			anim = {
				dict = 'weapon@w_sp_jerrycan',
				clip = 'fire',
			}
		})

		state.isFueling = false
	end)

	while state.isFueling do
		Wait(config.refillTick)
		if not state.isFueling then break end

		if state.petrolCan then
			durability += config.durabilityTick

			if durability >= state.petrolCan.metadata.ammo then
				lib.cancelProgress()
				durability = state.petrolCan.metadata.ammo
				break
			end
		else
			break
		end

		fuelAmount += config.refillValue

		if fuelAmount >= 100 then
			state.isFueling = false
			fuelAmount = 100.0
		end
	end

	ClearPedTasks(cache.ped)

	TriggerServerEvent('ox_fuel:updateFuelCan', durability, NetworkGetNetworkIdFromEntity(vehicle), fuelAmount)
end

-- ==========================================================================
-- STATE BAG CHANGE HANDLER FOR MULTIPLAYER HOSE RENDER SYNC
-- ==========================================================================

AddStateBagChangeHandler('fuelHose', nil, function(bagName, key, value, reserved, replicated)
	local serverId = tonumber(bagName:gsub('player:', ''))
	if not serverId then return end

	-- Skip local player since we handle our own rope immediately
	if serverId == GetPlayerServerId(PlayerId()) then return end

	-- Clean up existing rope for this player if it exists
	if activeRopes[serverId] then
		if activeRopes[serverId].ropeId then
			DeleteRope(activeRopes[serverId].ropeId)
		end
		activeRopes[serverId] = nil
	end

	if value then
		CreateThread(function()
			-- Wait for player and networked entities to load on our client
			local player = GetPlayerFromServerId(serverId)
			local timeout = 0
			while (player == -1 or not NetworkIsPlayerActive(player)) and timeout < 100 do
				Wait(100)
				player = GetPlayerFromServerId(serverId)
				timeout = timeout + 1
			end

			if player == -1 or not NetworkIsPlayerActive(player) then return end
			local ped = GetPlayerPed(player)
			if not ped or ped == 0 or not DoesEntityExist(ped) then return end

			-- Resolve networked nozzle prop
			timeout = 0
			local nozle = 0
			while nozle == 0 and timeout < 50 do
				Wait(100)
				nozle = NetToObj(value.nozzleNetId)
				timeout = timeout + 1
			end

			if not nozle or nozle == 0 or not DoesEntityExist(nozle) then return end

			-- Resolve networked pump prop
			local pumpEntity = 0
			if value.pumpNetId then
				pumpEntity = NetToObj(value.pumpNetId)
			end

			-- Load rope textures
			RopeLoadTextures()
			while not RopeAreTexturesLoaded() do
				Wait(0)
			end

			-- Spawn local rope connecting them on our screen
			local rope = AddRope(value.pumpCoords.x, value.pumpCoords.y, value.pumpCoords.z + 1.5, 0.0, 0.0, 0.0, 10.0, 4, 3.0, 0.5, 1.0, false, false, false, 1.0, false)
			
			if pumpEntity and pumpEntity ~= 0 and DoesEntityExist(pumpEntity) then
				AttachEntitiesToRope(rope, nozle, pumpEntity, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 3.0, false, false, 0, 0)
			else
				AttachRopeToEntity(rope, nozle, 0.0, 0.0, 0.0, false)
			end

			StartRopeUnwindingFront(rope)
			StopRopeWinding(rope)
			ActivatePhysics(rope)

			activeRopes[serverId] = {
				ropeId = rope
			}
		end)
	end
end)

return fuel
