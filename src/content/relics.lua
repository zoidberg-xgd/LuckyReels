-- src/content/relics.lua
-- Data-driven relic loading system

local ContentLoader = require("src.core.content_loader")

-- Load base game relics
local baseRelics = require("data.relics_base")
ContentLoader.loadRelics(baseRelics)

-- Note: All relics are now loaded from data/relics_base.lua
-- Legacy definitions removed

local relics_unused = {
    lucky_cat = {
        name_key = "relic_lucky_cat_name",
        desc_key = "relic_lucky_cat_desc",
        char = "招",
        color = {1, 0.8, 0.2},
        on_calculate_end = function(self, engine, context)
            engine.money = engine.money + 1
        end
    },
    
    piggy_bank = {
        name_key = "relic_piggy_bank_name",
        desc_key = "relic_piggy_bank_desc",
        char = "猪",
        color = {1, 0.6, 0.7},
        on_spin_end = function(self, engine)
            -- Save 1 coin per spin
            self.saved = (self.saved or 0) + 1
        end,
        on_calculate_end = function(self, engine, context)
            -- Pay out when rent is due
            if engine.spins_left == 0 and self.saved then
                engine.money = engine.money + self.saved
                self.saved = 0
            end
        end
    },
    
    four_leaf_clover = {
        name_key = "relic_clover_name",
        desc_key = "relic_clover_desc",
        char = "草",
        color = {0.3, 0.8, 0.3},
        on_calculate_end = function(self, engine, context)
            -- 10% chance to double score
            if math.random() < 0.1 then
                engine.money = engine.money + context.score
            end
        end
    },
    
    magnet = {
        name_key = "relic_magnet_name",
        desc_key = "relic_magnet_desc",
        char = "磁",
        color = {0.8, 0.2, 0.2},
        on_calculate_end = function(self, engine, context)
            -- +1 for every 5 coins earned
            local bonus = math.floor(context.score / 5)
            engine.money = engine.money + bonus
        end
    },
    
    hourglass = {
        name_key = "relic_hourglass_name",
        desc_key = "relic_hourglass_desc",
        char = "沙",
        color = {0.9, 0.8, 0.5},
        on_spin_start = function(self, engine)
            -- 20% chance for extra spin
            if math.random() < 0.2 then
                engine.spins_left = engine.spins_left + 1
            end
        end
    },
    
    golden_tooth = {
        name_key = "relic_tooth_name",
        desc_key = "relic_tooth_desc",
        char = "牙",
        color = {1, 0.9, 0.3},
        on_calculate_end = function(self, engine, context)
            -- +2 for each coin symbol on grid
            local coinCount = 0
            for r = 1, engine.grid.rows do
                for c = 1, engine.grid.cols do
                    local sym = engine.grid:getSymbol(r, c)
                    if sym and sym.key == "coin" then
                        coinCount = coinCount + 1
                    end
                end
            end
            engine.money = engine.money + (coinCount * 2)
        end
    },
    
    rabbit_foot = {
        name_key = "relic_rabbit_foot_name",
        desc_key = "relic_rabbit_foot_desc",
        char = "兔",
        color = {0.9, 0.7, 0.6},
        -- Increases rare symbol chance (handled in Registry)
    },
    
    crown = {
        name_key = "relic_crown_name",
        desc_key = "relic_crown_desc",
        char = "冠",
        color = {1, 0.85, 0.1},
        on_calculate_end = function(self, engine, context)
            -- +5 if score >= 20
            if context.score >= 20 then
                engine.money = engine.money + 5
            end
        end
    },
    
    dice_relic = {
        name_key = "relic_dice_name",
        desc_key = "relic_dice_desc",
        char = "骰",
        color = {1, 1, 1},
        on_spin_end = function(self, engine)
            -- Random bonus 0-3
            engine.money = engine.money + math.random(0, 3)
        end
    },
    
    shield = {
        name_key = "relic_shield_name",
        desc_key = "relic_shield_desc",
        char = "盾",
        color = {0.5, 0.5, 0.7},
        on_calculate_end = function(self, engine, context)
            -- Minimum 5 coins per spin
            if context.score < 5 then
                engine.money = engine.money + (5 - context.score)
            end
        end
    }
}

-- Removed: for k, v in pairs(relics) do Registry.registerRelic(k, v) end
