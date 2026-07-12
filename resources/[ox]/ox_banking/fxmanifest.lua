name 'ox_banking'
author 'Overextended'
version '1.0.6'
license 'MIT'
repository 'https://github.com/overextended/ox_banking.git'
description 'Banking system for ox_core'
fx_version 'cerulean'
game 'gta5'
ui_page 'dist/web/index.html'
lua54 'yes'

files {
	'dist/web/script.js',
	'dist/web/index.html',
	'dist/web/styles.css',
	'data/atms.json',
	'data/config.json',
	'data/banks.json',
	'locales/*.json',
}

dependencies {
	'/server:7290',
	'/onesync',
	'ox_core',
	'ox_lib',
	'oxmysql',
	'ox_inventory',
}

client_scripts {
	'@ox_lib/init.lua',
	'src/client/client.lua',
	'dist/client.js',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'dist/server.js',
}
