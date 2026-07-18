fx_version 'cerulean'
game 'gta5'

author 'Antigravity'
description 'Logistica Unificada de Entregas (Pacotes, Postos e Lojas)'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql'
}

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'

client_scripts {
    'client/deliverybox.lua',
    'client/gas_stations.lua',
    'client/shops_247.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/deliverybox.lua',
    'server/gas_stations.lua',
    'server/shops_247.lua'
}
