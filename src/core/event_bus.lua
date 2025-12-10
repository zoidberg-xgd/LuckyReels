-- src/core/event_bus.lua
-- Event Bus System for decoupled communication between modules

local EventBus = {}
EventBus._listeners = {}

--------------------------------------------------------------------------------
-- Core API
--------------------------------------------------------------------------------

--- Register a listener for an event
-- @param event string: Event name
-- @param callback function: Function to call when event fires
-- @param priority number: Optional priority (higher = called first, default 0)
-- @return string: Listener ID for unsubscribing
function EventBus.on(event, callback, priority)
    if type(callback) ~= "function" then
        error("EventBus.on: callback must be a function")
    end
    
    priority = priority or 0
    EventBus._listeners[event] = EventBus._listeners[event] or {}
    
    local id = tostring(callback) .. "_" .. tostring(math.random(100000))
    table.insert(EventBus._listeners[event], {
        id = id,
        callback = callback,
        priority = priority
    })
    
    -- Sort by priority (descending)
    table.sort(EventBus._listeners[event], function(a, b)
        return a.priority > b.priority
    end)
    
    return id
end

--- Register a one-time listener
-- @param event string: Event name
-- @param callback function: Function to call once
function EventBus.once(event, callback)
    local id
    id = EventBus.on(event, function(...)
        EventBus.off(event, id)
        callback(...)
    end)
    return id
end

--- Remove a listener
-- @param event string: Event name
-- @param id string: Listener ID returned from on()
function EventBus.off(event, id)
    if not EventBus._listeners[event] then return end
    
    for i, listener in ipairs(EventBus._listeners[event]) do
        if listener.id == id then
            table.remove(EventBus._listeners[event], i)
            return true
        end
    end
    return false
end

--- Emit an event to all listeners
-- @param event string: Event name
-- @param ... any: Arguments to pass to listeners
function EventBus.emit(event, ...)
    if not EventBus._listeners[event] then return end
    
    for _, listener in ipairs(EventBus._listeners[event]) do
        local success, err = pcall(listener.callback, ...)
        if not success then
            print(string.format("[EventBus] Error in '%s' listener: %s", event, err))
        end
    end
end

--- Clear all listeners for an event (or all events)
-- @param event string: Optional event name, nil clears all
function EventBus.clear(event)
    if event then
        EventBus._listeners[event] = nil
    else
        EventBus._listeners = {}
    end
end

--- Get listener count for an event
-- @param event string: Event name
-- @return number: Number of listeners
function EventBus.count(event)
    if not EventBus._listeners[event] then return 0 end
    return #EventBus._listeners[event]
end

--------------------------------------------------------------------------------
-- Predefined Event Names (for documentation and autocomplete)
--------------------------------------------------------------------------------

EventBus.Events = {
    -- Game lifecycle
    GAME_INIT = "game:init",
    GAME_START = "game:start",
    GAME_OVER = "game:over",
    GAME_RESET = "game:reset",
    
    -- Spin events
    SPIN_START = "spin:start",
    SPIN_REEL_STOP = "spin:reel_stop",      -- {column: number}
    SPIN_END = "spin:end",
    SPIN_RESULT = "spin:result",            -- {score: number, interactions: table}
    
    -- Collection events
    COLLECT_START = "collect:start",
    COLLECT_COIN = "collect:coin",          -- {value: number, x: number, y: number}
    COLLECT_END = "collect:end",
    
    -- Draft events
    DRAFT_START = "draft:start",            -- {options: table}
    DRAFT_PICK = "draft:pick",              -- {symbol: table, index: number}
    DRAFT_SKIP = "draft:skip",
    
    -- Symbol events
    SYMBOL_INTERACT = "symbol:interact",    -- {type: string, source: table, target: table}
    SYMBOL_DESTROY = "symbol:destroy",      -- {symbol: table, r: number, c: number}
    SYMBOL_ADD = "symbol:add",              -- {symbol: table}
    SYMBOL_REMOVE = "symbol:remove",        -- {symbol: table}
    
    -- Economy events
    MONEY_CHANGE = "money:change",          -- {old: number, new: number, delta: number}
    RENT_PAY = "rent:pay",                  -- {amount: number, newRent: number}
    RENT_FAIL = "rent:fail",                -- {money: number, rent: number}
    
    -- UI events
    UI_BUTTON_CLICK = "ui:button_click",    -- {id: string}
    UI_HOVER_START = "ui:hover_start",      -- {id: string}
    UI_HOVER_END = "ui:hover_end",          -- {id: string}
    
    -- Effect events
    EFFECT_SHAKE = "effect:shake",          -- {intensity: number, duration: number}
    EFFECT_FLASH = "effect:flash",          -- {color: table, alpha: number}
    EFFECT_PARTICLE = "effect:particle",    -- {type: string, x: number, y: number}
}

return EventBus
