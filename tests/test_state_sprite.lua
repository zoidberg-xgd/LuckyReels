-- tests/test_state_sprite.lua
-- State-Driven Sprite System 单元测试

local StateSprite = require("lib.state_sprite")

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

local function assertApprox(expected, actual, tolerance, msg)
    tolerance = tolerance or 0.001
    if math.abs(expected - actual) > tolerance then
        error(string.format("%s: expected ~%s, got %s", msg or "Assertion failed", tostring(expected), tostring(actual)))
    end
end

--------------------------------------------------------------------------------
-- Basic StateSprite Tests
--------------------------------------------------------------------------------

print("\n========================================")
print("State-Driven Sprite System Tests")
print("========================================\n")

test("StateSprite.new creates sprite with states", function()
    local sprite = StateSprite.new({
        states = {
            neutral = {sprite = "neutral.png", priority = 0},
            happy = {sprite = "happy.png", priority = 1},
        },
        defaultState = "neutral",
    })
    
    assertEquals("neutral", sprite:getState())
end)

test("StateSprite.new picks first state if no default", function()
    local sprite = StateSprite.new({
        states = {
            idle = {sprite = "idle.png"},
        },
    })
    
    assertEquals("idle", sprite:getState())
end)

test("StateSprite:setState changes state", function()
    local sprite = StateSprite.new({
        states = {
            neutral = {sprite = "neutral.png"},
            happy = {sprite = "happy.png"},
        },
        defaultState = "neutral",
    })
    
    sprite:setState("happy")
    assertEquals("happy", sprite:getState())
end)

test("StateSprite:setState ignores invalid state", function()
    local sprite = StateSprite.new({
        states = {
            neutral = {sprite = "neutral.png"},
        },
        defaultState = "neutral",
    })
    
    sprite:setState("nonexistent")
    assertEquals("neutral", sprite:getState())
end)

test("StateSprite:setState with duration creates temporary state", function()
    local sprite = StateSprite.new({
        states = {
            neutral = {sprite = "neutral.png"},
            surprised = {sprite = "surprised.png"},
        },
        defaultState = "neutral",
    })
    
    sprite:setState("surprised", {duration = 2})
    assertEquals("surprised", sprite:getState())
    
    sprite:update(1.0)
    assertEquals("surprised", sprite:getState())
    
    sprite:update(1.5)
    assertEquals("neutral", sprite:getState())
end)

test("StateSprite:getStateData returns state config", function()
    local sprite = StateSprite.new({
        states = {
            neutral = {sprite = "neutral.png", priority = 5},
        },
        defaultState = "neutral",
    })
    
    local data = sprite:getStateData()
    assertEquals("neutral.png", data.sprite)
    assertEquals(5, data.priority)
end)

--------------------------------------------------------------------------------
-- Condition Tests
--------------------------------------------------------------------------------

test("StateSprite conditions auto-switch state", function()
    local sprite = StateSprite.new({
        states = {
            neutral = {sprite = "neutral.png"},
            happy = {sprite = "happy.png"},
            sad = {sprite = "sad.png"},
        },
        conditions = {
            {state = "happy", when = function(ctx) return ctx.money > 100 end},
            {state = "sad", when = function(ctx) return ctx.money < 10 end},
        },
        defaultState = "neutral",
    })
    
    sprite:updateContext({money = 50})
    assertEquals("neutral", sprite:getState())
    
    sprite:updateContext({money = 150})
    assertEquals("happy", sprite:getState())
    
    sprite:updateContext({money = 5})
    assertEquals("sad", sprite:getState())
end)

test("StateSprite conditions respect priority", function()
    local sprite = StateSprite.new({
        states = {
            neutral = {sprite = "neutral.png"},
            critical = {sprite = "critical.png"},
            happy = {sprite = "happy.png"},
        },
        conditions = {
            {state = "happy", when = function(ctx) return ctx.money > 100 end, priority = 1},
            {state = "critical", when = function(ctx) return ctx.hp < 20 end, priority = 10},
        },
        defaultState = "neutral",
    })
    
    -- Both conditions true, critical has higher priority
    sprite:updateContext({money = 150, hp = 10})
    assertEquals("critical", sprite:getState())
end)

--------------------------------------------------------------------------------
-- Transition Tests
--------------------------------------------------------------------------------

test("StateSprite:isTransitioning returns correct value", function()
    local sprite = StateSprite.new({
        states = {
            a = {sprite = "a.png"},
            b = {sprite = "b.png"},
        },
        transitions = {
            default = {duration = 0.5, easing = "linear"},
        },
        defaultState = "a",
    })
    
    assertFalse(sprite:isTransitioning())
    
    sprite:setState("b")
    assertTrue(sprite:isTransitioning())
    
    sprite:update(0.6)
    assertFalse(sprite:isTransitioning())
end)

test("StateSprite transition progress updates correctly", function()
    local sprite = StateSprite.new({
        states = {
            a = {sprite = "a.png"},
            b = {sprite = "b.png"},
        },
        transitions = {
            default = {duration = 1.0, easing = "linear"},
        },
        defaultState = "a",
    })
    
    sprite:setState("b")
    assertEquals(0, sprite.transitionProgress)
    
    sprite:update(0.5)
    assertApprox(0.5, sprite.transitionProgress, 0.01)
    
    sprite:update(0.5)
    assertApprox(1.0, sprite.transitionProgress, 0.01)
end)

test("StateSprite uses specific transition when defined", function()
    local sprite = StateSprite.new({
        states = {
            neutral = {sprite = "neutral.png"},
            critical = {sprite = "critical.png"},
        },
        transitions = {
            default = {duration = 0.5, easing = "outQuad"},
            ["neutral->critical"] = {duration = 0.1, easing = "linear"},
        },
        defaultState = "neutral",
    })
    
    sprite:setState("critical")
    assertEquals(0.1, sprite.transitionDuration)
end)

