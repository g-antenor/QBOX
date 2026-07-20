--[[
    nv_hunting — configuração

    Caça e pesca vivem no mesmo resource porque são a mesma coisa do ponto de
    vista do servidor: o jogador vence um minigame e o servidor decide o que
    cai. Dividir isso em dois scripts significava duplicar a validação, o
    cooldown e o alerta policial em dois lugares que precisavam concordar.

    Cada atividade tem a sua seção, e elas não se enxergam:

        config/hunting.lua  -> Config.Hunting
        config/fishing.lua  -> Config.Fishing

    Este arquivo só existe para declarar a tabela antes dos outros dois. A
    ordem está fixada no fxmanifest.
]]

Config = {}
