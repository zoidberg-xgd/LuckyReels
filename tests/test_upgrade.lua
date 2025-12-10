-- tests/test_upgrade.lua
-- Unit tests for upgrade system

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
local Upgrade = require("src.core.upgrade")
local Registry = require("src.core.registry")

T.describe("Upgrade Configuration", function()
    
    T.it("should have correct config values", function()
        T.assertEqual(Upgrade.CONFIG.symbols_to_upgrade, 3, "Need 3 symbols")
        T.assertEqual(Upgrade.CONFIG.max_level, 3, "Max level is 3")
        T.assertTrue(Upgrade.CONFIG.value_multiplier > 1, "Value multiplier > 1")
    end)
    
end)

T.describe("Upgrade Level Detection", function()
    
    T.it("should return level 1 for new symbol", function()
        local sym = Registry.createSymbol("coin")
        T.assertEqual(Upgrade.getLevel(sym), 1, "New symbol is level 1")
    end)
    
    T.it("should return correct level for upgraded symbol", function()
        local sym = Registry.createSymbol("coin")
        sym.level = 2
        T.assertEqual(Upgrade.getLevel(sym), 2, "Level 2 symbol")
        
        sym.level = 3
        T.assertEqual(Upgrade.getLevel(sym), 3, "Level 3 symbol")
    end)
    
end)

T.describe("Upgrade Candidate Finding", function()
    
    T.it("should find upgrade candidates", function()
        local inventory = {
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
            Registry.createSymbol("flower"),
        }
        
        local candidates, level = Upgrade.findUpgradeCandidates(inventory, "coin")
        
        T.assertEqual(#candidates, 3, "Found 3 coin candidates")
        T.assertEqual(level, 1, "All level 1")
    end)
    
    T.it("should only find same level candidates", function()
        local inventory = {
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
        }
        inventory[1].level = 1
        inventory[2].level = 2  -- Different level
        
        local candidates = Upgrade.findUpgradeCandidates(inventory, "coin")
        
        T.assertEqual(#candidates, 1, "Only 1 candidate (same level)")
    end)
    
end)

T.describe("Upgrade Progress", function()
    
    T.it("should report upgrade progress", function()
        local inventory = {
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
        }
        
        local progress = Upgrade.getUpgradeProgress(inventory, "coin")
        
        T.assertEqual(progress.current, 2, "Current count")
        T.assertEqual(progress.needed, 3, "Needed count")
        T.assertEqual(progress.level, 1, "Current level")
        T.assertFalse(progress.canUpgrade, "Cannot upgrade yet")
    end)
    
    T.it("should report can upgrade when enough", function()
        local inventory = {
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
        }
        
        local progress = Upgrade.getUpgradeProgress(inventory, "coin")
        
        T.assertTrue(progress.canUpgrade, "Can upgrade")
    end)
    
    T.it("should not allow upgrade at max level", function()
        local inventory = {
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
        }
        for _, sym in ipairs(inventory) do
            sym.level = 3  -- Max level
        end
        
        local progress = Upgrade.getUpgradeProgress(inventory, "coin")
        
        T.assertFalse(progress.canUpgrade, "Cannot upgrade at max level")
    end)
    
end)

T.describe("Upgrade Execution", function()
    
    T.it("should upgrade symbol successfully", function()
        local inventory = {
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
            Registry.createSymbol("flower"),
        }
        
        local result = Upgrade.upgradeSymbol(inventory, "coin")
        
        T.assertNotNil(result, "Upgrade returned result")
        T.assertEqual(result.level, 2, "New symbol is level 2")
        T.assertEqual(#inventory, 2, "Inventory reduced (3 removed, 1 added)")
    end)
    
    T.it("should increase base value on upgrade", function()
        local inventory = {
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
        }
        local originalValue = inventory[1].base_value
        
        local result = Upgrade.upgradeSymbol(inventory, "coin")
        
        T.assertTrue(result.base_value > originalValue, "Value increased")
    end)
    
    T.it("should fail upgrade with not enough symbols", function()
        local inventory = {
            Registry.createSymbol("coin"),
            Registry.createSymbol("coin"),
        }
        
        local result, reason = Upgrade.upgradeSymbol(inventory, "coin")
        
        T.assertEqual(result, nil, "Upgrade failed")
        T.assertEqual(reason, "not_enough_symbols", "Correct reason")
    end)
    
end)

T.describe("Upgrade Quality Names", function()
    
    T.it("should return quality name for each level", function()
        local sym1 = Registry.createSymbol("coin")
        sym1.level = 1
        local sym2 = Registry.createSymbol("coin")
        sym2.level = 2
        local sym3 = Registry.createSymbol("coin")
        sym3.level = 3
        
        T.assertNotNil(Upgrade.getQualityName(sym1), "Level 1 has name")
        T.assertNotNil(Upgrade.getQualityName(sym2), "Level 2 has name")
        T.assertNotNil(Upgrade.getQualityName(sym3), "Level 3 has name")
    end)
    
    T.it("should return quality color for each level", function()
        local sym1 = Registry.createSymbol("coin")
        sym1.level = 1
        local sym2 = Registry.createSymbol("coin")
        sym2.level = 2
        local sym3 = Registry.createSymbol("coin")
        sym3.level = 3
        
        local color1 = Upgrade.getQualityColor(sym1)
        local color2 = Upgrade.getQualityColor(sym2)
        local color3 = Upgrade.getQualityColor(sym3)
        
        T.assertEqual(type(color1), "table", "Level 1 color is table")
        T.assertEqual(#color1, 3, "Color has 3 components")
    end)
    
end)

return T
