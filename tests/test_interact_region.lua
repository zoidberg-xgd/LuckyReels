-- tests/test_interact_region.lua
-- Interactive Region System 单元测试

local InteractRegion = require("lib.interact_region")

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

--------------------------------------------------------------------------------
-- Basic Region Tests
--------------------------------------------------------------------------------

print("\n========================================")
print("Interactive Region System Tests")
print("========================================\n")

test("InteractRegion.new creates rect region", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    assertEquals("rect", region.shape)
end)

test("InteractRegion.new creates circle region", function()
    local region = InteractRegion.new({
        shape = "circle",
        bounds = {50, 50, 30},  -- cx, cy, radius
    })
    assertEquals("circle", region.shape)
end)

test("InteractRegion.new creates ellipse region", function()
    local region = InteractRegion.new({
        shape = "ellipse",
        bounds = {50, 50, 40, 30},  -- cx, cy, rx, ry
    })
    assertEquals("ellipse", region.shape)
end)

test("InteractRegion.new creates polygon region", function()
    local region = InteractRegion.new({
        shape = "polygon",
        points = {{0, 0}, {100, 0}, {100, 100}, {0, 100}},
    })
    assertEquals("polygon", region.shape)
end)

--------------------------------------------------------------------------------
-- Contains Tests
--------------------------------------------------------------------------------

test("Rect region contains point inside", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    assertTrue(region:contains(50, 50))
    assertTrue(region:contains(0, 0))
    assertTrue(region:contains(100, 100))
end)

test("Rect region does not contain point outside", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    assertFalse(region:contains(-1, 50))
    assertFalse(region:contains(101, 50))
    assertFalse(region:contains(50, -1))
    assertFalse(region:contains(50, 101))
end)

test("Circle region contains point inside", function()
    local region = InteractRegion.new({
        shape = "circle",
        bounds = {50, 50, 30},
    })
    assertTrue(region:contains(50, 50))  -- center
    assertTrue(region:contains(50, 25))  -- edge
    assertTrue(region:contains(70, 50))  -- near edge
end)

test("Circle region does not contain point outside", function()
    local region = InteractRegion.new({
        shape = "circle",
        bounds = {50, 50, 30},
    })
    assertFalse(region:contains(0, 0))
    assertFalse(region:contains(100, 100))
end)

test("Ellipse region contains point inside", function()
    local region = InteractRegion.new({
        shape = "ellipse",
        bounds = {50, 50, 40, 20},  -- wider than tall
    })
    assertTrue(region:contains(50, 50))  -- center
    assertTrue(region:contains(80, 50))  -- right edge
end)

test("Polygon region contains point inside", function()
    local region = InteractRegion.new({
        shape = "polygon",
        points = {{0, 0}, {100, 0}, {100, 100}, {0, 100}},
    })
    assertTrue(region:contains(50, 50))
end)

test("Polygon region does not contain point outside", function()
    local region = InteractRegion.new({
        shape = "polygon",
        points = {{0, 0}, {100, 0}, {100, 100}, {0, 100}},
    })
    assertFalse(region:contains(150, 50))
end)

--------------------------------------------------------------------------------
-- Offset Tests
--------------------------------------------------------------------------------

test("setOffset moves region", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    
    assertTrue(region:contains(50, 50))
    assertFalse(region:contains(150, 150))
    
    region:setOffset(100, 100)
    
    assertFalse(region:contains(50, 50))
    assertTrue(region:contains(150, 150))
end)

--------------------------------------------------------------------------------
-- SubRegion Tests
--------------------------------------------------------------------------------

test("getSubRegion returns correct sub region", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
        subRegions = {
            {id = "top", shape = "rect", bounds = {0, 0, 100, 33}},
            {id = "middle", shape = "rect", bounds = {0, 33, 100, 34}},
            {id = "bottom", shape = "rect", bounds = {0, 67, 100, 33}},
        },
    })
    
    assertEquals("top", region:getSubRegion(50, 10))
    assertEquals("middle", region:getSubRegion(50, 50))
    assertEquals("bottom", region:getSubRegion(50, 80))
end)

test("getSubRegion returns nil for point outside", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
        subRegions = {
            {id = "inner", shape = "rect", bounds = {25, 25, 50, 50}},
        },
    })
    
    assertEquals("inner", region:getSubRegion(50, 50))
    assertEquals(nil, region:getSubRegion(10, 10))  -- in main but not in sub
