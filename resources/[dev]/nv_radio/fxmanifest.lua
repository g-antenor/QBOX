fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nv_radio'
description 'Rádio portátil com frequências, canais restritos e integração pma-voice'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_core',
    'ox_inventory',
    'pma-voice'
}

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
