-- tests/test_ecs.lua
-- Entity-Component System 单元测试

local ECS = require("lib.ecs")

local passed = 0
local failed = 0

local function test(name, fn)
    -- 每个测试前重置 ECS
    ECS.reset()
    
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

local function assertNil(value, msg)
    if value ~= nil then
        error(msg or "Expected nil, got " .. tostring(value))
    end
end

print("\n========================================")
print("Entity-Component System Tests")
print("========================================\n")

-- Component Tests
test("defineComponent creates component", function()
    ECS.defineComponent("Position", {x = 0, y = 0})
    assertTrue(ECS.hasComponent("Position"))
end)

test("getComponent returns component definition", function()
    ECS.defineComponent("Health", {value = 100, max = 100})
    local comp = ECS.getComponent("Health")
    assertNotNil(comp)
    assertEquals(100, comp._defaults.value)
end)

-- Entity Tests
test("createEntity creates entity with id", function()
    local entity = ECS.createEntity()
    assertNotNil(entity)
    assertTrue(entity.id > 0)
end)

test("createEntity increments id", function()
    local e1 = ECS.createEntity()
    local e2 = ECS.createEntity()
    assertEquals(e1.id + 1, e2.id)
end)

test("entity:add adds component", function()
    ECS.defineComponent("Position", {x = 0, y = 0})
    local entity = ECS.createEntity():add("Position", {x = 10, y = 20})
    
    assertTrue(entity:has("Position"))
    assertEquals(10, entity:get("Position").x)
    assertEquals(20, entity:get("Position").y)
end)

test("entity:add uses defaults", function()
    ECS.defineComponent("Health", {value = 100, max = 100})
    local entity = ECS.createEntity():add("Health")
    
    assertEquals(100, entity:get("Health").value)
end)

test("entity:add merges data with defaults", function()
    ECS.defineComponent("Health", {value = 100, max = 100})
    local entity = ECS.createEntity():add("Health", {value = 50})
    
    assertEquals(50, entity:get("Health").value)
    assertEquals(100, entity:get("Health").max)
end)

test("entity:remove removes component", function()
    ECS.defineComponent("Position", {x = 0, y = 0})
    local entity = ECS.createEntity():add("Position")
    
    assertTrue(entity:has("Position"))
    entity:remove("Position")
    assertFalse(entity:has("Position"))
end)

test("entity:tag and hasTag work", function()
    local entity = ECS.createEntity():tag("player")
    
    assertTrue(entity:hasTag("player"))
    assertFalse(entity:hasTag("enemy"))
end)

test("entity:untag removes tag", function()
    local entity = ECS.createEntity():tag("player")
    entity:untag("player")
    
    assertFalse(entity:hasTag("player"))
end)

test("entity:destroy marks entity as dead", function()
    local entity = ECS.createEntity()
    assertTrue(entity:isAlive())
    
    entity:destroy()
    assertFalse(entity:isAlive())
end)

test("getEntity returns entity by id", function()
    local entity = ECS.createEntity()
    local found = ECS.getEntity(entity.id)
    
    assertEquals(entity.id, found.id)
end)

test("destroyEntity removes entity", function()
    local entity = ECS.createEntity()
    local id = entity.id
    
    ECS.destroyEntity(entity)
    assertNil(ECS.getEntity(id))
end)

