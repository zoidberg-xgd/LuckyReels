-- data/events.lua
-- Random event definitions
-- Easy to modify and extend

return {
    -- Positive events
    {
        id = "free_symbol",
        name_key = "event_free_symbol_name",
        desc_key = "event_free_symbol_desc",
        weight = 10,
        type = "positive",
        effect = "add_random_symbol",
    },
    {
        id = "extra_spin",
        name_key = "event_extra_spin_name",
        desc_key = "event_extra_spin_desc",
        weight = 12,
        type = "positive",
        effect = "add_spin",
        value = 1,
    },
    {
        id = "rent_reduction",
        name_key = "event_rent_reduction_name",
        desc_key = "event_rent_reduction_desc",
        weight = 8,
        type = "positive",
        effect = "multiply_rent",
        value = 0.8,
    },
    {
        id = "bonus_coins",
        name_key = "event_bonus_coins_name",
        desc_key = "event_bonus_coins_desc",
        weight = 15,
        type = "positive",
        effect = "add_money",
        value = 5,
    },
    
    -- Negative events
    {
        id = "rent_increase",
        name_key = "event_rent_increase_name",
        desc_key = "event_rent_increase_desc",
        weight = 10,
        type = "negative",
        effect = "multiply_rent",
        value = 1.15,
    },
    {
        id = "lose_spin",
        name_key = "event_lose_spin_name",
        desc_key = "event_lose_spin_desc",
        weight = 8,
        type = "negative",
        effect = "remove_spin",
        value = 1,
    },
    {
        id = "tax",
        name_key = "event_tax_name",
        desc_key = "event_tax_desc",
        weight = 10,
        type = "negative",
        effect = "remove_money",
        value = 3,
    },
    
    -- Neutral events
    {
        id = "shuffle",
        name_key = "event_shuffle_name",
        desc_key = "event_shuffle_desc",
        weight = 5,
        type = "neutral",
        effect = "shuffle_inventory",
    },
}
