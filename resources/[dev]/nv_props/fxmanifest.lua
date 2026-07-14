fx_version 'cerulean'
lua54 'yes'
game 'gta5'

author 'Antigravity'
description 'Immersive physical prop drops and positioning system for ox_inventory'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory'
}

shared_script '@ox_lib/init.lua'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
