Config = {}

-- Configuração do uniforme obrigatório (camisa/camiseta)
Config.RequiredShirt = {
    componentId = 8,  -- 8 = T-shirt / Underwear
    drawableId = 15,  -- ID do desenho da camisa configurável
    textureId = 0     -- ID da textura da camisa
}

-- NPC de Início de Serviço
Config.StartNPC = {
    model = "a_m_m_business_01",
    coords = vec4(73.4795, -1562.7347, 29.5978, 54.4151), -- x, y, z, heading (Próximo à Legion Square/GoPostal)
    anim = { dict = 'amb@world_human_cop_idles@male@idle_b', name = 'idle_e' }
}

-- Posições dos 3 Pallets fixos onde os pacotes vão spawnar
Config.Pallets = {
    { coords = vec4(70.3361, -1565.1537, 29.5978, 54.1980) }, -- Pallet 1 (Padrão)
    { coords = vec4(67.5000, -1567.0000, 29.5978, 54.1980) }, -- Pallet 2
    { coords = vec4(64.7000, -1569.0000, 29.5978, 54.1980) }  -- Pallet 3
}

-- Modelos físicos dos pacotes (como strings para evitar conflitos de hash OneSync)
Config.Models = {
    pallet = "bkr_prop_coke_pallet_01a",
    letter = "prop_cs_box_clothes",
    small = "prop_cardbordbox_02a",
    large = "prop_cs_box_step"
}

-- Mapeamento dos itens do inventário para os nomes configurados
Config.Items = {
    letter = { name = 'delivery_letter', label = 'Caixa Pequena', payoutMin = 100, payoutMax = 500 },
    small = { name = 'delivery_small_box', label = 'Caixa Média', payoutMin = 150, payoutMax = 600 },
    large = { name = 'delivery_large_package', label = 'Caixa Grande', payoutMin = 200, payoutMax = 750 }
}

-- NPCs destinatários aleatórios
Config.ReceiverNPCs = {
    "a_m_y_business_01",
    "a_f_y_business_01",
    "a_m_y_downtown_01",
    "a_f_m_downtown_01",
    "a_m_m_eastsa_01",
    "a_m_y_beach_01"
}

-- Locais aleatórios para entrega
Config.DeliveryLocations = {
    { coords = vector3(1409.0068, 6538.0083, 16.4597), label = "Ponto de Teste - Entrega" },
    { coords = vector3(77.5855, -1555.6310, 29.5978), label = "Ponto de Teste - Entrega 2" },
    { coords = vector3(274.0063, -598.2046, 43.1178), label = "Ponto de Teste - Entrega 3" }
}
