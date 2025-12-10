-- src/game_states.lua
-- Game state definitions for the state machine

local StateMachine = require("src.core.state_machine")
local EventBus = require("src.core.event_bus")

local States = {}

--------------------------------------------------------------------------------
-- IDLE State - Waiting for player to spin
--------------------------------------------------------------------------------
States.IDLE = StateMachine.defineState({
    name = "IDLE",
    
    enter = function(self, sm, from)
        -- Nothing special on enter
    end,
    
    update = function(self, sm, dt)
        -- Idle state doesn't need updates
    end,
    
    keypressed = function(self, sm, key)
        if key == "space" then
            if sm.data.engine:spin() then
                sm:setState("SPINNING")
            end
        end
    end,
    
    mousepressed = function(self, sm, x, y, button)
        local UI = require("src.ui")
        local zone = UI.getZoneAt(x, y)
        if zone == "SPIN" then
            if sm.data.engine:spin() then
                sm:setState("SPINNING")
            end
        end
    end
})

--------------------------------------------------------------------------------
-- SPINNING State - Reels are spinning
--------------------------------------------------------------------------------
States.SPINNING = StateMachine.defineState({
    name = "SPINNING",
    
    enter = function(self, sm, from)
        sm.data.spinTimer = 0
    end,
    
    update = function(self, sm, dt)
        local engine = sm.data.engine
        engine.spin_timer = engine.spin_timer + dt
        
        if engine.spin_timer >= engine.spin_duration then
            engine:resolveSpin()
            sm:setState("COLLECTING")
        end
    end,
    
    -- No input during spinning
    keypressed = function(self, sm, key) end,
    mousepressed = function(self, sm, x, y, button) end
})

--------------------------------------------------------------------------------
-- COLLECTING State - Coins flying to HUD
--------------------------------------------------------------------------------
States.COLLECTING = StateMachine.defineState({
    name = "COLLECTING",
    
    enter = function(self, sm, from)
        sm.data.collectTimer = 0
    end,
    
    update = function(self, sm, dt)
        local engine = sm.data.engine
        local Effects = require("src.effects")
        
        engine.collect_timer = engine.collect_timer + dt
        
        -- Wait for minimum time AND all effects to finish
        if engine.collect_timer >= engine.collect_min_wait and not Effects.isCollecting() then
            engine:finishCollecting()
            
            -- Transition based on engine state
            if engine.state == "GAME_OVER" then
                sm:setState("GAME_OVER")
            elseif engine.state == "DRAFT" then
                sm:setState("DRAFT")
            else
                sm:setState("IDLE")
            end
        end
    end,
    
    -- No input during collecting
    keypressed = function(self, sm, key) end,
    mousepressed = function(self, sm, x, y, button) end
})

--------------------------------------------------------------------------------
-- DRAFT State - Choosing a new symbol
--------------------------------------------------------------------------------
States.DRAFT = StateMachine.defineState({
    name = "DRAFT",
    
    enter = function(self, sm, from)
        -- Draft options already set by engine
    end,
    
    update = function(self, sm, dt)
        -- Nothing to update
    end,
    
    keypressed = function(self, sm, key)
        local engine = sm.data.engine
        local index = tonumber(key)
        
        if index and index >= 1 and index <= #engine.draft_options then
            engine:pickDraft(index)
            sm:setState("IDLE")
        elseif key == "4" or key == "escape" then
            engine:pickDraft(nil)  -- Skip
            sm:setState("IDLE")
        end
    end,
    
    mousepressed = function(self, sm, x, y, button)
        local UI = require("src.ui")
        local zone = UI.getZoneAt(x, y)
        local engine = sm.data.engine
        
        if zone then
            if zone:match("^DRAFT_(%d+)$") then
                local index = tonumber(zone:match("DRAFT_(%d+)"))
                engine:pickDraft(index)
                sm:setState("IDLE")
            elseif zone == "SKIP" then
                engine:pickDraft(nil)
                sm:setState("IDLE")
            end
        end
    end
})

--------------------------------------------------------------------------------
-- REMOVING State - Selecting symbol to remove
--------------------------------------------------------------------------------
States.REMOVING = StateMachine.defineState({
    name = "REMOVING",
    
    enter = function(self, sm, from)
        -- Set by consumable
    end,
    
    keypressed = function(self, sm, key)
        local engine = sm.data.engine
        local index = tonumber(key)
        
        if index and index >= 1 and index <= #engine.inventory then
            engine:removeSymbolFromInventory(index)
            engine:finishConsumable()
            sm:setState("IDLE")
        elseif key == "escape" then
            engine.state = "IDLE"
            engine.active_consumable_index = nil
            sm:setState("IDLE")
        end
    end,
    
    mousepressed = function(self, sm, x, y, button)
        local UI = require("src.ui")
        local zone = UI.getZoneAt(x, y)
        local engine = sm.data.engine
        
        if zone then
            if zone:match("^REMOVE_(%d+)$") then
                local index = tonumber(zone:match("REMOVE_(%d+)"))
                engine:removeSymbolFromInventory(index)
                engine:finishConsumable()
                sm:setState("IDLE")
            elseif zone == "CANCEL_REMOVE" then
                engine.state = "IDLE"
                engine.active_consumable_index = nil
                sm:setState("IDLE")
            end
        end
    end
})

--------------------------------------------------------------------------------
-- GAME_OVER State
--------------------------------------------------------------------------------
States.GAME_OVER = StateMachine.defineState({
    name = "GAME_OVER",
    
    enter = function(self, sm, from)
        EventBus.emit(EventBus.Events.GAME_OVER, {
            engine = sm.data.engine
        })
    end,
    
    keypressed = function(self, sm, key)
        if key == "r" then
            -- Restart game
            sm.data.engine:init(sm.data.engine.config)
            sm:setState("IDLE")
            EventBus.emit(EventBus.Events.GAME_RESET, {})
        end
    end,
    
    mousepressed = function(self, sm, x, y, button)
        -- Could add restart button
    end
})

--------------------------------------------------------------------------------
-- Create State Machine
--------------------------------------------------------------------------------

function States.createGameStateMachine(engine)
    local sm = StateMachine.new({
        initial = "IDLE",
        states = {
            IDLE = States.IDLE,
            SPINNING = States.SPINNING,
            COLLECTING = States.COLLECTING,
            DRAFT = States.DRAFT,
            REMOVING = States.REMOVING,
            GAME_OVER = States.GAME_OVER,
        },
        transitions = {
            IDLE = {"SPINNING", "REMOVING"},
            SPINNING = {"COLLECTING"},
            COLLECTING = {"DRAFT", "GAME_OVER", "IDLE"},
            DRAFT = {"IDLE"},
            REMOVING = {"IDLE"},
            GAME_OVER = {"IDLE"},
        }
    })
    
    -- Store engine reference
    sm.data.engine = engine
    
    return sm
end

return States
