Config = {}

-- ============================================================================
-- ITENS
-- `lockpick` ja existe no ox_inventory. Os outros dois sao registrados por
-- este resource (ver README-ITENS.md).
-- ============================================================================
Config.Items = {
    key      = 'vehiclekey', -- chave; a placa vive no metadata
    cutters  = 'alicate',    -- alicate de corte, para ligacao direta
    lockpick = 'lockpick'    -- abre a tranca de fora
}

-- ============================================================================
-- TECLAS
-- ============================================================================
Config.Keybinds = {
    -- Liga/desliga o motor (so no banco do motorista).
    --
    -- Ligar tira a chave do inventario: ela fica na ignicao. Desligar devolve
    -- a chave a QUEM DESLIGOU -- e por isso que entrar num carro ligado e
    -- desliga-lo e uma forma legitima de ficar com ele.
    ignition = 'Z',
    -- Fora do veiculo: tranca/destranca o mais proximo com chave.
    -- Dentro: abre o painel de controle.
    lock     = 'L',

    -- Abre o painel de controle (portas, capo, porta-malas) em qualquer
    -- situacao -- inclusive de fora, que e como se abre o porta-malas.
    control  = 'K'
}

-- ============================================================================
-- IGNICAO
-- ============================================================================
Config.Ignition = {
    -- Nao existe opcao de "desligar sozinho ao sair do carro", e isso e de
    -- proposito: o motor continuar ligado E a mecanica. E o que permite roubar
    -- um carro em movimento e o que da sentido a regra de que desligar o motor
    -- entrega a chave a quem desligou.

    -- Tempo de partida antes do motor pegar (ms). 0 desativa a animacao.
    startTime = 1200,

    -- Veiculos que dispensam chave (emergencia, taxi da cidade, etc).
    -- Comparado com o nome do modelo em minusculas.
    noKeyModels = {
        -- ['police'] = true,
    }
}

-- ============================================================================
-- LIGACAO DIRETA (hotwire)
-- Precisa do alicate de corte no inventario. O item e consumido conforme
-- `consumeCutters`.
-- ============================================================================
Config.Hotwire = {
    duration    = 8000,  -- barra de progresso (ms)
    -- Preset do nv_minigames (skillbar). A dificuldade mora la, em
    -- nv_minigames/config.lua, nao aqui.
    minigame    = 'ligacao_direta',
    -- Consome o alicate ao concluir? false = ferramenta reutilizavel.
    consumeCutters = false,

    --[[
        CHOQUE AO ERRAR

        Encostar o fio errado da choque. E a unica punicao fisica da ligacao
        direta, e existe para o erro custar alguma coisa alem do tempo — sem
        isso, tentar de novo e sempre gratis.

        O dano nunca mata: `floor` e o piso de vida que o choque respeita. Com
        a vida ja abaixo dele, o jogador leva o tranco e o efeito, mas nao
        perde HP nenhum.
    ]]
    shock = {
        enabled = true,
        -- Vida perdida por falha, sorteada no intervalo.
        damage  = { 5, 12 },
        -- Piso de vida. No ox_core o jogador morre em 100, entao 105 deixa
        -- uma margem para o choque nunca ser a causa da morte.
        floor   = 105,
        -- Tempo (ms) que o jogador fica no chao levando o choque.
        ragdoll = 1200,
    },
    -- Falhar a ligacao direta chama a policia. Quem atende e o nv_dispatch, que
    -- so notifica se estiver ligado no config dele.
    alertEvent  = 'nv_dispatch:carTheft',
    -- Chance (0-100) de o alerta disparar quando falha.
    alertChance = 40
}

-- ============================================================================
-- TRANCAS
-- ============================================================================
Config.Lock = {
    -- Alcance para trancar/destrancar de fora, em metros.
    distance = 8.0,

    -- Pisca os faroies e toca o bipe ao trancar/destrancar de fora.
    feedback = true,

    -- Veiculos novos (recem comprados / sem registro) comecam trancados.
    defaultLocked = true,

    -- Como o jogo tranca o veiculo. Valores do SetVehicleDoorsLocked:
    --
    --    2 = trancado, MAS o GTA oferece quebrar o vidro e entrar
    --   10 = trancado e nao arrombavel pelo jogo
    --
    -- 10 e o padrao de proposito: com 2, o roubo nativo (quebrar janela,
    -- entrar, ligacao direta automatica) atropela o lockpick inteiro e nao
    -- sobra motivo para o jogador usar o item. Mude para 2 apenas se quiser o
    -- comportamento do jogo de volta.
    lockedState = 10
}

