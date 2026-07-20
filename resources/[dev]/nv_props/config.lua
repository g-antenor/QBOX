Config = {}

-- Modelo usado quando o item nao esta mapeado abaixo (ou quando o modelo
-- mapeado falha ao spawnar).
Config.DefaultModel = `prop_paper_bag_01`

--[[
    Mapeamento item do ox_inventory -> modelo do prop dropado.

    Somente itens presentes nesta lista viram prop fisico ao serem dropados;
    os demais caem no drop normal do ox_inventory. Para dar corpo fisico a um
    item novo, basta adicionar a linha aqui.

    Alguns modelos sao aproximacoes tematicas (nem todo item tem um prop
    equivalente no jogo base) — trocar e so editar o modelo da linha.
]]
Config.Items = {

    -- ------------------------------------------------------------------
    -- Bebidas e comida
    -- ------------------------------------------------------------------
    ['water']                  = `prop_ld_flow_bottle`,
    ['cola']                   = `prop_ecola_can`,
    ['sprunk']                 = `prop_ecola_can`,
    ['burger']                 = `prop_cs_burger_01`,
    ['testburger']             = `prop_cs_burger_01`,
    ['mustard']                = `prop_ld_flow_bottle`,
    ['coffee_cup']             = `p_ing_coffeecup_01`,

    -- ------------------------------------------------------------------
    -- Recicláveis / lixo
    -- ------------------------------------------------------------------
    ['glass']                  = `prop_beer_bottle`,
    ['plastic_bottle']         = `prop_ld_flow_bottle`,
    ['empty_can']              = `prop_ecola_can`,
    ['chips_bag']              = `prop_paper_bag_01`,
    ['beer_bottle_empty']      = `prop_beer_bottle`,
    ['wine_bottle_empty']      = `prop_wine_rose`,
    ['whiskey_bottle_empty']   = `prop_drink_whisky`,
    ['recycled_material']      = `prop_rub_trash_01a`,
    ['material_reciclavel']    = `prop_rub_trash_01a`,
    ['scrapmetal']             = `prop_rub_trash_04`,
    ['garbage']                = `prop_rub_binbag_01`,
    ['paperbag']               = `prop_paper_bag_01`,

    -- ------------------------------------------------------------------
    -- Sacos de lixo (o prop cheio só é usado quando metadata.isFull)
    -- ------------------------------------------------------------------
    ['trash_bag_black']        = `prop_rub_binbag_01`,
    ['trash_bag_white']        = `prop_rub_binbag_03`,

    -- ------------------------------------------------------------------
    -- Entregas
    -- ------------------------------------------------------------------
    -- Nota fiscal das lojas: papel amassado no chao. Dropar uma nota deixa
    -- rastro de onde a pessoa comprou -- e essa e a graca.
    ['nota_fiscal']            = `prop_cs_documents_01`,

    ['delivery_letter']        = `prop_cs_box_clothes`,
    ['delivery_small_box']     = `prop_cardbordbox_02a`,
    ['delivery_large_package'] = `prop_cs_box_step`,

    -- ------------------------------------------------------------------
    -- Pessoais / utilidades
    -- ------------------------------------------------------------------
    ['phone']                  = `prop_npc_phone_02`,
    ['broken_phone']           = `prop_phone_ing`,
    ['radio']                  = `prop_cs_hand_radio`,
    ['bandage']                = `prop_ld_health_pack`,
    ['armour']                 = `prop_armour_pickup`,
    ['parachute']              = `p_parachute1_s`,
    ['clothing']               = `prop_cs_box_clothes`,
    ['panties']                = `prop_paper_bag_01`,
    ['lockpick']               = `prop_tool_screwdvr01`,
    ['wire_cable']             = `prop_toolchest_01`,

    -- ------------------------------------------------------------------
    -- Dinheiro e documentos
    -- ------------------------------------------------------------------
    ['money']                  = `prop_anim_cash_pile_01`,
    ['black_money']            = `prop_money_bag_01`,
    ['mastercard']             = `prop_fib_form`,
    ['identification']         = `prop_fib_form`,

    -- ==================================================================
    -- ARMAS
    -- Os modelos `w_*` seguem a nomenclatura padrão do jogo base.
    -- ==================================================================

    -- Pistolas ---------------------------------------------------------
    ['weapon_pistol']           = `w_pi_pistol`,
    ['weapon_pistol_mk2']       = `w_pi_pistol_mk2`,
    ['weapon_combatpistol']     = `w_pi_combatpistol`,
    ['weapon_appistol']         = `w_pi_appistol`,
    ['weapon_pistol50']         = `w_pi_pistol50`,
    ['weapon_snspistol']        = `w_pi_sns_pistol`,
    ['weapon_snspistol_mk2']    = `w_pi_sns_pistol_mk2`,
    ['weapon_heavypistol']      = `w_pi_heavypistol`,
    ['weapon_vintagepistol']    = `w_pi_vintage_pistol`,
    ['weapon_marksmanpistol']   = `w_pi_singleshot`,
    ['weapon_revolver']         = `w_pi_revolver`,
    ['weapon_revolver_mk2']     = `w_pi_revolver_mk2`,
    ['weapon_doubleaction']     = `w_pi_wep1_gun`,
    ['weapon_navyrevolver']     = `w_pi_wep2_gun`,
    ['weapon_ceramicpistol']    = `w_pi_ceramicpistol`,
    ['weapon_stungun']          = `w_pi_stungun`,
    ['weapon_flaregun']         = `w_pi_flaregun`,
    ['weapon_machinepistol']    = `w_sb_compactsmg`,

    -- Submetralhadoras -------------------------------------------------
    ['weapon_microsmg']         = `w_sb_microsmg`,
    ['weapon_smg']              = `w_sb_smg`,
    ['weapon_smg_mk2']          = `w_sb_smg_mk2`,
    ['weapon_assaultsmg']       = `w_sb_assaultsmg`,
    ['weapon_combatpdw']        = `w_sb_pdw`,
    ['weapon_minismg']          = `w_sb_minismg`,
    ['weapon_gusenberg']        = `w_sb_gusenberg`,

    -- Fuzis ------------------------------------------------------------
    ['weapon_assaultrifle']       = `w_ar_assaultrifle`,
    ['weapon_assaultrifle_mk2']   = `w_ar_assaultrifle_mk2`,
    ['weapon_carbinerifle']       = `w_ar_carbinerifle`,
    ['weapon_carbinerifle_mk2']   = `w_ar_carbinerifle_mk2`,
    ['weapon_advancedrifle']      = `w_ar_advancedrifle`,
    ['weapon_specialcarbine']     = `w_ar_specialcarbine`,
    ['weapon_specialcarbine_mk2'] = `w_ar_specialcarbine_mk2`,
    ['weapon_bullpuprifle']       = `w_ar_bullpuprifle`,
    ['weapon_bullpuprifle_mk2']   = `w_ar_bullpuprifle_mk2`,
    ['weapon_compactrifle']       = `w_ar_assaultrifle_smg`,
    ['weapon_militaryrifle']      = `w_ar_militaryrifle`,
    ['weapon_heavyrifle']         = `w_ar_heavyrifle`,
    ['weapon_tacticalrifle']      = `w_ar_tacticalrifle`,
    ['weapon_battlerifle']        = `w_ar_battlerifle`,
    ['weapon_musket']             = `w_ar_musket`,

    -- Escopetas --------------------------------------------------------
    ['weapon_pumpshotgun']      = `w_sg_pumpshotgun`,
    ['weapon_pumpshotgun_mk2']  = `w_sg_pumpshotgun_mk2`,
    ['weapon_sawnoffshotgun']   = `w_sg_sawnoff`,
    ['weapon_assaultshotgun']   = `w_sg_assaultshotgun`,
    ['weapon_bullpupshotgun']   = `w_sg_bullpupshotgun`,
    ['weapon_heavyshotgun']     = `w_sg_heavyshotgun`,
    ['weapon_dbshotgun']        = `w_sg_doublebarrel`,
    ['weapon_autoshotgun']      = `w_sg_sweeper`,
    ['weapon_combatshotgun']    = `w_sg_combatshotgun`,

    -- Precisão ---------------------------------------------------------
    ['weapon_sniperrifle']        = `w_sr_sniperrifle`,
    ['weapon_heavysniper']        = `w_sr_heavysniper`,
    ['weapon_heavysniper_mk2']    = `w_sr_heavysniper_mk2`,
    ['weapon_marksmanrifle']      = `w_sr_marksmanrifle`,
    ['weapon_marksmanrifle_mk2']  = `w_sr_marksmanrifle_mk2`,
    ['weapon_precisionrifle']     = `w_sr_precisionrifle`,

    -- Metralhadoras ----------------------------------------------------
    ['weapon_mg']               = `w_mg_mg`,
    ['weapon_combatmg']         = `w_mg_combatmg`,
    ['weapon_combatmg_mk2']     = `w_mg_combatmg_mk2`,
    ['weapon_minigun']          = `w_mg_minigun`,

    -- Pesadas ----------------------------------------------------------
    ['weapon_rpg']              = `w_lr_rpg`,
    ['weapon_grenadelauncher']  = `w_lr_grenadelauncher`,
    ['weapon_compactlauncher']  = `w_lr_compactgl`,
    ['weapon_hominglauncher']   = `w_lr_homing`,
    ['weapon_firework']         = `w_lr_firework`,
    ['weapon_railgun']          = `w_ar_railgun`,

    -- Corpo a corpo ----------------------------------------------------
    ['weapon_bat']              = `w_me_bat`,
    ['weapon_knife']            = `w_me_knife_01`,
    ['weapon_crowbar']          = `w_me_crowbar`,
    ['weapon_hammer']           = `w_me_hammer`,
    ['weapon_golfclub']         = `w_me_gclub`,
    ['weapon_machete']          = `w_me_machette`,
    ['weapon_hatchet']          = `w_me_hatchet`,
    ['weapon_battleaxe']        = `w_me_battleaxe`,
    ['weapon_dagger']           = `w_me_dagger`,
    ['weapon_knuckle']          = `w_me_knuckle`,
    ['weapon_nightstick']       = `w_me_nightstick`,
    ['weapon_poolcue']          = `w_me_poolcue`,
    ['weapon_switchblade']      = `w_me_switchblade`,
    ['weapon_wrench']           = `w_me_wrench`,
    ['weapon_stone_hatchet']    = `w_me_stonehatchet`,
    ['weapon_bottle']           = `w_me_bottle`,
    ['weapon_flashlight']       = `w_me_flashlight`,

    -- Arremessáveis ----------------------------------------------------
    ['weapon_grenade']          = `w_ex_grenadefrag`,
    ['weapon_stickybomb']       = `w_ex_pe`,
    ['weapon_pipebomb']         = `w_ex_pipebomb`,
    ['weapon_molotov']          = `w_ex_molotov`,
    ['weapon_proxmine']         = `w_ex_apmine`,
    ['weapon_smokegrenade']     = `w_ex_grenadesmoke`,
    ['weapon_bzgas']            = `w_ex_grenadesmoke`,
    ['weapon_teargas']          = `w_ex_grenadesmoke`,
    ['weapon_flare']            = `w_ex_flare`,

    -- Utilitárias ------------------------------------------------------
    ['weapon_petrolcan']        = `w_am_jerrycan`,
    ['weapon_fertilizercan']    = `w_am_jerrycan`,
    ['weapon_hazardcan']        = `w_am_jerrycan`,
    ['weapon_fireextinguisher'] = `w_am_fire_exting`,
}
