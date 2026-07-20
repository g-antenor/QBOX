--[[
    nv_sit — configuracao

    O ponto do assento NAO e fixo: e calculado em runtime a partir das
    dimensoes reais do modelo (GetModelDimensions), entao bancos de tamanhos e
    origens diferentes funcionam sem offset proprio. Alem disso o jogador senta
    ONDE MIROU, o que faz bancos longos terem varios lugares.

    `tune` e so uma correcao fina aplicada por cima do calculo automatico, para
    o caso de algum prop especifico ficar flutuando ou afundado.
      tune.x = ao longo do banco   (+ direita)
      tune.y = profundidade        (+ frente)
      tune.z = altura              (+ cima)

    Use /sitdebug para ajustar em jogo e imprimir os valores prontos.
]]

Config = {}

-- Distancia maxima para a opcao aparecer no target.
Config.TargetDistance = 1.6

-- Raio usado para considerar o assento ocupado por outro ped.
Config.OccupiedRadius = 0.7

-- Folga nas pontas do banco: impede sentar "pendurado" na quina.
Config.SeatMargin = 0.35

-- Altura do assento como fracao da altura total do prop.
-- 0.5 = metade da altura, que e mais ou menos onde fica o assento de um banco.
--
-- Isso normaliza props com origem no chao e props com origem no centro: os dois
-- acabam no mesmo ponto fisico. Aumente se o ped ainda ficar baixo; diminua se
-- ele flutuar acima do banco.
Config.SeatHeightRatio = 0.5

-- Tecla para levantar (38 = E).
Config.StandKey = 38

Config.Groups = {

    -- ------------------------------------------------------------------
    -- Bancos de praca / rua
    -- ------------------------------------------------------------------
    {
        label    = 'Sentar',
        icon     = 'fa-solid fa-chair',
        scenario = 'PROP_HUMAN_SEAT_BENCH',
        heading  = 180.0,
        tune     = vec3(0.0, 0.0, 0.0),
        models   = {
            `prop_bench_01a`,
            `prop_bench_01b`,
            `prop_bench_01c`,
            `prop_bench_02`,
            `prop_bench_03`,
            `prop_bench_04`,
            `prop_bench_05`,
            `prop_bench_06`,
            `prop_bench_07`,
            `prop_bench_08`,
            `prop_bench_09`,
            `prop_bench_10`,
            `prop_bench_11`,
            `prop_fib_3b_bench`,
        },
    },

    -- ------------------------------------------------------------------
    -- Cadeiras avulsas (um lugar so: o eixo longo praticamente nao existe)
    -- ------------------------------------------------------------------
    {
        label    = 'Sentar',
        icon     = 'fa-solid fa-chair',
        scenario = 'PROP_HUMAN_SEAT_CHAIR',
        heading  = 180.0,
        tune     = vec3(0.0, 0.0, 0.0),
        models   = {
            `prop_chair_01a`,
            `prop_chair_01b`,
            `prop_chair_02`,
            `prop_chair_03`,
            `prop_chair_04a`,
            `prop_chair_04b`,
            `prop_chair_05`,
            `prop_chair_06`,
            `prop_chair_07`,
            `prop_chair_08`,
            `prop_chair_09`,
            `prop_chair_10`,
            `prop_off_chair_01`,
            `prop_off_chair_04`,
            `prop_off_chair_05`,
            `v_ilev_hd_chair`,
        },
    },
}
