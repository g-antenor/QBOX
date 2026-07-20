Config = {}

-- ============================================================================
-- GERAL
-- ============================================================================

-- Comando que abre o painel de controle da HUD.
Config.SettingsCommand = 'hud'

-- Tecla padrao do cinto de seguranca (nil desativa o keybind).
Config.SeatbeltKey = 'B'

-- ============================================================================
-- AVISO DE CINTO
--
-- Bipe curto e repetido enquanto o motorista anda sem cinto. Para sozinho em
-- exatamente tres situacoes: o carro para, o motor desliga ou o cinto entra.
-- ============================================================================
Config.SeatbeltBeep = {
    enabled = true,

    -- A partir de quantos km/h o aviso comeca.
    minSpeed = 2,

    -- O toque melodico dura 1,5 s; o intervalo deixa uma pausa limpa entre
    -- repeticoes enquanto o motorista continua sem cinto.
    interval = 3500,

    sound = {
        duration = 1500,
        volume = 0.12
    },

    -- Classes que nao tem cinto e por isso nunca avisam:
    -- 8 moto, 13 bicicleta, 14 barco, 15 helicoptero, 16 aviao.
    ignoreClasses = {
        [8] = true, [13] = true, [14] = true, [15] = true, [16] = true
    },

    -- Som do cinto travando / soltando.
    --
    -- O aviso dizia quando estava errado, mas nada confirmava quando ficava
    -- certo -- so a notificacao de texto, que voce le, nao ouve. O clique e o
    -- que faz o gesto terminar.
    --
    -- `buckle` e um clique seco (a lingueta entrando); `unbuckle` e o mesmo
    -- gesto ao contrario, mais suave. Trocar por qualquer par de
    -- name/set daqui: https://github.com/DurtyFree/gta-v-data-dumps
    buckle = {
        name = 'CLICK_BACK',
        set  = 'WEB_NAVIGATION_SOUNDS_PHONE'
    },

    unbuckle = {
        name = 'Highlight_Cancel',
        set  = 'DLC_HEIST_PLANNING_BOARD_SOUNDS'
    }
}

-- Taxa de atualizacao (ms).
Config.Tick = {
    status  = 250,  -- vida, colete, fome, sede, stress
    compass = 50,   -- direcao e nome da rua (a NUI ainda interpola entre eles)
    vehicle = 100   -- velocidade, marcha, combustivel
}

-- ============================================================================
-- HUD PADRAO DO GTA
-- ============================================================================
Config.DefaultHud = {
    -- A supressao em si NAO e configuravel: vive em client/nativehud.lua com
    -- valores fixos, para que nenhuma falha de config traga a HUD classica de
    -- volta. Isso tambem suprime help text e legendas nativas do jogo.

    -- Esconde a HUD do nv_hud enquanto o menu de pausa estiver aberto.
    hideOnPauseMenu = true
}

-- Bussola so aparece dentro de veiculo.
Config.CompassOnlyInVehicle = true

-- ============================================================================
-- MINIMAPA
-- O radar e um scaleform do jogo, entao ele nao e desenhado dentro da NUI:
-- a HUD mostra um retangulo-fantasma arrastavel e o radar real e movido para
-- acompanhar. Os numeros abaixo sao o espaco normalizado do jogo (0-1) e
-- podem precisar de um ajuste fino conforme a resolucao/safe zone.
-- ============================================================================
-- ============================================================================
-- MINIMAPA
--
-- Os valores abaixo vieram do qbx_hud (github.com/Qbox-project/qbx_hud), que
-- e uma implementacao ja rodada em producao. Duas licoes que mudaram tudo:
--
--  1. `SetMinimapClipType` EXISTE (0 = quadrado, 1 = redondo). Eu tinha
--     concluido o contrario porque a pagina de natives que consultei nao a
--     listava.
--  2. Cada formato tem seu PROPRIO conjunto de valores - inclusive a mascara,
--     que no modo redondo usa x = 0.200. Tentar servir os dois formatos com
--     uma base unica, como eu vinha fazendo, nunca poderia alinhar.
--
-- A correcao de proporcao para telas ultrawide e creditada ao Dalrae.
-- ============================================================================
Config.Minimap = {
    -- Valores por formato. `frame` descreve onde o radar aparece na tela
    -- (fracao da ALTURA para w/h), usado para desenhar a moldura da NUI.
    shapes = {
        quadrado = {
            clip = 0,
            dict = 'squaremap',
            minimap = { x =  0.0,   y = -0.047, w = 0.1638, h = 0.183 },
            mask    = { x =  0.0,   y =  0.0,   w = 0.128,  h = 0.200 },
            blur    = { x = -0.01,  y =  0.025, w = 0.262,  h = 0.300 },
            -- Medidas da moldura tiradas do CSS do qbx_hud (.square), que sao
            -- empiricas e ja batem com o radar. w/h sao fracao da ALTURA da
            -- tela (o CSS deles usa vh); left e fracao da largura.
            frame   = { w = 0.290, h = 0.185, left = 0.013, bottom = 0.063 }
        },

        redondo = {
            clip = 1,
            dict = 'circlemap',
            -- A largura vira h/proporcao em tempo de execucao (ver
            -- `circularWidth` no client). O qbx_hud usa 0.180 fixo, que em
            -- 16:9 estica a mascara circular e produz aquele oval; dividir a
            -- altura pela proporcao da tela devolve um circulo de verdade.
            -- `circular = true` faz a largura ser recalculada como
            -- altura/proporcao. Precisa valer para os TRES componentes: se so
            -- o `minimap` fica quadrado na tela, a mascara e o blur continuam
            -- esticados e o mapa sai oval do mesmo jeito.
            minimap = { x = -0.0100, y = -0.030, w = 0.180, h = 0.258, circular = true },
            mask    = { x =  0.200,  y =  0.0,   w = 0.065, h = 0.200, circular = true },
            blur    = { x =  0.0,    y =  0.015, w = 0.252, h = 0.338, circular = true },
            -- Moldura como circulo real: mesma medida nos dois eixos.
            frame   = { w = 0.229, h = 0.229, left = 0.020, bottom = 0.062 }
        }
    },

    -- Esconde o marcador de norte do radar (o "N" solto na borda).
    hideNorthBlip = true,

    -- Passo da calibragem fina da MOLDURA (setas no modo de edicao).
    -- Corrige so o desenho da NUI; nao mexe no radar.
    nudgeStep = 0.004
}

