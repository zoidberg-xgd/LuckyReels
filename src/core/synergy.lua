-- src/core/synergy.lua
-- Symbol synergy and combo system

local i18n = require("src.i18n")
local Synergy = {}

--------------------------------------------------------------------------------
-- Load Data from External File
--------------------------------------------------------------------------------

local function loadSynergyData()
    local data = require("data.synergies")
    Synergy.categories = data.categories
    Synergy.bonuses = data.bonuses
    Synergy.combos = data.combos
    print("[Synergy] Loaded " .. Synergy.countBonuses() .. " bonuses, " .. Synergy.countCombos() .. " combos")
end

-- Count helpers
function Synergy.countBonuses()
    local count = 0
    for _, bonuses in pairs(Synergy.bonuses or {}) do
        count = count + #bonuses
    end
    return count
end

function Synergy.countCombos()
    local count = 0
    for _ in pairs(Synergy.combos or {}) do
        count = count + 1
    end
    return count
end

-- Helper to get localized name
function Synergy.getName(key)
    return i18n.t(key) or key
end

-- Initialize on load
loadSynergyData()

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
                local minCount, mult, nameKey = bonus[1], bonus[2], bonus[3]
                if count >= minCount then
                    totalMultiplier = totalMultiplier * mult
                    table.insert(activeSynergies, {
                        type = "category",
                        name = Synergy.getName(nameKey),
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
                name = Synergy.getName(combo.name_key),
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