--------------------------------------------------------------------------------
-- Listener Tests
--------------------------------------------------------------------------------

test("StateSprite:onStateChange fires on state change", function()
    local sprite = StateSprite.new({
        states = {
            a = {sprite = "a.png"},
            b = {sprite = "b.png"},
        },
        defaultState = "a",
    })
    
    local changes = {}
    sprite:onStateChange(function(old, new)
        table.insert(changes, {old = old, new = new})
    end)
    
    sprite:setState("b")
    
    assertEquals(1, #changes)
    assertEquals("a", changes[1].old)
    assertEquals("b", changes[1].new)
end)

--------------------------------------------------------------------------------
-- Dynamic State/Condition Tests
--------------------------------------------------------------------------------

test("StateSprite:addState adds new state", function()
    local sprite = StateSprite.new({
        states = {
            a = {sprite = "a.png"},
        },
        defaultState = "a",
    })
    
    sprite:addState("b", {sprite = "b.png"})
    sprite:setState("b")
    assertEquals("b", sprite:getState())
end)

test("StateSprite:addCondition adds new condition", function()
    local sprite = StateSprite.new({
        states = {
            neutral = {sprite = "neutral.png"},
            angry = {sprite = "angry.png"},
        },
        defaultState = "neutral",
    })
    
    sprite:addCondition({
        state = "angry",
        when = function(ctx) return ctx.damage > 50 end,
    })
    
    sprite:updateContext({damage = 60})
    assertEquals("angry", sprite:getState())
end)

test("StateSprite:setTransition updates transition config", function()
    local sprite = StateSprite.new({
        states = {
            a = {sprite = "a.png"},
            b = {sprite = "b.png"},
        },
        defaultState = "a",
    })
    
    sprite:setTransition("a->b", {duration = 2.0, easing = "inQuad"})
    sprite:setState("b")
    
    assertEquals(2.0, sprite.transitionDuration)
end)

--------------------------------------------------------------------------------
-- Easing Tests
--------------------------------------------------------------------------------

test("Easing.linear returns t", function()
    assertEquals(0, StateSprite.Easing.linear(0))
    assertEquals(0.5, StateSprite.Easing.linear(0.5))
    assertEquals(1, StateSprite.Easing.linear(1))
end)

test("Easing.outQuad eases correctly", function()
    assertEquals(0, StateSprite.Easing.outQuad(0))
    assertApprox(0.75, StateSprite.Easing.outQuad(0.5), 0.01)
    assertEquals(1, StateSprite.Easing.outQuad(1))
end)

test("Easing.outBounce eases correctly", function()
    assertEquals(0, StateSprite.Easing.outBounce(0))
    assertEquals(1, StateSprite.Easing.outBounce(1))
    -- Should have bounce effect
    assertTrue(StateSprite.Easing.outBounce(0.5) > 0)
end)

--------------------------------------------------------------------------------
-- LayeredStateSprite Tests
--------------------------------------------------------------------------------

test("LayeredStateSprite.new creates layered sprite", function()
    local sprite = StateSprite.newLayered({
        layers = {
            {name = "body", z = 0},
            {name = "face", z = 1},
            {name = "clothes", z = 2},
        },
        layerStates = {
            face = {
                neutral = "face_neutral.png",
                happy = "face_happy.png",
            },
            clothes = {
                normal = "clothes_normal.png",
                torn = "clothes_torn.png",
            },
        },
    })
    
    assertTrue(sprite.layersByName.body ~= nil)
    assertTrue(sprite.layersByName.face ~= nil)
    assertTrue(sprite.layersByName.clothes ~= nil)
end)

test("LayeredStateSprite:setLayerState changes layer state", function()
    local sprite = StateSprite.newLayered({
        layers = {
            {name = "face", z = 0},
        },
        layerStates = {
            face = {
                neutral = "face_neutral.png",
                happy = "face_happy.png",
            },
        },
    })
    
    sprite:setLayerState("face", "happy")
    assertEquals("happy", sprite:getLayerState("face"))
end)

test("LayeredStateSprite:setLayerVisible toggles visibility", function()
    local sprite = StateSprite.newLayered({
        layers = {
            {name = "clothes", z = 0},
        },
        layerStates = {
            clothes = {normal = "clothes.png"},
        },
    })
    
    assertTrue(sprite.layersByName.clothes.visible)
    
    sprite:setLayerVisible("clothes", false)
    assertFalse(sprite.layersByName.clothes.visible)
end)

test("LayeredStateSprite layers are sorted by z", function()
    local sprite = StateSprite.newLayered({
        layers = {
            {name = "top", z = 10},
            {name = "bottom", z = 0},
            {name = "middle", z = 5},
        },
    })
    
    assertEquals("bottom", sprite.layers[1].name)
    assertEquals("middle", sprite.layers[2].name)
    assertEquals("top", sprite.layers[3].name)
end)

test("LayeredStateSprite:updateContext evaluates conditions", function()
    local sprite = StateSprite.newLayered({
        layers = {
            {name = "face", z = 0},
        },
        layerStates = {
            face = {
                neutral = "neutral.png",
                blush = "blush.png",
            },
        },
    })
    
    sprite:addCondition("face", {
        state = "blush",
        when = function(ctx) return ctx.embarrassed end,
    })
    
    sprite:updateContext({embarrassed = true})
    assertEquals("blush", sprite:getLayerState("face"))
end)

--------------------------------------------------------------------------------
-- Results
--------------------------------------------------------------------------------

print("\n========================================")
print(string.format("Results: %d passed, %d failed", passed, failed))
print("========================================\n")

return {
    passed = passed,
    failed = failed,
}
