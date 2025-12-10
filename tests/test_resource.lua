-- tests/test_resource.lua
-- Resource System 单元测试

local Resource = require("lib.resource")

local tests = {}
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

local function assertApprox(expected, actual, tolerance, msg)
    tolerance = tolerance or 0.001
    if math.abs(expected - actual) > tolerance then
        error(string.format("%s: expected ~%s, got %s", msg or "Assertion failed", tostring(expected), tostring(actual)))
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

--------------------------------------------------------------------------------
-- Basic Resource Tests
--------------------------------------------------------------------------------

test("Resource.new creates resource with defaults", function()
    local res = Resource.new({id = "test"})
    assertEquals("test", res.id)
    assertEquals(0, res.value)
    assertEquals(0, res.min)
    assertEquals(100, res.max)
end)

test("Resource.new respects config values", function()
    local res = Resource.new({
        id = "hp",
        value = 50,
        min = 10,
        max = 200,
        regen = 5,
        decay = 2,
    })
    assertEquals("hp", res.id)
    assertEquals(50, res.value)
    assertEquals(10, res.min)
    assertEquals(200, res.max)
    assertEquals(5, res.baseRegen)
    assertEquals(2, res.baseDecay)
end)

test("Resource:get returns current value", function()
    local res = Resource.new({value = 75})
    assertEquals(75, res:get())
end)

test("Resource:getPercent returns correct percentage", function()
    local res = Resource.new({value = 50, min = 0, max = 100})
    assertApprox(0.5, res:getPercent())
    
    res:set(25)
    assertApprox(0.25, res:getPercent())
    
    res:set(100)
    assertApprox(1.0, res:getPercent())
end)

test("Resource:set clamps value to min/max", function()
    local res = Resource.new({value = 50, min = 0, max = 100})
    
    res:set(150)
    assertEquals(100, res:get())
    
    res:set(-50)
    assertEquals(0, res:get())
end)

test("Resource:add increases value", function()
    local res = Resource.new({value = 50})
    res:add(20)
    assertEquals(70, res:get())
end)

test("Resource:subtract decreases value", function()
    local res = Resource.new({value = 50})
    res:subtract(20)
    assertEquals(30, res:get())
end)

test("Resource:setMax updates max and clamps value", function()
    local res = Resource.new({value = 80, max = 100})
    res:setMax(50)
    assertEquals(50, res.max)
    assertEquals(50, res:get())
end)

test("Resource:setMin updates min and clamps value", function()
    local res = Resource.new({value = 20, min = 0})
    res:setMin(30)
    assertEquals(30, res.min)
    assertEquals(30, res:get())
end)

--------------------------------------------------------------------------------
-- Modifier Tests
--------------------------------------------------------------------------------

test("Resource:addModifier adds modifier", function()
    local res = Resource.new({value = 50})
    res:addModifier({id = "buff", type = "regen", value = 10})
    assertTrue(res:hasModifier("buff"))
end)

test("Resource:removeModifier removes modifier", function()
    local res = Resource.new({value = 50})
    res:addModifier({id = "buff", type = "regen", value = 10})
    res:removeModifier("buff")
    assertFalse(res:hasModifier("buff"))
end)

test("Resource:getEffectiveRegen includes modifiers", function()
    local res = Resource.new({value = 50, regen = 5})
    res:addModifier({id = "buff1", type = "regen", value = 10})
    res:addModifier({id = "buff2", type = "regen", value = 3})
    assertEquals(18, res:getEffectiveRegen())
end)

test("Resource:getEffectiveDecay includes modifiers", function()
    local res = Resource.new({value = 50, decay = 2})
    res:addModifier({id = "poison", type = "decay", value = 5})
    assertEquals(7, res:getEffectiveDecay())
end)

test("Resource:update applies regen/decay", function()
    local res = Resource.new({value = 50, regen = 10, decay = 0})
    res:update(1.0)  -- 1 second
    assertEquals(60, res:get())
    
    res = Resource.new({value = 50, regen = 0, decay = 10})
    res:update(1.0)
    assertEquals(40, res:get())
end)

