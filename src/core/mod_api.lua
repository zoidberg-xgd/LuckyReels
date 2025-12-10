-- src/core/mod_api.lua
-- Mod API for LuckyReels
-- Allows players to create mods that modify game data, add content, and customize behavior

local ModAPI = {}

--------------------------------------------------------------------------------
-- Mod Registry
--------------------------------------------------------------------------------

ModAPI.mods = {}
ModAPI.loadOrder = {}

-- Register a mod
function ModAPI.register(modInfo)
    if not modInfo.id then
        error("Mod must have an 'id' field")
    end
    
    local mod = {
        id = modInfo.id,
        name = modInfo.name or modInfo.id,
        version = modInfo.version or "1.0.0",
        author = modInfo.author or "Unknown",
        description = modInfo.description or "",
        
        -- Callbacks
        onLoad = modInfo.onLoad,
        onUnload = modInfo.onUnload,
        onGameStart = modInfo.onGameStart,
        onSpinStart = modInfo.onSpinStart,
        onSpinEnd = modInfo.onSpinEnd,
        onFloorChange = modInfo.onFloorChange,
    }
    
    ModAPI.mods[mod.id] = mod
    table.insert(ModAPI.loadOrder, mod.id)
    
    print("[Mod] Registered: " .. mod.name .. " v" .. mod.version .. " by " .. mod.author)
    
    -- Call onLoad if provided
    if mod.onLoad then
        mod.onLoad(ModAPI)
    end
    
    return mod
end

-- Unregister a mod
function ModAPI.unregister(modId)
    local mod = ModAPI.mods[modId]
    if mod then
        if mod.onUnload then
            mod.onUnload(ModAPI)
        end
        ModAPI.mods[modId] = nil
        for i, id in ipairs(ModAPI.loadOrder) do
            if id == modId then
                table.remove(ModAPI.loadOrder, i)
                break
            end
        end
        print("[Mod] Unregistered: " .. modId)
    end
end

--------------------------------------------------------------------------------
-- Symbol API
--------------------------------------------------------------------------------

ModAPI.Symbols = {}

-- Add a new symbol
function ModAPI.Symbols.add(symbolDef)
    local Registry = require("src.core.registry")
    local i18n = require("src.i18n")
    
    if not symbolDef.key then
        error("Symbol must have a 'key' field")
    end
    
    -- Get localized name/desc or use provided
    local nameKey = "symbol_" .. symbolDef.key .. "_name"
    local descKey = "symbol_" .. symbolDef.key .. "_desc"
    
    -- Create symbol definition
    local def = {
        key = symbolDef.key,
        char = symbolDef.char or "?",
        color = symbolDef.color or {1, 1, 1},
        name = symbolDef.name or i18n.t(nameKey) or symbolDef.key,
        desc = symbolDef.desc or i18n.t(descKey) or "",
        base_value = symbolDef.base_value or 1,
        rarity = symbolDef.rarity or 1,
        tags = symbolDef.tags or {},
        
        -- Custom behavior
        onScore = symbolDef.onScore,
        onPlace = symbolDef.onPlace,
        onRemove = symbolDef.onRemove,
        onAdjacent = symbolDef.onAdjacent,
    }
    
    -- Register with game
    Registry.registerSymbol(def.key, def)
    
    print("[Mod] Added symbol: " .. def.key)
    return def
end

-- Modify an existing symbol
function ModAPI.Symbols.modify(key, modifications)
    local Registry = require("src.core.registry")
    local symbol = Registry.symbols[key]
    
    if not symbol then
        print("[Mod] Warning: Symbol not found: " .. key)
        return nil
    end
    
    for k, v in pairs(modifications) do
        symbol[k] = v
    end
    
    print("[Mod] Modified symbol: " .. key)
    return symbol
end

-- Get all symbols
function ModAPI.Symbols.getAll()
    local Registry = require("src.core.registry")
    return Registry.symbols
end

-- Get symbol by key
function ModAPI.Symbols.get(key)
    local Registry = require("src.core.registry")
    return Registry.symbols[key]
end

--------------------------------------------------------------------------------
-- Event API
--------------------------------------------------------------------------------

ModAPI.Events = {}

-- Add a new random event
function ModAPI.Events.add(eventDef)
    local Difficulty = require("src.core.difficulty")
    local i18n = require("src.i18n")
    
    if not eventDef.id then
        error("Event must have an 'id' field")
    end
    
    local event = {
        id = eventDef.id,
        name = eventDef.name or i18n.t(eventDef.name_key) or eventDef.id,
        desc = eventDef.desc or i18n.t(eventDef.desc_key) or "",
        weight = eventDef.weight or 10,
        type = eventDef.type or "neutral",
        apply = eventDef.apply,
    }
    
    table.insert(Difficulty.events, event)
    
    print("[Mod] Added event: " .. event.id)
    return event
end

-- Modify event weight
function ModAPI.Events.setWeight(eventId, weight)
    local Difficulty = require("src.core.difficulty")
    
    for _, event in ipairs(Difficulty.events) do
        if event.id == eventId then
            event.weight = weight
            print("[Mod] Set event weight: " .. eventId .. " = " .. weight)
            return true
        end
    end
    return false
