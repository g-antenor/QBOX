fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Antigravity'
description 'Garagem, chaves de veiculo, ignicao, trancas e ligacao direta'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_core',
    'ox_inventory',
    'oxmysql',
    'nv_minigames'
}

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'

client_scripts {
    -- Ordem importa: main.lua declara o namespace usado pelos demais.
    'client/main.lua',
    'client/keys.lua',
    'client/locks.lua',
    'client/garage.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/garage.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
