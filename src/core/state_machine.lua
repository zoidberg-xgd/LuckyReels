-- src/core/state_machine.lua
-- Finite State Machine for game state management

local EventBus = require("src.core.event_bus")

local StateMachine = {}
StateMachine.__index = StateMachine

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

--- Create a new state machine
-- @param config table: {states: table, initial: string, transitions: table}
-- @return StateMachine
function StateMachine.new(config)
    local self = setmetatable({}, StateMachine)
    
    self.states = config.states or {}
    self.current = nil
    self.previous = nil
    self.transitions = config.transitions or {}
    self.data = {}  -- Shared data between states
    
    -- Validate states have required methods
    for name, state in pairs(self.states) do
        state.name = name
    end
    
    -- Set initial state
    if config.initial then
        self:setState(config.initial)
    end
    
    return self
end

--------------------------------------------------------------------------------
-- Core API
--------------------------------------------------------------------------------

--- Get current state name
-- @return string
function StateMachine:getState()
    return self.current and self.current.name or nil
end

--- Check if in a specific state
-- @param name string: State name
-- @return boolean
function StateMachine:is(name)
    return self.current and self.current.name == name
end

--- Transition to a new state
-- @param name string: Target state name
-- @param ... any: Arguments passed to enter()
-- @return boolean: Success
function StateMachine:setState(name, ...)
    local newState = self.states[name]
    if not newState then
        print(string.format("[StateMachine] Unknown state: %s", name))
        return false
    end
    
    -- Check if transition is allowed
    if self.current and self.transitions[self.current.name] then
        local allowed = self.transitions[self.current.name]
        if type(allowed) == "table" then
            local found = false
            for _, s in ipairs(allowed) do
                if s == name then found = true; break end
            end
            if not found then
                print(string.format("[StateMachine] Transition %s -> %s not allowed", 
                    self.current.name, name))
                return false
            end
        end
    end
    
    -- Exit current state
    if self.current and self.current.exit then
        self.current:exit(self, name)
    end
    
    -- Store previous
    self.previous = self.current
    self.current = newState
    
    -- Emit event
    EventBus.emit("state:change", {
        from = self.previous and self.previous.name,
        to = name
    })
    
    -- Enter new state
    if self.current.enter then
        self.current:enter(self, self.previous and self.previous.name, ...)
    end
    
    return true
end

--- Update current state
-- @param dt number: Delta time
function StateMachine:update(dt)
    if self.current and self.current.update then
        self.current:update(self, dt)
    end
end

--- Draw current state
function StateMachine:draw()
    if self.current and self.current.draw then
        self.current:draw(self)
    end
end

--- Handle input in current state
-- @param input string: Input type
-- @param ... any: Input arguments
function StateMachine:input(input, ...)
    if self.current and self.current[input] then
        self.current[input](self.current, self, ...)
    end
end

--- Check if can transition to a state
-- @param name string: Target state name
-- @return boolean
function StateMachine:canTransition(name)
    if not self.current then return true end
    if not self.transitions[self.current.name] then return true end
    
    local allowed = self.transitions[self.current.name]
    if type(allowed) == "table" then
        for _, s in ipairs(allowed) do
            if s == name then return true end
        end
        return false
    end
    return true
end

--------------------------------------------------------------------------------
-- State Template
--------------------------------------------------------------------------------

--- Create a state definition helper
-- @param def table: State definition
-- @return table: State object
function StateMachine.defineState(def)
    return {
        name = def.name,
        enter = def.enter or function() end,
        exit = def.exit or function() end,
        update = def.update or function() end,
        draw = def.draw or function() end,
        -- Input handlers
        keypressed = def.keypressed,
        mousepressed = def.mousepressed,
        mousereleased = def.mousereleased,
    }
end

return StateMachine
