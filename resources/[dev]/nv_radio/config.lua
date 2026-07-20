--[[
    nv_radio — configuração

    A frequência é exibida como X.Y (ex.: 12.5). O pma-voice trabalha com canal
    inteiro, entao a conversao e frequencia * 10 (12.5 -> canal 125). Isso da
    subcanais de graca, no mesmo esquema do qbx_radio.
]]

Config = {}

-- Item do ox_inventory necessário para usar o rádio.
Config.Item = 'radio'

-- Faixa permitida (uma casa decimal).
Config.MinFrequency = 1.0
Config.MaxFrequency = 500.0
Config.DefaultFrequency = 1.0

-- Volume inicial do rádio (0-100), repassado ao pma-voice.
Config.DefaultVolume = 20

-- Teto do volume. O rádio não deve competir com a voz de proximidade.
Config.MaxVolume = 60

-- Quantas frequências o jogador pode guardar como favorito.
Config.MaxSaved = 6

-- Som de clique ao começar/parar de falar.
Config.MicClickDefault = true

-- Intervalo da checagem de "ainda tenho o rádio / ainda estou vivo" (ms).
Config.WatchInterval = 3000

-- ============================================================================
-- FREQUÊNCIAS RESTRITAS
--
-- Só quem estiver em um dos grupos listados consegue sintonizar. A validação
-- é feita NO SERVIDOR — o cliente só desenha a interface.
--
-- Use os mesmos nomes de grupo do ox_core.
-- ============================================================================
Config.Restricted = {
    [100.0] = { 'police' },
    [200.0] = { 'ambulance' },
    [300.0] = { 'mechanic' },
}

-- ============================================================================
-- NOMES NO VISOR
-- Puramente cosmético: aparece no lugar de "LIVRE" quando sintonizado.
-- ============================================================================
Config.Labels = {
    [100.0] = 'POLÍCIA',
    [200.0] = 'SAMU',
    [300.0] = 'MECÂNICA',
}

-- ============================================================================
-- FILTRO DE VOZ
--
-- O pma-voice já cria um submix de rádio, mas bem discreto. Aqui montamos um
-- mais fechado e entregamos a ele via setEffectSubmix, deixando a voz com
-- cara de transmissão (banda estreita + ruído de modulação).
--
-- Faixa mais estreita = mais "walkie-talkie". rmMix é a intensidade do efeito.
-- ============================================================================
Config.VoiceFilter = {
    enabled = true,

    freqLow = 500.0,   -- corta os graves
    freqHigh = 2600.0, -- corta os agudos
    rmMix = 0.45,      -- 0.0 = limpo, 1.0 = muito distorcido
    outLow = 400.0,
    outHigh = 3000.0,
}
