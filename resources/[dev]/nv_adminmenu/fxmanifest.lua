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
    -- Ordem importa: client.lua publica o `AdminTools` que panel.lua usa.
    'client.lua',
    'handling.lua',
    'client/panel.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/panel.css',
    'html/panel.js'
}

server_scripts {
    'server.lua',
    'server/panel.lua'
}

dependencies {
    'ox_lib',
    'ox_core'
}
