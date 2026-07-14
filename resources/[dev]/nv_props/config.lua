Config = {}

-- Fallback model hash if an item is not registered in the mapping below
Config.DefaultModel = `prop_paper_bag_01`

-- Mapping from inventory item names to 3D model hashes
Config.Items = {
    ['water'] = `prop_ld_flow_bottle`,
    ['cola'] = `prop_ecola_can`,
    ['burger'] = `prop_cs_burger_01`,
    ['phone'] = `prop_npc_phone`,
    ['bandage'] = `prop_paper_bag_01`,
    
    -- Weapons
    ['weapon_pistol'] = `w_pi_pistol`,
    ['weapon_combatpistol'] = `w_pi_combatpistol`,
    ['weapon_appistol'] = `w_pi_appistol`,
    ['weapon_heavypistol'] = `w_pi_heavypistol`,
    ['weapon_revolver'] = `w_pi_revolver`,
    ['weapon_microsmg'] = `w_sb_microsmg`,
    ['weapon_smg'] = `w_sb_smg`,
    ['weapon_assaultrifle'] = `w_ar_assaultrifle`,
    ['weapon_carbinerifle'] = `w_ar_carbinerifle`,
    ['weapon_advancedrifle'] = `w_ar_advancedrifle`,
    ['weapon_pumpshotgun'] = `w_sg_pumpshotgun`,
    ['weapon_sawnoffshotgun'] = `w_sg_sawnoffshotgun`,
    ['weapon_heavyshotgun'] = `w_sg_heavyshotgun`,
    ['weapon_marksmanrifle'] = `w_sr_marksmanrifle`,
    ['weapon_sniperrifle'] = `w_sr_sniperrifle`,
}
