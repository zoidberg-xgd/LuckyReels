-- tests/test_engine.lua
-- Unit tests for the game engine

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

-- Load required modules
require("src.content.symbols")
local Engine = require("src.core.engine")
local Registry = require("src.core.registry")

T.describe("Engine Initialization", function()
    
    T.it("should initialize with default config", function()
        local engine = Engine.new()
        engine:init({
            rows = 4,
            cols = 5,
            starting_money = 10,
            starting_rent = 25,
        })
        
        T.assertEqual(engine.money, 10, "Starting money")
        T.assertEqual(engine.rent, 25, "Starting rent")
        T.assertEqual(engine.floor, 1, "Starting floor")
        T.assertEqual(engine.state, "IDLE", "Initial state")
    end)
    
    T.it("should have inventory capacity limit", function()
        local engine = Engine.new()
        engine:init({})
        
        T.assertEqual(engine.inventory_max, 20, "Inventory max capacity")
    end)
    
    T.it("should load starting inventory", function()
        local engine = Engine.new()
        engine:init({
            starting_inventory = {"coin", "coin", "flower"}
        })
        
        T.assertEqual(#engine.inventory, 3, "Inventory count")
        T.assertEqual(engine.inventory[1].key, "coin", "First symbol")
    end)
    
end)

T.describe("Engine Money Operations", function()
    
    T.it("should track money changes", function()
        local engine = Engine.new()
        engine:init({starting_money = 50})
        
        T.assertEqual(engine.money, 50, "Initial money")
        
        engine.money = engine.money + 25
        T.assertEqual(engine.money, 75, "After adding")
        
        engine.money = engine.money - 30
        T.assertEqual(engine.money, 45, "After subtracting")
    end)
    
    T.it("should store pending score during spin", function()
        local engine = Engine.new()
        engine:init({
            starting_money = 10,
            starting_inventory = {"coin", "coin"}
        })
        
        -- Manually set pending score
        engine.pending_score = 15
        T.assertEqual(engine.pending_score, 15, "Pending score stored")
    end)
    
    T.it("should clear pending score after collecting", function()
        local engine = Engine.new()
        engine:init({starting_money = 10})
        engine.pending_score = 20
        engine.state = "COLLECTING"
        
        engine:finishCollecting()
        
        T.assertEqual(engine.pending_score, 0, "Pending score cleared")
    end)
    
end)

T.describe("Engine Rent System", function()
    
    T.it("should pay rent when enough money", function()
        local engine = Engine.new()
        engine:init({
            starting_money = 100,
            starting_rent = 30,
            spins_per_rent = 5
        })
        
        engine.spins_left = 0  -- Trigger rent check
        engine.state = "COLLECTING"
        engine:finishCollecting()
        
        T.assertEqual(engine.money, 70, "Money after rent")
        T.assertEqual(engine.state, "RENT_PAID", "State changed to RENT_PAID")
    end)
    
    T.it("should game over when not enough money", function()
        local engine = Engine.new()
        engine:init({
            starting_money = 20,
            starting_rent = 50,
            spins_per_rent = 5
        })
        
        engine.spins_left = 0
        engine.state = "COLLECTING"
        engine:finishCollecting()
        
        T.assertEqual(engine.state, "GAME_OVER", "Game over state")
    end)
    
    T.it("should advance floor after paying rent", function()
        local engine = Engine.new()
        engine:init({
            starting_money = 100,
            starting_rent = 25,
        })
        
        T.assertEqual(engine.floor, 1, "Initial floor")
        
        engine.spins_left = 0
        engine.state = "COLLECTING"
        engine:finishCollecting()
        
        T.assertEqual(engine.floor, 2, "Floor advanced")
    end)
    
    T.it("should store rent info for display", function()
        local engine = Engine.new()
        engine:init({
            starting_money = 100,
            starting_rent = 25,
        })
        
        engine.spins_left = 0
        engine.state = "COLLECTING"
        engine:finishCollecting()
        
        T.assertNotNil(engine.rent_info, "Rent info exists")
        T.assertEqual(engine.rent_info.paid, 25, "Paid amount")
        T.assertEqual(engine.rent_info.remaining, 75, "Remaining money")
        T.assertEqual(engine.rent_info.new_floor, 2, "New floor")
    end)
    
end)

T.describe("Engine Spin System", function()
    
    T.it("should decrement spins after spin", function()
        local engine = Engine.new()
        engine:init({
            starting_money = 10,
            spins_per_rent = 5,
            starting_inventory = {"coin"}
        })
        
        local initialSpins = engine.spins_left
        engine:spin()
        -- Simulate spin completion
        engine:resolveSpin()
        
        T.assertEqual(engine.spins_left, initialSpins - 1, "Spins decremented")
    end)
    
    T.it("should not spin when no spins left", function()
        local engine = Engine.new()
        engine:init({starting_money = 10})
        engine.spins_left = 0
        
        local result = engine:spin()
        T.assertFalse(result, "Spin should fail")
    end)
    
    T.it("should change state to SPINNING", function()
        local engine = Engine.new()
        engine:init({
            starting_money = 10,
            starting_inventory = {"coin"}
        })
        
        engine:spin()
        T.assertEqual(engine.state, "SPINNING", "State is SPINNING")
    end)
    
end)

T.describe("Engine Shop System", function()
    
    T.it("should open shop and create shop instance", function()
        local engine = Engine.new()
        engine:init({starting_money = 50})
        
        engine:openShop()
        
        -- May be EVENT or SHOP depending on random event
        T.assertTrue(engine.state == "SHOP" or engine.state == "EVENT", "Shop or Event state")
    end)
    
    T.it("should close shop and return to IDLE", function()
        local engine = Engine.new()
        engine:init({starting_money = 50})
        engine.state = "SHOP"
        engine.shop = {}
        
        engine:closeShop()
        
        T.assertEqual(engine.state, "IDLE", "State is IDLE")
        T.assertEqual(engine.shop, nil, "Shop cleared")
    end)
    
end)

return T
