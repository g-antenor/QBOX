fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Antigravity'
description 'Gerenciamento de organizacoes: policia, hospital, jobs e gangs'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_core',
    'oxmysql',
    'ox_target'
}

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'

client_scripts {
    -- Ordem importa: main.lua declara o namespace `Panel`.
    'client/main.lua',
    'client/keys.lua',
    'client/place.lua',
    'client/stashes.lua',
    'client/garage.lua',
    'client/wardrobe.lua',
    'client/duty.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- Ordem importa: main.lua declara o namespace `Orgs` e o schema.
    'server/main.lua',
    'server/orgs.lua',
    'server/members.lua',
    'server/resources.lua',
    'server/garage.lua',
    'server/wardrobe.lua',
    'server/dealership.lua',
    'server/duty.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
