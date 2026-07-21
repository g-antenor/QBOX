fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Antigravity'
description 'HUD customizavel (status, bussola, microfone, radio e veiculo)'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_core'
}

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'

client_scripts {
    -- Primeiro e sem dependencias: garante que a HUD nativa nunca apareca,
    -- mesmo que o restante do resource falhe.
    'client/nativehud.lua',
    'client/settings.lua',
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/logo.svg'
}

-- Texturas de mascara do radar (quadrado/redondo). A pasta stream/ e
-- reconhecida automaticamente pelo FiveM; nao entra em `files`.
-- Origem: qbx_hud (github.com/Qbox-project/qbx_hud).
