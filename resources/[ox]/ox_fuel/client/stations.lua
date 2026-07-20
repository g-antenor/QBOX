local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local stations = lib.load 'data.stations'

if config.showBlips == 2 then
	for station in pairs(stations) do utils.createBlip(station) end
end

if config.ox_target and config.showBlips ~= 1 then return end

---@param point CPoint
local function onEnterStation(point)
	if config.showBlips == 1 and not point.blip then
		point.blip = utils.createBlip(point.coords)
	end
end

---@param point CPoint
local function nearbyStation(point)
	if point.currentDistance > 15 then return end

	local pumps = point.pumps
	local pumpDistance

	for i = 1, #pumps do
		local pump = pumps[i]
		pumpDistance = #(cache.coords - pump)

		if pumpDistance <= 3 then
			state.nearestPump = pump

			local shownKey

			local function showHelp(key, text, icon)
				if shownKey ~= key then
					shownKey = key
					lib.showTextUI(text, { position = 'bottom-center', icon = icon })
				end
			end

			local function clearHelp()
				if shownKey then
					shownKey = nil
					lib.hideTextUI()
				end
			end

			repeat
				pumpDistance = #(GetEntityCoords(cache.ped) - pump)

				if cache.vehicle then
					showHelp('leave', 'Saia do veículo para abastecer', 'person-walking')
				else
					-- Abastecer veiculo e galao ficam so no menu do ox_target.
					clearHelp()
				end

				Wait(0)
			until pumpDistance > 3

			clearHelp()
			state.nearestPump = nil

			return
		end
	end
end

---@param point CPoint
local function onExitStation(point)
	if point.blip then
		point.blip = RemoveBlip(point.blip)
	end
end

for station, pumps in pairs(stations) do
	lib.points.new({
		coords = station,
		distance = 60,
		onEnter = onEnterStation,
		onExit = onExitStation,
		nearby = nearbyStation,
		pumps = pumps,
	})
end
