-- src/core/synergy.lua
-- Symbol synergy and combo system

local Synergy = {}

--------------------------------------------------------------------------------
-- Synergy Definitions
--------------------------------------------------------------------------------

-- Symbol categories for synergies
Synergy.categories = {
    fruit = {"cherry", "banana", "apple"},
    animal = {"cat", "monkey", "rabbit", "bee"},
    gem = {"coin", "pearl", "diamond"},
    food = {"milk", "candy", "banana"},
    nature = {"flower", "sun", "bee"},
}

-- Synergy bonuses: {min_count, multiplier, name}
Synergy.bonuses = {
    fruit = {
        {3, 1.5, "水果拼盘"},   -- 3+ fruits: 1.5x
        {5, 2.0, "水果大餐"},   -- 5+ fruits: 2x
    },
    animal = {
        {3, 1.3, "动物园"},     -- 3+ animals: 1.3x
        {5, 1.8, "野生王国"},   -- 5+ animals: 1.8x
    },
    gem = {
        {3, 1.4, "宝石收藏"},   -- 3+ gems: 1.4x
        {5, 2.0, "富甲天下"},   -- 5+ gems: 2x
    },
    food = {
        {3, 1.3, "美食家"},     -- 3+ food: 1.3x
    },
    nature = {
        {3, 1.5, "自然之力"},   -- 3+ nature: 1.5x
    },
}

-- Special combos: specific symbol combinations
Synergy.combos = {
    -- Cat + Milk combo bonus
    cat_milk = {
        symbols = {"cat", "milk"},
        bonus = 5,
        name = "猫咪套餐",
    },
    -- Flower + Sun + Bee
    garden = {
        symbols = {"flower", "sun", "bee"},
        bonus = 10,
        name = "完美花园",
    },
    -- Triple 7
    lucky_triple = {
        symbols = {"lucky_seven", "lucky_seven", "lucky_seven"},
        multiplier = 3,
        name = "三连七",
    },
    -- All coins
    coin_rush = {
        symbols = {"coin", "coin", "coin", "coin", "coin"},
        multiplier = 2,
        name = "金币风暴",
    },
}

--------------------------------------------------------------------------------
-- Core Methods
--------------------------------------------------------------------------------

-- Count symbols by category on grid
function Synergy.countByCategory(grid)
    local counts = {}
    for category, symbols in pairs(Synergy.categories) do
        counts[category] = 0
    end
    
    local symbolCounts = {}
    
    for r = 1, grid.rows do
        for c = 1, grid.cols do
            local sym = grid:getSymbol(r, c)
            if sym then
                symbolCounts[sym.key] = (symbolCounts[sym.key] or 0) + 1
                
                for category, symbols in pairs(Synergy.categories) do
                    for _, key in ipairs(symbols) do
                        if sym.key == key then
                            counts[category] = counts[category] + 1
                            break
                        end
                    end
                end
            end
        end
    end
    
    return counts, symbolCounts
end

-- Calculate synergy multiplier and bonuses
function Synergy.calculate(grid)
    local categoryCounts, symbolCounts = Synergy.countByCategory(grid)
    
    local totalMultiplier = 1.0
    local totalBonus = 0
    local activeSynergies = {}
    
    -- Check category synergies
    for category, count in pairs(categoryCounts) do
        local bonuses = Synergy.bonuses[category]
        if bonuses then
            for _, bonus in ipairs(bonuses) do
                local minCount, mult, name = bonus[1], bonus[2], bonus[3]
                if count >= minCount then
                    totalMultiplier = totalMultiplier * mult
                    table.insert(activeSynergies, {
                        type = "category",
                        name = name,
                        multiplier = mult,
                        count = count
                    })
                end
            end
        end
    end
    
    -- Check special combos
    for comboId, combo in pairs(Synergy.combos) do
        local hasAll = true
        local neededCounts = {}
        
        for _, symKey in ipairs(combo.symbols) do
            neededCounts[symKey] = (neededCounts[symKey] or 0) + 1
        end
        
        for symKey, needed in pairs(neededCounts) do
            if (symbolCounts[symKey] or 0) < needed then
                hasAll = false
                break
            end
        end
        
        if hasAll then
            if combo.multiplier then
                totalMultiplier = totalMultiplier * combo.multiplier
            end
            if combo.bonus then
                totalBonus = totalBonus + combo.bonus
            end
            table.insert(activeSynergies, {
                type = "combo",
                name = combo.name,
                multiplier = combo.multiplier,
                bonus = combo.bonus
            })
        end
    end
    
    return {
        multiplier = totalMultiplier,
        bonus = totalBonus,
        synergies = activeSynergies
    }
end

-- Get synergy preview for inventory (what synergies would activate)
function Synergy.getPreview(inventory)
    -- Create a mock grid to count
    local symbolCounts = {}
    for _, sym in ipairs(inventory) do
        symbolCounts[sym.key] = (symbolCounts[sym.key] or 0) + 1
    end
    
    local potentialSynergies = {}
    
    for category, symbols in pairs(Synergy.categories) do
        local count = 0
        for _, key in ipairs(symbols) do
            count = count + (symbolCounts[key] or 0)
        end
        
        local bonuses = Synergy.bonuses[category]
        if bonuses and count >= 2 then
            for _, bonus in ipairs(bonuses) do
                local minCount = bonus[1]
                table.insert(potentialSynergies, {
                    category = category,
                    name = bonus[3],
                    current = count,
                    needed = minCount,
                    active = count >= minCount
                })
            end
        end
    end
    
    return potentialSynergies
end

return Synergy
