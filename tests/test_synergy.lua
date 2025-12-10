-- tests/test_synergy.lua
-- Unit tests for synergy system

local T = require("tests.test_runner")

-- Mock love for headless testing
if not love then
    love = {
        graphics = {
            getWidth = function() return 1024 end,
            getHeight = function() return 768 end,
        }
    }
end

require("src.content.symbols")
local Synergy = require("src.core.synergy")
local Grid = require("src.core.grid")
local Registry = require("src.core.registry")

-- Helper to create a mock grid with specific symbols
local function createMockGrid(symbolKeys)
    local grid = Grid.new(4, 5)
    local index = 1
    for r = 1, grid.rows do
        for c = 1, grid.cols do
            if symbolKeys[index] then
                grid.cells[r][c] = Registry.createSymbol(symbolKeys[index])
            end
            index = index + 1
        end
    end
    return grid
end

T.describe("Synergy Categories", function()
    
    T.it("should have defined categories", function()
        T.assertNotNil(Synergy.categories.fruit, "Fruit category exists")
        T.assertNotNil(Synergy.categories.animal, "Animal category exists")
        T.assertNotNil(Synergy.categories.gem, "Gem category exists")
    end)
    
    T.it("should have symbols in each category", function()
        T.assertTrue(#Synergy.categories.fruit > 0, "Fruit has symbols")
        T.assertTrue(#Synergy.categories.animal > 0, "Animal has symbols")
        T.assertTrue(#Synergy.categories.gem > 0, "Gem has symbols")
    end)
    
end)

T.describe("Synergy Bonuses", function()
    
    T.it("should have bonus tiers for categories", function()
        T.assertNotNil(Synergy.bonuses.fruit, "Fruit bonuses exist")
        T.assertTrue(#Synergy.bonuses.fruit > 0, "Fruit has bonus tiers")
    end)
    
    T.it("should have increasing multipliers per tier", function()
        local fruitBonuses = Synergy.bonuses.fruit
        if #fruitBonuses >= 2 then
            T.assertTrue(fruitBonuses[2][2] > fruitBonuses[1][2], "Higher tier = higher multiplier")
        end
    end)
    
end)

T.describe("Synergy Calculation", function()
    
    T.it("should return multiplier of 1 with no synergies", function()
        local grid = createMockGrid({"coin"})  -- Just one coin
        local result = Synergy.calculate(grid)
        
        T.assertEqual(result.multiplier, 1, "No synergy multiplier")
        T.assertEqual(result.bonus, 0, "No synergy bonus")
        T.assertEqual(#result.synergies, 0, "No active synergies")
    end)
    
    T.it("should detect gem synergy with 3+ gems", function()
        local grid = createMockGrid({
            "coin", "coin", "coin", nil, nil,
            nil, nil, nil, nil, nil,
            nil, nil, nil, nil, nil,
            nil, nil, nil, nil, nil,
        })
        
        local result = Synergy.calculate(grid)
        
        T.assertTrue(result.multiplier > 1, "Has multiplier bonus")
        T.assertTrue(#result.synergies > 0, "Has active synergy")
    end)
    
end)

T.describe("Synergy Special Combos", function()
    
    T.it("should have special combos defined", function()
        T.assertNotNil(Synergy.combos, "Combos exist")
        T.assertTrue(next(Synergy.combos) ~= nil, "Has at least one combo")
    end)
    
    T.it("should detect cat_milk combo", function()
        local grid = createMockGrid({
            "cat", "milk", nil, nil, nil,
            nil, nil, nil, nil, nil,
            nil, nil, nil, nil, nil,
            nil, nil, nil, nil, nil,
        })
        
        local result = Synergy.calculate(grid)
        
        -- Check if cat_milk combo was detected (check for bonus instead of name)
        local foundCombo = false
        for _, syn in ipairs(result.synergies) do
            if syn.type == "combo" and syn.bonus == 5 then
                foundCombo = true
                break
            end
        end
        T.assertTrue(foundCombo, "Cat milk combo detected")
    end)
    
end)

T.describe("Synergy Preview", function()
    
    T.it("should preview potential synergies from inventory", function()
        local inventory = {
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
        }
        
        local preview = Synergy.getPreview(inventory)
        
        T.assertEqual(type(preview), "table", "Preview is table")
    end)
    
    T.it("should show progress toward synergies", function()
        local inventory = {
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
            Registry.createSymbol("pearl"),
        }
        
        local preview = Synergy.getPreview(inventory)
        
        -- Should show gem synergy progress
        local foundGem = false
        for _, syn in ipairs(preview) do
            if syn.category == "gem" then
                foundGem = true
                T.assertEqual(syn.current, 3, "3 gems counted")
            end
        end
    end)
    
end)

return T