--[[
    VEICULOS SEM PORTA (classes do GTA)

    Moto nao tem fechadura de porta -- nao ha o que arrombar, e trancar so
    impediria de subir nela, o que na pratica quer dizer "ninguem rouba moto".
    Entao:

      * moto nunca e trancada fisicamente: da para tirar o piloto e subir;
      * o que a protege e a IGNICAO, que continua pedindo a chave;
      * o lockpick, numa moto, e usado sentado nela para vencer a trava do
        contato -- e o equivalente da ligacao direta, sem alicate.

    Classes: 8 = motos, 13 = bicicletas.
]]
Config.Doorless = {
    [8]  = true,
    [13] = true
}

-- Rotulos das portas. O indice e o mesmo do nativo `SetVehicleDoorOpen`.
-- Portas que o modelo nao tem sao filtradas em tempo de execucao com
-- `GetIsDoorValid`, entao nao ha problema em listar as seis.
Config.Doors = {
    [0] = 'Porta dianteira esquerda',
    [1] = 'Porta dianteira direita',
    [2] = 'Porta traseira esquerda',
    [3] = 'Porta traseira direita',
    [4] = 'Capo',
    [5] = 'Porta-malas'
}

-- ============================================================================
-- LOCKPICK
--
-- Abre UMA entrada, nao o veiculo. O carro continua trancado na logica: dentro
-- dele o jogador ainda precisa destrancar pelo menu. Se sair antes disso, ou
-- deixar a janela de entrada expirar, a tranca volta.
-- ============================================================================
Config.Lockpick = {
    duration   = 6000,
    -- Preset do nv_minigames (skillbar); dificuldade em nv_minigames/config.lua.
    minigame   = 'arrombar_tranca',

    -- Segundos que a porta arrombada aceita entrada antes de trancar de novo.
    entryWindow = 12,

    --[[
        DESGASTE (pontos de durabilidade, de 0 a 100)

        Substitui a antiga `breakChance`, que era um sorteio: 35% de perder a
        ferramenta inteira de uma vez, sem aviso nenhum antes. Durabilidade
        conta a mesma historia de forma legivel - o jogador ve a barra descendo
        e decide se arrisca mais uma. O lockpick some sozinho ao chegar a zero
        (item.decay no ox_inventory).
    ]]
    wear = {
        success     = 8,   -- arrombou
        fail        = 22,  -- errou o minigame
        interrupted = 5    -- o carro se moveu no meio
    },

    -- Acima desta velocidade (m/s) o carro conta como "em movimento" e o
    -- arrombamento e abortado. 1.0 m/s = 3.6 km/h: nao dispara com o carro
    -- apenas balancando.
    moveSpeed = 1.0,

    -- Falhar o arrombamento dispara o alarme do carro E o chamado a policia --
    -- os dois no mesmo sorteio (ver locks.lua). Passar sem que nada disso
    -- aconteca e o resultado de `100 - alertChance`.
    --
    -- Quem responde por este evento e o nv_dispatch, e ele so notifica de
    -- verdade se `Config.Enabled` estiver ligado la. Deixar preenchido aqui com
    -- o dispatch desligado nao alerta ninguem.
    alertEvent  = 'nv_dispatch:carTheft',
    alertChance = 50
}

