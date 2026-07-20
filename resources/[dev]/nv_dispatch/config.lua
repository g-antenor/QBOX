Config = {}

-- ============================================================================
-- CHAVE MESTRA
--
-- Enquanto isto for `false` o resource carrega inteiro, aceita chamadas e nao
-- notifica ninguem. Existe porque a instrucao vigente e "alertas a policia
-- desativados por hora": o codigo fica pronto, ligado por uma linha, em vez de
-- comentado pela metade e esquecido.
--
-- Ligar aqui liga TUDO -- inclusive os alertas que o nv_garage dispara.
-- ============================================================================
Config.Enabled = false

-- Subtipos de organizacao (nv_orgs) que recebem os alertas.
--
-- Nao e uma lista de grupos: e uma lista de SUBTIPOS. Criar uma segunda
-- corporacao de policia no painel de organizacoes ja a faz receber dispatch,
-- sem editar isto.
Config.Departments = { 'police' }

-- Departamento do MDT que recebe os chamados como historico (`AddCall`).
-- nil desliga o registro no MDT e deixa o alerta so na tela.
Config.MdtDepartment = 'policia'

-- ============================================================================
-- TELA
-- ============================================================================

-- Quantos alertas ficam empilhados ao mesmo tempo. O mais antigo cai fora.
Config.MaxOnScreen = 4

-- Quanto tempo cada alerta fica na tela (ms).
Config.Duration = 18000

-- Tecla que marca no mapa o alerta mais recente.
--
-- Um alerta que voce nao consegue transformar em rota e so texto. O TODO pede
-- "uma bind que marque no mapa ao clicar" -- clicar num NUI sem foco nao e
-- possivel sem roubar o mouse do jogador no meio de uma perseguicao, entao e
-- tecla.
Config.MarkKey = 'J'

-- Som de alerta novo. Mesmo criterio do cinto: "discreto" e escolha de som,
-- porque `PlaySoundFrontend` nao tem volume.
Config.Sound = {
    name = 'Menu_Accept',
    set  = 'Phone_SoundSet_Default'
}

-- ============================================================================
-- BLIP
-- ============================================================================
Config.Blip = {
    -- Segundos que o blip do alerta fica no mapa. O rastro precisa esfriar:
    -- um mapa com 40 blips de meia hora atras nao informa nada.
    duration = 180,

    -- Raio (m) da area desenhada. O alerta aponta uma REGIAO, nao um jogador:
    -- dizer o metro exato onde o ladrao esta transforma dispatch em radar.
    radius = 90.0,

    alpha = 80
}

-- ============================================================================
-- CATEGORIAS
--
-- `blipSprite`: https://docs.fivem.net/docs/game-references/blips/
-- `priority`: alta | media | baixa -- vai para o MDT e colore a borda.
-- `icon`: id de um <symbol> no index.html.
-- ============================================================================
Config.Categories = {
    roubo_civil = {
        label      = 'Roubo a civil',
        code       = '10-31',
        icon       = 'ic-pessoa',
        priority   = 'alta',
        blipSprite = 458,
        blipColor  = 1
    },

    roubo_veiculo = {
        label      = 'Roubo de veiculo',
        code       = '10-35',
        icon       = 'ic-carro',
        priority   = 'alta',
        blipSprite = 225,
        blipColor  = 1
    },

    roubo_caixa = {
        label      = 'Roubo a caixa eletronico',
        code       = '10-90',
        icon       = 'ic-caixa',
        priority   = 'alta',
        blipSprite = 108,
        blipColor  = 1
    },

    explosao_caixa = {
        label      = 'Explosao de caixa eletronico',
        code       = '10-80',
        icon       = 'ic-explosao',
        priority   = 'alta',
        blipSprite = 436,
        blipColor  = 1
    },

    -- A unica de prioridade baixa, e de proposito: ela nao diz o que esta
    -- acontecendo, so que alguem esta escondendo alguma coisa por perto.
    perda_sinal = {
        label      = 'Perda de sinal',
        code       = '10-6',
        icon       = 'ic-sinal',
        priority   = 'baixa',
        blipSprite = 184,
        blipColor  = 47
    }
}

-- ============================================================================
-- BLOQUEADOR DE SINAL
--
-- COMO FUNCIONA, e por que assim:
--
-- Sucesso  -> os alertas de roubo ficam mudos pelo tempo de `duration`, MAS um
--             alerta `perda_sinal` sai no lugar, com a posicao borrada por
--             `blur` metros e prioridade baixa. A policia fica sabendo que ha
--             algo acontecendo naquela regiao, sem saber o que nem onde
--             exatamente.
--
-- Falha    -> o item e gasto e nada e bloqueado. O ladrao so descobre quando o
--             alarme toca.
--
-- O bloqueador nao apaga o jogo policial, ele o troca por um pior para os dois
-- lados: e isso que faz valer a pena carregar um, e faz valer a pena a policia
-- atender um "perda de sinal".
-- ============================================================================
Config.Jammer = {
    item = 'bloqueador_sinal',

    -- Segundos de bloqueio depois de um uso bem-sucedido.
    duration = 180,

    -- Chance (%) de o aparelho falhar.
    failChance = 25,

    -- Tempo da barra de progresso ao usar (ms).
    useTime = 4000,

    -- Raio (m) do borrao na posicao do alerta de perda de sinal.
    blur = 150.0,

    -- Desgaste por uso (0-100). O item some sozinho ao zerar (decay).
    wear = {
        success = 25,
        fail    = 40
    }
}
