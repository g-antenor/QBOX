fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NV'
description 'Crafting independente com NUI, permissoes de organizacao e ox_inventory'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_core',
    'ox_inventory',
    'ox_target',
    'oxmysql'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client/main.lua'
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