--[[
    VEICULOS DO MUNDO (transito e estacionados)

    Todo veiculo que nao passou pelas maos de ninguem -- sem o statebag
    `nvLocked` -- e tratado aqui. Sao duas regras diferentes com o mesmo
    objetivo: a unica entrada num carro que nao e seu passa pelo lockpick e
    pela ligacao direta deste resource.

      lockUntracked : carro parado e vazio tambem fica trancado. Sem isto ele
                      fica com a tranca NATIVA do GTA (estado 2), que e a que
                      oferece quebrar o vidro e entrar -- e o roubo nativo
                      atropela o lockpick inteiro.
      lockNpcDriven : carro com NPC ao volante. Nada de arrancar o motorista
                      e sair dirigindo.

    Os dois usam `Config.Lock.lockedState` (10 = trancado e nao arrombavel).
]]
Config.WorldVehicles = {
    enabled = true,

    -- Carro parado, vazio e sem dono: trancado. Este e o que mata o roubo
    -- nativo; desligar volta a deixar o GTA decidir, e o vidro volta a quebrar.
    lockUntracked = true,

    -- Carro com NPC ao volante: trancado.
    lockNpcDriven = true,

    -- Aplica a regra do NPC so com o motor ligado (o carro "em uso"). Nao
    -- afeta `lockUntracked`, que vale justamente para o carro desligado.
    requireEngineOn = true,

    -- Raio de varredura em volta do jogador (m) e intervalo (ms).
    radius   = 30.0,
    interval = 900,

    -- Modelos que nunca sao trancados automaticamente. Os modelos de
    -- `Config.Ignition.noKeyModels` ja entram aqui sozinhos: um carro que
    -- dispensa chave nao faz sentido estar trancado contra voce.
    ignoreModels = {
        -- ['taxi'] = true,
    }
}

-- ============================================================================
-- GARAGENS
--
-- As vagas (`spawns`) sao o coracao do sistema: cada uma vira um marcador com
-- [E] no chao. Guardar em cima de uma vaga grava a posicao EXATA do carro, e
-- retirar devolve o carro naquele mesmo ponto se ele ainda estiver livre.
--
--   ped     = onde fica o marcador/zona que abre a lista
--   spawns  = vagas (x, y, z, heading)
--   impound = true marca o patio de apreensao (ver Config.Impound)
--   blip    = false desativa o icone no mapa
--
-- ATENCAO: as coordenadas vieram do ss-garage (Simplified-Studios), que e um
-- mapeamento publico do mapa base. Elas NAO foram conferidas dentro deste
-- servidor: se voce tem MLO ou mapa customizado em algum desses pontos, a vaga
-- pode cair dentro de parede. Agora que cada vaga tem marcador, isso e visivel
-- de longe. Use /nvgaragecoords para capturar a posicao certa e corrigir.
-- ============================================================================

local GARAGE_BLIP  = { sprite = 357, color = 3,  scale = 0.8 }
local IMPOUND_BLIP = { sprite = 68,  color = 1,  scale = 0.9 }

