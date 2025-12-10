-- tests/test_grid.lua
local test = require("tests.minitest")
local Grid = require("src.core.grid")
-- Load symbols to registry
require("src.content.symbols")
local Registry = require("src.core.registry")

test.describe("Grid System", function()
    test.it("should create an empty grid of correct size", function()
        local g = Grid.new(4, 5)
        test.assert_equal(4, g.rows)
        test.assert_equal(5, g.cols)
        test.assert(g.cells[4][5] == nil, "Cell should be nil")
    end)

    test.it("should place symbols correctly via spin", function()
        local g = Grid.new(2, 2)
        local inventory = {Registry.createSymbol("coin"), Registry.createSymbol("flower")}
        g:spin(inventory)
        
        -- Since inventory (2) < grid size (4), some cells should be nil
        local count = 0
        for r=1, 2 do
            for c=1, 2 do
                if g.cells[r][c] then count = count + 1 end
            end
        end
        test.assert_equal(2, count, "Should have exactly 2 items on grid")
    end)
    
    test.it("should remove symbol correctly", function()
        local g = Grid.new(2, 2)
        g.cells[1][1] = Registry.createSymbol("coin")
        test.assert(g:getSymbol(1, 1) ~= nil, "Symbol should exist")
        
        g:removeSymbol(1, 1)
        test.assert(g:getSymbol(1, 1) == nil, "Symbol should be removed")
    end)
end)
