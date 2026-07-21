fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Antigravity'
description 'Danos, desgaste, inspecoes e ordens de servico persistentes'
version '1.0.0'

dependencies { 'ox_lib', 'ox_core', 'ox_inventory', 'ox_target', 'oxmysql', 'nv_orgs' }

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_scripts { 'client/main.lua', 'client/orders.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua', 'server/orders.lua' }
