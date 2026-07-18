Config = {}

-- ============================================================================
-- GOPOSTAL PACKAGE JOB CONFIGURATION (from nv_deliverybox)
-- ============================================================================
Config.RequiredShirt = {
    componentId = 8,  -- 8 = T-shirt / Underwear
    drawableId = 15,  -- ID do desenho da camisa
    textureId = 0     -- ID da textura
}

Config.StartNPC = {
    model = "a_m_m_business_01",
    coords = vec4(73.4795, -1562.7347, 29.5978, 54.4151), -- GoPostal Legion Square
    anim = { dict = 'amb@world_human_cop_idles@male@idle_b', name = 'idle_e' }
}

Config.Pallets = {
    { coords = vec4(70.3361, -1565.1537, 29.5978, 54.1980) },
    { coords = vec4(67.5000, -1567.0000, 29.5978, 54.1980) },
    { coords = vec4(64.7000, -1569.0000, 29.5978, 54.1980) }
}

Config.Models = {
    pallet = "bkr_prop_coke_pallet_01a",
    letter = "prop_cs_box_clothes",
    small = "prop_cardbordbox_02a",
    large = "prop_cs_box_step"
}

Config.Items = {
    letter = { name = 'delivery_letter', label = 'Caixa Pequena', payoutMin = 100, payoutMax = 500 },
    small = { name = 'delivery_small_box', label = 'Caixa Média', payoutMin = 150, payoutMax = 600 },
    large = { name = 'delivery_large_package', label = 'Caixa Grande', payoutMin = 200, payoutMax = 750 }
}

Config.ReceiverNPCs = {
    "a_m_y_business_01",
    "a_f_y_business_01",
    "a_m_y_downtown_01",
    "a_f_m_downtown_01",
    "a_m_m_eastsa_01",
    "a_m_y_beach_01"
}

Config.DeliveryLocations = {
    { coords = vector3(1409.0068, 6538.0083, 16.4597), label = "Ponto de Teste - Entrega" },
    { coords = vector3(77.5855, -1555.6310, 29.5978), label = "Ponto de Teste - Entrega 2" },
    { coords = vector3(274.0063, -598.2046, 43.1178), label = "Ponto de Teste - Entrega 3" }
}

