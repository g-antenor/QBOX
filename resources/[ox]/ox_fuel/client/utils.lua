local config = require 'config'

local utils = {}

---@param coords vector3
---@return integer
function utils.createBlip(coords)
	local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
	SetBlipSprite(blip, 361)
	SetBlipDisplay(blip, 4)
	SetBlipScale(blip, 0.8)
	SetBlipColour(blip, 6)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName('ox_fuel_station')
	EndTextCommandSetBlipName(blip)

	return blip
end

function utils.getVehicleInFront()
	local coords = GetEntityCoords(cache.ped)
	local destination = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.2, -0.25)
	local handle = StartShapeTestCapsule(coords.x, coords.y, coords.z, destination.x, destination.y, destination.z, 2.2,
		2, cache.ped, 4)

	while true do
		Wait(0)
		local retval, _, _, _, entityHit = GetShapeTestResult(handle)

		if retval ~= 1 then
			return entityHit ~= 0 and entityHit
		end
	end
end

local bones = {
	'petrolcap',
	'petroltank',
	'petroltank_l',
	'hub_lr',
	'engine',
}

---@param vehicle integer
function utils.getVehiclePetrolCapBoneIndex(vehicle)
	for i = 1, #bones do
		local boneIndex = GetEntityBoneIndexByName(vehicle, bones[i])

		if boneIndex ~= -1 then
			return boneIndex
		end
	end
end

---@return number
local function defaultMoneyCheck()
	return exports.ox_inventory:GetItemCount('money')
end

utils.getMoney = defaultMoneyCheck

-- utils.draw3DText foi removido: todo texto de status do ox_fuel passou a usar
-- o TextUI do ox_lib (client/fuel.lua e client/target.lua).

---Dinheiro em maos suficiente para pelo menos um tick de abastecimento?
---Memoizado por 500ms porque o canInteract do ox_target roda com frequencia
---alta enquanto o jogador aponta para o veiculo.
---@return boolean
do
	local checkedAt, cached = 0, false

	function utils.hasFuelMoney()
		local now = GetGameTimer()

		if now - checkedAt > 500 then
			checkedAt = now
			cached = (utils.getMoney() or 0) >= (config.priceTick or 0)
		end

		return cached
	end
end

exports('setMoneyCheck', function(fn)
	utils.getMoney = fn or defaultMoneyCheck
end)

return utils
