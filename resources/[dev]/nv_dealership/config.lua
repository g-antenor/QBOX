Config = {}

Config.MaxOrderUnits = 10
Config.OrderPickupMinutes = 20
Config.TestDriveSeconds = 60
Config.TestBucketBase = 7000
Config.TruckModel = 'packer'
Config.TrailerModel = 'tr4'
Config.DeliveryNpcModel = 's_m_m_dockwork_01'
Config.WholesaleRate = 0.72

-- O peso e uma estimativa em kg usada pelo ferro-velho. Preco, nome, marca e
-- demais dados continuam vindo de ox_core/common/data/vehicles.json.
Config.VehicleClasses = {
    [0] = { key = 'compact', label = 'Compactos' },
    [1] = { key = 'sedan', label = 'Sedans' },
    [2] = { key = 'suv', label = 'SUVs' },
    [3] = { key = 'coupe', label = 'Coupes' },
    [4] = { key = 'muscle', label = 'Muscle' },
    [5] = { key = 'sportsclassic', label = 'Esportivos classicos' },
    [6] = { key = 'sports', label = 'Esportivos' },
    [7] = { key = 'super', label = 'Super' },
    [8] = { key = 'motorcycle', label = 'Motos' },
    [9] = { key = 'offroad', label = 'Off-road' },
    [10] = { key = 'industrial', label = 'Industriais' },
    [11] = { key = 'utility', label = 'Utilitarios' },
    [12] = { key = 'van', label = 'Vans' },
    [13] = { key = 'cycle', label = 'Bicicletas' },
    [14] = { key = 'boat', label = 'Barcos' },
    [15] = { key = 'helicopter', label = 'Helicopteros' },
    [16] = { key = 'plane', label = 'Avioes' },
    [17] = { key = 'service', label = 'Servico' },
    [18] = { key = 'emergency', label = 'Emergencia' },
    [19] = { key = 'military', label = 'Militares' },
    [20] = { key = 'commercial', label = 'Comerciais' },
    [21] = { key = 'train', label = 'Trens' },
    [22] = { key = 'openwheel', label = 'Formula' }
}

-- Sobrescreva apenas dados comerciais. O peso pertence a lista central.
Config.VehicleOverrides = {}

-- Ferro-velho: o modelo e o peso sao resolvidos pelo catalogo de veiculos
-- carregado do ox_core; veiculos ausentes dessa lista nao sao aceitos.
Config.Scrapyard = {
    enabled = true,
    coords = vec4(-459.52, -1712.16, 18.77, 52.0),
    vehicleRadius = 6.0,
    npcModel = 's_m_y_xmech_02',
    pricePerKg = 10,
    blip = { enabled = true, sprite = 318, color = 1, scale = 0.75, label = 'Ferro-velho' }
}