-- ============================================================================
-- GAS STATION REPLENISHMENT CONFIGURATION
-- ============================================================================
Config.GasStations = {
    npcModel = `s_m_m_trucker_01`,
    npcCoords = vec4(2707.38, 1652.01, 24.57, 253.30),
    truckModel = `phantom`,
    truckSpawn = vec4(2826.83, 1619.92, 24.48, 79.25),
    trailerModel = `tanker`,
    trailerSpawn = vec4(2783.92, 1709.18, 24.61, 91.55),
    criticalFuelLimit = 50,     -- 50 Liters
    replenishThreshold = 120,   -- 120 Liters
    maxFuelCapacity = 200,      -- 200 Liters
    replenishAmount = 80,       -- 80 Liters
    replenishCost = 1000,       -- Paid by gas station register
    playerReward = 1000,        -- Paid to driver per delivery
    requiredCriticalStations = 2, -- Min critical stations to allow starting job

    -- ------------------------------------------------------------------
    -- EVENT / MISSION FLOW
    -- ------------------------------------------------------------------
    cooldown = 60,              -- (legado) não usado com o cooldown de pátio
    fuelDuration = 30000,       -- (legado) fluxo antigo de barra fixa
    hoseMaxDistance = 8.0,      -- Distância máxima do trailer antes da mangueira explodir

    -- ---------------- GATILHO / FILA DO EVENTO ----------------
    emptyTrigger = 3,           -- Nº de postos vazios para disparar o evento automático
    emptyLevel = 0,             -- Fuel <= isso conta como "vazio"
    qualifyLevel = 100,         -- Postos com fuel <= isso (50% de 200) entram na fila
    maxPerTrip = 100,           -- Litros máximos que um caminhão leva por viagem
    pricePerLiter = 1,          -- $ por litro entregue (pago pelo caixa do posto)
    spawnCooldown = 10,         -- Segundos após o pátio ficar livre para liberar novo caminhão
    fuelRate = 4,               -- Litros por segundo ao descarregar no posto
    monitorInterval = 5000,     -- Intervalo (ms) do monitor que conta postos vazios

    returnPoint = vec3(2688.20, 1519.69, 24.64),           -- Leve o caminhão aqui e aperte E
    returnNpcModel = `s_m_m_trucker_01`,                   -- NPC que leva o caminhão embora
    returnNpcSpawn = vec4(2683.17, 1514.95, 24.51, 285.97),

    hoseProp = `prop_cs_fuel_nozle`,  -- Bico da mangueira preso à mão do jogador

    -- Modelos de bomba onde a mangueira pode ser conectada
    pumpModels = {
        `prop_gas_pump_old2`, `prop_gas_pump_1a`, `prop_vintage_pump`,
        `prop_gas_pump_old3`, `prop_gas_pump_1c`, `prop_gas_pump_1b`,
        `prop_gas_pump_1d`, `prop_gas_pump_1`
    },

    -- Sprites dos blips do mapa (ajuste conforme preferir)
    blips = {
        event   = 436,  -- Ícone de fogo (evento ativo)
        truck   = 477,  -- Ir até o caminhão
        trailer = 479,  -- Ir até o trailer
        station = 361,  -- Posto de entrega
        ret     = 50,   -- Devolver o caminhão
        payment = 280,  -- Receber pagamento
    },

    -- ------------------------------------------------------------------
    -- MODO DE TESTE
    -- Usa somente um posto (o mais próximo do fuelPoint) e um ponto de
    -- abastecimento fixo. Desative (enabled = false) para o fluxo normal.
    -- ------------------------------------------------------------------
    test = {
        enabled = true,
        fuelPoint = vec3(2588.46, 373.83, 108.47), -- Leve a mangueira aqui e aperte E
    }
}

-- ============================================================================
-- 24/7 CONVENIENCE STORES CONFIGURATION
-- ============================================================================
Config.Shops247 = {
    npcModel = `s_m_m_dockwork_01`,
    npcCoords = vec4(912.44, -1268.32, 25.56, 120.00), -- Logistic Port
    truckModel = `mule`,
    truckSpawn = vec4(923.65, -1257.44, 25.50, 210.00),
    deliveryItem = 'delivery_crate', -- Item to be delivered
    deliveryReward = 500,           -- Paid to player
    deliveryCost = 500,             -- Deducted from 24/7 register
    locations = {
        { coords = vector3(25.68, -1346.81, 29.50), label = "Loja 24/7 - Innocence Blvd" },
        { coords = vector3(373.87, 325.89, 103.56), label = "Loja 24/7 - Clinton Ave" },
        { coords = vector3(-48.37, -1757.51, 29.42), label = "Loja 24/7 - Grove St" },
        { coords = vector3(-707.67, -914.22, 19.21), label = "Loja 24/7 - Little Seoul" },
        { coords = vector3(-1222.93, -906.99, 12.33), label = "Loja 24/7 - Vespucci Blvd" },
        { coords = vector3(1163.37, -323.80, 69.20), label = "Loja 24/7 - Mirror Park" },
        { coords = vector3(1961.12, 3740.67, 32.34), label = "Loja 24/7 - Sandy Shores" },
        { coords = vector3(2678.91, 3280.67, 55.24), label = "Loja 24/7 - Senora Fwy" },
        { coords = vector3(1729.21, 6414.13, 35.03), label = "Loja 24/7 - Paleto Bay" },
        { coords = vector3(1698.38, 4924.40, 42.06), label = "Loja 24/7 - Grapeseed" }
    }
}
