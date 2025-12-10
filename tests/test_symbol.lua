-- tests/test_symbol.lua
local test = require("tests.minitest")
-- Must load content to register symbols first
require("src.content.symbols")
local Registry = require("src.core.registry")
local Grid = require("src.core.grid")

test.describe("Symbol System", function()
    test.it("should create valid symbols from registry", function()
        local s = Registry.createSymbol("coin")
        test.assert_equal("coin", s.key)
        test.assert_equal(1, s.base_value)
    end)
    
    test.it("should generate different rarities", function()
        -- Statistical test
        local pool = {}
        for i=1, 100 do
            local type = Registry.getRandomSymbolKey()
            pool[type] = (pool[type] or 0) + 1
        end
        test.assert(pool["coin"] > 0, "Should generate commons")
    end)
    
    test.it("interaction: cat drinks milk", function()
        local g = Grid.new(3, 3)
        g.cells[2][2] = Registry.createSymbol("cat")
        g.cells[1][2] = Registry.createSymbol("milk")
        
        local cat = g.cells[2][2]
        
        local val, logs = cat:getValue(g, 2, 2)
        
        test.assert_equal(11, val, "Cat should get bonus")
        test.assert(g.cells[1][2] == nil, "Milk should be removed")
    end)
    
    test.it("interaction: miner mines ore", function()
        local g = Grid.new(3, 3)
        g.cells[2][2] = Registry.createSymbol("miner")
        g.cells[1][2] = Registry.createSymbol("ore")
        
        local miner = g.cells[2][2]
        local val, logs = miner:getValue(g, 2, 2)
        
        -- Miner(1) + Bonus(10) = 11
        test.assert_equal(11, val, "Miner should get bonus")
        test.assert(g.cells[1][2] == nil, "Ore should be destroyed")
    end)
    
    test.it("interaction: toddler eats candy", function()
        local g = Grid.new(3, 3)
        g.cells[2][2] = Registry.createSymbol("toddler")
        g.cells[1][2] = Registry.createSymbol("candy")
        
        local toddler = g.cells[2][2]
        local val, logs = toddler:getValue(g, 2, 2)
        
        -- Toddler(1) + Bonus(5) = 6
        test.assert_equal(6, val, "Toddler should get bonus")
        test.assert(g.cells[1][2] == nil, "Candy should be eaten")
    end)
    
    test.it("interaction: sun buffs flower", function()
        local g = Grid.new(3, 3)
        g.cells[2][2] = Registry.createSymbol("flower")
        g.cells[1][2] = Registry.createSymbol("sun") -- Sun is neighbor
        
        local flower = g.cells[2][2]
        local sun = g.cells[1][2]
        
        -- Calculate Flower
        local val, logs = flower:getValue(g, 2, 2)
        
        -- Flower(1) * 5 = 5
        test.assert_equal(5, val, "Flower should be buffed by Sun")
        
        -- Sun should NOT be destroyed
        test.assert(g.cells[1][2] ~= nil, "Sun should persist")
        
        -- Calculate Sun (ensure it still gives its own value)
        local sVal = sun:getValue(g, 1, 2)
        test.assert_equal(3, sVal, "Sun gives base value")
    end)
end)
