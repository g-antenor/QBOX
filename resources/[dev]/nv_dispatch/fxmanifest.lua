fx_version 'cerulean'
game 'gta5'

author 'Antigravity'
description 'Dispatch — alertas de ocorrencia para as corporacoes'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

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

dependencies {
    'ox_lib',
    'ox_core',
    'oxmysql'
}
