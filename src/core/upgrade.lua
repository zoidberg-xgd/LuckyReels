-- src/core/upgrade.lua
-- Symbol upgrade and destruction system

local Registry = require("src.core.registry")
local EventBus = require("src.core.event_bus")

local Upgrade = {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

Upgrade.CONFIG = {
    -- Symbols needed to upgrade
    symbols_to_upgrade = 3,
    
    -- Value multiplier per level
    value_multiplier = 2,
    
    -- Max upgrade level
    max_level = 3,
    
    -- Destruction rewards (base value * multiplier)
    destroy_multiplier = {
        [1] = 2,   -- Level 1: 2x base value
        [2] = 5,   -- Level 2: 5x base value
        [3] = 12,  -- Level 3: 12x base value
    },
    
    -- Quality names
    quality_names = {
        [1] = "普通",
        [2] = "优质",
        [3] = "精良",
    },
    
    -- Quality colors (use Config.visual.quality_colors if available)
    quality_colors = nil,  -- Will be loaded from Config
}

-- Load quality colors from Config
local function getQualityColors()
    if not Upgrade.CONFIG.quality_colors then
        local Config = require("src.core.config")
        Upgrade.CONFIG.quality_colors = Config.visual.quality_colors
    end
    return Upgrade.CONFIG.quality_colors
end

--------------------------------------------------------------------------------
-- Core Methods
--------------------------------------------------------------------------------

--- Get symbol level (default 1)
function Upgrade.getLevel(symbol)
    return symbol.level or 1
end

--- Get symbol quality name
function Upgrade.getQualityName(symbol)
    local level = Upgrade.getLevel(symbol)
    return Upgrade.CONFIG.quality_names[level] or "普通"
end

--- Get symbol quality color
function Upgrade.getQualityColor(symbol)
    local level = Upgrade.getLevel(symbol)
    local colors = getQualityColors()
    return colors[level] or {0.7, 0.7, 0.7}
end

--- Check if symbol can be upgraded
function Upgrade.canUpgrade(symbol)
    local level = Upgrade.getLevel(symbol)
    return level < Upgrade.CONFIG.max_level
end

--- Find matching symbols in inventory for upgrade
-- Returns indices of symbols that can be combined
function Upgrade.findUpgradeCandidates(inventory, targetKey)
    local candidates = {}
    local targetLevel = nil
    
    for i, sym in ipairs(inventory) do
        if sym.key == targetKey then
            local level = Upgrade.getLevel(sym)
            if targetLevel == nil then
                targetLevel = level
            end
            if level == targetLevel and Upgrade.canUpgrade(sym) then
                table.insert(candidates, i)
            end
        end
    end
    
    return candidates, targetLevel
end

--- Check if upgrade is possible for a symbol type
function Upgrade.canUpgradeSymbol(inventory, symbolKey)
    local candidates, level = Upgrade.findUpgradeCandidates(inventory, symbolKey)
    return #candidates >= Upgrade.CONFIG.symbols_to_upgrade and level < Upgrade.CONFIG.max_level
end

--- Perform upgrade: combine N symbols into 1 upgraded symbol
-- Returns the upgraded symbol or nil if failed
function Upgrade.upgradeSymbol(inventory, symbolKey)
    local candidates, currentLevel = Upgrade.findUpgradeCandidates(inventory, symbolKey)
    
    if #candidates < Upgrade.CONFIG.symbols_to_upgrade then
        return nil, "not_enough_symbols"
    end
    
    if currentLevel >= Upgrade.CONFIG.max_level then
        return nil, "max_level"
    end
    
    -- Remove symbols (from end to preserve indices)
    local toRemove = {}
    for i = 1, Upgrade.CONFIG.symbols_to_upgrade do
        table.insert(toRemove, candidates[i])
    end
    table.sort(toRemove, function(a, b) return a > b end)
    
    for _, idx in ipairs(toRemove) do
        table.remove(inventory, idx)
    end
    
    -- Create upgraded symbol
    local newSymbol = Registry.createSymbol(symbolKey)
    newSymbol.level = currentLevel + 1
    newSymbol.base_value = newSymbol.base_value * Upgrade.CONFIG.value_multiplier
    
    -- Add to inventory
    table.insert(inventory, newSymbol)
    
    EventBus.emit("symbol:upgrade", {
        symbol = newSymbol,
        fromLevel = currentLevel,
        toLevel = newSymbol.level
    })
    
    return newSymbol
end

--- Calculate destruction reward
function Upgrade.getDestroyReward(symbol)
    local level = Upgrade.getLevel(symbol)
    local baseValue = Registry.symbol_types[symbol.key].value or 1
    local multiplier = Upgrade.CONFIG.destroy_multiplier[level] or 2
    return baseValue * multiplier
end

--- Destroy a symbol for coins
function Upgrade.destroySymbol(inventory, index, engine)
    local symbol = inventory[index]
    if not symbol then
        return nil, "invalid_index"
    end
    
    local reward = Upgrade.getDestroyReward(symbol)
    engine.money = engine.money + reward
    table.remove(inventory, index)
    
    EventBus.emit("symbol:destroy", {
        symbol = symbol,
        reward = reward
    })
    EventBus.emit(EventBus.Events.SYMBOL_REMOVE, {symbol = symbol})
    
    return reward
end

--- Get upgrade progress for a symbol type
-- Returns {current = N, needed = M, canUpgrade = bool}
function Upgrade.getUpgradeProgress(inventory, symbolKey)
    local candidates, level = Upgrade.findUpgradeCandidates(inventory, symbolKey)
    local needed = Upgrade.CONFIG.symbols_to_upgrade
    local canUpgrade = #candidates >= needed and (level or 1) < Upgrade.CONFIG.max_level
    
    return {
        current = #candidates,
        needed = needed,
        level = level or 1,
        canUpgrade = canUpgrade
    }
end

--- Get all upgradeable symbol types in inventory
function Upgrade.getUpgradeableTypes(inventory)
    local types = {}
    local checked = {}
    
    for _, sym in ipairs(inventory) do
        if not checked[sym.key] then
            checked[sym.key] = true
            if Upgrade.canUpgradeSymbol(inventory, sym.key) then
                table.insert(types, {
                    key = sym.key,
                    progress = Upgrade.getUpgradeProgress(inventory, sym.key)
                })
            end
        end
    end
    
    return types
end

return Upgrade