test("getAllEntities returns all alive entities", function()
    ECS.createEntity()
    ECS.createEntity()
    local e3 = ECS.createEntity()
    e3:destroy()
    
    local all = ECS.getAllEntities()
    assertEquals(2, #all)
end)

test("clearEntities removes all entities", function()
    ECS.createEntity()
    ECS.createEntity()
    
    ECS.clearEntities()
    assertEquals(0, #ECS.getAllEntities())
end)

-- System Tests
test("defineSystem creates system", function()
    ECS.defineComponent("Position", {x = 0, y = 0})
    ECS.defineSystem("Movement", {"Position"}, function(entity, dt) end)
    
    assertNotNil(ECS.getSystem("Movement"))
end)

test("system update is called for matching entities", function()
    ECS.defineComponent("Counter", {value = 0})
    ECS.defineSystem("CounterSystem", {"Counter"}, function(entity, dt)
        entity:get("Counter").value = entity:get("Counter").value + 1
    end)
    
    local entity = ECS.createEntity():add("Counter")
    
    ECS.update(0.1)
    assertEquals(1, entity:get("Counter").value)
    
    ECS.update(0.1)
    assertEquals(2, entity:get("Counter").value)
end)

test("system only updates entities with required components", function()
    ECS.defineComponent("A", {})
    ECS.defineComponent("B", {})
    
    local updated = {}
    ECS.defineSystem("TestSystem", {"A", "B"}, function(entity, dt)
        updated[entity.id] = true
    end)
    
    local e1 = ECS.createEntity():add("A"):add("B")
    local e2 = ECS.createEntity():add("A")  -- missing B
    local e3 = ECS.createEntity():add("B")  -- missing A
    
    ECS.update(0.1)
    
    assertTrue(updated[e1.id])
    assertNil(updated[e2.id])
    assertNil(updated[e3.id])
end)

test("setSystemEnabled disables system", function()
    ECS.defineComponent("Counter", {value = 0})
    ECS.defineSystem("CounterSystem", {"Counter"}, function(entity, dt)
        entity:get("Counter").value = entity:get("Counter").value + 1
    end)
    
    local entity = ECS.createEntity():add("Counter")
    
    ECS.setSystemEnabled("CounterSystem", false)
    ECS.update(0.1)
    
    assertEquals(0, entity:get("Counter").value)
end)

test("system priority affects order", function()
    ECS.defineComponent("Value", {v = 0})
    
    local order = {}
    ECS.defineSystem("First", {"Value"}, function(entity, dt)
        table.insert(order, "first")
    end)
    ECS.defineSystem("Second", {"Value"}, function(entity, dt)
        table.insert(order, "second")
    end)
    
    ECS.setSystemPriority("First", 10)
    ECS.setSystemPriority("Second", 5)
    
    ECS.createEntity():add("Value")
    ECS.update(0.1)
    
    assertEquals("first", order[1])
    assertEquals("second", order[2])
end)

-- Query Tests
test("query returns entities with components", function()
    ECS.defineComponent("A", {})
    ECS.defineComponent("B", {})
    
    ECS.createEntity():add("A"):add("B")
    ECS.createEntity():add("A")
    ECS.createEntity():add("B")
    
    assertEquals(1, #ECS.query({"A", "B"}))
    assertEquals(2, #ECS.query({"A"}))
    assertEquals(2, #ECS.query({"B"}))
end)

test("queryByTag returns entities with tag", function()
    ECS.createEntity():tag("player")
    ECS.createEntity():tag("enemy")
    ECS.createEntity():tag("enemy")
    
    assertEquals(1, #ECS.queryByTag("player"))
    assertEquals(2, #ECS.queryByTag("enemy"))
end)

test("each iterates over matching entities", function()
    ECS.defineComponent("Value", {v = 0})
    
    ECS.createEntity():add("Value", {v = 1})
    ECS.createEntity():add("Value", {v = 2})
    ECS.createEntity():add("Value", {v = 3})
    
    local sum = 0
    ECS.each({"Value"}, function(entity)
        sum = sum + entity:get("Value").v
    end)
    
    assertEquals(6, sum)
end)

test("reduce aggregates values", function()
    ECS.defineComponent("Value", {v = 0})
    
    ECS.createEntity():add("Value", {v = 10})
    ECS.createEntity():add("Value", {v = 20})
    ECS.createEntity():add("Value", {v = 30})
    
    local total = ECS.reduce({"Value"}, function(acc, entity)
        return acc + entity:get("Value").v
    end, 0)
    
    assertEquals(60, total)
end)

test("count returns entity count", function()
    ECS.defineComponent("A", {})
    
    ECS.createEntity():add("A")
    ECS.createEntity():add("A")
    ECS.createEntity()
    
    assertEquals(2, ECS.count({"A"}))
end)

-- Callback Tests
test("onAdd callback is called", function()
    ECS.defineComponent("A", {})
    ECS.defineComponent("B", {})
    
    local addedEntities = {}
    ECS.defineSystem("TestSystem", {"A", "B"}, function() end)
    ECS.setSystemCallback("TestSystem", "onAdd", function(entity)
        addedEntities[entity.id] = true
    end)
    
    local entity = ECS.createEntity():add("A")
    assertNil(addedEntities[entity.id])  -- not yet, missing B
    
    entity:add("B")
    assertTrue(addedEntities[entity.id])  -- now has both
end)

test("onRemove callback is called", function()
    ECS.defineComponent("A", {})
    ECS.defineComponent("B", {})
    
    local removedEntities = {}
    ECS.defineSystem("TestSystem", {"A", "B"}, function() end)
    ECS.setSystemCallback("TestSystem", "onRemove", function(entity)
        removedEntities[entity.id] = true
    end)
    
    local entity = ECS.createEntity():add("A"):add("B")
    assertNil(removedEntities[entity.id])
    
    entity:remove("B")
    assertTrue(removedEntities[entity.id])
end)

-- Serialization Tests
test("serialize and deserialize entities", function()
    ECS.defineComponent("Position", {x = 0, y = 0})
    ECS.defineComponent("Health", {value = 100})
    
    local e1 = ECS.createEntity():add("Position", {x = 10, y = 20}):add("Health", {value = 50})
    local e2 = ECS.createEntity():add("Position", {x = 30, y = 40}):tag("player")
    
    local data = ECS.serialize()
    
    ECS.clearEntities()
    assertEquals(0, #ECS.getAllEntities())
    
    ECS.deserialize(data)
    
    local restored = ECS.getAllEntities()
    assertEquals(2, #restored)
end)

-- Chain API Tests
test("entity methods are chainable", function()
    ECS.defineComponent("A", {})
    ECS.defineComponent("B", {})
    
    local entity = ECS.createEntity()
        :add("A")
        :add("B")
        :tag("test")
    
    assertTrue(entity:has("A"))
    assertTrue(entity:has("B"))
    assertTrue(entity:hasTag("test"))
end)

-- Reset Tests
test("reset clears everything", function()
    ECS.defineComponent("Test", {})
    ECS.defineSystem("TestSystem", {"Test"}, function() end)
    ECS.createEntity():add("Test")
    
    ECS.reset()
    
    assertFalse(ECS.hasComponent("Test"))
    assertNil(ECS.getSystem("TestSystem"))
    assertEquals(0, #ECS.getAllEntities())
end)

test("clearRuntime keeps definitions", function()
    ECS.defineComponent("Test", {})
    ECS.defineSystem("TestSystem", {"Test"}, function() end)
    ECS.createEntity():add("Test")
    
    ECS.clearRuntime()
    
    assertTrue(ECS.hasComponent("Test"))
    assertNotNil(ECS.getSystem("TestSystem"))
    assertEquals(0, #ECS.getAllEntities())
end)

print("\n========================================")
print(string.format("Results: %d passed, %d failed", passed, failed))
print("========================================\n")

return {passed = passed, failed = failed}
