-- src/api.lua
-- Public API for LuckClone
-- This module exposes a clean interface for modding and extensions

local API = {
    _VERSION = "0.1.0",
    _DESCRIPTION = "LuckClone - A Luck Be a Landlord Clone"
}

--------------------------------------------------------------------------------
-- Module References (lazy loaded)
--------------------------------------------------------------------------------

local _modules = {}

local function getModule(name)
    if not _modules[name] then
        _modules[name] = require(name)
    end
    return _modules[name]
end

--------------------------------------------------------------------------------
-- Registry API - Add custom content
--------------------------------------------------------------------------------

API.Registry = {}

--- Register a new symbol type
-- @param key string: Unique identifier
-- @param definition table: Symbol definition
-- @example
-- API.Registry.addSymbol("my_symbol", {
--     name_key = "symbol_my_name",
--     char = "X",
--     color = {1, 0, 0},
--     value = 5,
--     rarity = 2,
--     desc_key = "symbol_my_desc",
--     on_calculate = function(self, grid, r, c)
--         return self.base_value * 2, {}, {}
--     end
-- })
function API.Registry.addSymbol(key, definition)
    local Registry = getModule("src.core.registry")
    Registry.registerSymbol(key, definition)
end

--- Register a new relic type
-- @param key string: Unique identifier
-- @param definition table: Relic definition with hooks
function API.Registry.addRelic(key, definition)
    local Registry = getModule("src.core.registry")
    Registry.registerRelic(key, definition)
end

--- Register a new consumable type
-- @param key string: Unique identifier
-- @param definition table: Consumable definition
function API.Registry.addConsumable(key, definition)
    local Registry = getModule("src.core.registry")
    Registry.registerConsumable(key, definition)
end

--- Get all registered symbol keys
-- @return table: Array of symbol keys
function API.Registry.getSymbolKeys()
    local Registry = getModule("src.core.registry")
    local keys = {}
    for k in pairs(Registry.symbol_types) do
        table.insert(keys, k)
    end
    return keys
end

--- Get symbol definition by key
-- @param key string: Symbol key
-- @return table: Symbol definition or nil
function API.Registry.getSymbol(key)
    local Registry = getModule("src.core.registry")
    return Registry.symbol_types[key]
end

--------------------------------------------------------------------------------
-- Events API - Subscribe to game events
--------------------------------------------------------------------------------

API.Events = {}

--- Subscribe to an event
-- @param event string: Event name (use API.Events.Names.*)
-- @param callback function: Handler function
-- @return string: Subscription ID
function API.Events.on(event, callback)
    local EventBus = getModule("src.core.event_bus")
    return EventBus.on(event, callback)
end

--- Subscribe to an event once
-- @param event string: Event name
-- @param callback function: Handler function
function API.Events.once(event, callback)
    local EventBus = getModule("src.core.event_bus")
    return EventBus.once(event, callback)
end

--- Unsubscribe from an event
-- @param event string: Event name
-- @param id string: Subscription ID
function API.Events.off(event, id)
    local EventBus = getModule("src.core.event_bus")
    return EventBus.off(event, id)
end

--- Emit an event (for mods)
-- @param event string: Event name
-- @param data any: Event data
function API.Events.emit(event, data)
    local EventBus = getModule("src.core.event_bus")
    EventBus.emit(event, data)
end

-- Event name constants
API.Events.Names = {
    -- Game
    GAME_INIT = "game:init",
    GAME_OVER = "game:over",
    
    -- Spin
    SPIN_START = "spin:start",
    SPIN_END = "spin:end",
    SPIN_RESULT = "spin:result",
    
    -- Economy
    MONEY_CHANGE = "money:change",
    RENT_PAY = "rent:pay",
    
    -- Symbols
    SYMBOL_INTERACT = "symbol:interact",
    SYMBOL_ADD = "symbol:add",
    SYMBOL_REMOVE = "symbol:remove",
    
    -- Draft
    DRAFT_START = "draft:start",
    DRAFT_PICK = "draft:pick",
}

--------------------------------------------------------------------------------
-- Effects API - Trigger visual effects
--------------------------------------------------------------------------------

API.Effects = {}

--- Trigger screen shake
-- @param intensity number: Shake intensity (1-20)
-- @param duration number: Duration in seconds
function API.Effects.shake(intensity, duration)
    local Effects = getModule("src.effects")
    Effects.screenShake(intensity, duration)
end

--- Trigger screen flash
-- @param r number: Red (0-1)
-- @param g number: Green (0-1)
-- @param b number: Blue (0-1)
-- @param alpha number: Alpha (0-1)
-- @param duration number: Duration in seconds
function API.Effects.flash(r, g, b, alpha, duration)
    local Effects = getModule("src.effects")
    Effects.screenFlash(r, g, b, alpha, duration)
end

--- Add floating text popup
-- @param x number: X position
-- @param y number: Y position
-- @param text string: Text to display
-- @param color table: {r, g, b} color
function API.Effects.popup(x, y, text, color)
    local Effects = getModule("src.effects")
    Effects.addPopup(x, y, text, color)
end

--- Add sparkle particles
-- @param x number: X position
-- @param y number: Y position
-- @param count number: Number of particles
-- @param color table: {r, g, b} color
function API.Effects.sparkles(x, y, count, color)
    local Effects = getModule("src.effects")
    Effects.addSparkles(x, y, count, color)
