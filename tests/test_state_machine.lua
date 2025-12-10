-- tests/test_state_machine.lua
-- Unit tests for StateMachine

local MiniTest = require("tests.minitest")

-- Mock EventBus
package.loaded["src.core.event_bus"] = {
    emit = function() end,
    on = function() end,
    Events = {}
}

local StateMachine = require("src.core.state_machine")

--------------------------------------------------------------------------------
-- Basic State Machine Tests
--------------------------------------------------------------------------------

MiniTest.it("new: creates state machine", function()
    local sm = StateMachine.new({
        states = {
            IDLE = {name = "IDLE"},
            RUNNING = {name = "RUNNING"}
        },
        initial = "IDLE"
    })
    
    MiniTest.assert(sm ~= nil, "Should create state machine")
    MiniTest.assertEqual(sm:getState(), "IDLE", "Should start in initial state")
end)

MiniTest.it("setState: transitions to new state", function()
    local sm = StateMachine.new({
        states = {
            A = {name = "A"},
            B = {name = "B"}
        },
        initial = "A"
    })
    
    sm:setState("B")
    MiniTest.assertEqual(sm:getState(), "B")
end)

MiniTest.it("is: checks current state", function()
    local sm = StateMachine.new({
        states = {
            A = {name = "A"},
            B = {name = "B"}
        },
        initial = "A"
    })
    
    MiniTest.assert(sm:is("A"), "Should be in state A")
    MiniTest.assert(not sm:is("B"), "Should not be in state B")
    
    sm:setState("B")
    MiniTest.assert(not sm:is("A"), "Should not be in state A")
    MiniTest.assert(sm:is("B"), "Should be in state B")
end)

--------------------------------------------------------------------------------
-- Enter/Exit Callbacks
--------------------------------------------------------------------------------

MiniTest.it("enter: called on state entry", function()
    local entered = false
    
    local sm = StateMachine.new({
        states = {
            A = {name = "A"},
            B = {
                name = "B",
                enter = function() entered = true end
            }
        },
        initial = "A"
    })
    
    MiniTest.assert(not entered, "Should not enter B yet")
    sm:setState("B")
    MiniTest.assert(entered, "Should have entered B")
end)

MiniTest.it("exit: called on state exit", function()
    local exited = false
    
    local sm = StateMachine.new({
        states = {
            A = {
                name = "A",
                exit = function() exited = true end
            },
            B = {name = "B"}
        },
        initial = "A"
    })
    
    MiniTest.assert(not exited, "Should not exit A yet")
    sm:setState("B")
    MiniTest.assert(exited, "Should have exited A")
end)

MiniTest.it("enter: receives previous state name", function()
    local fromState = nil
    
    local sm = StateMachine.new({
        states = {
            A = {name = "A"},
            B = {
                name = "B",
                enter = function(self, sm, from)
                    fromState = from
                end
            }
        },
        initial = "A"
    })
    
    sm:setState("B")
    MiniTest.assertEqual(fromState, "A", "Should receive previous state name")
end)

--------------------------------------------------------------------------------
-- Transition Rules
--------------------------------------------------------------------------------

MiniTest.it("transitions: allows valid transitions", function()
    local sm = StateMachine.new({
        states = {
            A = {name = "A"},
            B = {name = "B"},
            C = {name = "C"}
        },
        initial = "A",
        transitions = {
            A = {"B"},
            B = {"C"},
            C = {"A"}
        }
    })
    
    MiniTest.assert(sm:setState("B"), "A -> B should be allowed")
    MiniTest.assert(sm:setState("C"), "B -> C should be allowed")
    MiniTest.assert(sm:setState("A"), "C -> A should be allowed")
end)

MiniTest.it("transitions: blocks invalid transitions", function()
    local sm = StateMachine.new({
        states = {
            A = {name = "A"},
            B = {name = "B"},
            C = {name = "C"}
        },
        initial = "A",
        transitions = {
            A = {"B"},  -- A can only go to B
            B = {"C"},
            C = {"A"}
        }
    })
    
    MiniTest.assert(not sm:setState("C"), "A -> C should be blocked")
    MiniTest.assertEqual(sm:getState(), "A", "Should still be in A")
end)

MiniTest.it("canTransition: checks if transition allowed", function()
    local sm = StateMachine.new({
        states = {
            A = {name = "A"},
            B = {name = "B"},
            C = {name = "C"}
        },
        initial = "A",
        transitions = {
            A = {"B", "C"}
        }
    })
    
    MiniTest.assert(sm:canTransition("B"), "Should allow A -> B")
    MiniTest.assert(sm:canTransition("C"), "Should allow A -> C")
end)

--------------------------------------------------------------------------------
-- Update/Draw
--------------------------------------------------------------------------------

MiniTest.it("update: calls current state update", function()
    local updateCount = 0
    
    local sm = StateMachine.new({
        states = {
            A = {
                name = "A",
                update = function(self, sm, dt)
                    updateCount = updateCount + dt
                end
            }
        },
        initial = "A"
    })
    
    sm:update(0.1)
    sm:update(0.2)
    
    MiniTest.assertEqual(updateCount, 0.3, "Should accumulate dt")
end)

--------------------------------------------------------------------------------
-- Data Sharing
--------------------------------------------------------------------------------

MiniTest.it("data: shared between states", function()
    local sm = StateMachine.new({
        states = {
            A = {
                name = "A",
                enter = function(self, sm)
                    sm.data.value = 42
                end
            },
            B = {
                name = "B",
                enter = function(self, sm)
                    sm.data.value = sm.data.value * 2
                end
            }
        },
        initial = "A"
    })
    
    MiniTest.assertEqual(sm.data.value, 42)
    sm:setState("B")
    MiniTest.assertEqual(sm.data.value, 84)
end)

--------------------------------------------------------------------------------
-- defineState Helper
--------------------------------------------------------------------------------

MiniTest.it("defineState: creates state with defaults", function()
    local state = StateMachine.defineState({
        name = "TEST",
        enter = function() end
    })
    
    MiniTest.assertEqual(state.name, "TEST")
    MiniTest.assert(type(state.enter) == "function")
    MiniTest.assert(type(state.exit) == "function", "Should have default exit")
    MiniTest.assert(type(state.update) == "function", "Should have default update")
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

print("\n=== StateMachine Tests ===")
MiniTest.runAll()