Config.Garages = {
    -- ---------------------------------------------------------- Los Santos --

    ['pillbox'] = {
        label  = 'Estacionamento Pillbox Hill',
        ped    = vec3(213.35, -795.13, 30.86),
        spawns = {
            vec4(221.54, -806.78, 30.67, 69.92),
            vec4(222.43, -804.28, 30.67, 75.82),
            vec4(223.26, -801.83, 30.66, 74.33),
            vec4(224.13, -799.34, 30.66, 67.34),
            vec4(225.42, -796.97, 30.65, 68.20),
            vec4(231.41, -807.54, 30.46, 246.18),
            vec4(232.58, -805.12, 30.46, 253.25),
            vec4(233.64, -802.61, 30.47, 254.70),
            vec4(234.41, -800.09, 30.49, 252.28),
            vec4(235.28, -797.45, 30.50, 265.21)
        },
        blip = GARAGE_BLIP
    },

    ['motel'] = {
        label  = 'Estacionamento do Motel',
        ped    = vec3(285.40, -346.73, 44.94),
        spawns = {
            vec4(283.99, -342.49, 44.92, 69.53),
            vec4(285.30, -339.29, 44.92, 72.09),
            vec4(286.57, -336.12, 44.92, 68.81),
            vec4(287.89, -332.93, 44.92, 67.15),
            vec4(289.20, -329.76, 44.92, 67.61),
            vec4(293.30, -345.87, 44.92, 252.00),
            vec4(294.52, -342.76, 44.92, 246.73),
            vec4(295.55, -339.41, 44.92, 251.73)
        },
        blip = GARAGE_BLIP
    },

    ['sapcounsel'] = {
        label  = 'Estacionamento San Andreas',
        ped    = vec3(-331.07, -778.99, 33.96),
        spawns = {
            vec4(-341.51, -767.35, 33.97, 91.59),
            vec4(-341.80, -764.63, 33.97, 93.64),
            vec4(-342.86, -756.77, 33.97, 270.87),
            vec4(-337.40, -751.69, 33.97, 0.37),
            vec4(-334.43, -751.73, 33.97, 4.30),
            vec4(-331.82, -751.75, 33.97, 2.74),
            vec4(-328.88, -751.72, 33.97, 2.87)
        },
        blip = GARAGE_BLIP
    },

    ['caears24'] = {
        label  = 'Estacionamento Caears 24',
        ped    = vec3(68.84, 16.29, 69.14),
        spawns = {
            vec4(64.25, 17.37, 69.23, 164.09),
            vec4(61.22, 18.51, 69.29, 160.25),
            vec4(58.17, 19.59, 69.39, 160.61),
            vec4(55.19, 20.83, 69.64, 151.07)
        },
        blip = GARAGE_BLIP
    },

    ['caears24sul'] = {
        label  = 'Estacionamento Caears 24 (Sul)',
        ped    = vec3(-453.61, -796.90, 30.55),
        spawns = {
            vec4(-459.46, -806.76, 30.54, 89.32),
            vec4(-459.29, -803.54, 30.54, 93.59),
            vec4(-459.15, -800.30, 30.54, 95.22),
            vec4(-459.23, -797.29, 30.55, 91.25),
            vec4(-467.86, -797.27, 30.55, 270.24),
            vec4(-467.99, -800.44, 30.54, 268.92),
            vec4(-467.75, -803.56, 30.54, 269.20),
            vec4(-467.78, -806.71, 30.54, 270.85)
        },
        blip = GARAGE_BLIP
    },

    ['laguna'] = {
        label  = 'Estacionamento Laguna',
        ped    = vec3(366.01, 295.98, 103.44),
        spawns = {
            vec4(362.41, 293.31, 103.49, 70.38),
            vec4(361.07, 289.67, 103.48, 71.12),
            vec4(359.87, 285.86, 103.47, 73.93),
            vec4(358.42, 282.18, 103.38, 68.42),
            vec4(374.64, 293.39, 103.27, 350.49),
            vec4(378.55, 292.07, 103.19, 344.72),
            vec4(382.33, 291.10, 103.11, 341.45),
            vec4(386.32, 289.83, 103.05, 343.43),
            vec4(371.55, 285.94, 103.26, 160.28),
            vec4(375.29, 284.75, 103.19, 160.42),
            vec4(378.99, 283.13, 103.11, 160.02)
        },
        blip = GARAGE_BLIP
    },

    ['aeroporto'] = {
        label  = 'Estacionamento do Aeroporto',
        ped    = vec3(-784.42, -2035.50, 8.87),
        spawns = {
            vec4(-778.68, -2038.98, 8.88, 137.88),
            vec4(-776.35, -2041.41, 8.89, 141.10),
            vec4(-773.85, -2043.84, 8.89, 138.44),
            vec4(-771.43, -2046.31, 8.90, 135.15),
            vec4(-769.00, -2048.79, 8.90, 141.19),
            vec4(-766.59, -2051.23, 8.90, 130.35),
            vec4(-764.35, -2053.66, 8.90, 134.26),
            vec4(-762.00, -2056.31, 8.90, 135.78),
            vec4(-759.42, -2058.61, 8.91, 133.74),
            vec4(-757.10, -2060.93, 8.91, 135.77)
        },
        blip = GARAGE_BLIP
    },

    ['praia'] = {
        label  = 'Estacionamento da Praia',
        ped    = vec3(-1186.39, -1505.35, 4.38),
        spawns = {
            vec4(-1184.20, -1496.47, 4.38, 298.41),
            vec4(-1185.94, -1493.84, 4.38, 303.72),
            vec4(-1187.59, -1491.26, 4.38, 299.91),
            vec4(-1189.48, -1488.77, 4.38, 303.77),
            vec4(-1191.43, -1486.19, 4.38, 304.57),
            vec4(-1192.93, -1483.57, 4.38, 303.14),
            vec4(-1176.11, -1490.85, 4.38, 128.26),
            vec4(-1177.81, -1488.50, 4.38, 126.47),
            vec4(-1179.50, -1485.93, 4.38, 126.56)
        },
        blip = GARAGE_BLIP
    },

    ['casino'] = {
        label  = 'Estacionamento do Cassino',
        ped    = vec3(884.25, -3.92, 78.76),
        spawns = {
            vec4(881.88, -15.23, 78.76, 237.01),
            vec4(880.08, -18.24, 78.76, 238.06),
            vec4(878.21, -20.97, 78.76, 243.91),
            vec4(876.47, -24.12, 78.76, 244.03),
            vec4(874.72, -26.90, 78.76, 236.26),
            vec4(890.36, -20.58, 78.76, 62.48),
            vec4(888.47, -23.47, 78.76, 58.66),
            vec4(886.57, -26.42, 78.76, 57.02),
            vec4(884.82, -29.32, 78.76, 55.08)
        },
        blip = GARAGE_BLIP
    },

    -- ------------------------------------------------------------ interior --

    ['sandy'] = {
        label  = 'Estacionamento Sandy Shores',
        ped    = vec3(1137.67, 2664.16, 38.00),
        spawns = {
            vec4(1131.54, 2648.87, 38.00, 187.25),
            vec4(1127.51, 2648.94, 38.00, 181.55),
            vec4(1124.12, 2648.92, 38.00, 188.42),
            vec4(1120.38, 2648.97, 38.00, 180.07),
            vec4(1116.63, 2648.82, 38.00, 178.76),
            vec4(1113.23, 2654.20, 38.00, 88.38),
            vec4(1112.98, 2657.89, 38.00, 96.84)
        },
        blip = GARAGE_BLIP
    },

    ['grapeseed'] = {
        label  = 'Estacionamento Grapeseed',
        ped    = vec3(895.47, 3649.74, 32.79),
        spawns = {
            vec4(898.76, 3646.06, 32.77, 269.45),
            vec4(898.66, 3649.52, 32.77, 268.03),
            vec4(898.72, 3652.98, 32.77, 268.18)
        },
        blip = GARAGE_BLIP
    },

    ['paleto'] = {
        label  = 'Estacionamento Paleto Bay',
        ped    = vec3(85.00, 6393.00, 31.38),
        spawns = {
            vec4(80.10, 6395.31, 31.23, 312.10),
            vec4(77.54, 6397.75, 31.23, 317.14),
            vec4(74.48, 6400.48, 31.23, 311.71),
            vec4(71.73, 6403.13, 31.23, 320.09)
        },
        blip = GARAGE_BLIP
    },

    -- ------------------------------------------------- patio de apreensao --
    --
    -- `impound = true` muda tudo o que interessa: a lista mostra SO os
    -- veiculos apreendidos, nao da para guardar nada aqui, a retirada cobra a
    -- taxa do Config.Impound e o carro sai numa vaga do patio -- e nao no
    -- lugar onde o dono o havia deixado, porque ele veio de guincho.
    ['patio'] = {
        label   = 'Patio de Apreensao',
        ped     = vec3(409.65, -1623.39, 29.29),
        impound = true,
        spawns  = {
            vec4(419.72, -1635.86, 29.29, 271.06),
            vec4(419.75, -1638.83, 29.29, 265.56),
            vec4(419.68, -1641.92, 29.29, 271.07),
            vec4(417.57, -1645.68, 29.29, 231.22),
            vec4(418.78, -1630.38, 29.29, 321.42),
            vec4(416.61, -1628.38, 29.29, 318.89)
        },
        blip = IMPOUND_BLIP
    }
}