end

-- Remove an event
function ModAPI.Events.remove(eventId)
    local Difficulty = require("src.core.difficulty")
    
    for i, event in ipairs(Difficulty.events) do
        if event.id == eventId then
            table.remove(Difficulty.events, i)
            print("[Mod] Removed event: " .. eventId)
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Synergy API
--------------------------------------------------------------------------------

ModAPI.Synergies = {}

-- Add a new category
function ModAPI.Synergies.addCategory(categoryId, symbolKeys)
    local Synergy = require("src.core.synergy")
    Synergy.categories[categoryId] = symbolKeys
    print("[Mod] Added synergy category: " .. categoryId)
end

-- Add a bonus tier to a category
function ModAPI.Synergies.addBonus(categoryId, minCount, multiplier, nameKey)
    local Synergy = require("src.core.synergy")
    
    if not Synergy.bonuses[categoryId] then
        Synergy.bonuses[categoryId] = {}
    end
    
    table.insert(Synergy.bonuses[categoryId], {minCount, multiplier, nameKey})
    print("[Mod] Added synergy bonus: " .. categoryId .. " (" .. minCount .. "+ = " .. multiplier .. "x)")
end

-- Add a special combo
function ModAPI.Synergies.addCombo(comboId, comboDef)
    local Synergy = require("src.core.synergy")
    
    Synergy.combos[comboId] = {
        symbols = comboDef.symbols,
        bonus = comboDef.bonus,
        multiplier = comboDef.multiplier,
        name_key = comboDef.name_key,
    }
    
    print("[Mod] Added combo: " .. comboId)
end

--------------------------------------------------------------------------------
-- Config API
--------------------------------------------------------------------------------

ModAPI.Config = {}

