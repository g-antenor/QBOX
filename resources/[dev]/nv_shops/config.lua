--[[
    nv_shops — configuracao

    Substitui as lojas General (24/7) e Ammunation do ox_inventory. A diferenca
    nao e visual: aqui a loja tem ESTOQUE e CAIXA no banco, como os postos de
    gasolina do nv_delivery. Comprar tira do estoque e poe dinheiro no caixa.

    Pagamento e SOMENTE em dinheiro (item `money`). Nao existe cartao, nao
    existe transferencia -- e uma regra do servidor, nao uma opcao de config.
]]

Config = {}

-- ============================================================================
-- GERAL
-- ============================================================================

-- Item usado como dinheiro vivo no ox_inventory.
Config.MoneyItem = 'money'

-- Item de comprovante entregue a cada compra (ver `nota_fiscal` no items.lua).
-- nil desativa a emissao.
Config.ReceiptItem = 'nota_fiscal'

-- Distancia maxima do balcao para a compra ser aceita (m). Validada no
-- SERVIDOR: a NUI e apenas a vitrine.
Config.MaxDistance = 4.0

-- Teto de itens por compra, para uma NUI adulterada nao pedir 10 mil unidades
-- e travar o servidor no meio do loop.
Config.MaxCartQuantity = 100

-- ============================================================================
-- CATEGORIAS
--
-- `icon` e o id de um <symbol> no index.html -- SVG, nao emoji. Para criar uma
-- categoria nova, adicione o <symbol id="ic-xxx"> la e referencie aqui.
-- ============================================================================
Config.Categories = {
    ['247'] = {
        { id = 'comidas',   label = 'Comidas',   icon = 'ic-comida' },
        { id = 'bebidas',   label = 'Bebidas',   icon = 'ic-bebida' },
        { id = 'materiais', label = 'Materiais', icon = 'ic-material' }
    },

    ammunation = {
        { id = 'brancas',    label = 'Armas Brancas', icon = 'ic-faca' },
        { id = 'fogo',       label = 'Armas de Fogo', icon = 'ic-pistola' },
        { id = 'municoes',   label = 'Municoes',      icon = 'ic-municao' },
        -- So aparece nas lojas do norte (`hunting = true`).
        { id = 'cacas',      label = 'Cacas',         icon = 'ic-caca', hunting = true },
        { id = 'utilidades', label = 'Utilidades',    icon = 'ic-utilidade' }
    }
}

