-- src/utils.lua
-- Utility functions and helpers

local Utils = {}

--------------------------------------------------------------------------------
-- TABLE UTILITIES
--------------------------------------------------------------------------------

-- Deep copy a table
function Utils.deepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[Utils.deepCopy(k)] = Utils.deepCopy(v)
        end
        setmetatable(copy, Utils.deepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Merge two tables (shallow)
function Utils.merge(t1, t2)
    local result = {}
    for k, v in pairs(t1 or {}) do result[k] = v end
    for k, v in pairs(t2 or {}) do result[k] = v end
    return result
end

-- Fisher-Yates shuffle
function Utils.shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

--------------------------------------------------------------------------------
-- MATH UTILITIES
--------------------------------------------------------------------------------

-- Clamp a value between min and max
function Utils.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Linear interpolation
function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

-- Map a value from one range to another
function Utils.map(value, inMin, inMax, outMin, outMax)
    return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin)
end

--------------------------------------------------------------------------------
-- EASING FUNCTIONS
--------------------------------------------------------------------------------

function Utils.easeOutBack(t, b, c, d, s)
    s = s or 1.70158
    t = t / d - 1
    return c * (t * t * ((s + 1) * t + s) + 1) + b
end

function Utils.easeOutElastic(t, b, c, d)
    if t == 0 then return b end
    t = t / d
    if t == 1 then return b + c end
    local p = d * 0.3
    local s = p / 4
    return c * math.pow(2, -10 * t) * math.sin((t * d - s) * (2 * math.pi) / p) + c + b
end

function Utils.easeOutCubic(t, b, c, d)
    t = t / d - 1
    return c * (t * t * t + 1) + b
end

function Utils.easeInQuad(t, b, c, d)
    t = t / d
    return c * t * t + b
end

function Utils.easeOutQuad(t, b, c, d)
    t = t / d
    return -c * t * (t - 2) + b
end

--------------------------------------------------------------------------------
-- VALIDATION
--------------------------------------------------------------------------------

-- Assert with custom message
function Utils.assert(condition, message, ...)
    if not condition then
        error(string.format(message or "Assertion failed", ...), 2)
    end
    return condition
end

-- Check if value is a number
function Utils.isNumber(v)
    return type(v) == "number"
end

-- Check if value is a string
function Utils.isString(v)
    return type(v) == "string"
end

-- Check if value is a table
function Utils.isTable(v)
    return type(v) == "table"
end

-- Check if value is a function
function Utils.isFunction(v)
    return type(v) == "function"
end

--------------------------------------------------------------------------------
-- COLOR UTILITIES
--------------------------------------------------------------------------------

-- Convert HSV to RGB
function Utils.hsvToRgb(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    
    return r, g, b
end

-- Lighten a color
function Utils.lighten(color, amount)
    return {
        Utils.clamp(color[1] + amount, 0, 1),
        Utils.clamp(color[2] + amount, 0, 1),
        Utils.clamp(color[3] + amount, 0, 1),
        color[4] or 1
    }
end

-- Darken a color
function Utils.darken(color, amount)
    return Utils.lighten(color, -amount)
end

--------------------------------------------------------------------------------
-- STRING UTILITIES
--------------------------------------------------------------------------------

-- Format number with commas
function Utils.formatNumber(n)
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

return Utils
