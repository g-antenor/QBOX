--[[
    nv_hunting — servidor da CAÇA

    O cliente manda só o netId da carcaça. Tudo que decide valor fica aqui:
    quantos cortes a carcaça aguenta, quantos já foram feitos e o que cai.

    O contador ficava em state bag, que é escrito pelo dono da entidade — ou
    seja, pelo cliente. Bastava nunca incrementar para esfolar o mesmo animal
    infinitamente. Agora o servidor é o dono do contador.
]]

-- [netId] = { cuts = feitos, total = limite sorteado }
local carcass = {}

-- [src] = timestamp do último corte.
local lastSkin = {}

-- Um corte legítimo leva no mínimo a barra de progresso inteira, e ainda tem o
-- minigame antes. Usar a duração real fecha o "pula a animação e spamma".
local COOLDOWN = Config.Hunting.CutDuration

---@param drops table
---@return table<string, number>
local function rollDrops(drops)
    local rewards = {}

    for i = 1, #drops do
        local drop = drops[i]

        if math.random(100) <= (drop.chance or 100) then
            rewards[drop.item] = math.random(drop.min or 1, drop.max or 1)
        end
    end

    return rewards
end

lib.callback.register('nv_hunting:server:skin', function(source, netId)
    if type(netId) ~= 'number' then return false end

    local now = GetGameTimer()

    if lastSkin[source] and now - lastSkin[source] < COOLDOWN then return false end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    -- Só carcaça: sem isso dava para esfolar animal vivo.
    if GetEntityHealth(entity) > 0 then return false end

    local animal = Config.Hunting.Animals[GetEntityModel(entity)]
    if not animal then return false end

    -- Longe demais para ter esfolado de verdade.
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    if #(GetEntityCoords(ped) - GetEntityCoords(entity)) > 5.0 then return false end

    local entry = carcass[netId]

    if not entry then
        entry = { cuts = 0, total = math.random(animal.cuts[1], animal.cuts[2]) }
        carcass[netId] = entry
    end

    -- Carcaça esgotada: nada mais sai dela, independente do que o cliente ache.
    if entry.cuts >= entry.total then return false end

    lastSkin[source] = now
    entry.cuts = entry.cuts + 1

    local finished = entry.cuts >= entry.total
    if finished then carcass[netId] = nil end

    local rewards = rollDrops(animal.drops)
    local gave = false

    for item, count in pairs(rewards) do
        if exports.ox_inventory:AddItem(source, item, count) then
            gave = true
        end
    end

    if not gave then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'inform',
            description = 'Você não conseguiu aproveitar nada desse corte.'
        })
    end

    -- Alerta policial: desativado por padrão (Config.Hunting.PoliceAlert.enabled).
    local alert = Config.Hunting.PoliceAlert

    if alert and alert.enabled and alert.event and math.random(100) <= alert.chance then
        TriggerEvent(alert.event, source, GetEntityCoords(ped))
    end

    return { finished = finished }
end)

-- Carcaças somem do mapa sem avisar; sem a limpeza a tabela cresce para sempre.
CreateThread(function()
    while true do
        Wait(300000)

        for netId in pairs(carcass) do
            local entity = NetworkGetEntityFromNetworkId(netId)

            if not entity or entity == 0 or not DoesEntityExist(entity) then
                carcass[netId] = nil
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    lastSkin[source] = nil
end)
