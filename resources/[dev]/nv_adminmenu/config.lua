Config = {}

-- ============================================================================
-- PAINEL DE ADMINISTRACAO
-- ============================================================================

-- Tecla que abre o painel. A MESMA tecla fecha.
--
-- F6 e uma escolha consciente: F1..F4 sao do jogo, F5 costuma ser inventario
-- ou celular em servidores de RP, F7 ja e o "voltar ao editor" do handling e
-- F8 e o console. Se colidir com algo no seu setup, troque aqui.
Config.PanelKey = 'F6'

-- ============================================================================
-- VEICULOS  (opcao "Adicionar Veiculo no Nome")
-- ============================================================================
Config.Vehicles = {
    -- O carro nasce na garagem mais proxima do JOGADOR que vai receber, e nao
    -- sempre na mesma. Quem esta em Sandy nao precisa atravessar o mapa para
    -- pegar um carro que acabaram de dar a ele.
    --
    -- false = usa sempre `garage` abaixo.
    useNearest = true,

    -- Garagem usada quando `useNearest` esta desligado, quando o jogador nao
    -- tem posicao (personagem ainda carregando) ou quando o nv_garage nao esta
    -- rodando. Precisa ser uma CHAVE de `Config.Garages` do nv_garage.
    garage = 'legion'
}

-- Common prop models to resolve hashes to string names during selection
Config.PropList = {
    -- Bins & Trash
    "prop_dumpster_01a", "prop_dumpster_01b", "prop_dumpster_02a", "prop_dumpster_02b",
    "prop_dumpster_4a", "prop_dumpster_4b", "prop_dumpster_3a", "prop_bin_01a",
    "prop_bin_02a", "prop_bin_03a", "prop_bin_04a", "prop_bin_05a", "prop_bin_06a",
    "prop_bin_07a", "prop_bin_08a", "prop_bin_08open", "prop_bin_09a", "prop_bin_10a",
    "prop_bin_10b", "prop_bin_11a", "prop_bin_12a", "prop_bin_13a", "prop_bin_14a",
    "prop_bin_14b", "prop_rub_binbag_01", "prop_rub_binbag_01b", "prop_rub_binbag_03",
    "prop_rub_binbag_04", "prop_rub_binbag_05", "prop_rub_binbag_06", "prop_rub_binbag_08",
    "prop_rub_trash_01a", "prop_rub_trash_02a", "prop_rub_trash_03a", "prop_rub_trash_04",
    "prop_rub_trash_05a", "prop_rub_trash_06", "prop_cardbordbox_02a", "prop_cs_box_step",
    "prop_cs_box_clothes"
}
