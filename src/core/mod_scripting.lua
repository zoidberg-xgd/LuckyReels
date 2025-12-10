-- src/core/mod_scripting.lua
-- Advanced scripting system for mods
-- Allows users to define custom behaviors, animations, and logic

local ModScripting = {}

--------------------------------------------------------------------------------
-- Script Registry
--------------------------------------------------------------------------------

ModScripting.scripts = {
    -- Custom animation functions
    animations = {},
    
    -- Custom reaction functions
    reactions = {},
    
    -- Update hooks (called every frame)
    updates = {},
    
    -- Event hooks
    events = {},
    
    -- Custom parameter calculators
    parameters = {},
}

--------------------------------------------------------------------------------
-- Animation Registration
--------------------------------------------------------------------------------

-- Register a custom animation that can be used in parts.lua
-- Example:
--   ModScripting.registerAnimation("wiggle", function(part, time, intensity)
--       part.rotation = math.sin(time * 10) * intensity * 0.1
--   end)
function ModScripting.registerAnimation(name, func)
    ModScripting.scripts.animations[name] = func
    print("[ModScript] Registered animation: " .. name)
end

-- Get a registered animation
function ModScripting.getAnimation(name)
    return ModScripting.scripts.animations[name]
end

--------------------------------------------------------------------------------
-- Reaction Registration
--------------------------------------------------------------------------------

-- Register a custom reaction for game events
-- Example:
--   ModScripting.registerReaction("coin_collect", function(character, data)
--       character:triggerReaction("bounce", 0.3)
--       character.expression = "happy"
--   end)
function ModScripting.registerReaction(eventType, func)
    ModScripting.scripts.reactions[eventType] = ModScripting.scripts.reactions[eventType] or {}
    table.insert(ModScripting.scripts.reactions[eventType], func)
    print("[ModScript] Registered reaction for: " .. eventType)
end

-- Trigger all registered reactions for an event
function ModScripting.triggerReactions(eventType, character, data)
    local reactions = ModScripting.scripts.reactions[eventType]
    if reactions then
        for _, func in ipairs(reactions) do
            local ok, err = pcall(func, character, data)
            if not ok then
                print("[ModScript] Reaction error: " .. tostring(err))
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Update Hooks
--------------------------------------------------------------------------------

-- Register a function to be called every frame
-- Example:
--   ModScripting.registerUpdate("my_effect", function(character, dt, gameState)
--       if gameState.money > 50 then
--           character.parts.body.scaleX = 1.1
--       end
--   end)
function ModScripting.registerUpdate(name, func)
    ModScripting.scripts.updates[name] = func
    print("[ModScript] Registered update hook: " .. name)
end

-- Remove an update hook
function ModScripting.removeUpdate(name)
    ModScripting.scripts.updates[name] = nil
end

-- Run all update hooks
function ModScripting.runUpdates(character, dt, gameState)
    for name, func in pairs(ModScripting.scripts.updates) do
        local ok, err = pcall(func, character, dt, gameState)
        if not ok then
            print("[ModScript] Update error in " .. name .. ": " .. tostring(err))
        end
    end
end

--------------------------------------------------------------------------------
-- Event Hooks
--------------------------------------------------------------------------------

-- Register a hook for game events
function ModScripting.registerEventHook(eventType, func)
    ModScripting.scripts.events[eventType] = ModScripting.scripts.events[eventType] or {}
    table.insert(ModScripting.scripts.events[eventType], func)
end

-- Trigger event hooks
function ModScripting.triggerEvent(eventType, ...)
    local hooks = ModScripting.scripts.events[eventType]
    if hooks then
        for _, func in ipairs(hooks) do
            local ok, err = pcall(func, ...)
            if not ok then
                print("[ModScript] Event hook error: " .. tostring(err))
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Custom Parameter Calculators
--------------------------------------------------------------------------------

-- Register a custom parameter calculator
-- Example:
--   ModScripting.registerParameter("excitement", function(gameState)
--       return (gameState.money / gameState.rent) * (gameState.floor / 10)
--   end)
function ModScripting.registerParameter(name, func)
    ModScripting.scripts.parameters[name] = func
    print("[ModScript] Registered parameter: " .. name)
