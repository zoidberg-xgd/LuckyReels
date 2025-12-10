-- tests/test_proc_shape.lua
-- Procedural Shape System 单元测试

local ProcShape = require("lib.proc_shape")

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
-- Mock Resource for testing bindings
--------------------------------------------------------------------------------
local MockResource = {}
MockResource.__index = MockResource

function MockResource.new(value)
    return setmetatable({value = value}, MockResource)
end

function MockResource:get()
    return self.value
end

function MockResource:set(v)
    self.value = v
end

--------------------------------------------------------------------------------
-- ProcShape Tests
--------------------------------------------------------------------------------

print("\n========================================")
print("Procedural Shape System Tests")
print("========================================\n")

test("ProcShape.new creates shape with defaults", function()
    local shape = ProcShape.new({})
    assertEquals("ellipse", shape.type)
    assertEquals(50, shape.baseWidth)
    assertEquals(40, shape.baseHeight)
    assertEquals(1.0, shape.params.scale)
end)

test("ProcShape.new respects config", function()
    local shape = ProcShape.new({
        type = "polygon",
        baseWidth = 100,
        baseHeight = 80,
        params = {
            scale = 2.0,
            stretchX = 1.5,
        },
    })
    assertEquals("polygon", shape.type)
    assertEquals(100, shape.baseWidth)
    assertEquals(80, shape.baseHeight)
    assertEquals(2.0, shape.params.scale)
    assertEquals(1.5, shape.params.stretchX)
end)

test("ProcShape:setParam and getParam work", function()
    local shape = ProcShape.new({})
    shape:setParam("scale", 1.5)
    assertEquals(1.5, shape:getParam("scale"))
    
    shape:setParam("sag", 0.3)
    assertEquals(0.3, shape:getParam("sag"))
end)

test("ProcShape:bindParam binds to resource", function()
    local shape = ProcShape.new({})
    local resource = MockResource.new(500)
    
    shape:bindParam("scale", resource, function(v)
        return 1 + v / 1000
    end)
    
    assertApprox(1.5, shape:getParam("scale"), 0.01)
    
    resource:set(1000)
    assertApprox(2.0, shape:getParam("scale"), 0.01)
end)

test("ProcShape:unbindParam removes binding", function()
    local shape = ProcShape.new({})
    local resource = MockResource.new(500)
    
    shape:bindParam("scale", resource, function(v) return v / 100 end)
    assertEquals(5, shape:getParam("scale"))
    
    shape:unbindParam("scale")
    shape:setParam("scale", 1.0)
    assertEquals(1.0, shape:getParam("scale"))
end)

test("ProcShape:getSize returns correct dimensions", function()
    local shape = ProcShape.new({
        baseWidth = 100,
        baseHeight = 50,
    })
    
    local w, h = shape:getSize()
    assertEquals(100, w)
    assertEquals(50, h)
    
    shape:setParam("scale", 2.0)
    w, h = shape:getSize()
    assertEquals(200, w)
    assertEquals(100, h)
    
    shape:setParam("stretchX", 1.5)
    w, h = shape:getSize()
    assertEquals(300, w)
    assertEquals(100, h)
end)

