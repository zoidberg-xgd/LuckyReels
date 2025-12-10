-- tests/test_event_bus.lua
-- Unit tests for EventBus

local MiniTest = require("tests.minitest")

-- Reset EventBus before tests
local EventBus = require("src.core.event_bus")

--------------------------------------------------------------------------------
-- Basic Event Tests
--------------------------------------------------------------------------------

MiniTest.it("on/emit: basic event", function()
    EventBus.clear()
    
    local received = nil
    EventBus.on("test:basic", function(data)
        received = data
    end)
    
    EventBus.emit("test:basic", {value = 42})
    
    MiniTest.assert(received ~= nil, "Should receive event")
    MiniTest.assertEqual(received.value, 42)
end)

MiniTest.it("on: multiple listeners", function()
    EventBus.clear()
    
    local count = 0
    EventBus.on("test:multi", function() count = count + 1 end)
    EventBus.on("test:multi", function() count = count + 1 end)
    EventBus.on("test:multi", function() count = count + 1 end)
    
    EventBus.emit("test:multi")
    
    MiniTest.assertEqual(count, 3, "All listeners should be called")
end)

MiniTest.it("on: priority order", function()
    EventBus.clear()
    
    local order = {}
    EventBus.on("test:priority", function() table.insert(order, "low") end, 0)
    EventBus.on("test:priority", function() table.insert(order, "high") end, 10)
    EventBus.on("test:priority", function() table.insert(order, "medium") end, 5)
    
    EventBus.emit("test:priority")
    
    MiniTest.assertEqual(order[1], "high", "High priority first")
    MiniTest.assertEqual(order[2], "medium", "Medium priority second")
    MiniTest.assertEqual(order[3], "low", "Low priority last")
end)

--------------------------------------------------------------------------------
-- Once Tests
--------------------------------------------------------------------------------

MiniTest.it("once: only fires once", function()
    EventBus.clear()
    
    local count = 0
    EventBus.once("test:once", function() count = count + 1 end)
    
    EventBus.emit("test:once")
    EventBus.emit("test:once")
    EventBus.emit("test:once")
    
    MiniTest.assertEqual(count, 1, "Should only fire once")
end)

--------------------------------------------------------------------------------
-- Off Tests
--------------------------------------------------------------------------------

MiniTest.it("off: removes listener", function()
    EventBus.clear()
    
    local count = 0
    local id = EventBus.on("test:off", function() count = count + 1 end)
    
    EventBus.emit("test:off")
    MiniTest.assertEqual(count, 1)
    
    EventBus.off("test:off", id)
    EventBus.emit("test:off")
    MiniTest.assertEqual(count, 1, "Should not fire after off()")
end)

--------------------------------------------------------------------------------
-- Clear Tests
--------------------------------------------------------------------------------

MiniTest.it("clear: removes all listeners for event", function()
    EventBus.clear()
    
    local count = 0
    EventBus.on("test:clear", function() count = count + 1 end)
    EventBus.on("test:clear", function() count = count + 1 end)
    EventBus.on("test:other", function() count = count + 1 end)
    
    EventBus.clear("test:clear")
    
    EventBus.emit("test:clear")
    MiniTest.assertEqual(count, 0, "Cleared event should not fire")
    
    EventBus.emit("test:other")
    MiniTest.assertEqual(count, 1, "Other event should still fire")
end)

MiniTest.it("clear: removes all listeners", function()
    EventBus.clear()
    
    local count = 0
    EventBus.on("test:a", function() count = count + 1 end)
    EventBus.on("test:b", function() count = count + 1 end)
    
    EventBus.clear()
    
    EventBus.emit("test:a")
    EventBus.emit("test:b")
    MiniTest.assertEqual(count, 0, "No events should fire after clear()")
end)

--------------------------------------------------------------------------------
-- Count Tests
--------------------------------------------------------------------------------

MiniTest.it("count: returns listener count", function()
    EventBus.clear()
    
    MiniTest.assertEqual(EventBus.count("test:count"), 0)
    
    EventBus.on("test:count", function() end)
    MiniTest.assertEqual(EventBus.count("test:count"), 1)
    
    EventBus.on("test:count", function() end)
    MiniTest.assertEqual(EventBus.count("test:count"), 2)
end)

--------------------------------------------------------------------------------
-- Error Handling Tests
--------------------------------------------------------------------------------

MiniTest.it("emit: handles listener errors gracefully", function()
    EventBus.clear()
    
    local secondCalled = false
    
    EventBus.on("test:error", function()
        error("Intentional error")
    end)
    EventBus.on("test:error", function()
        secondCalled = true
    end)
    
    -- Should not throw
    EventBus.emit("test:error")
    
    MiniTest.assert(secondCalled, "Second listener should still be called")
end)

MiniTest.it("on: rejects non-function callback", function()
    EventBus.clear()
    
    local success = pcall(function()
        EventBus.on("test:invalid", "not a function")
    end)
    
    MiniTest.assert(not success, "Should throw on non-function callback")
end)

--------------------------------------------------------------------------------
-- Event Names Tests
--------------------------------------------------------------------------------

MiniTest.it("Events: predefined names exist", function()
    MiniTest.assert(EventBus.Events.SPIN_START ~= nil)
    MiniTest.assert(EventBus.Events.SPIN_END ~= nil)
    MiniTest.assert(EventBus.Events.MONEY_CHANGE ~= nil)
    MiniTest.assert(EventBus.Events.GAME_OVER ~= nil)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

print("\n=== EventBus Tests ===")
MiniTest.runAll()
