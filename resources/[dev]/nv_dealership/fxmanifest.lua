fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NV'
description 'Concessionarias, estoque, vendas e entregas'

dependencies { 'ox_lib', 'ox_core', 'ox_inventory', 'ox_target', 'oxmysql', 'nv_garage', 'nv_orgs' }
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/tablet.css', 'html/app.js' }
