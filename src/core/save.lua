-- src/core/save.lua
-- Save/Load system for game progress

local Save = {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

Save.SAVE_FILE = "save.json"
Save.SETTINGS_FILE = "settings.json"
Save.VERSION = 1

--------------------------------------------------------------------------------
-- JSON Library (simple implementation)
--------------------------------------------------------------------------------

-- We'll use a simple JSON encoder/decoder
local function encodeValue(val, indent, currentIndent)
    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        if val ~= val then return "null" end -- NaN
        if val == math.huge then return "1e999" end
        if val == -math.huge then return "-1e999" end
        return tostring(val)
    elseif t == "string" then
        return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    elseif t == "table" then
        local isArray = #val > 0 or next(val) == nil
        if isArray then
            local parts = {}
            for i, v in ipairs(val) do
                parts[i] = encodeValue(v, indent, currentIndent)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                if type(k) == "string" then
                    table.insert(parts, '"' .. k .. '":' .. encodeValue(v, indent, currentIndent))
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

local function encode(val)
    return encodeValue(val, false, "")
end

local function decode(str)
    if not str or str == "" then return nil end
    
    local pos = 1
    local function skipWhitespace()
        while pos <= #str and str:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
    end
    
    local parseValue
    
    local function parseString()
        pos = pos + 1 -- skip opening quote
        local start = pos
        local result = ""
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return result
            elseif c == '\\' then
                pos = pos + 1
                local escaped = str:sub(pos, pos)
                if escaped == 'n' then result = result .. '\n'
                elseif escaped == 'r' then result = result .. '\r'
                elseif escaped == 't' then result = result .. '\t'
                elseif escaped == '"' then result = result .. '"'
                elseif escaped == '\\' then result = result .. '\\'
                else result = result .. escaped end
                pos = pos + 1
            else
                result = result .. c
                pos = pos + 1
            end
        end
        return result
    end
    
    local function parseNumber()
        local start = pos
        while pos <= #str and str:sub(pos, pos):match("[%d%.eE%+%-]") do
            pos = pos + 1
        end
        return tonumber(str:sub(start, pos - 1))
    end
    
    local function parseArray()
        pos = pos + 1 -- skip [
        local arr = {}
        skipWhitespace()
        if str:sub(pos, pos) == ']' then
            pos = pos + 1
            return arr
        end
        while true do
            skipWhitespace()
            table.insert(arr, parseValue())
            skipWhitespace()
            if str:sub(pos, pos) == ']' then
                pos = pos + 1
                return arr
            elseif str:sub(pos, pos) == ',' then
                pos = pos + 1
            else
                break
            end
        end
        return arr
    end
    
    local function parseObject()
        pos = pos + 1 -- skip {
        local obj = {}
        skipWhitespace()
        if str:sub(pos, pos) == '}' then
            pos = pos + 1
            return obj
        end
        while true do
            skipWhitespace()
            if str:sub(pos, pos) ~= '"' then break end
            local key = parseString()
            skipWhitespace()
            if str:sub(pos, pos) ~= ':' then break end
            pos = pos + 1
            skipWhitespace()
            obj[key] = parseValue()
            skipWhitespace()
            if str:sub(pos, pos) == '}' then
                pos = pos + 1
                return obj
            elseif str:sub(pos, pos) == ',' then
                pos = pos + 1
            else
                break
            end
        end
        return obj
    end
    
    parseValue = function()
        skipWhitespace()
        local c = str:sub(pos, pos)
        if c == '"' then
            return parseString()
        elseif c == '{' then
            return parseObject()
        elseif c == '[' then
            return parseArray()
        elseif c == 't' then
            pos = pos + 4
            return true
        elseif c == 'f' then
            pos = pos + 5
            return false
        elseif c == 'n' then
            pos = pos + 4
            return nil
        elseif c:match("[%d%-]") then
            return parseNumber()
        end
        return nil
    end
    
    return parseValue()
end

Save.json = {encode = encode, decode = decode}

--------------------------------------------------------------------------------
-- Save Game State
--------------------------------------------------------------------------------

function Save.saveGame(engine)
    local data = {
        version = Save.VERSION,
        timestamp = os.time(),
        
        -- Core state
        money = engine.money,
        floor = engine.floor,
        rent = engine.rent,
        spins_left = engine.spins_left,
        
        -- Inventory (serialize symbols)
        inventory = {},
        
        -- Grid state
        grid = {
            rows = engine.grid.rows,
            cols = engine.grid.cols,
            cells = {}
        },
        
        -- Relics
        relics = {},
        
        -- Statistics
        stats = engine.stats or {},
    }
    
    -- Serialize inventory
    for i, sym in ipairs(engine.inventory or {}) do
        table.insert(data.inventory, {
            key = sym.key,
            level = sym.level or 1,
        })
    end
    
    -- Serialize grid
    for r = 1, engine.grid.rows do
        data.grid.cells[r] = {}
        for c = 1, engine.grid.cols do
            local sym = engine.grid.cells[r][c]
            if sym then
                data.grid.cells[r][c] = {
                    key = sym.key,
                    level = sym.level or 1,
                }
            end
        end
    end
    
    -- Serialize relics
    for i, relic in ipairs(engine.relics or {}) do
        table.insert(data.relics, {
            key = relic.key,
        })
    end
    
    -- Write to file
    local jsonStr = encode(data)
    local success, err = love.filesystem.write(Save.SAVE_FILE, jsonStr)
    
    if success then
        print("[Save] Game saved successfully")
        return true
    else
        print("[Save] Error saving game: " .. tostring(err))
        return false
    end
end

--------------------------------------------------------------------------------
-- Load Game State
--------------------------------------------------------------------------------

function Save.loadGame()
    local content, err = love.filesystem.read(Save.SAVE_FILE)
    
    if not content then
        print("[Save] No save file found")
        return nil
    end
    
    local data = decode(content)
    
    if not data then
        print("[Save] Error parsing save file")
        return nil
    end
    
    -- Version check
    if data.version ~= Save.VERSION then
        print("[Save] Save version mismatch, may have compatibility issues")
    end
    
    print("[Save] Game loaded successfully")
    return data
end

--------------------------------------------------------------------------------
-- Apply Loaded Data to Engine
--------------------------------------------------------------------------------

function Save.applyToEngine(engine, data)
    if not data then return false end
    
    local Registry = require("src.core.registry")
    
    -- Apply core state
    engine.money = data.money or 5
    engine.floor = data.floor or 1
    engine.rent = data.rent or 15
    engine.spins_left = data.spins_left or 5
    
    -- Rebuild inventory
    engine.inventory = {}
    for _, symData in ipairs(data.inventory or {}) do
        local sym = Registry.createSymbol(symData.key)
        if sym then
            sym.level = symData.level or 1
            table.insert(engine.inventory, sym)
        end
    end
    
    -- Rebuild grid
    if data.grid then
        engine.grid.rows = data.grid.rows
        engine.grid.cols = data.grid.cols
        for r = 1, engine.grid.rows do
            engine.grid.cells[r] = engine.grid.cells[r] or {}
            for c = 1, engine.grid.cols do
                local symData = data.grid.cells[r] and data.grid.cells[r][c]
                if symData then
                    local sym = Registry.createSymbol(symData.key)
                    if sym then
                        sym.level = symData.level or 1
                        engine.grid.cells[r][c] = sym
                    end
                else
                    engine.grid.cells[r][c] = nil
                end
            end
        end
    end
    
    -- Rebuild relics
    engine.relics = {}
    for _, relicData in ipairs(data.relics or {}) do
        local relic = Registry.createRelic(relicData.key)
        if relic then
            table.insert(engine.relics, relic)
        end
    end
    
    -- Apply stats
    engine.stats = data.stats or {}
    
    print("[Save] Applied save data to engine")
    return true
end

--------------------------------------------------------------------------------
-- Delete Save
--------------------------------------------------------------------------------

function Save.deleteSave()
    if love.filesystem.getInfo(Save.SAVE_FILE) then
        love.filesystem.remove(Save.SAVE_FILE)
        print("[Save] Save file deleted")
        return true
    end
    return false
end

--------------------------------------------------------------------------------
-- Check if Save Exists
--------------------------------------------------------------------------------

function Save.hasSave()
    return love.filesystem.getInfo(Save.SAVE_FILE) ~= nil
end

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

function Save.saveSettings(settings)
    local jsonStr = encode(settings)
    love.filesystem.write(Save.SETTINGS_FILE, jsonStr)
    print("[Save] Settings saved")
end

function Save.loadSettings()
    local content = love.filesystem.read(Save.SETTINGS_FILE)
    if content then
        return decode(content)
    end
    return nil
end

return Save
