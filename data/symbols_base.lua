-- data/symbols_base.lua
-- Base game symbols - data driven definition
-- Use ContentLoader.Behaviors for common patterns

return {
    -- ========== BASIC VALUE SYMBOLS ==========
    coin = {
        char = "币",
        color = {1, 1, 0},
        value = 1,
        rarity = 1,
        -- Level-based effects
        on_calculate = function(self, grid, r, c)
            local level = self.level or 1
            local base = level  -- Lv1: 1, Lv2: 2, Lv3: 3
            local bonus = 0
            local logs = {}
            
            if level >= 2 then
                -- Lv2+: Adjacent coins +1 each
                for dr = -1, 1 do
                    for dc = -1, 1 do
                        if dr ~= 0 or dc ~= 0 then
                            local sym = grid:getSymbol(r + dr, c + dc)
                            if sym and sym.key == "coin" then
                                bonus = bonus + 1
                            end
                        end
                    end
                end
            end
            
            if level >= 3 then
                -- Lv3: All coins on grid +1
                for gr = 1, grid.rows do
                    for gc = 1, grid.cols do
                        local sym = grid:getSymbol(gr, gc)
                        if sym and sym.key == "coin" and (gr ~= r or gc ~= c) then
                            bonus = bonus + 1
                        end
                    end
                end
            end
            
            return base + bonus, logs
        end,
    },
    
    cherry = {
        char = "樱",
        color = {0.8, 0, 0},
        value = 3,  -- Increased from 2
        rarity = 2,
    },
    
    pearl = {
        char = "珠",
        color = {0.95, 0.95, 1},
        value = 4,  -- Increased from 3
        rarity = 2,
    },
    
    diamond = {
        char = "钻",
        color = {0.6, 0.9, 1},
        value = 8,  -- Increased from 5
        rarity = 3,
    },
    
    -- ========== CONSUME INTERACTION SYMBOLS ==========
    cat = {
        char = "猫",
        color = {0.8, 0.8, 0.8},
        value = 1,
        rarity = 2,
        behavior = {
            type = "consume_adjacent_delayed",
            args = {"milk", 10, {1, 1, 1}}
        }
    },
    
    milk = {
        char = "奶",
        color = {1, 1, 1},
        value = 2,  -- Increased
        rarity = 1,
    },
    
    miner = {
        char = "矿",
        color = {0.4, 0.4, 0.5},
        value = 1,
        rarity = 2,
        behavior = {
            type = "consume_adjacent",
            args = {"ore", 10, {0.6, 0.5, 0.3}}
        }
    },
    
    ore = {
        char = "石",
        color = {0.3, 0.3, 0.3},
        value = 2,  -- Increased
        rarity = 1,
    },
    
    toddler = {
        char = "童",
        color = {0.9, 0.7, 0.6},
        value = 1,
        rarity = 2,
        behavior = {
            type = "consume_adjacent",
            args = {"candy", 5, {1, 0.5, 0.8}}
        }
    },
    
    candy = {
        char = "糖",
        color = {1, 0.4, 0.7},
        value = 2,  -- Increased
        rarity = 1,
    },
    
    monkey = {
        char = "猴",
        color = {0.6, 0.4, 0.2},
        value = 1,
        rarity = 2,
        behavior = {
            type = "consume_adjacent",
            args = {"banana", 5, {1, 0.9, 0.3}}
        }
    },
    
    banana = {
        char = "蕉",
        color = {1, 0.9, 0.3},
        value = 2,  -- Increased
        rarity = 1,
    },
    
    thief = {
        char = "盗",
        color = {0.3, 0.3, 0.4},
        value = 0,
        rarity = 2,
        behavior = {
            type = "consume_adjacent",
            args = {"coin", 3, {0.5, 0.5, 0.6}}
        }
    },
    
    -- ========== BOOST INTERACTION SYMBOLS ==========
    flower = {
        char = "花",
        color = {1, 0.5, 0.5},
        value = 2,  -- Increased
        rarity = 1,
        behavior = {
            type = "boost_from_adjacent",
            args = {"sun", 4, {1, 0.9, 0.3}}
        }
    },
    
    sun = {
        char = "日",
        color = {1, 0.8, 0},
        value = 3,
        rarity = 3,
    },
    
    bee = {
        char = "蜂",
        color = {1, 0.9, 0.2},
        value = 1,
        rarity = 2,
        behavior = {
            type = "boost_from_adjacent",
            args = {"flower", 2, {1, 0.9, 0.3}}
        }
    },
    
    -- ========== COPY/SYNERGY SYMBOLS ==========
    witch = {
        char = "巫",
        color = {0.6, 0.2, 0.8},
        value = 2,
        rarity = 3,
        behavior = {
            type = "copy_adjacent_values",
            args = {{0.7, 0.3, 0.9}}
        }
    },
    
    -- ========== SELF-MULTIPLYING SYMBOLS ==========
    rabbit = {
        char = "兔",
        color = {1, 0.8, 0.8},
        value = 1,
        rarity = 2,
        behavior = {
            type = "count_same_type",
            args = {1}  -- +100% per other rabbit
        }
    },
    
    -- ========== DESTROYER SYMBOLS ==========
    bomb = {
        char = "弹",
        color = {0.3, 0.3, 0.3},
        value = 0,
        rarity = 2,
        behavior = {
            type = "destroy_all_adjacent",
            args = {2, true}  -- 2 per destroyed, destroy self
        }
    },
    
    -- ========== POSITION-BASED SYMBOLS ==========
    king = {
        char = "王",
        color = {1, 0.85, 0.2},
        value = 2,
        rarity = 3,
        behavior = {
            type = "row_bonus",
            args = {1}  -- +1 per symbol in row
        }
    },
    
    void = {
        char = "虚",
        color = {0.2, 0.1, 0.3},
        value = 0,
        rarity = 1,
        behavior = {
            type = "bonus_per_empty",
            args = {2}  -- +2 per empty adjacent
        }
    },
    
    -- ========== RANDOM SYMBOLS ==========
    dice = {
        char = "骰",
        color = {1, 1, 1},
        value = 0,
        rarity = 2,
        -- Custom function for dice roll with animation
        on_calculate = function(self, grid, r, c)
            local roll = math.random(1, 6)
            -- Create a "roll" interaction effect on self
            local interactions = {{
                type = "dice_roll",
                targetR = r, targetC = c,
                sourceR = r, sourceC = c,
                value = roll,
                color = {1, 1, 1}
            }}
            return roll, {}, interactions
        end
    },
    
    -- ========== CONDITIONAL SYMBOLS ==========
    lucky_seven = {
        char = "7",
        color = {1, 0.2, 0.2},
        value = 7,
        rarity = 3,
        -- Custom on_calculate for complex condition
        on_calculate = function(self, grid, r, c)
            local count = 0
            for gr = 1, grid.rows do
                for gc = 1, grid.cols do
                    if grid:getSymbol(gr, gc) then
                        count = count + 1
                    end
                end
            end
            local interactions = {}
            if count == 7 then
                -- Jackpot! Triple value with special effect
                table.insert(interactions, {
                    type = "jackpot",
                    targetR = r, targetC = c,
                    sourceR = r, sourceC = c,
                    value = self.base_value * 3,
                    color = {1, 0.2, 0.2}
                })
                return self.base_value * 3, {}, interactions
            end
            return self.base_value, {}, {}
        end
    },
}