test("Resource:update removes expired modifiers", function()
    local res = Resource.new({value = 50})
    res:addModifier({id = "temp", type = "regen", value = 10, duration = 1.0})
    assertTrue(res:hasModifier("temp"))
    
    res:update(0.5)
    assertTrue(res:hasModifier("temp"))
    
    res:update(0.6)
    assertFalse(res:hasModifier("temp"))
end)

--------------------------------------------------------------------------------
-- Threshold Tests
--------------------------------------------------------------------------------

test("Resource:onThreshold triggers on 'below'", function()
    local res = Resource.new({value = 50})
    local triggered = false
    res:onThreshold(30, "below", function() triggered = true end)
    
    res:set(40)
    assertFalse(triggered)
    
    res:set(25)
    assertTrue(triggered)
end)

test("Resource:onThreshold triggers on 'above'", function()
    local res = Resource.new({value = 50})
    local triggered = false
    res:onThreshold(70, "above", function() triggered = true end)
    
    res:set(60)
    assertFalse(triggered)
    
    res:set(75)
    assertTrue(triggered)
end)

test("Resource:onThreshold triggers on 'equal'", function()
    local res = Resource.new({value = 50})
    local triggered = false
    res:onThreshold(0, "equal", function() triggered = true end)
    
    res:set(10)
    assertFalse(triggered)
    
    res:set(0)
    assertTrue(triggered)
end)

test("Resource:onThreshold triggers on 'cross'", function()
    local res = Resource.new({value = 50})
    local triggerCount = 0
    res:onThreshold(30, "cross", function() triggerCount = triggerCount + 1 end)
    
    res:set(25)  -- cross below
    assertEquals(1, triggerCount)
    
    res:set(35)  -- cross above
    assertEquals(2, triggerCount)
end)

--------------------------------------------------------------------------------
-- Listener Tests
--------------------------------------------------------------------------------