-- ============================================================================
-- LIMIARES DE ALERTA (piscar em vermelho)
-- ============================================================================
Config.Critical = {
    vida   = 20,  -- <= 20%
    colete = 20,  -- <= 20%
    fome   = 20,  -- <= 20% (valor exibido = saciedade)
    sede   = 20,  -- <= 20%
    stress = 80,  -- >= 80%
    fuel   = 15   -- <= 15%
}

-- ============================================================================
-- VALOR "IDEAL" DE CADA STATUS
-- Com `showAllStatus = false`, o item some quando esta nesse valor - a HUD so
-- mostra o que merece atencao. Colete usa 0 porque andar sem colete e o
-- estado normal, nao 100.
-- ============================================================================
Config.IdleValue = {
    vida   = 100,
    colete = 0,
    fome   = 100,
    sede   = 100,
    stress = 0
}

-- ============================================================================
-- MOTOR (piscar/vermelho fixo)
-- GetVehicleEngineHealth: 1000 = intacto, <= 0 = destruido.
-- ============================================================================
Config.Engine = {
    damaged   = 700, -- abaixo disso: pisca em vermelho
    destroyed = 100  -- abaixo disso: vermelho fixo, sem piscar
}

-- ============================================================================
-- FAIXAS DO COMBUSTIVEL
-- Acima de `low` = verde, entre `low` e `critical` = laranja,
-- abaixo de `critical` = vermelho piscando.
-- ============================================================================
Config.Fuel = {
    low      = 45,
    critical = 20
}

-- ============================================================================
-- PADROES DA HUD
-- Sao usados no primeiro acesso do jogador e ao clicar em "Resetar".
-- ============================================================================
Config.Defaults = {
    -- Formato dos elementos.
    minimapShape = 'quadrado', -- 'quadrado' | 'redondo'
    statusShape  = 'redondo',  -- 'redondo' | 'quadrado'
    compassStyle = 'padrao',   -- 'padrao' (regua) | 'compacta' (no mapa)

    -- Minimapa
    -- Deslocamento em fracao de tela, aplicado ao radar E a moldura.
    -- { 0, 0 } = posicao original do jogo. Ajustado arrastando com o mouse.
    minimapOffset = { x = 0.0, y = 0.0 },
    -- Calibragem exclusiva da moldura (setas no modo de edicao), para encostar
    -- a borda no radar sem mover o radar.
    borderOffset = { x = 0.0, y = 0.0 },

    -- Status
    showPercent = true,   -- porcentagem abaixo do icone
    -- 'auto'    = esconde o que estiver no valor ideal (Config.IdleValue)
    -- 'todos'   = sempre exibe todos
    -- 'selecao' = exibe apenas os marcados em `visible`
    statusMode  = 'auto',

    -- Visibilidade de cada elemento.
    visible = {
        vida    = true,
        colete  = true,
        fome    = true,
        sede    = true,
        stress  = true,
        minimap = true,
        compass = true,
        mic     = true,
        radio   = true,
        vehicle = true
    },

    -- Posicoes salvas pelo modo de edicao (percentuais da tela).
    -- Vazio = usa a ancoragem padrao definida no html/app.js.
    positions = {}
}

-- ============================================================================
-- VOZ (pma-voice)
-- O alcance vem pronto do state bag do pma-voice ("Sussurro", "Normal",
-- "Grito") e e exibido como texto. A UI propria dele fica desligada pelo
-- convar `voice_enableUi 0` no server.cfg.
-- ============================================================================
