--[[
    nv_minigames — configuracao

    Em vez de espalhar numeros magicos pelos scripts que chamam os minigames,
    registre aqui um PRESET com nome e chame por ele:

        exports.nv_minigames:Start('arrombar_porta')

    Assim, balancear a dificuldade de uma atividade e mexer neste arquivo,
    sem tocar no codigo que a usa.
]]

Config = {}

-- ---------------------------------------------------------------- padroes --

-- Usados quando o preset (ou a chamada) nao especificar.
Config.Default = {
    difficulty = 'medium',  -- 'easy' | 'medium' | 'hard'
    timeout    = 30000,     -- ms ate a partida falhar sozinha
}

-- Se true, um preset inexistente cai no Config.Fallback em vez de falhar.
-- Deixe false enquanto desenvolve, para pegar erro de digitacao cedo.
Config.AllowUnknownPreset = false
Config.Fallback = { game = 'skillbar', difficulty = 'medium' }

-- ----------------------------------------------------------------- presets --
--
-- Cada preset precisa de `game`. O resto e opcional e sobrescreve o preset de
-- dificuldade do proprio jogo.
--
--   game = 'locked'   -> pins, zone (graus), speed (graus/s)
--   game = 'mines'    -> size (lado da grade), mines, reveals
--   game = 'skillbar' -> rounds, zone (% da barra), speed (%/s)
--   game = 'timing'   -> rounds, window (% da barra), duration (ms por rodada)
--
Config.Presets = {

    -- Fechaduras / arrombamento -------------------------------------------
    ['arrombar_porta'] = {
        game       = 'locked',
        difficulty = 'medium',
        pins       = 4,
    },
    ['arrombar_veiculo'] = {
        game       = 'locked',
        difficulty = 'hard',
        pins       = 5,
        timeout    = 25000,
    },
    ['cofre'] = {
        game       = 'locked',
        difficulty = 'hard',
        pins       = 6,
        speed      = 320,
        timeout    = 45000,
    },

    -- Risco / sabotagem ----------------------------------------------------
    ['desarmar'] = {
        game       = 'mines',
        difficulty = 'hard',
        size       = 5,
        mines      = 8,
        reveals    = 7,
    },
    ['hackear'] = {
        game       = 'mines',
        difficulty = 'medium',
        size       = 5,
        mines      = 5,
        reveals    = 6,
    },

    -- Pericia manual -------------------------------------------------------
    ['reparo'] = {
        game       = 'skillbar',
        difficulty = 'medium',
        rounds     = 3,
    },
    ['lockpick_rapido'] = {
        game       = 'skillbar',
        difficulty = 'easy',
        rounds     = 2,
    },

    --- Lockpick na tranca do veiculo (nv_garage / locks.lua).
    ['arrombar_tranca'] = {
        game       = 'skillbar',
        difficulty = 'medium',
        rounds     = 3,
        timeout    = 25000,
    },

    --- Ligacao direta com alicate ou lockpick (nv_garage / keys.lua).
    --- Mais dificil que a tranca: errar aqui toma choque e tira vida.
    ['ligacao_direta'] = {
        game       = 'skillbar',
        difficulty = 'hard',
        rounds     = 3,
        zone       = 12,
        timeout    = 25000,
    },

    --- Vasculhar a pilha de sucata (nv_recycle). A dificuldade sobe a cada
    --- rodada de busca: o caller passa `zone`/`speed` como override.
    ['reciclagem'] = {
        game       = 'skillbar',
        difficulty = 'medium',
        rounds     = 3,
        timeout    = 25000,
    },

    -- Sincronia ------------------------------------------------------------
    ['abastecer'] = {
        game       = 'timing',
        difficulty = 'easy',
        rounds     = 2,
    },
    ['ignicao'] = {
        game       = 'timing',
        difficulty = 'hard',
        rounds     = 3,
        window     = 8,
    },

    --- Corte na carcaca (nv_hunting / hunting.lua).
    ['esfolar'] = {
        game       = 'timing',
        difficulty = 'medium',
        rounds     = 2,
        window     = 16,
    },

    --[[
        Pesca (nv_hunting / fishing.lua), um preset por tier do peixe.

        O tier sai do calculo de profundidade + distancia da costa; quanto
        maior, mais briga o peixe da. Balancear a pesca e mexer nestes cinco
        presets, sem tocar no client.
    ]]
    ['pescar_t0'] = { game = 'timing', difficulty = 'easy',   rounds = 1, window = 26 },
    ['pescar_t1'] = { game = 'timing', difficulty = 'easy',   rounds = 2, window = 22 },
    ['pescar_t2'] = { game = 'timing', difficulty = 'medium', rounds = 2, window = 16 },
    ['pescar_t3'] = { game = 'timing', difficulty = 'medium', rounds = 3, window = 13 },
    ['pescar_t4'] = { game = 'timing', difficulty = 'hard',   rounds = 4, window = 9 },
}
