-- tests/test_config.lua
-- Unit tests for Config module

local MiniTest = require("tests.minitest")
local Config = require("src.config")

--------------------------------------------------------------------------------
-- Grid Config Tests
--------------------------------------------------------------------------------

MiniTest.it("grid: has required fields", function()
    MiniTest.assert(Config.grid ~= nil, "grid config should exist")
    MiniTest.assert(Config.grid.rows ~= nil, "rows should exist")
    MiniTest.assert(Config.grid.cols ~= nil, "cols should exist")
    MiniTest.assert(Config.grid.cellSize ~= nil, "cellSize should exist")
    MiniTest.assert(Config.grid.offsetX ~= nil, "offsetX should exist")
    MiniTest.assert(Config.grid.offsetY ~= nil, "offsetY should exist")
end)

MiniTest.it("grid.toScreen: converts coordinates", function()
    local x, y = Config.grid.toScreen(1, 1)
    MiniTest.assert(type(x) == "number", "x should be number")
    MiniTest.assert(type(y) == "number", "y should be number")
    
    -- First cell should be at offset + half cell size
    local expectedX = Config.grid.offsetX + Config.grid.cellSize / 2
    local expectedY = Config.grid.offsetY + Config.grid.cellSize / 2
    MiniTest.assertEqual(x, expectedX)
    MiniTest.assertEqual(y, expectedY)
end)

MiniTest.it("grid.toScreen: second row/col offset", function()
    local x1, y1 = Config.grid.toScreen(1, 1)
    local x2, y2 = Config.grid.toScreen(2, 2)
    
    local cellStep = Config.grid.cellSize + Config.grid.padding
    MiniTest.assertEqual(x2 - x1, cellStep, "Column step should be cellSize + padding")
    MiniTest.assertEqual(y2 - y1, cellStep, "Row step should be cellSize + padding")
end)

--------------------------------------------------------------------------------
-- Balance Config Tests
--------------------------------------------------------------------------------

MiniTest.it("balance: has required fields", function()
    MiniTest.assert(Config.balance ~= nil)
    MiniTest.assert(Config.balance.starting_money ~= nil)
    MiniTest.assert(Config.balance.starting_rent ~= nil)
    MiniTest.assert(Config.balance.spins_per_rent ~= nil)
end)

MiniTest.it("balance: values are reasonable", function()
    MiniTest.assert(Config.balance.starting_money >= 0, "starting_money should be >= 0")
    MiniTest.assert(Config.balance.starting_rent > 0, "starting_rent should be > 0")
    MiniTest.assert(Config.balance.spins_per_rent > 0, "spins_per_rent should be > 0")
end)

--------------------------------------------------------------------------------
-- Animation Config Tests
--------------------------------------------------------------------------------

MiniTest.it("animation: has timing fields", function()
    MiniTest.assert(Config.animation ~= nil)
    MiniTest.assert(Config.animation.spin_duration ~= nil)
    MiniTest.assert(Config.animation.reel_delays ~= nil)
    MiniTest.assert(type(Config.animation.reel_delays) == "table")
end)

MiniTest.it("animation: reel_delays are increasing", function()
    local delays = Config.animation.reel_delays
    for i = 2, #delays do
        MiniTest.assert(delays[i] > delays[i-1], 
            "reel_delays should be increasing")
    end
end)

--------------------------------------------------------------------------------
-- Colors Config Tests
--------------------------------------------------------------------------------

MiniTest.it("colors: has required colors", function()
    MiniTest.assert(Config.colors ~= nil)
    MiniTest.assert(Config.colors.common ~= nil)
    MiniTest.assert(Config.colors.uncommon ~= nil)
    MiniTest.assert(Config.colors.rare ~= nil)
    MiniTest.assert(Config.colors.money ~= nil)
end)

MiniTest.it("colors: are valid RGB", function()
    local function isValidColor(c)
        return type(c) == "table" and #c >= 3 and
               c[1] >= 0 and c[1] <= 1 and
               c[2] >= 0 and c[2] <= 1 and
               c[3] >= 0 and c[3] <= 1
    end
    
    MiniTest.assert(isValidColor(Config.colors.common), "common should be valid color")
    MiniTest.assert(isValidColor(Config.colors.money), "money should be valid color")
end)

--------------------------------------------------------------------------------
-- Rarity Config Tests
--------------------------------------------------------------------------------

MiniTest.it("rarity: has weights", function()
    MiniTest.assert(Config.rarity ~= nil)
    MiniTest.assert(Config.rarity.weights ~= nil)
    MiniTest.assert(Config.rarity.weights[1] ~= nil, "Common weight should exist")
    MiniTest.assert(Config.rarity.weights[2] ~= nil, "Uncommon weight should exist")
    MiniTest.assert(Config.rarity.weights[3] ~= nil, "Rare weight should exist")
end)

MiniTest.it("rarity: weights decrease with rarity", function()
    local w = Config.rarity.weights
    MiniTest.assert(w[1] > w[2], "Common should be more common than Uncommon")
    MiniTest.assert(w[2] > w[3], "Uncommon should be more common than Rare")
end)

--------------------------------------------------------------------------------
-- Debug Config Tests
--------------------------------------------------------------------------------

MiniTest.it("debug: has flags", function()
    MiniTest.assert(Config.debug ~= nil)
    MiniTest.assert(type(Config.debug.show_fps) == "boolean")
    MiniTest.assert(type(Config.debug.skip_animations) == "boolean")
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

print("\n=== Config Tests ===")
MiniTest.runAll()
