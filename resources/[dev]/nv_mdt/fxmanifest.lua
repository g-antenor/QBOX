fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Antigravity'
description 'MDT: terminal de policia, hospital e mecanica'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_core',
    'oxmysql'
}

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- Ordem importa: main.lua declara o namespace `Mdt` e cria o schema.
    'server/main.lua',
    'server/police.lua',
    -- Depois de police.lua: `Mdt.pendingInvoices` e usado pela ficha do cidadao,
    -- mas so em runtime, entao a ordem aqui e apenas de leitura.
    'server/invoices.lua',
    'server/hospital.lua',
    'server/mechanic.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
