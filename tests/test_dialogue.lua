-- tests/test_dialogue.lua
-- Conditional Dialogue System 单元测试

local Dialogue = require("lib.dialogue")

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

local function assertNil(value, msg)
    if value ~= nil then
        error(msg or "Expected nil, got " .. tostring(value))
    end
end

local function assertNotNil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil value")
    end
end

print("\n========================================")
print("Conditional Dialogue System Tests")
print("========================================\n")

test("DialogueLibrary.new creates library", function()
    local lib = Dialogue.newLibrary({
        entries = {{id = "greeting", text = "Hello!"}},
    })
    assertEquals(1, #lib.entries)
end)

test("DialogueLibrary:addEntry adds entry", function()
    local lib = Dialogue.newLibrary({})
    lib:addEntry({id = "test", text = "Test"})
    assertEquals(1, #lib.entries)
end)

test("DialogueLibrary entries sorted by priority", function()
    local lib = Dialogue.newLibrary({
        entries = {
            {id = "low", text = "Low", priority = 1},
            {id = "high", text = "High", priority = 10},
        },
    })
    assertEquals("high", lib.entries[1].id)
end)

test("Simple equality condition", function()
    local lib = Dialogue.newLibrary({
        entries = {
            {id = "happy", text = "Happy!", conditions = {mood = "happy"}},
        },
    })
    assertNotNil(lib:query({mood = "happy"}))
    assertNil(lib:query({mood = "sad"}))
end)

test("Greater than condition", function()
    local lib = Dialogue.newLibrary({
        entries = {{id = "rich", text = "Rich!", conditions = {money = {">", 100}}}},
    })
    assertNil(lib:query({money = 50}))
    assertNotNil(lib:query({money = 150}))
end)

test("Less than condition", function()
    local lib = Dialogue.newLibrary({
        entries = {{id = "poor", text = "Poor!", conditions = {money = {"<", 20}}}},
    })
    assertNotNil(lib:query({money = 10}))
    assertNil(lib:query({money = 50}))
end)

test("Between condition", function()
    local lib = Dialogue.newLibrary({
        entries = {{id = "normal", text = "Normal", conditions = {hp = {"between", {30, 70}}}}},
    })
    assertNotNil(lib:query({hp = 50}))
    assertNil(lib:query({hp = 10}))
end)

test("In list condition", function()
    local lib = Dialogue.newLibrary({
        entries = {{id = "weekend", text = "Weekend!", conditions = {day = {"in", {"sat", "sun"}}}}},
    })
    assertNotNil(lib:query({day = "sat"}))
    assertNil(lib:query({day = "mon"}))
end)

test("Multiple conditions (AND)", function()
    local lib = Dialogue.newLibrary({
        entries = {{id = "both", text = "Both!", conditions = {hp = {">", 50}, money = {">", 100}}}},
    })
    assertNotNil(lib:query({hp = 80, money = 150}))
    assertNil(lib:query({hp = 80, money = 50}))
end)

test("Higher priority matched first", function()
    local lib = Dialogue.newLibrary({
        entries = {
            {id = "normal", text = "Normal", priority = 0, conditions = {hp = {">", 0}}},
            {id = "critical", text = "Critical!", priority = 10, conditions = {hp = {"<", 20}}},
        },
    })
    assertEquals("critical", lib:query({hp = 10}).id)
    assertEquals("normal", lib:query({hp = 50}).id)
end)

test("format replaces variables", function()
    local lib = Dialogue.newLibrary({
        entries = {{id = "greeting", text = "Hello, {name}!"}},
    })
    local text = lib:format(lib.entries[1], {name = "Player"})
    assertEquals("Hello, Player!", text)
end)

test("format uses variable functions", function()
    local lib = Dialogue.newLibrary({
        entries = {{id = "status", text = "HP: {hp_pct}"}},
        variables = {hp_pct = function(ctx) return math.floor(ctx.hp / ctx.maxHp * 100) .. "%" end},
    })
    local text = lib:format(lib.entries[1], {hp = 75, maxHp = 100})
    assertEquals("HP: 75%", text)
end)

test("Cooldown prevents reuse", function()
    local lib = Dialogue.newLibrary({
        entries = {
            {id = "once", text = "Once!", cooldown = 60},
            {id = "always", text = "Always"},
        },
    })
    assertEquals("once", lib:query({}).id)
    lib:_setCooldown("once", 60)
    assertEquals("always", lib:query({}).id)
end)

test("clearCooldown works", function()
    local lib = Dialogue.newLibrary({entries = {{id = "test", text = "Test"}}})
    lib:_setCooldown("test", 60)
    assertFalse(lib:_checkCooldown("test"))
    lib:clearCooldown("test")
    assertTrue(lib:_checkCooldown("test"))
end)

test("queryAll returns all matches", function()
    local lib = Dialogue.newLibrary({
        entries = {
            {id = "a", text = "A", conditions = {x = true}},
            {id = "b", text = "B", conditions = {x = true}},
            {id = "c", text = "C", conditions = {x = false}},
        },
    })
    assertEquals(2, #lib:queryAll({x = true}))
end)

test("query filters by tags", function()
    local lib = Dialogue.newLibrary({
        entries = {
            {id = "a", text = "A", tags = {"greeting"}},
            {id = "b", text = "B", tags = {"farewell"}},
        },
    })
    assertEquals("a", lib:query({}, {tags = {"greeting"}}).id)
end)

test("get returns entry and text", function()
    local lib = Dialogue.newLibrary({entries = {{id = "hi", text = "Hello, {name}!"}}})
    local entry, text = lib:get({name = "World"})
    assertEquals("hi", entry.id)
    assertEquals("Hello, World!", text)
end)

test("get records history", function()
    local lib = Dialogue.newLibrary({entries = {{id = "test", text = "Test"}}})
    lib:get({})
    lib:get({})
    assertEquals(2, #lib:getHistory())
end)

-- DialogueTree Tests
test("DialogueTree:start sets current node", function()
    local tree = Dialogue.newTree({nodes = {start = {text = "Hello!"}}})
    tree:start()
    assertEquals("start", tree.currentNode)
end)

test("DialogueTree:getText returns text", function()
    local tree = Dialogue.newTree({nodes = {start = {text = "Hello!"}}})
    tree:start()
    assertEquals("Hello!", tree:getText())
end)

test("DialogueTree:getChoices returns choices", function()
    local tree = Dialogue.newTree({
        nodes = {start = {text = "Choose:", choices = {{text = "A", next = "a"}, {text = "B", next = "b"}}}},
    })
    tree:start()
    assertEquals(2, #tree:getChoices())
end)

test("DialogueTree:choose advances node", function()
    local tree = Dialogue.newTree({
        nodes = {
            start = {text = "Choose:", choices = {{text = "Go A", next = "a"}}},
            a = {text = "At A!"},
        },
    })
    tree:start()
    tree:choose(1)
    assertEquals("a", tree.currentNode)
end)

test("DialogueTree:continue advances without choices", function()
    local tree = Dialogue.newTree({
        nodes = {start = {text = "First", next = "second"}, second = {text = "Second"}},
    })
    tree:start()
    tree:continue()
    assertEquals("second", tree.currentNode)
end)

test("DialogueTree:isEnded works", function()
    local tree = Dialogue.newTree({nodes = {start = {text = "End"}}})
    tree:start()
    assertFalse(tree:isEnded())
    tree:continue()
    assertTrue(tree:isEnded())
end)

test("DialogueTree choice conditions filter", function()
    local tree = Dialogue.newTree({
        nodes = {start = {text = "Choose:", choices = {
            {text = "Free", next = "a"},
            {text = "Paid", next = "b", conditions = {money = {">=", 100}}},
        }}},
    })
    tree:start("start", {money = 50})
    assertEquals(1, #tree:getChoices())
    tree:start("start", {money = 150})
    assertEquals(2, #tree:getChoices())
end)

test("DialogueTree:goTo jumps to node", function()
    local tree = Dialogue.newTree({nodes = {start = {text = "Start"}, other = {text = "Other"}}})
    tree:start()
    tree:goTo("other")
    assertEquals("other", tree.currentNode)
end)

test("DialogueTree:addNode adds node", function()
    local tree = Dialogue.newTree({nodes = {}})
    tree:addNode("new", {text = "New node"})
    assertNotNil(tree.nodes.new)
end)

print("\n========================================")
print(string.format("Results: %d passed, %d failed", passed, failed))
print("========================================\n")

return {passed = passed, failed = failed}