-- ============================================================================
-- ATENDENTES
--
-- Um ped em pe no ponto da garagem. Com ox_target ele VIRA o alvo (mirar a
-- pessoa e mais claro do que mirar um ponto no ar onde ela por acaso esta);
-- sem ox_target ele e so cenario e quem abre a lista continua sendo o [E].
--
-- `pedHeading` em cada garagem controla para onde ele olha (0 = norte). Sem
-- isso todos encaram o mesmo lado, e um ou outro fica de costas para quem
-- chega -- use /nvgaragecoords, que ja imprime o heading atual.
-- ============================================================================
Config.Peds = {
    enabled = true,

    -- As coordenadas `ped` das garagens sao de quem esta EM PE ali, ou seja,
    -- vem na altura dos olhos. Sem este desconto o atendente nasce flutuando.
    zOffset = -1.0,

    garage = {
        model    = 'cs_floyd',
        scenario = 'WORLD_HUMAN_CLIPBOARD'
    },

    impound = {
        model    = 'csb_trafficwarden',
        scenario = 'WORLD_HUMAN_CLIPBOARD'
    }
}

-- ============================================================================
-- PATIO DE APREENSAO
-- ============================================================================
Config.Impound = {
    -- Taxa minima, cobrada assim que o veiculo chega ao patio.
    baseFee = 100,

    -- Acrescimo por dia completo parado no patio. O relogio comeca quando o
    -- carro entra e NAO reinicia: deixar o veiculo esquecido custa caro.
    dailyFee = 100,

    -- Acrescimo unico para veiculo que chegou destruido (explodiu). E o
    -- conserto, nao o guincho, por isso e bem maior que a diaria.
    destroyedFee = 700,

    -- Item usado como dinheiro no ox_inventory. A taxa sai do dinheiro EM
    -- MAOS: nada de debitar conta bancaria.
    moneyItem = 'money',

    -- Vida de motor (0-1000) a partir da qual o veiculo conta como destruido.
    destroyedEngineHealth = 0,

    -- Intervalo da varredura que procura veiculos destruidos (ms).
    scanInterval = 15000,

    -- Intervalo da varredura que carimba a data de entrada no patio (ms).
    -- Precisa existir porque o ox_core manda veiculos para o patio sozinho
    -- (no restart do servidor, por exemplo), sem passar por este resource.
    stampInterval = 120000
}

