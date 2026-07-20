fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Antigravity'
description 'Lojas 24/7 e Ammu-Nation com estoque, caixa e nota fiscal'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_core',
    'ox_inventory',
    'ox_target',
    'oxmysql'
}

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
