--[[
    nv_hunting — configuração da CAÇA

    Fluxo: abate o animal com uma arma de caça -> mira no corpo pelo ox_target
    -> "Esfolar" com a faca equipada -> minigame -> recebe os drops. Depois de
    N cortes o corpo é removido.
]]

Config.Hunting = {}

-- Faca necessária na mão para esfolar.
--
-- Isto NÃO esconde mais a opção do target: sem faca, "Esfolar" continua
-- aparecendo e avisa o que falta. Portão invisível é indistinguível de bug para
-- quem está jogando.
Config.Hunting.Knife = `WEAPON_KNIFE`

-- Exigir que o animal tenha morrido de forma aproveitável?
Config.Hunting.CheckKillWeapon = true

--[[
    CAUSAS DE MORTE REJEITADAS

    Antes isto era uma lista de armas PERMITIDAS, com cinco entradas (musket,
    três snipers e faca). Qualquer outra coisa — pistola, escopeta, fuzil —
    deixava a carcaça inesfolável, e sem nenhuma mensagem explicando. Era o
    motivo mais provável de "matei o bicho e não aparece nada".

    Invertido: a regra que se queria de verdade é "não vale atropelar nem
    explodir". Então lista-se o que NÃO conta, e qualquer arma de verdade passa.
    Uma lista de bloqueio erra para o lado permissivo; uma de permissão erra
    para o lado que trava o jogador.
]]
Config.Hunting.RejectedCauses = {
    [`WEAPON_RUN_OVER_BY_CAR`] = 'atropelado',
    [`WEAPON_RAMMED_BY_CAR`]   = 'atropelado',
    [`WEAPON_EXPLOSION`]       = 'explodido',
    [`WEAPON_FALL`]            = 'morto pela queda',
    [`WEAPON_DROWNING`]        = 'afogado',
    [`WEAPON_DROWNING_IN_VEHICLE`] = 'afogado',
    [`WEAPON_FIRE`]            = 'queimado',
}

-- Distância do target no corpo do animal.
Config.Hunting.TargetDistance = 1.8

-- Preset do nv_minigames rodado a cada corte (jogo `timing`). A dificuldade
-- mora em nv_minigames/config.lua, não aqui.
Config.Hunting.Minigame = 'esfolar'

-- Tempo da animação de corte (ms).
Config.Hunting.CutDuration = 4000

--[[
    ANIMAIS

    cuts   : { min, max } cortes até o corpo sumir
    drops  : cada corte sorteia a lista; `chance` é a probabilidade em %
             de aquele item sair naquele corte
]]
Config.Hunting.Animals = {
    [`a_c_boar`] = {
        label = 'Javali',
        cuts = { 3, 5 },
        drops = {
            { item = 'meat_boar', min = 1, max = 2, chance = 85 },
            { item = 'hide_boar', min = 1, max = 1, chance = 45 },
        }
    },

    [`a_c_deer`] = {
        label = 'Cervo',
        cuts = { 2, 3 },
        drops = {
            { item = 'meat_deer', min = 1, max = 2, chance = 85 },
            { item = 'hide_deer', min = 1, max = 1, chance = 50 },
        }
    },

    [`a_c_coyote`] = {
        label = 'Coiote',
        cuts = { 2, 3 },
        drops = {
            { item = 'meat_coyote', min = 1, max = 1, chance = 75 },
            { item = 'hide_coyote', min = 1, max = 1, chance = 45 },
        }
    },

    [`a_c_mtlion`] = {
        label = 'Leão da Montanha',
        cuts = { 2, 3 },
        drops = {
            { item = 'meat_mtlion', min = 1, max = 2, chance = 80 },
            { item = 'hide_mtlion', min = 1, max = 1, chance = 55 },
        }
    },

    [`a_c_rabbit_01`] = {
        label = 'Coelho',
        cuts = { 1, 2 },
        drops = {
            { item = 'meat_rabbit', min = 1, max = 1, chance = 80 },
            { item = 'hide_rabbit', min = 1, max = 1, chance = 40 },
        }
    },

    [`a_c_rat`] = {
        label = 'Rato',
        cuts = { 1, 1 },
        drops = {
            { item = 'meat_rat', min = 1, max = 1, chance = 60 },
            { item = 'hide_rat', min = 1, max = 1, chance = 30 },
        }
    },

    [`a_c_crow`] = {
        label = 'Corvo',
        cuts = { 1, 2 },
        drops = {
            { item = 'meat_crow', min = 1, max = 1, chance = 70 },
        }
    },

    [`a_c_seagull`] = {
        label = 'Gaivota',
        cuts = { 1, 2 },
        drops = {
            { item = 'meat_seagull', min = 1, max = 1, chance = 70 },
        }
    },

    [`a_c_cormorant`] = {
        label = 'Cormorão',
        cuts = { 1, 2 },
        drops = {
            { item = 'meat_cormorant', min = 1, max = 1, chance = 70 },
        }
    },

    [`a_c_chickenhawk`] = {
        label = 'Falcão',
        cuts = { 1, 2 },
        drops = {
            { item = 'meat_chickenhawk', min = 1, max = 1, chance = 70 },
        }
    },
}

-- ============================================================================
-- ALERTA POLICIAL
-- Desativado por enquanto, a pedido. A chamada já existe no server, basta
-- ligar aqui e preencher o evento do seu dispatch.
-- ============================================================================
Config.Hunting.PoliceAlert = {
    enabled = false,
    chance = 15,          -- % de chance por abate
    event = nil,          -- ex.: 'dispatch:server:huntingShot'
}
