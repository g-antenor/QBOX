fx_version 'cerulean'
game 'gta5'

author 'Antigravity'
description 'Admin Menu with Prop Selector, Noclip, PedMenu, Teleportation, and Prop Alignment Editor'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'ox_lib',
    'ox_core'
}
