--[[
    nv_hunting — servidor da PESCA

    O cliente calcula o tier (só ele tem as natives de água). O servidor não
    aceita item vindo do cliente: recebe apenas o tier, valida vara e isca,
    e escolhe o peixe da lista daquele tier.
]]

local lastCatch = {}

-- Uma pescaria legítima leva no mínimo a espera do arremesso, e ainda tem o
-- minigame depois. Cooldown menor que isso deixava o cliente pular a animação.
local COOLDOWN = Config.Fishing.WaitTime[1]

--- Zona (lago) que contém o ponto, se houver.
local function zoneFor(coords)
    for i = 1, #Config.Fishing.Zones do
        local zone = Config.Fishing.Zones[i]

        if #(coords - zone.center) <= zone.radius then return zone end
    end
end

--- Teto de tier que o SERVIDOR aceita naquela posição.
--- O cliente calcula o tier, mas não manda no limite: assim um cliente
--- modificado não pesca orca no lago do Mirror Park.
---@param coords vector3
---@return integer
local function maxTierFor(coords)
    local zone = zoneFor(coords)
    if zone then return zone.maxTier end

    -- Fora de lago é oceano. Com áreas de mar aberto definidas, peixe
    -- grande/raro só vale dentro delas.
    if #Config.Fishing.DeepWater > 0 then
        for i = 1, #Config.Fishing.DeepWater do
            local area = Config.Fishing.DeepWater[i]

            if #(coords - area.center) <= area.radius then return 4 end
        end

        return Config.Fishing.MaxTierNearShore
    end

    return 4
end

lib.callback.register('nv_hunting:server:catch', function(source, tier)
    if type(tier) ~= 'number' then return false end

    local now = GetGameTimer()

    if lastCatch[source] and now - lastCatch[source] < COOLDOWN then return false end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end

    -- Trava pelo lugar onde o jogador realmente está.
    tier = math.floor(tier)
    if tier < 0 then tier = 0 end

    tier = math.min(tier, maxTierFor(GetEntityCoords(ped)))

    local pool = Config.Fishing.Fish[tier]
    if not pool then return false end

    lastCatch[source] = now

    local inventory = exports.ox_inventory

    if inventory:GetItemCount(source, Config.Fishing.Rod) < 1 then
        return false
    end

    if inventory:GetItemCount(source, Config.Fishing.Bait) < Config.Fishing.BaitPerCast then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Você está sem isca.'
        })
        return false
    end

    if not inventory:RemoveItem(source, Config.Fishing.Bait, Config.Fishing.BaitPerCast) then
        return false
    end

    -- Baú submerso entra no lugar do peixe, só em água que dá peixe grande.
    local treasure = Config.Fishing.Treasure

    if treasure and tier >= treasure.minTier and math.random(100) <= treasure.chance then
        if inventory:AddItem(source, treasure.item, 1) then
            return treasure.item
        end
    end

    local item = pool[math.random(#pool)]

    if not inventory:AddItem(source, item, 1) then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Você não tem espaço para carregar isso.'
        })
        return false
    end

    -- Alerta policial: desativado por padrão (Config.Fishing.PoliceAlert.enabled).
    local alert = Config.Fishing.PoliceAlert

    if alert and alert.enabled and alert.event and math.random(100) <= alert.chance then
        TriggerEvent(alert.event, source, GetEntityCoords(GetPlayerPed(source)))
    end

    return item
end)

AddEventHandler('playerDropped', function()
    lastCatch[source] = nil
end)
