Config = {}

-- Distancia maxima de interacao (metros)
Config.InteractionDistance = 2.0

-- Teclas padrao (Keybinds)
Config.Keybinds = {
    handsUp = 'X',
    pointing = 'B'
}

-- Itens configurados
Config.Items = {
    handcuffs     = 'handcuffs',
    handcuffKey   = 'handcuff_key',
    gunpowderTest = 'teste_polvora',
    drugTest      = 'teste_drogas',
    breathalyzer  = 'bafometro',
    cone          = 'police_cone',
    barricade     = 'police_barricade',
    spike         = 'police_spike'
}

-- Modelos de props para posicionamento
Config.Props = {
    ['police_cone'] = {
        model = `prop_roadcone02a`,
        label = 'Cone Policial'
    },
    ['police_barricade'] = {
        model = `prop_barrier_work05`,
        label = 'Barricada Policial'
    },
    ['police_spike'] = {
        model = `p_ld_strikebar_01`,
        label = 'Fita de Pregos (Spike)'
    }
}

-- Animacoes de algema e acoes policiais
Config.Anims = {
    handsUp = {
        dict = 'random@mugging3',
        clip = 'handsup_standing_base'
    },
    cuffArrest = {
        dict = 'mp_arrest_paired',
        cop = 'cop_p2_back',
        target = 'crook_p2_back'
    },
    cuffFront = {
        dict = 'anim@heists@fleeca_bank@hostages@cops',
        clip = 'cuffed_loop_left'
    },
    cuffBehind = {
        dict = 'anim@move_m@cuffed',
        clip = 'idle'
    },
    uncuff = {
        dict = 'mp_arresting',
        clip = 'a_uncuff'
    },
    search = {
        dict = 'anim@gangops@morgue@table@',
        clip = 'player_search'
    },
    sample = {
        dict = 'missheistdockssetup1clipboard@idle_a',
        clip = 'idle_a'
    }
}
