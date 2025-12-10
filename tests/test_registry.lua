-- tests/test_registry.lua
-- Unit tests for Registry validation

local MiniTest = require("tests.minitest")

-- Mock love for headless testing
if not love then
    _G.love = {
        graphics = {
            newFont = function() return {} end,
            setFont = function() end,
        },
        filesystem = {
            getInfo = function() return nil end
        },
        audio = {
            newSource = function() return {} end
        }
    }
end

-- Mock Fonts
_G.Fonts = {
    small = {},
    normal = {},
    big = {}
}

local Registry = require("src.core.registry")

--------------------------------------------------------------------------------
-- Symbol Registration Tests
--------------------------------------------------------------------------------

MiniTest.it("registerSymbol: valid symbol", function()
    -- Should not throw
    Registry.registerSymbol("test_valid", {
        name = "Test Symbol",
        char = "T",
        color = {1, 0, 0},
        value = 5,
        rarity = 2
    })
    
    MiniTest.assert(Registry.symbol_types["test_valid"] ~= nil, "Symbol should be registered")
    MiniTest.assertEqual(Registry.symbol_types["test_valid"].value, 5)
end)

MiniTest.it("registerSymbol: missing key throws", function()
    local success = pcall(function()
        Registry.registerSymbol(nil, {name = "Test"})
    end)
    MiniTest.assert(not success, "Should throw on nil key")
end)

MiniTest.it("registerSymbol: empty key throws", function()
    local success = pcall(function()
        Registry.registerSymbol("", {name = "Test"})
    end)
    MiniTest.assert(not success, "Should throw on empty key")
end)

MiniTest.it("registerSymbol: missing name throws", function()
    local success = pcall(function()
        Registry.registerSymbol("test_no_name", {
            char = "X",
            value = 1
        })
    end)
    MiniTest.assert(not success, "Should throw when no name or name_key")
end)

MiniTest.it("registerSymbol: invalid color throws", function()
    local success = pcall(function()
        Registry.registerSymbol("test_bad_color", {
            name = "Test",
            color = {2, 0, 0}  -- Invalid: > 1
        })
    end)
    MiniTest.assert(not success, "Should throw on invalid color value")
end)

MiniTest.it("registerSymbol: invalid rarity throws", function()
    local success = pcall(function()
        Registry.registerSymbol("test_bad_rarity", {
            name = "Test",
            rarity = 5  -- Invalid: must be 1-3
        })
    end)
    MiniTest.assert(not success, "Should throw on invalid rarity")
end)

MiniTest.it("registerSymbol: on_calculate must be function", function()
    local success = pcall(function()
        Registry.registerSymbol("test_bad_calc", {
            name = "Test",
            on_calculate = "not a function"
        })
    end)
    MiniTest.assert(not success, "Should throw when on_calculate is not a function")
end)

MiniTest.it("registerSymbol: defaults applied", function()
    Registry.registerSymbol("test_defaults", {
        name = "Test Defaults"
    })
    
    local def = Registry.symbol_types["test_defaults"]
    MiniTest.assertEqual(def.rarity, 1, "Default rarity should be 1")
    MiniTest.assertEqual(def.value, 1, "Default value should be 1")
    MiniTest.assert(def.renderer ~= nil, "Default renderer should be created")
end)

--------------------------------------------------------------------------------
-- Relic Registration Tests
--------------------------------------------------------------------------------

MiniTest.it("registerRelic: valid relic", function()
    Registry.registerRelic("test_relic", {
        name = "Test Relic",
        char = "R",
        color = {0.5, 0.5, 1},
        on_spin_end = function() end
    })
    
    MiniTest.assert(Registry.relic_types["test_relic"] ~= nil)
end)

MiniTest.it("registerRelic: invalid hook throws", function()
    local success = pcall(function()
        Registry.registerRelic("test_bad_hook", {
            name = "Test",
            on_spin_start = "not a function"
        })
    end)
    MiniTest.assert(not success, "Should throw when hook is not a function")
end)

--------------------------------------------------------------------------------
-- Consumable Registration Tests
--------------------------------------------------------------------------------

MiniTest.it("registerConsumable: valid consumable", function()
    Registry.registerConsumable("test_consumable", {
        name = "Test Item",
        char = "I",
        on_use = function() return true end
    })
    
    MiniTest.assert(Registry.consumable_types["test_consumable"] ~= nil)
end)

--------------------------------------------------------------------------------
-- Instance Creation Tests
--------------------------------------------------------------------------------

MiniTest.it("createSymbol: creates valid instance", function()
    Registry.registerSymbol("test_instance", {
        name = "Instance Test",
        char = "I",
        color = {1, 1, 0},
        value = 3
    })
    
    local instance = Registry.createSymbol("test_instance")
    
    MiniTest.assert(instance ~= nil, "Instance should be created")
    MiniTest.assertEqual(instance.key, "test_instance")
    MiniTest.assertEqual(instance.base_value, 3)
    MiniTest.assert(instance.renderer ~= nil, "Instance should have renderer")
    MiniTest.assert(type(instance.getValue) == "function", "Instance should have getValue method")
end)

MiniTest.it("createSymbol: unknown key throws", function()
    local success = pcall(function()
        Registry.createSymbol("nonexistent_symbol")
    end)
    MiniTest.assert(not success, "Should throw on unknown symbol key")
end)

MiniTest.it("getRandomSymbolKey: returns valid key", function()
    -- Ensure at least one symbol exists
    Registry.registerSymbol("test_random", {name = "Random Test"})
    
    local key = Registry.getRandomSymbolKey()
    MiniTest.assert(type(key) == "string", "Should return a string key")
    MiniTest.assert(Registry.symbol_types[key] ~= nil, "Key should exist in registry")
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

print("\n=== Registry Tests ===")
MiniTest.runAll()
