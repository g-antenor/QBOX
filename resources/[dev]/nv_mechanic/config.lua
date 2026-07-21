Config = {}

Config.UpdateInterval = 500
Config.SaveInterval = 15000
Config.MechanicSubtype = 'mecanica'

Config.WorkOrders = {
    toolbox = 'toolbox',
    inspectDuration = 9000,
    repairDistance = 4.0,
    parts = {
        engine  = { label='Motor', item='sheet_metal', amount=2, tool='toolbox', value=900, animation='engine' },
        body    = { label='Lataria', item='sheet_metal', amount=2, tool='blowtorch', value=500, animation='torch' },
        hood    = { label='Capo', item='car_hood', amount=1, tool='blowtorch', value=450, animation='torch' },
        trunk   = { label='Porta-malas', item='car_trunk', amount=1, tool='blowtorch', value=400, animation='torch' },
        door0   = { label='Porta dianteira esquerda', item='car_door', amount=1, tool='blowtorch', value=400, animation='torch', door=0 },
        door1   = { label='Porta dianteira direita', item='car_door', amount=1, tool='blowtorch', value=400, animation='torch', door=1 },
        door2   = { label='Porta traseira esquerda', item='car_door', amount=1, tool='blowtorch', value=350, animation='torch', door=2 },
        door3   = { label='Porta traseira direita', item='car_door', amount=1, tool='blowtorch', value=350, animation='torch', door=3 },
        bumperF = { label='Para-choque dianteiro', item='car_bumper', amount=1, tool='blowtorch', value=300, animation='torch', bumper=0 },
        bumperR = { label='Para-choque traseiro', item='car_bumper', amount=1, tool='blowtorch', value=300, animation='torch', bumper=1 },
        window0 = { label='Vidro dianteiro esquerdo', item='automotive_glass', amount=1, tool='toolbox', value=180, animation='body', window=0 },
        window1 = { label='Vidro dianteiro direito', item='automotive_glass', amount=1, tool='toolbox', value=180, animation='body', window=1 },
        windshield = { label='Para-brisa dianteiro', item='automotive_glass', amount=1, tool='toolbox', value=300, animation='body', window=6, bone='windscreen' },
        rearWindow = { label='Vidro traseiro', item='automotive_glass', amount=1, tool='toolbox', value=260, animation='body', window=7, bone='windscreen_r' },
        tyre0   = { label='Pneu dianteiro esquerdo', item='car_tyre', amount=1, tool='wheel_wrench', value=250, animation='tyre', tyre=0 },
        tyre1   = { label='Pneu dianteiro direito', item='car_tyre', amount=1, tool='wheel_wrench', value=250, animation='tyre', tyre=1 },
        tyre4   = { label='Pneu traseiro esquerdo', item='car_tyre', amount=1, tool='wheel_wrench', value=250, animation='tyre', tyre=4 },
        tyre5   = { label='Pneu traseiro direito', item='car_tyre', amount=1, tool='wheel_wrench', value=250, animation='tyre', tyre=5 },
        fuel    = { label='Sistema de combustivel', item='sheet_metal', amount=1, tool='toolbox', value=350, animation='under' },
        transmission = { label='Transmissao', item='sheet_metal', amount=1, tool='toolbox', value=500, animation='under' }
    }
}

Config.Damage = {
    collisionMultiplier = 0.32,
    minimumImpact = 8.0,
    maximumEngineLoss = 115.0,
    motorcycleMultiplier = 1.2,
    stopEngineAt = 80.0
}

Config.Airborne = {
    graceSeconds = 1.0,
    allTyresSeconds = 5.0,
    engineDamagePerSecond = 16.0,
    landingVerticalMultiplier = 0.65
}

Config.Offroad = {
    criticalSeconds = 5 * 60 * 60,
    minimumSpeed = 5.0,
    -- Materiais GTA tratados como estrada. Todo o restante desgasta pneu comum.
    roadMaterials = {
        [joaat('CONCRETE')] = true, [joaat('CONCRETE_POTHOLE')] = true,
        [joaat('CONCRETE_DUSTY')] = true, [joaat('TARMAC')] = true,
        [joaat('TARMAC_PAINTED')] = true, [joaat('RUMBLE_STRIP')] = true
    },
    offroadClasses = { [9] = true }, -- classe Off-road
    tyreWearPerSecond = 0.008
}

Config.Tyres = {
    normalWearPerKm = 0.015,
    slidingWearPerSecond = 0.12,
    burstAt = 0.0
}

Config.Rollover = {
    fireAfter = 3,
    extraDangerAfter = 5,
    decisionSeconds = 30,
    baseExplosionChance = 35,
    extraExplosionChance = 45
}

Config.Vertical = { angle = 70.0, seconds = 10.0 }

Config.TowModels = {
    [joaat('towtruck')] = { type = 'hook' },
    [joaat('towtruck2')] = { type = 'hook' },
    [joaat('flatbed')] = { type = 'flatbed', offset = vec3(0.0, -2.2, 1.05) }
}