-- ============================================================================
-- CATALOGO
--
--   name     = item do ox_inventory (confira em data/items.lua e data/weapons.lua)
--   label    = como aparece na vitrine
--   price    = preco unitario, em dinheiro
--   stock    = estoque inicial E teto de reposicao daquele item por loja
--   license  = licenca exigida (ox_core), opcional
--   metadata = metadata aplicado ao item entregue, opcional
--
-- ATENCAO: o catalogo e limitado pelos itens que EXISTEM hoje no ox_inventory.
-- Nao inventei nomes: cada `name` daqui foi conferido contra data/items.lua e
-- data/weapons.lua. Ao adicionar item novo no inventario, adicione aqui.
-- ============================================================================
Config.Catalog = {
    ['247'] = {
        -- ---------------------------------------------------------- comidas --
        { name = 'burger',   label = 'Hamburguer',       price = 12,  stock = 40, category = 'comidas' },
        { name = 'mustard',  label = 'Mostarda',         price = 8,   stock = 25, category = 'comidas' },

        -- ---------------------------------------------------------- bebidas --
        { name = 'water',    label = 'Agua Mineral',     price = 6,   stock = 60, category = 'bebidas' },
        { name = 'sprunk',   label = 'Sprunk',           price = 9,   stock = 50, category = 'bebidas' },

        -- -------------------------------------------------------- materiais --
        { name = 'bandage',          label = 'Bandagem',        price = 45,  stock = 20, category = 'materiais' },
        { name = 'paperbag',         label = 'Sacola de Papel', price = 3,   stock = 40, category = 'materiais' },
        { name = 'trash_bag_black',  label = 'Saco de Lixo',    price = 5,   stock = 40, category = 'materiais' },
        { name = 'trash_bag_white',  label = 'Saco Reciclavel', price = 5,   stock = 40, category = 'materiais' },
        { name = 'phone',            label = 'Celular',         price = 850, stock = 8,  category = 'materiais' },
        { name = 'radio',            label = 'Radio',           price = 650, stock = 8,  category = 'materiais' },
        { name = 'fishingrod',       label = 'Vara de Pesca',   price = 320, stock = 10, category = 'materiais' },
        { name = 'fishbait',         label = 'Isca',            price = 12,  stock = 80, category = 'materiais' }
    },

    ammunation = {
        -- ---------------------------------------------------- armas brancas --
        { name = 'WEAPON_KNIFE',   label = 'Faca',        price = 250,  stock = 10, category = 'brancas' },
        { name = 'WEAPON_BAT',     label = 'Taco',        price = 180,  stock = 10, category = 'brancas' },
        { name = 'WEAPON_MACHETE', label = 'Machete',     price = 400,  stock = 6,  category = 'brancas' },
        { name = 'WEAPON_HATCHET', label = 'Machadinha',  price = 380,  stock = 6,  category = 'brancas' },
        { name = 'WEAPON_KNUCKLE', label = 'Soco Ingles', price = 220,  stock = 8,  category = 'brancas' },

        -- ---------------------------------------------------- armas de fogo --
        -- `license = 'weapon'` faz o ox_core exigir porte. O registro no
        -- metadata e o que amarra a arma ao dono na pericia.
        { name = 'WEAPON_PISTOL',       label = 'Pistola',          price = 12000, stock = 4, category = 'fogo', license = 'weapon', metadata = { registered = true } },
        { name = 'WEAPON_COMBATPISTOL', label = 'Pistola de Combate', price = 18000, stock = 3, category = 'fogo', license = 'weapon', metadata = { registered = true } },
        { name = 'WEAPON_PUMPSHOTGUN',  label = 'Escopeta',         price = 26000, stock = 2, category = 'fogo', license = 'weapon', metadata = { registered = true } },

        -- --------------------------------------------------------- municoes --
        { name = 'ammo-9',       label = 'Municao 9mm',      price = 8,  stock = 300, category = 'municoes' },
        { name = 'ammo-45',      label = 'Municao .45',      price = 10, stock = 250, category = 'municoes' },
        { name = 'ammo-shotgun', label = 'Cartucho Calibre 12', price = 18, stock = 150, category = 'municoes' },
        { name = 'ammo-rifle',   label = 'Municao de Rifle', price = 22, stock = 120, category = 'municoes' },

        -- ------------------------------------------------------------ cacas --
        -- So nas lojas marcadas com `hunting = true` (norte do mapa). O rifle
        -- de caca e a unica arma longa que se compra no balcao.
        { name = 'WEAPON_MUSKET',      label = 'Mosquete',        price = 22000, stock = 2,  category = 'cacas', license = 'weapon', metadata = { registered = true } },
        { name = 'WEAPON_SNIPERRIFLE', label = 'Rifle de Caca',   price = 48000, stock = 1,  category = 'cacas', license = 'weapon', metadata = { registered = true } },
        { name = 'ammo-musket',        label = 'Municao Mosquete', price = 30,   stock = 80, category = 'cacas' },
        { name = 'ammo-sniper',        label = 'Municao de Rifle de Caca', price = 45, stock = 60, category = 'cacas' },

        -- ------------------------------------------------------- utilidades --
        { name = 'armour',              label = 'Colete',        price = 3500, stock = 10, category = 'utilidades' },
        { name = 'WEAPON_FLASHLIGHT',   label = 'Lanterna',      price = 150,  stock = 15, category = 'utilidades' },
        { name = 'at_flashlight',       label = 'Lanterna Tatica', price = 900, stock = 8, category = 'utilidades' },
        { name = 'parachute',           label = 'Paraquedas',    price = 2500, stock = 5,  category = 'utilidades' }
    }
}

