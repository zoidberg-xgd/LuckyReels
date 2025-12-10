-- data/synergies.lua
-- Synergy and combo definitions
-- Easy to modify and extend

return {
    -- Symbol categories for synergies
    categories = {
        fruit = {"cherry", "banana", "apple"},
        animal = {"cat", "monkey", "rabbit", "bee"},
        gem = {"coin", "pearl", "diamond"},
        food = {"milk", "candy", "banana"},
        nature = {"flower", "sun", "bee"},
    },
    
    -- Category synergy bonuses
    -- Format: {min_count, multiplier, name_key}
    bonuses = {
        fruit = {
            {3, 1.5, "synergy_fruit_platter"},
            {5, 2.0, "synergy_fruit_feast"},
        },
        animal = {
            {3, 1.3, "synergy_zoo"},
            {5, 1.8, "synergy_wild_kingdom"},
        },
        gem = {
            {3, 1.4, "synergy_gem_collection"},
            {5, 2.0, "synergy_treasure"},
        },
        food = {
            {3, 1.3, "synergy_gourmet"},
        },
        nature = {
            {3, 1.5, "synergy_nature_power"},
        },
    },
    
    -- Special combos: specific symbol combinations
    combos = {
        cat_milk = {
            symbols = {"cat", "milk"},
            bonus = 5,
            name_key = "combo_cat_milk",
        },
        garden = {
            symbols = {"flower", "sun", "bee"},
            bonus = 10,
            name_key = "combo_garden",
        },
        lucky_triple = {
            symbols = {"lucky_seven", "lucky_seven", "lucky_seven"},
            multiplier = 3,
            name_key = "combo_triple_seven",
        },
        coin_rush = {
            symbols = {"coin", "coin", "coin", "coin", "coin"},
            multiplier = 2,
            name_key = "combo_coin_rush",
        },
    },
}
