-- src/core/registry.lua
local i18n = require("src.i18n")

local Registry = {}
Registry.symbol_types = {}
Registry.relic_types = {}
Registry.consumable_types = {}

Registry.rarity_weights = {
    [1] = 100, -- Common
    [2] = 30,  -- Uncommon
    [3] = 10   -- Rare
}

local RendererFactory = require("src.core.renderer_factory")

--------------------------------------------------------------------------------
-- Validation Helpers
--------------------------------------------------------------------------------

local function assertType(value, expectedType, fieldName, context)
    if type(value) ~= expectedType then
        error(string.format("[Registry] %s: '%s' must be a %s, got %s", 
            context, fieldName, expectedType, type(value)))
    end
end

local function assertOptionalType(value, expectedType, fieldName, context)
    if value ~= nil and type(value) ~= expectedType then
        error(string.format("[Registry] %s: '%s' must be a %s or nil, got %s", 
            context, fieldName, expectedType, type(value)))
    end
end

local function assertColor(color, fieldName, context)
    if color == nil then return end
    if type(color) ~= "table" or #color < 3 then
        error(string.format("[Registry] %s: '%s' must be a color table {r, g, b}", 
            context, fieldName))
    end
    for i = 1, 3 do
        if type(color[i]) ~= "number" or color[i] < 0 or color[i] > 1 then
            error(string.format("[Registry] %s: '%s[%d]' must be a number between 0 and 1", 
                context, fieldName, i))
        end
    end
end

local function assertRarity(rarity, context)
    if rarity ~= nil then
        if type(rarity) ~= "number" or rarity < 1 or rarity > 3 then
            error(string.format("[Registry] %s: 'rarity' must be 1, 2, or 3", context))
        end
    end
end

--------------------------------------------------------------------------------
-- Symbol Registration
--------------------------------------------------------------------------------

--- Register a new symbol type with validation
-- @param key string: Unique identifier
-- @param def table: Symbol definition
function Registry.registerSymbol(key, def)
    local context = "registerSymbol('" .. tostring(key) .. "')"
    
    -- Validate key
    assertType(key, "string", "key", context)
    if key == "" then
        error("[Registry] " .. context .. ": key cannot be empty")
    end
    
    -- Validate definition
    assertType(def, "table", "definition", context)
    
    -- Validate required fields
    if def.name_key == nil and def.name == nil then
        error("[Registry] " .. context .. ": must have 'name_key' or 'name'")
    end
    assertOptionalType(def.name_key, "string", "name_key", context)
    assertOptionalType(def.name, "string", "name", context)
    assertOptionalType(def.char, "string", "char", context)
    assertColor(def.color, "color", context)
    assertOptionalType(def.value, "number", "value", context)
    assertRarity(def.rarity, context)
    assertOptionalType(def.on_calculate, "function", "on_calculate", context)
    
    -- Warn on overwrite
    if Registry.symbol_types[key] then
        print("[Registry] Warning: Overwriting symbol type '" .. key .. "'")
    end
    
    -- Set defaults
    def.key = key
    def.rarity = def.rarity or 1
    def.value = def.value or 1
    
    -- Default renderer config
    if not def.renderer then
        def.renderer = {
            type = "text",
            char = def.char or "?",
            color = def.color or {1, 1, 1}
        }
    end
    
    Registry.symbol_types[key] = def
end

--------------------------------------------------------------------------------
-- Relic Registration
--------------------------------------------------------------------------------

--- Register a new relic type with validation
-- @param key string: Unique identifier
-- @param def table: Relic definition
function Registry.registerRelic(key, def)
    local context = "registerRelic('" .. tostring(key) .. "')"
    
    -- Validate key
    assertType(key, "string", "key", context)
    if key == "" then
        error("[Registry] " .. context .. ": key cannot be empty")
    end
    
    -- Validate definition
    assertType(def, "table", "definition", context)
    
    -- Validate fields
    if def.name_key == nil and def.name == nil then
        error("[Registry] " .. context .. ": must have 'name_key' or 'name'")
    end
    assertOptionalType(def.on_spin_start, "function", "on_spin_start", context)
    assertOptionalType(def.on_spin_end, "function", "on_spin_end", context)
    assertOptionalType(def.on_calculate_end, "function", "on_calculate_end", context)
    
    def.key = key
    if not def.renderer then
        def.renderer = {
            type = "text",
            char = def.char or "?",
            color = def.color or {1, 1, 1}
        }
    end
    Registry.relic_types[key] = def
end

--------------------------------------------------------------------------------
-- Consumable Registration
--------------------------------------------------------------------------------

