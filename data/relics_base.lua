-- data/relics_base.lua
-- Base game relics - data driven definition

return {
    lucky_cat = {
        char = "招",
        color = {1, 0.8, 0.2},
        on_calculate_end = function(self, engine, context)
            engine.money = engine.money + 1
        end
    },
    
    piggy_bank = {
        char = "猪",
        color = {1, 0.6, 0.7},
        on_spin_end = function(self, engine)
            self.saved = (self.saved or 0) + 1
        end,
        on_calculate_end = function(self, engine, context)
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
            if math.random() < 0.1 then
                engine.money = engine.money + context.score
            end
        end
    },
    
    magnet = {
        char = "磁",
        color = {0.8, 0.2, 0.2},
        on_calculate_end = function(self, engine, context)
            local bonus = math.floor(context.score / 5)
            engine.money = engine.money + bonus
        end
    },
    
    hourglass = {
        char = "沙",
        color = {0.9, 0.8, 0.5},
        on_spin_start = function(self, engine)
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
        char = "兔",
        color = {0.9, 0.7, 0.6},
        -- Effect handled in Registry rarity calculation
    },
    
    crown = {
        char = "冠",
        color = {1, 0.85, 0.1},
        on_calculate_end = function(self, engine, context)
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
            engine.money = engine.money + math.random(0, 3)
        end
    },
    
    shield = {
        char = "盾",
        color = {0.5, 0.5, 0.7},
        on_calculate_end = function(self, engine, context)
            if context.score < 5 then
                engine.money = engine.money + (5 - context.score)
            end
        end
    },
}
