--[[
    nv_hunting — configuração da PESCA

    O que sai da água é decidido por DOIS fatores medidos no ponto do arremesso:

      profundidade  = superfície da água até o fundo (raycast)
      distância da costa = até onde ainda há água ao redor

    Os dois viram uma nota de 0 a 1, a nota escolhe uma faixa (Bands) e a faixa
    sorteia o tier do peixe. Zonas (lagos) limitam o tier máximo por cima disso,
    então lago nunca dá tubarão por mais fundo que seja.
]]

Config.Fishing = {}

-- Itens.
Config.Fishing.Rod = 'fishingrod'
Config.Fishing.Bait = 'fishbait'
Config.Fishing.BaitPerCast = 1

-- Água mais rasa que isso não tem peixe nenhum (córregos, poças, beira seca).
Config.Fishing.MinDepth = 0.5

-- Referências para normalizar a nota. Profundidade >= DeepDepth conta como
-- "fundo máximo"; distância >= OffshoreDistance conta como "mar aberto".
Config.Fishing.DeepDepth = 25.0
Config.Fishing.OffshoreDistance = 300.0

-- Peso de cada fator na nota final.
Config.Fishing.DepthWeight = 0.6
Config.Fishing.ShoreWeight = 0.4

-- Alcance do arremesso (m) e tempo de espera até fisgar.
Config.Fishing.CastRange = 30.0
Config.Fishing.WaitTime = { 4000, 12000 }

-- ============================================================================
-- TIERS
--   0 = lixo | 1 = pequeno | 2 = médio | 3 = grande | 4 = raro de mar aberto
-- ============================================================================
Config.Fishing.Fish = {
    [0] = { 'fishingtin', 'fishingboot' },
    [1] = { 'mackerel', 'flounder' },
    [2] = { 'bass', 'codfish' },
    [3] = { 'stingray' },
    [4] = { 'sharkhammer', 'sharktiger', 'dolphin', 'killerwhale' },
}

-- Preset do nv_minigames (jogo `timing`) por tier: peixe grande briga mais.
-- Os números de dificuldade moram em nv_minigames/config.lua.
Config.Fishing.Minigame = {
    [0] = 'pescar_t0',
    [1] = 'pescar_t1',
    [2] = 'pescar_t2',
    [3] = 'pescar_t3',
    [4] = 'pescar_t4',
}

-- Baú submerso: só aparece a partir do tier 3, no lugar do peixe.
Config.Fishing.Treasure = { item = 'fishinglootbig', chance = 3, minTier = 3 }

-- ============================================================================
-- FAIXAS
--
-- `chance` é a probabilidade de fisgar alguma coisa naquela faixa; `weights` é
-- o peso relativo de cada tier quando fisga.
--
-- A primeira faixa é a beirada: quase sempre volta vazio, e quando vem é peixe
-- pequeno. A última é mar aberto e fundo, a única que libera tier 4.
-- ============================================================================
Config.Fishing.Bands = {
    { max = 0.15, chance = 20, weights = { [0] = 60, [1] = 40 } },
    { max = 0.35, chance = 55, weights = { [0] = 35, [1] = 50, [2] = 15 } },
    { max = 0.60, chance = 75, weights = { [0] = 20, [1] = 40, [2] = 32, [3] = 8 } },
    { max = 0.85, chance = 85, weights = { [0] = 12, [1] = 28, [2] = 38, [3] = 18, [4] = 4 } },
    { max = 1.01, chance = 90, weights = { [0] = 8, [1] = 18, [2] = 34, [3] = 28, [4] = 12 } },
}

-- ============================================================================
-- ZONAS (lagos e águas fechadas)
--
-- maxTier    : teto do que pode sair ali, por mais fundo que esteja
-- chanceMult : multiplica a chance de fisgar (use < 1 para deixar raro)
--
-- ATENÇÃO: as coordenadas e raios são aproximados — confira em jogo e ajuste.
-- ============================================================================
Config.Fishing.Zones = {
    {
        name = 'Alamo Sea',
        center = vec3(1100.0, 4200.0, 30.0),
        radius = 2000.0,
        maxTier = 2,        -- no mais fundo, chega a peixe médio
        chanceMult = 1.0,
    },
    {
        name = 'Lago do Mirror Park',
        center = vec3(1080.0, -710.0, 57.0),
        radius = 200.0,
        maxTier = 1,        -- só peixe pequeno
        chanceMult = 0.35,  -- e raro
    },
}

-- ============================================================================
-- MAR ABERTO (validação de servidor)
--
-- O tier é calculado no cliente, porque só ele tem as natives de água. Para o
-- servidor não depender disso, ele reaplica o teto das Zones acima E, se esta
-- lista tiver alguma área, exige estar dentro de uma delas para liberar peixe
-- grande/raro.
--
-- Vazia = sem restrição extra (o servidor confia no tier fora dos lagos).
-- Preencha com as áreas de mar aberto do seu mapa para travar de vez.
-- ============================================================================
Config.Fishing.DeepWater = {
    -- { center = vec3(3500.0, 3800.0, 0.0), radius = 1500.0 },
}

-- Teto aplicado quando DeepWater está preenchida e o jogador está fora de
-- todas as áreas listadas.
Config.Fishing.MaxTierNearShore = 2

-- ============================================================================
-- ALERTA POLICIAL
-- Desativado por enquanto, a pedido.
-- ============================================================================
Config.Fishing.PoliceAlert = {
    enabled = false,
    chance = 10,
    event = nil,
}