--- Register a new consumable type with validation
-- @param key string: Unique identifier
-- @param def table: Consumable definition
function Registry.registerConsumable(key, def)
    local context = "registerConsumable('" .. tostring(key) .. "')"
    
    -- Validate key
    assertType(key, "string", "key", context)
    if key == "" then
        error("[Registry] " .. context .. ": key cannot be empty")
    end
    
    -- Validate definition
    assertType(def, "table", "definition", context)
    
    -- Validate fields
    if def.name_key == nil and def.name == nil then
        error("[Registry] " .. context .. ": must have 'name_key' or 'name'")
    end
    assertOptionalType(def.on_use, "function", "on_use", context)
    
    def.key = key
    if not def.renderer then
        def.renderer = {
            type = "text",
            char = def.char or "?",
            color = def.color or {1, 1, 1}
        }
    end
    Registry.consumable_types[key] = def
end

-- API: Create a new instance of a symbol
function Registry.createSymbol(key)
    local def = Registry.symbol_types[key]
    if not def then error("Unknown symbol type: " .. tostring(key)) end

    local instance = {
        key = key,
        id = tostring(math.random(10000000)),
        -- Store keys for dynamic translation
        _name_key = def.name_key,
        _desc_key = def.desc_key,
        _static_name = def.name,
        _static_desc = def.desc,
        
        -- New: Renderer Component
        renderer = RendererFactory.create(def.renderer),
        
        -- Legacy visual props (for UI compat if needed, but UI should use renderer)
        base_value = def.value,
        rarity = def.rarity,
        -- Methods
        on_calculate = def.on_calculate,
        
        -- Helper to get calculated value
        getValue = function(self, grid, r, c)
            if self.on_calculate then
                return self:on_calculate(grid, r, c)
            end
            return self.base_value, {}
        end
    }
    
    -- Dynamic name/desc getters using metatables
    setmetatable(instance, {
        __index = function(t, k)
            if k == "name" then
                return t._name_key and i18n.t(t._name_key) or t._static_name
            elseif k == "desc" then
                return t._desc_key and i18n.t(t._desc_key) or t._static_desc
            end
            return rawget(t, k)
        end
    })
    
    return instance
end

-- API: Create Relic Instance
function Registry.createRelic(key)
    local def = Registry.relic_types[key]
    if not def then error("Unknown relic: " .. key) end
    
    -- Create default text renderer if none specified
    local rendererDef = def.renderer or {
        type = "text",
        char = def.char or "?",
        color = def.color or {1, 0.8, 0.2}
    }
    
    local instance = {
        key = key,
        _name_key = def.name_key,
        _desc_key = def.desc_key,
        _static_name = def.name,
        _static_desc = def.desc,
        
        renderer = RendererFactory.create(rendererDef),
        
        -- Hooks
        on_spin_start = def.on_spin_start,
        on_spin_end = def.on_spin_end,
        on_calculate_end = def.on_calculate_end
    }
    
    setmetatable(instance, {
        __index = function(t, k)
            if k == "name" then
                return t._name_key and i18n.t(t._name_key) or t._static_name
            elseif k == "desc" then
                return t._desc_key and i18n.t(t._desc_key) or t._static_desc
            end
            return rawget(t, k)
        end
    })
    
    return instance
end

-- API: Create Consumable Instance
function Registry.createConsumable(key)
    local def = Registry.consumable_types[key]
    if not def then error("Unknown consumable: " .. key) end
    
    -- Create default text renderer if none specified
    local rendererDef = def.renderer or {
        type = "text",
        char = def.char or "?",
        color = def.color or {0.5, 0.5, 1}
    }
    
    local instance = {
        key = key,
        _name_key = def.name_key,
        _desc_key = def.desc_key,
        _static_name = def.name,
        _static_desc = def.desc,
        
        renderer = RendererFactory.create(rendererDef),
        
        on_use = def.on_use
    }
    
    setmetatable(instance, {
        __index = function(t, k)
            if k == "name" then
                return t._name_key and i18n.t(t._name_key) or t._static_name
            elseif k == "desc" then
                return t._desc_key and i18n.t(t._desc_key) or t._static_desc
            end
            return rawget(t, k)
        end
    })
    
    return instance
end

-- API: Get all symbol keys
function Registry.getSymbolKeys()
    local keys = {}
    for key, _ in pairs(Registry.symbol_types) do
        table.insert(keys, key)
    end
    return keys
end

-- API: Get a random symbol key based on rarity weights
function Registry.getRandomSymbolKey()
    local pool = {}
    for key, def in pairs(Registry.symbol_types) do
        local weight = Registry.rarity_weights[def.rarity] or 100
        for i = 1, weight do
            table.insert(pool, key)
        end
    end
    return pool[math.random(#pool)]
end

return Registry
