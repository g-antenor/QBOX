fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Antigravity'
description 'Chat local/DM/ADM/Alerta com nome de personagem (substitui o chat padrao)'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_core'
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
