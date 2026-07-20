--[[
    nv_hunting — cliente da PESCA

    Toda a leitura da água acontece aqui (profundidade e distância da costa são
    natives de cliente). O servidor recebe o tier já calculado e decide o item.

    A caça do mesmo resource vive em client/hunting.lua e não conversa com
    este arquivo.
]]

local fishing = false

-- ------------------------------------------------------------- leitura ----

--- Altura da superfície da água num ponto, se houver água.
---@return number|nil
local function waterAt(x, y, z)
    local found, height = GetWaterHeight(x, y, z)

    return found and height or nil
end

--- Profundidade: da superfície até o fundo, por raycast para baixo.
---@param x number
---@param y number
---@param surface number
---@return number
local function depthAt(x, y, surface)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        x, y, surface - 0.2,
        x, y, surface - 200.0,
        1,      -- só geometria do mapa
        0, 7
    )

    local _, hit, endCoords = GetShapeTestResult(handle)

    if hit == 1 then
        return math.max(0.0, surface - endCoords.z)
    end

    -- Sem fundo encontrado = muito fundo mesmo.
    return Config.Fishing.DeepDepth
end

--- Quão longe da terra o ponto está: cresce o raio até achar terra em volta.
---@param x number
---@param y number
---@param z number
---@return number distância aproximada em metros
local function shoreDistance(x, y, z)
    local rings = { 20.0, 50.0, 100.0, 200.0, 300.0 }
    local reached = 0.0

    for i = 1, #rings do
        local radius = rings[i]

        for angle = 0, 315, 45 do
            local rad = math.rad(angle)
            local sx = x + math.cos(rad) * radius
            local sy = y + math.sin(rad) * radius

            -- Uma única direção sem água já significa costa por perto.
            if not waterAt(sx, sy, z + 5.0) then
                return reached
            end
        end

        reached = radius
    end

    return reached
end

--- Zona configurada que contém o ponto (lago), se houver.
local function zoneAt(coords)
    for i = 1, #Config.Fishing.Zones do
        local zone = Config.Fishing.Zones[i]

        if #(coords - zone.center) <= zone.radius then
            return zone
        end
    end
end

-- --------------------------------------------------------------- sorteio --

--- Nota 0..1 combinando profundidade e distância da costa.
local function scoreFor(depth, shore)
    local depthScore = math.min(depth / Config.Fishing.DeepDepth, 1.0)
    local shoreScore = math.min(shore / Config.Fishing.OffshoreDistance, 1.0)

    return depthScore * Config.Fishing.DepthWeight + shoreScore * Config.Fishing.ShoreWeight
end

local function bandFor(score)
    for i = 1, #Config.Fishing.Bands do
        if score <= Config.Fishing.Bands[i].max then return Config.Fishing.Bands[i] end
    end

    return Config.Fishing.Bands[#Config.Fishing.Bands]
end

--- Sorteia o tier respeitando o teto da zona.
---@param band table
---@param maxTier integer|nil
---@return integer
local function rollTier(band, maxTier)
    local total, pool = 0, {}

    for tier, weight in pairs(band.weights) do
        if not maxTier or tier <= maxTier then
            total = total + weight
            pool[#pool + 1] = { tier = tier, weight = weight }
        end
    end

    -- Teto cortou tudo: sobra lixo.
    if total <= 0 then return 0 end

    local roll = math.random() * total

    for i = 1, #pool do
        roll = roll - pool[i].weight
        if roll <= 0 then return pool[i].tier end
    end

    return 0
end

-- ---------------------------------------------------------------- pescar --

--- Ponto do arremesso: primeiro ponto com água à frente do jogador.
---@return vector3|nil
local function castPoint()
    local ped = cache.ped
    local coords = GetEntityCoords(ped)

    for distance = 5.0, Config.Fishing.CastRange, 5.0 do
        local point = GetOffsetFromEntityInWorldCoords(ped, 0.0, distance, 0.0)
        local surface = waterAt(point.x, point.y, coords.z + 10.0)

        if surface then
            return vec3(point.x, point.y, surface)
        end
    end
end

local function fish()
    if fishing then return end

    local point = castPoint()

    if not point then return end

    local depth = depthAt(point.x, point.y, point.z)

    if depth < Config.Fishing.MinDepth then
        return lib.notify({ type = 'error', description = 'A água aqui é rasa demais.' })
    end

    local shore = shoreDistance(point.x, point.y, point.z)
    local zone = zoneAt(point)
    local band = bandFor(scoreFor(depth, shore))

    fishing = true

    local casting = lib.progressBar({
        label = 'Arremessando...',
        duration = math.random(Config.Fishing.WaitTime[1], Config.Fishing.WaitTime[2]),
        position = 'bottom',
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_c' },
    })

    if not casting then
        fishing = false
        return
    end

    -- Nem toda espera vira fisgada.
    local chance = band.chance * ((zone and zone.chanceMult) or 1.0)

    if math.random(100) > chance then
        fishing = false
        return lib.notify({ type = 'inform', description = 'Não veio nada dessa vez.' })
    end

    local tier = rollTier(band, zone and zone.maxTier)

    local minigame = Config.Fishing.Minigame[tier] or Config.Fishing.Minigame[0]

    if not exports.nv_minigames:Start(minigame) then
        fishing = false
        return lib.notify({ type = 'error', description = 'Escapou da linha.' })
    end

    local item = lib.callback.await('nv_hunting:server:catch', false, tier)
    fishing = false

    if item then
        lib.notify({ type = 'success', description = ('Você pescou: %s'):format(item) })
    end
end

-- ---------------------------------------------------------------- entrada --

--- Chamado pelo ox_inventory ao usar a vara (client.export em items.lua).
exports('useRod', function()
    fish()
end)

RegisterCommand('pescar', fish, false)

--- Utilitário de ajuste: mostra o que o script está lendo da água à sua frente.
RegisterCommand('fishdebug', function()
    local point = castPoint()

    if not point then return print('[nv_hunting] sem água à frente') end

    local depth = depthAt(point.x, point.y, point.z)
    local shore = shoreDistance(point.x, point.y, point.z)
    local zone = zoneAt(point)
    local score = scoreFor(depth, shore)

    print(('[nv_hunting] profundidade %.1fm | costa %.0fm | nota %.2f | zona %s | tier max %s')
        :format(depth, shore, score, zone and zone.name or 'oceano', zone and zone.maxTier or 4))
end, false)
