-- mods/example_mod.lua
-- Example mod demonstrating the Mod API
-- This mod adds a new symbol, event, and modifies game balance

return function(ModAPI)
    
    -- Register this mod
    ModAPI.register({
        id = "example_mod",
        name = "Example Mod",
        version = "1.0.0",
        author = "LuckyReels Team",
        description = "Demonstrates how to create mods",
        
        onLoad = function(api)
            print("Example mod loaded!")
        end,
    })
    
    ----------------------------------------------------------------------------
    -- Add a new symbol: Lucky Star
    ----------------------------------------------------------------------------
    
    ModAPI.Symbols.add({
        key = "lucky_star",
        char = "★",  -- Display character
        color = {1, 0.9, 0.3},  -- Gold color
        base_value = 3,
        rarity = 2,  -- Uncommon
        tags = {"lucky", "multiplier"},
    })
    
    -- Add translations for the new symbol
    ModAPI.i18n.add("en", "symbol_lucky_star_name", "Lucky Star")
    ModAPI.i18n.add("en", "symbol_lucky_star_desc", "+3 coins. Doubles adjacent symbol values.")
    ModAPI.i18n.add("zh", "symbol_lucky_star_name", "幸运星")
    ModAPI.i18n.add("zh", "symbol_lucky_star_desc", "+3金币。使相邻符号价值翻倍。")
    
    ----------------------------------------------------------------------------
    -- Add a new event: Double or Nothing
    ----------------------------------------------------------------------------
    
    ModAPI.Events.add({
        id = "double_or_nothing",
        name = "Double or Nothing",
        desc = "50% chance to double your money, 50% chance to lose half!",
        weight = 5,
        type = "neutral",
        
        apply = function(engine)
            if math.random() < 0.5 then
                engine.money = engine.money * 2
                return "Won! Money doubled!"
            else
                engine.money = math.floor(engine.money / 2)
                return "Lost! Money halved!"
            end
        end,
    })
    
    -- Add translations
    ModAPI.i18n.add("en", "event_double_or_nothing_name", "Double or Nothing")
    ModAPI.i18n.add("en", "event_double_or_nothing_desc", "50% chance to double, 50% to halve!")
    ModAPI.i18n.add("zh", "event_double_or_nothing_name", "孤注一掷")
    ModAPI.i18n.add("zh", "event_double_or_nothing_desc", "50%几率翻倍，50%几率减半！")
    
    ----------------------------------------------------------------------------
    -- Add a new synergy: Lucky category
    ----------------------------------------------------------------------------
    
    ModAPI.Synergies.addCategory("lucky", {"lucky_seven", "lucky_star", "coin"})
    ModAPI.Synergies.addBonus("lucky", 3, 1.5, "synergy_lucky_charm")
    
    ModAPI.i18n.add("en", "synergy_lucky_charm", "Lucky Charm")
    ModAPI.i18n.add("zh", "synergy_lucky_charm", "幸运护符")
    
    ----------------------------------------------------------------------------
    -- Modify game balance (optional)
    ----------------------------------------------------------------------------
    
    -- Uncomment to modify:
    -- ModAPI.Config.setBalance("starting_money", 10)
    -- ModAPI.Config.setBalance("starting_rent", 12)
    
    ----------------------------------------------------------------------------
    -- Hook into game events
    ----------------------------------------------------------------------------
    
    ModAPI.Hooks.on("game:spin", function()
        -- Called when player spins
        -- print("Player is spinning!")
    end)
    
    ModAPI.Hooks.on("game:score", function(score, symbols)
        -- Called when scoring happens
        -- print("Scored: " .. score)
    end)
    
end
