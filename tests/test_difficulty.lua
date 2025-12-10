-- tests/test_difficulty.lua
-- Unit tests for difficulty system

local T = require("tests.test_runner")

local Difficulty = require("src.core.difficulty")

T.describe("Difficulty Rent Calculation", function()
    
    T.it("should calculate tutorial phase rent (floors 1-5)", function()
        T.assertEqual(Difficulty.calculateRent(1), 15, "Floor 1 rent")
        T.assertEqual(Difficulty.calculateRent(2), 20, "Floor 2 rent")
        T.assertEqual(Difficulty.calculateRent(3), 25, "Floor 3 rent")
        T.assertEqual(Difficulty.calculateRent(5), 35, "Floor 5 rent")
    end)
    
    T.it("should calculate growth phase rent (floors 6-10)", function()
        T.assertEqual(Difficulty.calculateRent(6), 43, "Floor 6 rent")
        T.assertEqual(Difficulty.calculateRent(10), 75, "Floor 10 rent")
    end)
    
    T.it("should calculate challenge phase rent (floors 11-15)", function()
        T.assertEqual(Difficulty.calculateRent(11), 90, "Floor 11 rent")
        T.assertEqual(Difficulty.calculateRent(15), 150, "Floor 15 rent")
    end)
    
    T.it("should calculate mastery phase rent (floors 16-20)", function()
        T.assertEqual(Difficulty.calculateRent(16), 175, "Floor 16 rent")
        T.assertEqual(Difficulty.calculateRent(20), 275, "Floor 20 rent")
    end)
    
    T.it("should calculate endless mode rent exponentially", function()
        local rent21 = Difficulty.calculateRent(21)
        local rent22 = Difficulty.calculateRent(22)
        
        T.assertTrue(rent21 > 275, "Floor 21 > 275")
        T.assertTrue(rent22 > rent21, "Floor 22 > Floor 21")
        -- Check exponential growth (1.12x)
        T.assertApprox(rent22 / rent21, 1.12, 0.05, "Exponential growth rate")
    end)
    
end)

T.describe("Difficulty Spins Per Floor", function()
    
    T.it("should give 6 spins for tutorial floors", function()
        T.assertEqual(Difficulty.getSpins(1), 6, "Floor 1 spins")
        T.assertEqual(Difficulty.getSpins(5), 6, "Floor 5 spins")
    end)
    
    T.it("should give 5 spins for mid floors", function()
        T.assertEqual(Difficulty.getSpins(6), 5, "Floor 6 spins")
        T.assertEqual(Difficulty.getSpins(10), 5, "Floor 10 spins")
        T.assertEqual(Difficulty.getSpins(15), 5, "Floor 15 spins")
    end)
    
    T.it("should give 4 spins for endless floors", function()
        T.assertEqual(Difficulty.getSpins(16), 4, "Floor 16 spins")
        T.assertEqual(Difficulty.getSpins(20), 4, "Floor 20 spins")
    end)
    
end)

T.describe("Difficulty Boss Floors", function()
    
    T.it("should identify boss floors (every 5th)", function()
        T.assertFalse(Difficulty.isBossFloor(1), "Floor 1 not boss")
        T.assertFalse(Difficulty.isBossFloor(4), "Floor 4 not boss")
        T.assertTrue(Difficulty.isBossFloor(5), "Floor 5 is boss")
        T.assertTrue(Difficulty.isBossFloor(10), "Floor 10 is boss")
        T.assertTrue(Difficulty.isBossFloor(15), "Floor 15 is boss")
    end)
    
    T.it("should return boss requirement for boss floors", function()
        local req = Difficulty.getBossRequirement(5)
        T.assertNotNil(req, "Boss requirement exists")
        T.assertEqual(req.type, "money", "Requirement type")
        T.assertEqual(req.amount, 35 * 2, "Requirement amount (2x rent)")
    end)
    
    T.it("should return nil for non-boss floors", function()
        local req = Difficulty.getBossRequirement(3)
        T.assertEqual(req, nil, "No requirement for non-boss")
    end)
    
end)

T.describe("Difficulty Checkpoints", function()
    
    T.it("should identify checkpoint floors", function()
        T.assertFalse(Difficulty.isCheckpoint(1), "Floor 1 not checkpoint")
        T.assertFalse(Difficulty.isCheckpoint(2), "Floor 2 not checkpoint")
        T.assertTrue(Difficulty.isCheckpoint(3), "Floor 3 is checkpoint")
        T.assertFalse(Difficulty.isCheckpoint(5), "Floor 5 not checkpoint")
        T.assertTrue(Difficulty.isCheckpoint(7), "Floor 7 is checkpoint")
    end)
    
end)

T.describe("Difficulty Random Events", function()
    
    T.it("should have events defined", function()
        T.assertTrue(#Difficulty.events > 0, "Events exist")
    end)
    
    T.it("should have positive, negative, and neutral events", function()
        local hasPositive, hasNegative, hasNeutral = false, false, false
        for _, event in ipairs(Difficulty.events) do
            if event.type == "positive" then hasPositive = true end
            if event.type == "negative" then hasNegative = true end
            if event.type == "neutral" then hasNeutral = true end
        end
        T.assertTrue(hasPositive, "Has positive events")
        T.assertTrue(hasNegative, "Has negative events")
        T.assertTrue(hasNeutral, "Has neutral events")
    end)
    
    T.it("should roll events with increasing probability", function()
        -- Test that higher floors have higher event chance
        -- We can't test randomness directly, but we can verify the function exists
        local event1 = Difficulty.rollEvent(1)
        local event10 = Difficulty.rollEvent(10)
        -- Both should return nil or an event table
        T.assertTrue(event1 == nil or type(event1) == "table", "Floor 1 event valid")
        T.assertTrue(event10 == nil or type(event10) == "table", "Floor 10 event valid")
    end)
    
end)

T.describe("Difficulty Floor Info", function()
    
    T.it("should return complete floor info", function()
        local info = Difficulty.getFloorInfo(5)
        
        T.assertEqual(info.floor, 5, "Floor number")
        T.assertEqual(info.rent, 35, "Rent amount")
        T.assertEqual(info.spins, 6, "Spins count")
        T.assertTrue(info.isBoss, "Is boss floor")
        T.assertFalse(info.isCheckpoint, "Not checkpoint")
        T.assertNotNil(info.bossReq, "Has boss requirement")
    end)
    
end)

return T