-- ============================================================================
-- COMPORTAMENTO DA GARAGEM
-- ============================================================================
Config.Garage = {
    -- true  = ox_target (zona clicavel)
    -- false = marcador no chao + tecla E
    useTarget = true,

    -- Raio da zona de interacao (m).
    radius = 2.0,

    -- Distancia maxima do ponto da garagem para conseguir guardar (m).
    storeDistance = 30.0,

    -- Descer do carro (com a animacao normal) antes de guardar.
    --
    -- false guarda com o jogador ainda no banco, e o carro some por baixo
    -- dele: o ped fica um instante flutuando na posicao de dirigir antes de
    -- cair no chao.
    exitAnimation = true,

    -- Cada veiculo so volta para a garagem de onde saiu?
    -- false = qualquer garagem aceita qualquer veiculo (mais amigavel).
    strictReturn = false,

    -- Nome que o ox_core usa para o patio de apreensao. Veiculos nesse estado
    -- aparecem na lista mas nao podem ser retirados.
    impoundName = 'impound',

    -- Raio de interacao de cada VAGA (m). Menor que o da garagem: uma vaga e
    -- um lugar especifico, e raios grandes fazem duas vagas vizinhas
    -- disputarem o mesmo [E].
    spotRadius = 3.0,

    -- Marcador de cada vaga. Mais discreto que o da garagem, porque sao
    -- varios na tela ao mesmo tempo.
    -- Desenhar o marcador de cada vaga no chao?
    --
    -- Desligado: com vagas lado a lado, meia duzia de circulos acesos ao mesmo
    -- tempo suja mais do que ajuda. O [E] aparece ao chegar perto e resolve.
    -- Ligue temporariamente se precisar conferir se alguma vaga caiu dentro de
    -- parede.
    showSpotMarkers = false,

    spotMarker = {
        type  = 27,
        scale = vec3(1.8, 1.8, 1.0),
        color = { r = 255, g = 36, b = 56, a = 90 },
        drawDistance = 25.0
    },

    -- Marcador (so quando useTarget = false).
    marker = {
        type  = 36,
        scale = vec3(0.7, 0.7, 0.7),
        color = { r = 255, g = 36, b = 56, a = 140 },
        drawDistance = 15.0
    }
}

-- ============================================================================
-- FAIXAS DE COR DAS BARRAS NA NUI
-- Acima de `good` = verde, acima de `warn` = laranja, abaixo = vermelho.
-- ============================================================================
Config.Bars = {
    good = 70,
    warn = 35
}