end

-- Calculate a custom parameter
function ModScripting.calculateParameter(name, gameState)
    local func = ModScripting.scripts.parameters[name]
    if func then
        local ok, result = pcall(func, gameState)
        if ok then
            return result
        else
            print("[ModScript] Parameter error: " .. tostring(result))
        end
    end
    return 0
end

-- Get all custom parameters
function ModScripting.calculateAllParameters(gameState)
    local params = {}
    for name, func in pairs(ModScripting.scripts.parameters) do
        local ok, result = pcall(func, gameState)
        if ok then
            params[name] = result
        end
    end
    return params
end

--------------------------------------------------------------------------------
-- Script Loading
--------------------------------------------------------------------------------

-- Load a script file from the mods directory
function ModScripting.loadScript(path)
    if love and love.filesystem then
        local content = love.filesystem.read(path)
        if content then
            local chunk, err = loadstring(content, path)
            if chunk then
                -- Create a sandboxed environment
                local env = ModScripting.createSandbox()
                setfenv(chunk, env)
                
                local ok, result = pcall(chunk)
                if ok then
                    print("[ModScript] Loaded: " .. path)
                    return true
                else
                    print("[ModScript] Error in " .. path .. ": " .. tostring(result))
                end
            else
                print("[ModScript] Parse error in " .. path .. ": " .. tostring(err))
            end
        end
    end
    return false
end

-- Create a sandboxed environment for scripts
function ModScripting.createSandbox()
    local sandbox = {
        -- Safe Lua functions
        print = print,
        pairs = pairs,
        ipairs = ipairs,
        type = type,
        tostring = tostring,
        tonumber = tonumber,
        math = math,
        string = string,
        table = table,
        
        -- Mod scripting API
        registerAnimation = ModScripting.registerAnimation,
        registerReaction = ModScripting.registerReaction,
        registerUpdate = ModScripting.registerUpdate,
        registerParameter = ModScripting.registerParameter,
        registerEventHook = ModScripting.registerEventHook,
        
        -- Access to ModAPI (if needed)
        ModAPI = _G.ModAPI,
        ModScripting = ModScripting,
    }
    
    -- Allow access to self
    sandbox._G = sandbox
    
    return sandbox
end

--------------------------------------------------------------------------------
-- Built-in Animations
--------------------------------------------------------------------------------

-- Register some built-in animations that users can reference
function ModScripting.registerBuiltins()
    -- Wobble animation
    ModScripting.registerAnimation("wobble", function(part, time, intensity)
        intensity = intensity or 1
        part.rotation = (part.rotation or 0) + math.sin(time * 8) * 0.1 * intensity
        part.scaleX = (part.scaleX or 1) + math.sin(time * 6) * 0.05 * intensity
    end)
    
    -- Float animation
    ModScripting.registerAnimation("float", function(part, time, intensity)
        intensity = intensity or 1
        part.y = (part.y or 0) + math.sin(time * 2) * 5 * intensity
    end)
    
    -- Pulse animation
    ModScripting.registerAnimation("pulse", function(part, time, intensity)
        intensity = intensity or 1
        local pulse = 1 + math.sin(time * 4) * 0.1 * intensity
        part.scaleX = (part.scaleX or 1) * pulse
        part.scaleY = (part.scaleY or 1) * pulse
    end)
    
    -- Shake animation
    ModScripting.registerAnimation("shake_anim", function(part, time, intensity)
        intensity = intensity or 1
        part.x = (part.x or 0) + math.sin(time * 20) * 2 * intensity
    end)
    
    -- Squash and stretch
    ModScripting.registerAnimation("squash", function(part, time, intensity)
        intensity = intensity or 1
        local squash = math.sin(time * 6)
        part.scaleX = (part.scaleX or 1) + squash * 0.1 * intensity
        part.scaleY = (part.scaleY or 1) - squash * 0.1 * intensity
    end)
end

-- Initialize built-ins
ModScripting.registerBuiltins()

return ModScripting