-- ============================================================================
-- LOJAS
--
--   type    = '247' ou 'ammunation' (escolhe categorias e catalogo)
--   coords  = onde fica o balcao
--   ped     = modelo e heading do atendente (nil usa o padrao do tipo)
--   hunting = true libera a aba "Cacas" (lojas do norte)
--
-- As coordenadas dos 24/7 vieram do Config.Shops247 do nv_delivery, para as
-- duas coisas falarem da MESMA loja -- o caixa que o entregador abastece e o
-- caixa que enche quando alguem compra.
-- ============================================================================
Config.Shops = {
    -- ------------------------------------------------------------- 24/7 --
    { id = 1,  type = '247', label = 'Loja 24/7 - Innocence Blvd', coords = vec3(25.68, -1346.81, 29.50) },
    { id = 2,  type = '247', label = 'Loja 24/7 - Clinton Ave',    coords = vec3(373.87, 325.89, 103.56) },
    { id = 3,  type = '247', label = 'Loja 24/7 - Grove St',       coords = vec3(-48.37, -1757.51, 29.42) },
    { id = 4,  type = '247', label = 'Loja 24/7 - Little Seoul',   coords = vec3(-707.67, -914.22, 19.21) },
    { id = 5,  type = '247', label = 'Loja 24/7 - Vespucci Blvd',  coords = vec3(-1222.93, -906.99, 12.33) },
    { id = 6,  type = '247', label = 'Loja 24/7 - Mirror Park',    coords = vec3(1163.37, -323.80, 69.20) },
    { id = 7,  type = '247', label = 'Loja 24/7 - Sandy Shores',   coords = vec3(1961.12, 3740.67, 32.34) },
    { id = 8,  type = '247', label = 'Loja 24/7 - Senora Fwy',     coords = vec3(2678.91, 3280.67, 55.24) },
    { id = 9,  type = '247', label = 'Loja 24/7 - Paleto Bay',     coords = vec3(1729.21, 6414.13, 35.03) },
    { id = 10, type = '247', label = 'Loja 24/7 - Grapeseed',      coords = vec3(1698.38, 4924.40, 42.06) },

    -- ------------------------------------------------------ ammunation --
    { id = 11, type = 'ammunation', label = 'Ammu-Nation - Pillbox',    coords = vec3(-662.18, -934.96, 21.83) },
    { id = 12, type = 'ammunation', label = 'Ammu-Nation - Cypress',    coords = vec3(810.25, -2157.60, 29.62) },
    { id = 13, type = 'ammunation', label = 'Ammu-Nation - Hawick',     coords = vec3(252.63, -50.00, 69.94) },
    { id = 14, type = 'ammunation', label = 'Ammu-Nation - Downtown',   coords = vec3(22.56, -1109.89, 29.80) },
    { id = 15, type = 'ammunation', label = 'Ammu-Nation - Little Seoul', coords = vec3(842.44, -1033.42, 28.19) },

    -- Norte: aqui se compra material de caca.
    { id = 16, type = 'ammunation', label = 'Ammu-Nation - Sandy Shores', coords = vec3(1693.44, 3760.16, 34.71), hunting = true },
    { id = 17, type = 'ammunation', label = 'Ammu-Nation - Paleto Bay',   coords = vec3(-330.24, 6083.88, 31.45), hunting = true },
    { id = 18, type = 'ammunation', label = 'Ammu-Nation - Route 68',     coords = vec3(-1117.58, 2698.61, 18.55), hunting = true },
    { id = 19, type = 'ammunation', label = 'Ammu-Nation - Palomino',     coords = vec3(2567.69, 294.38, 108.73), hunting = true }
}

-- ============================================================================
-- ATENDENTES E BLIPS
-- ============================================================================
Config.Peds = {
    enabled = true,

    -- As coordenadas acima sao do balcao (altura de quem esta em pe).
    zOffset = -1.0,

    ['247'] = {
        model    = 's_m_y_shop_mask',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT'
    },

    ammunation = {
        model    = 's_m_y_ammucity_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT'
    }
}

Config.Blips = {
    ['247']     = { sprite = 59,  color = 2, scale = 0.7 },
    ammunation  = { sprite = 110, color = 1, scale = 0.7 }
}

-- ============================================================================
-- REPOSICAO DE ESTOQUE
--
-- A CONTA ja funciona; o EVENTO ainda nao existe.
--
-- Uma loja entra na fila de reposicao quando fica sem algum item OU quando o
-- estoque total dela cai abaixo de `lowStockPercent`. Quando o numero de lojas
-- na fila chega em `minStores`, ha material suficiente para uma rota de
-- entrega valer a pena.
--
-- `event` esta desligado de proposito, a pedido: por enquanto o sistema apenas
-- CONTA e registra no console. Quando a rota existir, e so apontar o nome do
-- evento aqui -- ele recebe a lista de lojas pendentes.
-- ============================================================================
Config.Restock = {
    -- Percentual do estoque total abaixo do qual a loja entra na fila mesmo
    -- sem ter zerado nenhum item.
    lowStockPercent = 50,

    -- Quantas lojas pendentes para valer uma rota.
    minStores = 3,

    -- Intervalo da verificacao (ms).
    interval = 300000,

    -- Evento disparado com a lista de lojas. nil = so conta e loga.
    --
    -- Aponta para o aviso da distribuidora (nv_delivery): quando a fila enche,
    -- todo mundo online e avisado de que ha carga esperando no galpao. O
    -- servico em si e "puxado" -- ele so aceita comecar se esta fila existir --
    -- entao este evento e o chamado, nao o gatilho.
    event = 'nv_delivery:shop247:restockNeeded',

    -- Imprime no console do servidor a cada verificacao.
    log = true
}