end

--- Add coin burst effect
-- @param x number: X position
-- @param y number: Y position
-- @param count number: Number of coins
function API.Effects.coinBurst(x, y, count)
    local Effects = getModule("src.effects")
    Effects.addCoinBurst(x, y, count)
end

--- Spawn flying coin
-- @param fromX number: Start X
-- @param fromY number: Start Y
-- @param value number: Coin value
-- @param delay number: Delay before flying
function API.Effects.flyingCoin(fromX, fromY, value, delay)
    local Effects = getModule("src.effects")
    Effects.addFlyingCoin(fromX, fromY, value, delay)
end

--------------------------------------------------------------------------------
-- Config API - Read/modify game configuration
--------------------------------------------------------------------------------

API.Config = {}

--- Get a config value
-- @param path string: Dot-separated path (e.g., "grid.cellSize")
-- @return any: Config value
function API.Config.get(path)
    local Config = getModule("src.config")
    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    
    local value = Config
    for _, part in ipairs(parts) do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return value
end

--- Set a config value (use with caution)
-- @param path string: Dot-separated path
-- @param value any: New value
function API.Config.set(path, value)
    local Config = getModule("src.config")
    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    
    local target = Config
    for i = 1, #parts - 1 do
        if type(target[parts[i]]) ~= "table" then
            target[parts[i]] = {}
        end
        target = target[parts[i]]
    end
    target[parts[#parts]] = value
end

--------------------------------------------------------------------------------
-- i18n API - Localization
--------------------------------------------------------------------------------

API.i18n = {}

--- Get translated string
-- @param key string: Translation key
-- @param ... any: Format arguments
-- @return string: Translated string
function API.i18n.t(key, ...)
    local i18n = getModule("src.i18n")
    return i18n.t(key, ...)
end

--- Add translations for a language
-- @param lang string: Language code (e.g., "en", "zh")
-- @param translations table: Key-value translation pairs
function API.i18n.addTranslations(lang, translations)
    local i18n = getModule("src.i18n")
    -- This would need i18n module modification to support
    -- For now, just merge into current strings if matching
    if i18n.current_lang == lang then
        for k, v in pairs(translations) do
            i18n.strings[k] = v
        end
    end
end

--------------------------------------------------------------------------------
-- Utils API - Utility functions
--------------------------------------------------------------------------------

API.Utils = {}

--- Deep copy a table
function API.Utils.deepCopy(t)
    local Utils = getModule("src.utils")
    return Utils.deepCopy(t)
end

--- Shuffle an array
function API.Utils.shuffle(t)
    local Utils = getModule("src.utils")
    return Utils.shuffle(t)
end

--- Clamp a value
function API.Utils.clamp(value, min, max)
    local Utils = getModule("src.utils")
    return Utils.clamp(value, min, max)
end

--- Linear interpolation
function API.Utils.lerp(a, b, t)
    local Utils = getModule("src.utils")
    return Utils.lerp(a, b, t)
end

--- Format number with commas
function API.Utils.formatNumber(n)
    local Utils = getModule("src.utils")
    return Utils.formatNumber(n)
end

--------------------------------------------------------------------------------
-- Grid API - Query grid state
--------------------------------------------------------------------------------

API.Grid = {}

--- Get symbol at position
-- @param grid table: Grid object
-- @param r number: Row
-- @param c number: Column
-- @return table: Symbol or nil
function API.Grid.getSymbol(grid, r, c)
    return grid:getSymbol(r, c)
end

--- Get all neighbors of a position
-- @param grid table: Grid object
-- @param r number: Row
-- @param c number: Column
-- @param includeDiagonal boolean: Include diagonal neighbors
-- @return table: Array of {r, c, symbol} tables
function API.Grid.getNeighbors(grid, r, c, includeDiagonal)
    local neighbors = {}
    local dirs = includeDiagonal 
        and {{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}}
        or {{-1,0},{0,-1},{0,1},{1,0}}
    
    for _, d in ipairs(dirs) do
        local nr, nc = r + d[1], c + d[2]
        local sym = grid:getSymbol(nr, nc)
        if sym then
            table.insert(neighbors, {r = nr, c = nc, symbol = sym})
        end
    end
    return neighbors
end

--- Find all symbols of a type
-- @param grid table: Grid object
-- @param key string: Symbol key
-- @return table: Array of {r, c, symbol} tables
function API.Grid.findSymbols(grid, key)
    local found = {}
    for r = 1, grid.rows do
        for c = 1, grid.cols do
            local sym = grid:getSymbol(r, c)
            if sym and sym.key == key then
                table.insert(found, {r = r, c = c, symbol = sym})
            end
        end
    end
    return found
end

--- Count symbols of a type
-- @param grid table: Grid object
-- @param key string: Symbol key
-- @return number: Count
function API.Grid.countSymbols(grid, key)
    return #API.Grid.findSymbols(grid, key)
end

--------------------------------------------------------------------------------
-- Version Info
--------------------------------------------------------------------------------

function API.getVersion()
    return API._VERSION
end

function API.getDescription()
    return API._DESCRIPTION
end

return API