end)

--------------------------------------------------------------------------------
-- Event Listener Tests
--------------------------------------------------------------------------------

test("on registers listener", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
        interactions = {"click"},
    })
    
    local clicked = false
    region:on("click", function()
        clicked = true
    end)
    
    assertEquals(1, #region.listeners.click)
end)

test("off removes listener", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    
    local callback = function() end
    region:on("click", callback)
    assertEquals(1, #region.listeners.click)
    
    region:off("click", callback)
    assertEquals(0, #region.listeners.click)
end)

test("off without callback removes all listeners", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    
    region:on("click", function() end)
    region:on("click", function() end)
    assertEquals(2, #region.listeners.click)
    
    region:off("click")
    assertEquals(0, #region.listeners.click)
end)

--------------------------------------------------------------------------------
-- Mouse Event Tests
--------------------------------------------------------------------------------

test("mousepressed returns true when inside", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    
    assertTrue(region:mousepressed(50, 50, 1))
    assertTrue(region.state.isPressed)
end)

test("mousepressed returns false when outside", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    
    assertFalse(region:mousepressed(150, 150, 1))
    assertFalse(region.state.isPressed)
end)

test("mousereleased triggers click event", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
        interactions = {"click"},
    })
    
    local clickX, clickY = nil, nil
    region:on("click", function(x, y)
        clickX, clickY = x, y
    end)
    
    region:mousepressed(50, 50, 1)
    region:mousereleased(50, 50, 1)
    
    assertEquals(50, clickX)
    assertEquals(50, clickY)
end)

test("mousemoved triggers hover events", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
        interactions = {"hover"},
    })
    
    local hoverState = nil
    region:on("hover", function(x, y, entering)
        hoverState = entering
    end)
    
    region:mousemoved(50, 50)
    assertTrue(hoverState)
    
    region:mousemoved(150, 150)
    assertFalse(hoverState)
end)

test("mousemoved triggers enter/leave events", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    
    local entered = false
    local left = false
    
    region:on("enter", function() entered = true end)
    region:on("leave", function() left = true end)
    
    region:mousemoved(50, 50)
    assertTrue(entered)
    assertFalse(left)
    
    region:mousemoved(150, 150)
    assertTrue(left)
end)

--------------------------------------------------------------------------------
-- Hold Test
--------------------------------------------------------------------------------

test("update tracks hold time", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
        interactions = {"hold"},
    })
    
    local holdDuration = 0
    region:on("hold", function(x, y, duration)
        holdDuration = duration
    end)
    
    region:mousepressed(50, 50, 1)
    region.state.lastPosition = {x = 50, y = 50}
    
    region:update(0.5)
    assertTrue(holdDuration > 0)
    
    region:update(0.5)
    assertTrue(holdDuration >= 1.0)
end)

--------------------------------------------------------------------------------
-- Enabled/Disabled Tests
--------------------------------------------------------------------------------

test("setEnabled disables region", function()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    
    assertTrue(region:contains(50, 50))
    
    region:setEnabled(false)
    assertFalse(region:contains(50, 50))
    assertFalse(region:mousepressed(50, 50, 1))
end)

--------------------------------------------------------------------------------
-- Manager Tests
--------------------------------------------------------------------------------

test("InteractRegionManager registers and gets regions", function()
    local manager = InteractRegion.newManager()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    
    manager:register("test", region)
    assertEquals(region, manager:get("test"))
end)

test("InteractRegionManager removes regions", function()
    local manager = InteractRegion.newManager()
    local region = InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 100, 100},
    })
    
    manager:register("test", region)
    manager:remove("test")
    assertEquals(nil, manager:get("test"))
end)

test("InteractRegionManager mousepressed returns region id", function()
    local manager = InteractRegion.newManager()
    
    manager:register("region1", InteractRegion.new({
        shape = "rect",
        bounds = {0, 0, 50, 50},
    }))
    
    manager:register("region2", InteractRegion.new({
        shape = "rect",
        bounds = {50, 50, 50, 50},
    }))
    
    assertEquals("region1", manager:mousepressed(25, 25, 1))
    assertEquals("region2", manager:mousepressed(75, 75, 1))
    assertEquals(nil, manager:mousepressed(200, 200, 1))
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
