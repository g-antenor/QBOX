Config = {}

-- Trash Models list (Dumpsters, wheelie bins, trash bags, piles)
Config.TrashModels = {
    -- Dumpsters
    `prop_dumpster_01a`,
    `prop_dumpster_01b`,
    `prop_dumpster_02a`,
    `prop_dumpster_02b`,
    `prop_dumpster_4a`,
    `prop_dumpster_4b`,
    `prop_dumpster_3a`,
    -- Bins / Trash cans
    `prop_bin_01a`,
    `prop_bin_02a`,
    `prop_bin_03a`,
    `prop_bin_04a`,
    `prop_bin_05a`,
    `prop_bin_06a`,
    `prop_bin_07a`,
    `prop_bin_08a`,
    `prop_bin_08open`,
    `prop_bin_09a`,
    `prop_bin_10a`,
    `prop_bin_10b`,
    `prop_bin_11a`,
    `prop_bin_12a`,
    `prop_bin_13a`,
    `prop_bin_14a`,
    `prop_bin_14b`,
    -- Trash bags & piles
    `prop_rub_binbag_01`,
    `prop_rub_binbag_01b`,
    `prop_rub_binbag_02`,
    `prop_rub_binbag_03`,
    `prop_rub_binbag_03b`,
    `prop_rub_binbag_04`,
    `prop_rub_binbag_05`,
    `prop_rub_binbag_06`,
    `prop_rub_binbag_08`,
    `prop_rub_trash_01a`,
    `prop_rub_trash_02a`,
    `prop_rub_trash_03a`,
    `prop_rub_trash_04`,
    `prop_rub_trash_05a`,
    `prop_rub_trash_06`
}

-- Cooldown per bin in seconds (default 5 minutes)
Config.CooldownTime = 300

-- Search animation details (Washing hands style)
Config.SearchAnim = {
    dict = "anim@gangops@facility@servers@bodysearch@",
    name = "player_search",
    flag = 49 -- Upper body only, allows cancel
}


-- Speed multiplier progression config for Skill Checks
-- Round size is 3 mini-games. The speed gets faster.
Config.RoundsDifficulty = {
    [1] = { speed = 1.0, area = 15 },
    [2] = { speed = 1.2, area = 13 },
    [3] = { speed = 1.4, area = 11 },
    [4] = { speed = 1.6, area = 9 },
    [5] = { speed = 1.8, area = 7 }
}

-- Loot drop table
-- Common items have higher weight, rare items have lower weight
Config.Loot = {
    -- Common items
    { item = "glass", label = "Vidro", weight = 60, min = 1, max = 3 },
    { item = "plastic_bottle", label = "Garrafa Plástica Vazia", weight = 60, min = 1, max = 2 },
    { item = "empty_can", label = "Latinha Vazia", weight = 60, min = 1, max = 3 },
    { item = "chips_bag", label = "Saco de Salgadinho Vazio", weight = 60, min = 1, max = 1 },
    { item = "coffee_cup", label = "Copo de Café Vazio", weight = 60, min = 1, max = 1 },
    
    -- Assorted empty drink bottles (beverage)
    { 
        item = "assorted_bottle", 
        label = "Garrafa de Bebida Vazia", 
        weight = 60, 
        min = 1, 
        max = 2,
        subItems = { "beer_bottle_empty", "wine_bottle_empty", "whiskey_bottle_empty" } 
    },
    
    -- Rare items
    { item = "wire_cable", label = "Cabo de Fio", weight = 15, min = 1, max = 2 },
    { item = "broken_phone", label = "Celular Quebrado", weight = 10, min = 1, max = 1 },
    { item = "money", label = "2 Dólares", weight = 15, min = 2, max = 2 }
}

-- Extra task/task series success reward multipliers or items
Config.FinalBonusLoot = {
    chance = 40, -- 40% chance of an extra rare item when completing all rounds
    items = { "wire_cable", "broken_phone", "money" }
}
