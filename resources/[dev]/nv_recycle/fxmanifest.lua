fx_version 'cerulean'
game 'gta5'

author 'Antigravity'
description 'Sistema de Reciclagem e Vasculhar Lixeiras'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory'
}

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
