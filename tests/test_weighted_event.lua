-- tests/test_weighted_event.lua
-- Weighted Event System 单元测试

local WeightedEvent = require("lib.weighted_event")

local passed = 0
local failed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("✓ " .. name)
    else
        failed = failed + 1
        print("✗ " .. name)
        print("  Error: " .. tostring(err))
    end
end

local function assertEquals(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", msg or "Assertion failed", tostring(expected), tostring(actual)))
    end
end

local function assertTrue(value, msg)
    if not value then
        error(msg or "Expected true, got false")
    end
end

local function assertFalse(value, msg)
    if value then
        error(msg or "Expected false, got true")
    end
end

local function assertNotNil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil value")
    end
end

print("\n========================================")
print("Weighted Event System Tests")
print("========================================\n")

test("WeightedEventPool.new creates pool", function()
    local pool = WeightedEvent.newPool({
        events = {
            {id = "a", weight = 10},
            {id = "b", weight = 5},
        },
    })
    assertEquals(2, #pool.events)
end)

test("addEvent adds event", function()
    local pool = WeightedEvent.newPool({events = {}})
    pool:addEvent({id = "new", weight = 10})
    assertEquals(1, #pool.events)
end)

test("removeEvent removes event", function()
    local pool = WeightedEvent.newPool({
        events = {{id = "a", weight = 10}, {id = "b", weight = 5}},
    })
    pool:removeEvent("a")
    assertEquals(1, #pool.events)
    assertEquals("b", pool.events[1].id)
end)

test("getEvent returns event", function()
    local pool = WeightedEvent.newPool({
        events = {{id = "test", weight = 10, type = "rare"}},
    })
    local event = pool:getEvent("test")
    assertNotNil(event)
    assertEquals("test", event.id)
    assertEquals("rare", event.type)
end)

test("roll returns event with 100% chance", function()
    local pool = WeightedEvent.newPool({
        events = {{id = "only", weight = 10}},
    })
    local triggered, event = pool:roll({baseChance = 1.0})
    assertTrue(triggered)
    assertEquals("only", event.id)
end)

test("roll respects baseChance", function()
    local pool = WeightedEvent.newPool({
        events = {{id = "test", weight = 10}},
    })
    
    -- 0% chance should never trigger
    local triggerCount = 0
    for _ = 1, 100 do
        local triggered = pool:roll({baseChance = 0})
        if triggered then triggerCount = triggerCount + 1 end
    end
    assertEquals(0, triggerCount)
end)

test("roll weighted distribution", function()
    local pool = WeightedEvent.newPool({
        events = {
            {id = "common", weight = 90},
            {id = "rare", weight = 10},
        },
    })
    
    local results = pool:simulate(1000, {baseChance = 1.0})
    
    -- Common should be much more frequent
    assertTrue(results.common > results.rare)
    -- Common should be roughly 90%
    assertTrue(results.common > 700)
end)

test("roll with filter", function()
    local pool = WeightedEvent.newPool({
        events = {
            {id = "a", weight = 10, type = "positive"},
            {id = "b", weight = 10, type = "negative"},
        },
    })
    
    local results = pool:simulate(100, {
        baseChance = 1.0,
        filter = {type = "positive"},
    })
    
    assertEquals(100, results.a or 0)
    assertEquals(nil, results.b)
end)

test("modifier multiplies weight", function()
    local pool = WeightedEvent.newPool({
        events = {
            {id = "a", weight = 10, type = "positive"},
            {id = "b", weight = 10, type = "negative"},
        },
        modifiers = {
            {
                condition = function(ctx) return ctx.boost end,
                filter = {type = "positive"},
                multiply = 10,
            },
        },
    })
    
    -- Without boost
    local weights = pool:getWeights({boost = false})
    assertEquals(10, weights.a)
    assertEquals(10, weights.b)
    
    -- With boost
    weights = pool:getWeights({boost = true})
    assertEquals(100, weights.a)
    assertEquals(10, weights.b)
end)

test("modifier adds weight", function()
    local pool = WeightedEvent.newPool({
        events = {{id = "test", weight = 10}},
        modifiers = {
            {
                condition = function(ctx) return ctx.bonus end,
                add = 20,
            },
        },
    })
    
    assertEquals(10, pool:getWeights({bonus = false}).test)
    assertEquals(30, pool:getWeights({bonus = true}).test)
end)

test("pity guarantees event", function()
    local pool = WeightedEvent.newPool({
        events = {
            {id = "common", weight = 100, type = "common"},
            {id = "rare", weight = 1, type = "rare"},
        },
        pity = {
            threshold = 5,
            guarantee = {type = "rare"},
        },
    })
    
    -- Force 5 rolls without trigger
    pool.rollCount = 4
    pool.lastTriggerRoll = 0
    
    local triggered, event = pool:roll({baseChance = 1.0})
    assertTrue(triggered)
    assertEquals("rare", event.id)
end)

test("getHistory returns recent history", function()
    local pool = WeightedEvent.newPool({
        events = {{id = "test", weight = 10}},
    })
    
    for _ = 1, 5 do
        pool:roll({baseChance = 1.0})
    end
    
    local history = pool:getHistory(3)
    assertEquals(3, #history)
end)

test("getStats returns statistics", function()
    local pool = WeightedEvent.newPool({
        events = {{id = "test", weight = 10}},
    })
    
    pool:roll({baseChance = 1.0})
    pool:roll({baseChance = 1.0})
    
    local stats = pool:getStats()
    assertEquals(2, stats.totalRolls)
    assertEquals(2, stats.events.test.count)
end)

test("resetStats clears statistics", function()
    local pool = WeightedEvent.newPool({
        events = {{id = "test", weight = 10}},
    })
    
    pool:roll({baseChance = 1.0})
    pool:resetStats()
    
    local stats = pool:getStats()
    assertEquals(0, stats.totalRolls)
    assertEquals(0, stats.events.test.count)
end)

test("getProbabilities returns correct probabilities", function()
    local pool = WeightedEvent.newPool({
        events = {
            {id = "a", weight = 75},
            {id = "b", weight = 25},
        },
    })
    
    local probs = pool:getProbabilities()
    assertTrue(math.abs(probs.a - 0.75) < 0.01)
    assertTrue(math.abs(probs.b - 0.25) < 0.01)
end)

test("serialize and deserialize", function()
    local pool = WeightedEvent.newPool({
        events = {{id = "test", weight = 10}},
    })
    
    pool:roll({baseChance = 1.0})
    pool:roll({baseChance = 1.0})
    
    local data = pool:serialize()
    
    local pool2 = WeightedEvent.newPool({
        events = {{id = "test", weight = 10}},
    })
    pool2:deserialize(data)
    
    assertEquals(2, pool2.rollCount)
    assertEquals(2, #pool2.history)
end)

test("simulate does not affect real stats", function()
    local pool = WeightedEvent.newPool({
        events = {{id = "test", weight = 10}},
    })
    
    pool:simulate(100, {baseChance = 1.0})
    
    assertEquals(0, pool.rollCount)
    assertEquals(0, #pool.history)
end)

test("multiple modifiers stack", function()
    local pool = WeightedEvent.newPool({
        events = {{id = "test", weight = 10}},
        modifiers = {
            {condition = function() return true end, multiply = 2},
            {condition = function() return true end, add = 5},
        },
    })
    
    -- 10 * 2 + 5 = 25
    assertEquals(25, pool:getWeights({}).test)
end)

test("zero weight event not selected", function()
    local pool = WeightedEvent.newPool({
        events = {
            {id = "zero", weight = 0},
            {id = "normal", weight = 10},
        },
    })
    
    local results = pool:simulate(100, {baseChance = 1.0})
    assertEquals(nil, results.zero)
    assertEquals(100, results.normal)
end)

print("\n========================================")
print(string.format("Results: %d passed, %d failed", passed, failed))
print("========================================\n")

return {passed = passed, failed = failed}