test("ProcShape:getOutlinePoints returns points for ellipse", function()
    local shape = ProcShape.new({
        type = "ellipse",
        baseWidth = 100,
        baseHeight = 50,
    })
    
    local points = shape:getOutlinePoints(16)
    assertEquals(16, #points)
    
    -- 检查点在椭圆上
    for _, p in ipairs(points) do
        assertTrue(p.x ~= nil)
        assertTrue(p.y ~= nil)
    end
end)

test("ProcShape:getOutlinePoints returns points for polygon", function()
    local shape = ProcShape.new({
        type = "polygon",
        baseWidth = 100,
        baseHeight = 100,
    })
    
    local points = shape:getOutlinePoints(6)
    assertEquals(6, #points)
end)

test("ProcShape:contains detects point inside ellipse", function()
    local shape = ProcShape.new({
        type = "ellipse",
        baseWidth = 100,
        baseHeight = 100,
    })
    
    -- 中心点
    assertTrue(shape:contains(100, 100, 100, 100))
    
    -- 边缘内
    assertTrue(shape:contains(120, 100, 100, 100))
    
    -- 外部
    assertFalse(shape:contains(200, 200, 100, 100))
end)

test("ProcShape physics initializes correctly", function()
    local shape = ProcShape.new({
        physics = {
            jiggle = true,
            stiffness = 200,
            damping = 20,
        },
    })
    
    assertTrue(shape.physics.jiggle)
    assertEquals(200, shape.physics.stiffness)
    assertEquals(20, shape.physics.damping)
    assertEquals(0, shape.physics.velocity.x)
    assertEquals(0, shape.physics.displacement.x)
end)

test("ProcShape:poke affects velocity when jiggle enabled", function()
    local shape = ProcShape.new({
        physics = {
            jiggle = true,
            stiffness = 100,
            damping = 10,
        },
    })
    
    shape:poke(10, 0, 1)
    assertTrue(shape.physics.velocity.x ~= 0 or shape.physics.velocity.y ~= 0)
end)

test("ProcShape:poke does nothing when jiggle disabled", function()
    local shape = ProcShape.new({
        physics = {
            jiggle = false,
        },
    })
    
    shape:poke(10, 0, 1)
    assertEquals(0, shape.physics.velocity.x)
    assertEquals(0, shape.physics.velocity.y)
end)

test("ProcShape:update applies physics", function()
    local shape = ProcShape.new({
        physics = {
            jiggle = true,
            stiffness = 100,
            damping = 5,
        },
    })
    
    shape:poke(0, 10, 2)
    local initialVelY = shape.physics.velocity.y
    
    shape:update(0.1)
    
    -- 位移应该改变
    assertTrue(shape.physics.displacement.x ~= 0 or shape.physics.displacement.y ~= 0)
end)

test("ProcShape:update updates bound parameters", function()
    local shape = ProcShape.new({})
    local resource = MockResource.new(100)
    
    shape:bindParam("scale", resource, function(v) return v / 100 end)
    
    resource:set(200)
    shape:update(0.1)
    
    assertEquals(2.0, shape.params.scale)
end)

test("ProcShape:setColor and setFillColor work", function()
    local shape = ProcShape.new({})
    
    shape:setColor(1, 0, 0, 1)
    assertEquals(1, shape.color[1])
    assertEquals(0, shape.color[2])
    assertEquals(0, shape.color[3])
    
    shape:setFillColor(0, 1, 0, 0.5)
    assertEquals(0, shape.fillColor[1])
    assertEquals(1, shape.fillColor[2])
    assertEquals(0.5, shape.fillColor[4])
end)

--------------------------------------------------------------------------------
-- BezierShape Tests
--------------------------------------------------------------------------------

test("BezierShape.new creates shape with control points", function()
    local shape = ProcShape.newBezier({
        controlPoints = {
            {x = 0, y = -50, fixed = true},
            {x = 50, y = 0, fixed = false},
            {x = 0, y = 50, fixed = false},
            {x = -50, y = 0, fixed = false},
        },
    })
    
    assertEquals(4, #shape.controlPoints)
    assertTrue(shape.controlPoints[1].fixed)
    assertFalse(shape.controlPoints[2].fixed)
end)

test("BezierShape:setParam and getParam work", function()
    local shape = ProcShape.newBezier({
        controlPoints = {{x = 0, y = 0}},
    })
    
    shape:setParam("scale", 2.0)
    assertEquals(2.0, shape:getParam("scale"))
end)

test("BezierShape:bindParam binds to resource", function()
    local shape = ProcShape.newBezier({
        controlPoints = {{x = 0, y = 0}},
    })
    local resource = MockResource.new(100)
    
    shape:bindParam("volume", resource, function(v) return v * 2 end)
    assertEquals(200, shape:getParam("volume"))
end)

test("BezierShape:getControlPoints returns points with displacement", function()
    local shape = ProcShape.newBezier({
        controlPoints = {
            {x = 0, y = 0},
            {x = 10, y = 10},
        },
        physics = {jiggle = true},
    })
    
    local cps = shape:getControlPoints()
    assertEquals(2, #cps)
    assertEquals(0, cps[1].x)
    assertEquals(10, cps[2].x)
end)

test("BezierShape deform rules modify control points", function()
    local shape = ProcShape.newBezier({
        controlPoints = {
            {x = 0, y = -50, fixed = true},
            {x = 50, y = 0, fixed = false},
            {x = 0, y = 50, fixed = false},
            {x = -50, y = 0, fixed = false},
        },
        deformRules = {
            {point = 2, axis = "x", param = "scale", formula = function(s) return 50 * s end},
        },
    })
    
    shape:setParam("scale", 2.0)
    shape:update(0.1)
    
    assertEquals(100, shape.controlPoints[2].x)
end)

test("BezierShape:poke affects non-fixed points", function()
    local shape = ProcShape.newBezier({
        controlPoints = {
            {x = 0, y = 0, fixed = true},
            {x = 50, y = 0, fixed = false},
        },
        physics = {jiggle = true, stiffness = 100, damping = 10},
    })
    
    shape:poke(50, 0, 1)
    
    -- 固定点不受影响
    assertEquals(0, shape.physics.velocities[1].x)
    assertEquals(0, shape.physics.velocities[1].y)
    
    -- 非固定点受影响
    assertTrue(shape.physics.velocities[2].x ~= 0 or shape.physics.velocities[2].y ~= 0)
end)

test("BezierShape:getOutlinePoints returns curve points", function()
    local shape = ProcShape.newBezier({
        controlPoints = {
            {x = 0, y = -50},
            {x = 50, y = -50},
            {x = 50, y = 50},
            {x = 0, y = 50},
        },
        segments = 16,
    })
    
    local points = shape:getOutlinePoints()
    assertTrue(#points > 0)
end)

test("BezierShape:setColor works", function()
    local shape = ProcShape.newBezier({
        controlPoints = {{x = 0, y = 0}},
    })
    
    shape:setColor(1, 0.5, 0, 1)
    assertEquals(1, shape.color[1])
    assertEquals(0.5, shape.color[2])
    assertEquals(0, shape.color[3])
end)

test("BezierShape physics updates correctly", function()
    local shape = ProcShape.newBezier({
        controlPoints = {
            {x = 0, y = 0, fixed = false},
            {x = 10, y = 0, fixed = false},
        },
        physics = {jiggle = true, stiffness = 100, damping = 5},
    })
    
    -- 给一个初始速度
    shape.physics.velocities[1].x = 10
    
    shape:update(0.1)
    
    -- 位移应该改变
    assertTrue(shape.physics.displacements[1].x ~= 0)
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
