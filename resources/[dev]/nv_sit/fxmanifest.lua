fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nv_sit'
description 'Sentar em bancos e cadeiras pelo ox_target'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_target'
}

shared_script '@ox_lib/init.lua'

shared_script 'config.lua'

client_script 'client.lua'