test("Resource:onChange fires on value change", function()
    local res = Resource.new({value = 50})
    local changes = {}
    res:onChange(function(old, new)
        table.insert(changes, {old = old, new = new})
    end)
    
    res:set(60)
    res:set(40)
    
    assertEquals(2, #changes)
    assertEquals(50, changes[1].old)
    assertEquals(60, changes[1].new)
    assertEquals(60, changes[2].old)
    assertEquals(40, changes[2].new)
end)

test("Resource:onMin fires when reaching minimum", function()
    local res = Resource.new({value = 50, min = 0})
    local triggered = false
    res:onMin(function() triggered = true end)
    
    res:set(10)
    assertFalse(triggered)
    
    res:set(0)
    assertTrue(triggered)
end)

test("Resource:onMax fires when reaching maximum", function()
    local res = Resource.new({value = 50, max = 100})
    local triggered = false
    res:onMax(function() triggered = true end)
    
    res:set(90)
    assertFalse(triggered)
    
    res:set(100)
    assertTrue(triggered)
end)

--------------------------------------------------------------------------------
-- Serialization Tests
--------------------------------------------------------------------------------

test("Resource:serialize returns correct data", function()
    local res = Resource.new({
        id = "hp",
        value = 75,
        min = 0,
        max = 100,
        regen = 5,
        decay = 2,
    })
    res:addModifier({id = "buff", type = "regen", value = 10})
    
    local data = res:serialize()
    assertEquals("hp", data.id)
    assertEquals(75, data.value)
    assertEquals(0, data.min)
    assertEquals(100, data.max)
    assertEquals(5, data.baseRegen)
    assertEquals(2, data.baseDecay)
    assertTrue(data.modifiers.buff ~= nil)
end)

test("Resource.deserialize restores resource", function()
    local data = {
        id = "hp",
        value = 75,
        min = 0,
        max = 100,
        baseRegen = 5,
        baseDecay = 2,
        modifiers = {},
    }
    
    local res = Resource.deserialize(data)
    assertEquals("hp", res.id)
    assertEquals(75, res:get())
    assertEquals(0, res.min)
    assertEquals(100, res.max)
end)

--------------------------------------------------------------------------------
-- DerivedResource Tests
--------------------------------------------------------------------------------

test("DerivedResource computes value from dependencies", function()
    local volume = Resource.new({id = "volume", value = 500, max = 1000})
    local capacity = Resource.new({id = "capacity", value = 1000, max = 2000})
    
    local tension = Resource.newDerived({
        id = "tension",
        dependencies = {volume = volume, capacity = capacity},
        formula = function(deps)
            return (deps.volume / deps.capacity) * 100
        end,
        min = 0,
        max = 100,
    })
    
    assertApprox(50, tension:get())
    
    volume:set(750)
    assertApprox(75, tension:get())
end)

test("DerivedResource:getPercent works correctly", function()
    local a = Resource.new({id = "a", value = 50, max = 100})
    
    local derived = Resource.newDerived({
        id = "derived",
        dependencies = {a = a},
        formula = function(deps) return deps.a * 2 end,
        min = 0,
        max = 200,
    })
    
    assertApprox(0.5, derived:getPercent())
end)

test("DerivedResource:onChange fires on computed value change", function()
    local a = Resource.new({id = "a", value = 50, max = 100})
    local changes = {}
    
    local derived = Resource.newDerived({
        id = "derived",
        dependencies = {a = a},
        formula = function(deps) return deps.a end,
    })
    
    derived:onChange(function(old, new)
        table.insert(changes, {old = old, new = new})
    end)
    
    derived:get()  -- initial: cachedValue goes from 0 to 50
    a:set(60)
    derived:get()  -- should trigger change: 50 to 60
    
    -- First change: 0 -> 50 (initial), Second change: 50 -> 60
    assertEquals(2, #changes)
    assertEquals(0, changes[1].old)
    assertEquals(50, changes[1].new)
    assertEquals(50, changes[2].old)
    assertEquals(60, changes[2].new)
end)

--------------------------------------------------------------------------------
-- ResourceManager Tests
--------------------------------------------------------------------------------

test("ResourceManager:register and get work", function()
    local manager = Resource.newManager()
    local hp = Resource.new({id = "hp", value = 100})
    local mp = Resource.new({id = "mp", value = 50})
    
    manager:register(hp):register(mp)
    
    assertEquals(hp, manager:get("hp"))
    assertEquals(mp, manager:get("mp"))
    assertEquals(nil, manager:get("nonexistent"))
end)

test("ResourceManager:update updates all resources", function()
    local manager = Resource.newManager()
    local hp = Resource.new({id = "hp", value = 50, regen = 10})
    local mp = Resource.new({id = "mp", value = 50, decay = 5})
    
    manager:register(hp):register(mp)
    manager:update(1.0)
    
    assertEquals(60, hp:get())
    assertEquals(45, mp:get())
end)

test("ResourceManager serialization round-trip", function()
    local manager = Resource.newManager()
    local hp = Resource.new({id = "hp", value = 75, max = 100})
    manager:register(hp)
    
    local data = manager:serialize()
    
    -- Create new manager and restore
    local manager2 = Resource.newManager()
    local hp2 = Resource.new({id = "hp", value = 0, max = 100})
    manager2:register(hp2)
    manager2:deserialize(data)
    
    assertEquals(75, manager2:get("hp"):get())
end)

--------------------------------------------------------------------------------
-- Reset Test
--------------------------------------------------------------------------------

test("Resource:reset clears modifiers and resets value", function()
    local res = Resource.new({id = "hp", value = 50, max = 100})
    res:addModifier({id = "buff", type = "regen", value = 10})
    res:set(30)
    
    res:reset()
    
    assertEquals(100, res:get())
    assertFalse(res:hasModifier("buff"))
    
    res:reset(50)
    assertEquals(50, res:get())
end)

--------------------------------------------------------------------------------
-- Run all tests
--------------------------------------------------------------------------------

print("\n========================================")
print("Resource System Tests")
print("========================================\n")

-- Run tests
for _, testFn in pairs(tests) do
    testFn()
end

print("\n========================================")
print(string.format("Results: %d passed, %d failed", passed, failed))
print("========================================\n")

return {
    passed = passed,
    failed = failed,
}