-- Modify balance values
function ModAPI.Config.setBalance(key, value)
    local Config = require("src.core.config")
    if Config.balance[key] ~= nil then
        Config.balance[key] = value
        print("[Mod] Set balance." .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

-- Modify difficulty values
function ModAPI.Config.setDifficulty(key, value)
    local Config = require("src.core.config")
    if Config.difficulty[key] ~= nil then
        Config.difficulty[key] = value
        print("[Mod] Set difficulty." .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

-- Modify shop values
function ModAPI.Config.setShop(key, value)
    local Config = require("src.core.config")
    if Config.shop[key] ~= nil then
        Config.shop[key] = value
        print("[Mod] Set shop." .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

-- Get any config value
function ModAPI.Config.get(section, key)
    local Config = require("src.core.config")
    if Config[section] and Config[section][key] ~= nil then
        return Config[section][key]
    end
    return nil
end

--------------------------------------------------------------------------------
-- Character API
--------------------------------------------------------------------------------

ModAPI.Character = {}

-- Load character from file (Spine, Parts, Spritesheet)
function ModAPI.Character.loadFromFile(path)
    local CharacterLoader = require("src.character_loader")
    local char = CharacterLoader.load(path)
    
    if char then
        print("[Mod] Loaded character from: " .. path)
        return char
    end
    return nil
end

-- Register a custom character
function ModAPI.Character.register(charDef)
    if not charDef.id then
        error("Character must have an 'id' field")
    end
    
    ModAPI.Character._customs = ModAPI.Character._customs or {}
    
    local char = {
        id = charDef.id,
        name = charDef.name or charDef.id,
        
        -- Required methods
        new = charDef.new,
        update = charDef.update,
        draw = charDef.draw,
        react = charDef.react,
        lookAt = charDef.lookAt,
        
        -- Optional config
        colors = charDef.colors,
        position = charDef.position,
    }
    
    ModAPI.Character._customs[char.id] = char
    print("[Mod] Registered character: " .. char.id)
    return char
end

-- Set active character
function ModAPI.Character.setActive(charId)
    local Character = require("src.character")
    local custom = ModAPI.Character._customs and ModAPI.Character._customs[charId]
    
    if custom and custom.new then
        -- Create instance of custom character
        local instance = custom.new()
        -- Inject required methods
        instance.update = custom.update
        instance.draw = custom.draw
        instance.react = custom.react or function() end
        instance.lookAt = custom.lookAt or function() end
        
        -- Replace singleton
        Character._customInstance = instance
        print("[Mod] Set active character: " .. charId)
        return true
    end
    return false
end

-- Get current character instance
function ModAPI.Character.getInstance()
    local Character = require("src.character")
    return Character._customInstance or Character.getInstance()
end

--------------------------------------------------------------------------------
-- Localization API
--------------------------------------------------------------------------------

ModAPI.i18n = {}

-- Add translations
function ModAPI.i18n.addTranslations(lang, translations)
    local i18n = require("src.i18n")
    local locales = i18n.locales or {}
    
    if not locales[lang] then
        locales[lang] = {}
    end
    
    local count = 0
    for key, value in pairs(translations) do
        locales[lang][key] = value
        count = count + 1
    end
    
    i18n.locales = locales
    print("[Mod] Added " .. count .. " translations for " .. lang)
end

-- Add a single translation
function ModAPI.i18n.add(lang, key, value)
    local i18n = require("src.i18n")
    local locales = i18n.locales or {}
    
    if not locales[lang] then
        locales[lang] = {}
    end
    
    locales[lang][key] = value
    i18n.locales = locales
end

--------------------------------------------------------------------------------
-- Hooks API (Event-based)
--------------------------------------------------------------------------------

ModAPI.Hooks = {}
ModAPI.Hooks._callbacks = {}

-- Register a hook callback
function ModAPI.Hooks.on(hookName, callback)
    if not ModAPI.Hooks._callbacks[hookName] then
        ModAPI.Hooks._callbacks[hookName] = {}
    end
    table.insert(ModAPI.Hooks._callbacks[hookName], callback)
end

-- Trigger a hook
function ModAPI.Hooks.trigger(hookName, ...)
    local callbacks = ModAPI.Hooks._callbacks[hookName]
    if callbacks then
        for _, callback in ipairs(callbacks) do
            callback(...)
        end
    end
end

-- Available hooks:
-- "game:start" - When game starts
-- "game:spin" - When spin starts
-- "game:score" - When scoring happens (score, symbols)
-- "game:floor" - When floor changes (oldFloor, newFloor)
-- "shop:open" - When shop opens
-- "shop:buy" - When item bought (item)
-- "symbol:place" - When symbol placed (symbol, row, col)
-- "symbol:remove" - When symbol removed (symbol)

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

ModAPI.Utils = {}

-- Deep copy a table
function ModAPI.Utils.deepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[ModAPI.Utils.deepCopy(k)] = ModAPI.Utils.deepCopy(v)
        end
        setmetatable(copy, ModAPI.Utils.deepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Merge tables
function ModAPI.Utils.merge(base, override)
    local result = ModAPI.Utils.deepCopy(base)
    for k, v in pairs(override) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = ModAPI.Utils.merge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Mod Loader
--------------------------------------------------------------------------------

-- External mod directory (user's save directory)
ModAPI.externalModDir = nil

function ModAPI.setupExternalMods()
    -- LÖVE's save directory is writable and persists after game is packaged
    -- On Windows: %APPDATA%/LOVE/gamename/
    -- On macOS: ~/Library/Application Support/LOVE/gamename/
    -- On Linux: ~/.local/share/love/gamename/
    
    if love and love.filesystem then
        -- Create mods directory in save folder if it doesn't exist
        local saveDir = love.filesystem.getSaveDirectory()
        ModAPI.externalModDir = saveDir
        
        -- Ensure mods folder exists
        if not love.filesystem.getInfo("mods") then
            love.filesystem.createDirectory("mods")
        end
        
        print("[Mod] External mod directory: " .. saveDir .. "/mods")
        print("[Mod] Users can add .lua files here to create mods!")
    end
end

function ModAPI.loadMods()
    -- Setup external mod directory first
    ModAPI.setupExternalMods()
    
    -- Load mods from mods/ directory (both internal and external)
    local modDir = "mods"
    
    -- Check if love.filesystem is available
    if love and love.filesystem then
        local items = love.filesystem.getDirectoryItems(modDir)
        
        for _, item in ipairs(items) do
            local path = modDir .. "/" .. item
            local info = love.filesystem.getInfo(path)
            
            if info and info.type == "directory" then
                -- Look for init.lua in mod folder
                local initPath = path .. "/init.lua"
                if love.filesystem.getInfo(initPath) then
                    print("[Mod] Loading: " .. item)
                    local chunk, err = love.filesystem.load(initPath)
                    if chunk then
                        local success, result = pcall(chunk)
                        if success and type(result) == "function" then
                            -- Mod returns a function, call it with ModAPI
                            local ok, modErr = pcall(result, ModAPI)
                            if not ok then
                                print("[Mod] Error initializing " .. item .. ": " .. tostring(modErr))
                            end
                        elseif not success then
                            print("[Mod] Error loading " .. item .. ": " .. tostring(result))
                        end
                    else
                        print("[Mod] Error parsing " .. item .. ": " .. tostring(err))
                    end
                end
            elseif info and item:match("%.lua$") then
                -- Single file mod
                print("[Mod] Loading: " .. item)
                local chunk, err = love.filesystem.load(path)
                if chunk then
                    local success, result = pcall(chunk)
                    if success and type(result) == "function" then
                        -- Mod returns a function, call it with ModAPI
                        local ok, modErr = pcall(result, ModAPI)
                        if not ok then
                            print("[Mod] Error initializing " .. item .. ": " .. tostring(modErr))
                        end
                    elseif not success then
                        print("[Mod] Error loading " .. item .. ": " .. tostring(result))
                    end
                else
                    print("[Mod] Error parsing " .. item .. ": " .. tostring(err))
                end
            end
        end
    end
    
    print("[Mod] Loaded " .. #ModAPI.loadOrder .. " mods")
end

return ModAPI
