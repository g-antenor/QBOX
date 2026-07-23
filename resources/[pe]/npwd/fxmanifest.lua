fx_version("cerulean")
game("gta5")
name("nv_phone")
description("nv_phone - Celular NV2")
authors({ "itschip", "erik-sn", "TasoOneAsia", "kidz", "RockySouthpaw", "SamShanks", "c-wide", "mojito" })
version("3.15.1-beta.2")

shared_script "@ox_lib/init.lua"

client_scripts({
	"dist/game/client/cl_controls.lua",
	"dist/game/client/garage.lua",
	"dist/game/client/notification.lua",
	"dist/game/client/bank.lua",
	"dist/game/client/phone.lua",
})

server_scripts({
	"@oxmysql/lib/MySQL.lua",
	"dist/game/server/notification.lua",
	"dist/game/server/bank.lua",
	"dist/game/server/phone.lua",
})

exports({
	"createNotification",
	"Notify",
})

server_exports({
	"createNotification",
	"Notify",
})

ui_page("dist/html/index.html")

files({
	"config.json",
	"dist/html/index.html",
	"dist/html/**/*",
})

dependency({
	"screenshot-basic",
	"pma-voice",
	"oxmysql",
})
