fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nv_police'
description 'Sistema de policia: algemas, revistar, testes de polvora/drogas, bafometro e props'
author 'NV2'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/cuffs.lua',
    'client/tests.lua',
    'client/props.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'ox_core',
    'ox_lib',
    'ox_inventory',
    'ox_target'
}

exports {
    'useHandcuffs',
    'useHandcuffKey',
    'useGunpowderTest',
    'useDrugTest',
    'useBreathalyzer',
    'useCone',
    'useBarricade',
    'useSpike'
}
