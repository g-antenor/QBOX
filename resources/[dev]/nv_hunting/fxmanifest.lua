fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nv_hunting'
description 'Caça e pesca: abate, esfola, arremesso e drops por animal/tier'
version '2.0.0'

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'nv_minigames'
}

shared_script '@ox_lib/init.lua'

shared_scripts {
    -- Ordem importa: init.lua declara a tabela Config que os outros preenchem.
    'config/init.lua',
    'config/hunting.lua',
    'config/fishing.lua'
}

client_scripts {
    'client/hunting.lua',
    'client/fishing.lua'
}

server_scripts {
    'server/hunting.lua',
    'server/fishing.lua'
}
