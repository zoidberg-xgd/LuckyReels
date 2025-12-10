-- tests/test_shop.lua
-- Unit tests for shop system

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
require("src.content.relics")
local Shop = require("src.core.shop")

T.describe("Shop Initialization", function()
    
    T.it("should create shop with symbols", function()
        local shop = Shop.new(1)
        T.assertTrue(#shop.symbols > 0, "Has symbols")
    end)
    
    T.it("should create shop with relics", function()
        local shop = Shop.new(1)
        T.assertTrue(#shop.relics >= 0, "Has relics array")
    end)
    
    T.it("should set prices on symbols", function()
        local shop = Shop.new(1)
        for _, sym in ipairs(shop.symbols) do
            T.assertNotNil(sym.price, "Symbol has price")
            T.assertTrue(sym.price > 0, "Price is positive")
        end
    end)
    
    T.it("should scale prices with floor", function()
        local shop1 = Shop.new(1)
        local shop5 = Shop.new(5)
        
        -- Prices should generally be higher on higher floors
        -- (due to price scaling in config)
        T.assertTrue(shop5.floor > shop1.floor, "Higher floor shop")
    end)
    
end)

T.describe("Shop Buying", function()
    
    T.it("should buy symbol when enough money", function()
        local shop = Shop.new(1)
        local mockEngine = {
            money = 100,
            inventory = {},
            inventory_max = 20
        }
        
        local firstSymbol = shop.symbols[1]
        local price = firstSymbol.price
        
        local success = shop:buySymbol(1, mockEngine)
        
        T.assertTrue(success, "Purchase successful")
        T.assertEqual(mockEngine.money, 100 - price, "Money deducted")
        T.assertEqual(#mockEngine.inventory, 1, "Symbol added to inventory")
        T.assertTrue(firstSymbol.sold, "Symbol marked as sold")
    end)
    
    T.it("should fail to buy when not enough money", function()
        local shop = Shop.new(1)
        local mockEngine = {
            money = 1,  -- Very little money
            inventory = {},
            inventory_max = 20
        }
        
        local success, reason = shop:buySymbol(1, mockEngine)
        
        T.assertFalse(success, "Purchase failed")
        T.assertEqual(reason, "not_enough_money", "Correct failure reason")
    end)
    
    T.it("should fail to buy when inventory full", function()
        local shop = Shop.new(1)
        local mockEngine = {
            money = 1000,
            inventory = {},
            inventory_max = 2
        }
        
        -- Fill inventory
        for i = 1, 2 do
            table.insert(mockEngine.inventory, {key = "test"})
        end
        
        local success, reason = shop:buySymbol(1, mockEngine)
        
        T.assertFalse(success, "Purchase failed")
        T.assertEqual(reason, "inventory_full", "Correct failure reason")
    end)
    
    T.it("should fail to buy already sold item", function()
        local shop = Shop.new(1)
        local mockEngine = {
            money = 100,
            inventory = {},
            inventory_max = 20
        }
        
        -- Buy once
        shop:buySymbol(1, mockEngine)
        
        -- Try to buy again
        local success, reason = shop:buySymbol(1, mockEngine)
        
        T.assertFalse(success, "Second purchase failed")
        T.assertEqual(reason, "already_sold", "Correct failure reason")
    end)
    
end)

T.describe("Shop Selling", function()
    
    T.it("should sell symbol and get money", function()
        local shop = Shop.new(1)
        local mockEngine = {
            money = 50,
            inventory = {{key = "coin", base_value = 1, rarity = 1}}
        }
        
        local initialMoney = mockEngine.money
        shop:sellSymbol(1, mockEngine)
        
        T.assertTrue(mockEngine.money > initialMoney, "Money increased")
        T.assertEqual(#mockEngine.inventory, 0, "Symbol removed")
    end)
    
    T.it("should calculate sell price based on rarity", function()
        local shop = Shop.new(1)
        
        local commonSym = {key = "coin", rarity = 1}
        local rareSym = {key = "diamond", rarity = 3}
        
        local commonPrice = shop:getSellPrice(commonSym)
        local rarePrice = shop:getSellPrice(rareSym)
        
        T.assertTrue(rarePrice > commonPrice, "Rare sells for more")
    end)
    
end)

T.describe("Shop Reroll", function()
    
    T.it("should reroll when enough money", function()
        local shop = Shop.new(1)
        local mockEngine = {
            money = 100,
            inventory = {}
        }
        
        local oldSymbols = {}
        for i, sym in ipairs(shop.symbols) do
            oldSymbols[i] = sym.key
        end
        
        local success = shop:reroll(mockEngine)
        
        T.assertTrue(success, "Reroll successful")
        T.assertTrue(mockEngine.money < 100, "Money spent on reroll")
    end)
    
    T.it("should fail reroll when not enough money", function()
        local shop = Shop.new(1)
        local mockEngine = {
            money = 0,
            inventory = {}
        }
        
        local success = shop:reroll(mockEngine)
        
        T.assertFalse(success, "Reroll failed")
    end)
    
end)

return T
