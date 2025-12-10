-- tests/test_money_system.lua
-- Unit tests for the money/coin system

local T = require("tests.test_runner")

-- Mock love graphics for headless testing
if not love then
    love = {
        graphics = {
            getWidth = function() return 1024 end,
            getHeight = function() return 768 end,
        }
    }
end

local Effects = require("src.effects")
local Engine = require("src.core.engine")

T.describe("Effects Money Display System", function()
    
    T.it("should initialize displayedMoney to 0", function()
        Effects.init()
        T.assertEqual(Effects.getDisplayedMoney(), 0, "Initial displayed money")
    end)
    
    T.it("should set displayed money correctly", function()
        Effects.init()
        Effects.setDisplayedMoney(100)
        T.assertEqual(Effects.getDisplayedMoney(), 100, "Set displayed money")
    end)
    
    T.it("should sync downward immediately (rent payment)", function()
        Effects.init()
        Effects.setDisplayedMoney(100)
        Effects.syncDisplayedMoney(80)  -- Simulate rent payment
        T.assertEqual(Effects.getDisplayedMoney(), 80, "Sync down for rent")
    end)
    
    T.it("should not sync upward automatically", function()
        Effects.init()
        Effects.setDisplayedMoney(50)
        Effects.syncDisplayedMoney(100)  -- Try to sync up
        -- Should NOT change because we want coins to animate
        T.assertEqual(Effects.getDisplayedMoney(), 50, "Should not sync up")
    end)
    
    T.it("should track pending coins separately", function()
        Effects.init()
        Effects.setDisplayedMoney(50)
        Effects.pendingCoins = 10
        T.assertEqual(Effects.getDisplayedMoney(), 50, "Displayed money unchanged")
        T.assertEqual(Effects.pendingCoins, 10, "Pending coins tracked")
    end)
    
    T.it("should report collecting state correctly", function()
        Effects.init()
        T.assertFalse(Effects.isCollecting(), "Not collecting initially")
        
        Effects.pendingCoins = 5
        T.assertTrue(Effects.isCollecting(), "Collecting when pending coins")
        
        Effects.pendingCoins = 0
        Effects.addFlyingCoin(100, 100, 5, 0)
        T.assertTrue(Effects.isCollecting(), "Collecting when flying coins")
    end)
    
end)

T.describe("Flying Coin System", function()
    
    T.it("should create flying coin with correct value", function()
        Effects.init()
        Effects.setCoinTarget(50, 50)
        Effects.addFlyingCoin(200, 200, 10, 0)
        
        T.assertEqual(#Effects.flyingCoins, 1, "One flying coin created")
        T.assertEqual(Effects.flyingCoins[1].value, 10, "Coin value correct")
    end)
    
    T.it("should support delayed coin spawn", function()
        Effects.init()
        Effects.setCoinTarget(50, 50)
        Effects.addFlyingCoin(200, 200, 5, 0.5)  -- 0.5s delay
        
        T.assertEqual(Effects.flyingCoins[1].timer, -0.5, "Negative timer for delay")
    end)
    
    T.it("should add money when coin collected via callback", function()
        Effects.init()
        Effects.setCoinTarget(50, 50)
        
        local collectedValue = 0
        Effects.onCoinCollected = function(value)
            collectedValue = collectedValue + value
        end
        
        -- Simulate coin reaching target
        Effects.addFlyingCoin(50, 50, 7, 0)
        Effects.flyingCoins[1].timer = 1  -- Force completion
        Effects.flyingCoins[1].duration = 0.5
        Effects.update(0.1)  -- Process
        
        T.assertEqual(collectedValue, 7, "Callback received correct value")
    end)
    
    T.it("should update displayed money when coin collected", function()
        Effects.init()
        Effects.setDisplayedMoney(100)
        Effects.setCoinTarget(50, 50)
        
        -- Add coin and force collection
        Effects.addFlyingCoin(50, 50, 15, 0)
        Effects.flyingCoins[1].timer = 1
        Effects.flyingCoins[1].duration = 0.5
        Effects.update(0.1)
        
        T.assertEqual(Effects.getDisplayedMoney(), 115, "Displayed money increased")
    end)
    
end)

T.describe("Scoring Queue System (Balatro-style)", function()
    
    T.it("should queue symbol for scoring", function()
        Effects.init()
        Effects.queueSymbolScore(100, 100, 80, 80, 5, {1, 1, 0}, 0)
        
        T.assertEqual(#Effects.scoringQueue, 1, "One item in queue")
        T.assertEqual(Effects.scoringQueue[1].value, 5, "Correct value")
        T.assertEqual(Effects.scoringQueue[1].phase, "waiting", "Initial phase")
    end)
    
    T.it("should process delay before scoring", function()
        Effects.init()
        Effects.queueSymbolScore(100, 100, 80, 80, 5, {1, 1, 0}, 0.5)
        
        T.assertEqual(Effects.scoringQueue[1].phase, "waiting", "Initial phase is waiting")
        T.assertEqual(Effects.scoringQueue[1].delay, 0.5, "Delay is 0.5")
        
        Effects.updateScoring(0.3)  -- Not enough time (delay now 0.2)
        T.assertTrue(Effects.scoringQueue[1].delay > 0, "Still has delay")
        
        Effects.updateScoring(0.3)  -- Now enough (delay should be <= 0)
        -- After delay expires, phase changes to punch
        local isPunching = Effects.hasActiveScoring()
        T.assertTrue(isPunching, "Scoring is now active")
    end)
    
    T.it("should report active scoring correctly", function()
        Effects.init()
        T.assertFalse(Effects.hasActiveScoring(), "No active scoring initially")
        
        Effects.queueSymbolScore(100, 100, 80, 80, 5, {1, 1, 0}, 0)
        T.assertTrue(Effects.hasActiveScoring(), "Has active scoring when queued")
    end)
    
    T.it("should clear scoring queue", function()
        Effects.init()
        Effects.queueSymbolScore(100, 100, 80, 80, 5, {1, 1, 0}, 0)
        Effects.queueSymbolScore(200, 100, 80, 80, 3, {1, 1, 0}, 0)
        
        Effects.clearScoring()
        T.assertEqual(#Effects.scoringQueue, 0, "Queue cleared")
        T.assertEqual(Effects.currentScoring, nil, "Current scoring cleared")
    end)
    
end)

T.describe("HUD Bounce Effect", function()
    
    T.it("should initialize bounce to 0", function()
        Effects.init()
        T.assertEqual(Effects.hudBounce, 0, "Initial bounce is 0")
    end)
    
    T.it("should return scale of 1 when no bounce", function()
        Effects.init()
        Effects.hudBounce = 0
        T.assertEqual(Effects.getHudBounce(), 1, "Scale is 1 with no bounce")
    end)
    
    T.it("should return increased scale when bouncing", function()
        Effects.init()
        Effects.hudBounce = 0.15
        local scale = Effects.getHudBounce()
        T.assertTrue(scale > 1, "Scale > 1 when bouncing")
        T.assertApprox(scale, 1.045, 0.01, "Correct bounce scale")
    end)
    
    T.it("should decay bounce over time", function()
        Effects.init()
        Effects.hudBounce = 0.15
        Effects.update(0.1)  -- Update with dt
        T.assertTrue(Effects.hudBounce < 0.15, "Bounce decreased")
    end)
    
end)

return T
