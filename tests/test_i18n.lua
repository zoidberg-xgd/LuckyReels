-- tests/test_i18n.lua
-- Tests for internationalization - ensure no hardcoded strings

package.path = package.path .. ";./?.lua;./?/init.lua"

local T = require("tests.minitest")
local i18n = require("src.i18n")

--------------------------------------------------------------------------------
-- Test Setup
--------------------------------------------------------------------------------

local function getAllKeys(locale)
    i18n.setLanguage(locale)
    local keys = {}
    for k, _ in pairs(i18n.translations[locale] or {}) do
        keys[k] = true
    end
    return keys
end

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

T.describe("i18n Language Support", function()
    
    T.it("should have English translations", function()
        local en = require("src.locales.en")
        T.assertNotNil(en, "English locale exists")
        T.assertTrue(next(en) ~= nil, "Has translations")
    end)
    
    T.it("should have Chinese translations", function()
        local zh = require("src.locales.zh")
        T.assertNotNil(zh, "Chinese locale exists")
        T.assertTrue(next(zh) ~= nil, "Has translations")
    end)
    
    T.it("should switch languages", function()
        i18n.setLanguage("en")
        T.assertEqual(i18n.getLanguage(), "en", "Language is English")
        
        i18n.setLanguage("zh")
        T.assertEqual(i18n.getLanguage(), "zh", "Language is Chinese")
    end)
    
end)

T.describe("i18n Key Parity", function()
    
    T.it("should have same keys in both languages", function()
        local en = require("src.locales.en")
        local zh = require("src.locales.zh")
        
        local missingInZh = {}
        local missingInEn = {}
        
        for k, _ in pairs(en) do
            if not zh[k] then
                table.insert(missingInZh, k)
            end
        end
        
        for k, _ in pairs(zh) do
            if not en[k] then
                table.insert(missingInEn, k)
            end
        end
        
        if #missingInZh > 0 then
            print("  Missing in zh: " .. table.concat(missingInZh, ", "))
        end
        if #missingInEn > 0 then
            print("  Missing in en: " .. table.concat(missingInEn, ", "))
        end
        
        T.assertEqual(#missingInZh, 0, "All English keys exist in Chinese")
        T.assertEqual(#missingInEn, 0, "All Chinese keys exist in English")
    end)
    
end)

T.describe("i18n Symbol Names", function()
    
    T.it("should have all symbol names translated", function()
        local Registry = require("src.core.registry")
        local en = require("src.locales.en")
        
        local missing = {}
        for key, _ in pairs(Registry.symbols) do
            local nameKey = "symbol_" .. key .. "_name"
            local descKey = "symbol_" .. key .. "_desc"
            
            if not en[nameKey] then
                table.insert(missing, nameKey)
            end
            if not en[descKey] then
                table.insert(missing, descKey)
            end
        end
        
        if #missing > 0 then
            print("  Missing symbol translations: " .. table.concat(missing, ", "))
        end
        
        T.assertEqual(#missing, 0, "All symbols have translations")
    end)
    
end)

T.describe("i18n Synergy Names", function()
    
    T.it("should have all synergy names translated", function()
        local Synergy = require("src.core.synergy")
        local en = require("src.locales.en")
        
        local missing = {}
        
        -- Check category synergies
        for _, bonuses in pairs(Synergy.bonuses) do
            for _, bonus in ipairs(bonuses) do
                local nameKey = bonus[3]
                if not en[nameKey] then
                    table.insert(missing, nameKey)
                end
            end
        end
        
        -- Check combos
        for _, combo in pairs(Synergy.combos) do
            if combo.name_key and not en[combo.name_key] then
                table.insert(missing, combo.name_key)
            end
        end
        
        if #missing > 0 then
            print("  Missing synergy translations: " .. table.concat(missing, ", "))
        end
        
        T.assertEqual(#missing, 0, "All synergies have translations")
    end)
    
end)

T.describe("i18n Event Names", function()
    
    T.it("should have all event names translated", function()
        local eventData = require("data.events")
        local en = require("src.locales.en")
        
        local missing = {}
        
        for _, event in ipairs(eventData) do
            if not en[event.name_key] then
                table.insert(missing, event.name_key)
            end
            if not en[event.desc_key] then
                table.insert(missing, event.desc_key)
            end
        end
        
        if #missing > 0 then
            print("  Missing event translations: " .. table.concat(missing, ", "))
        end
        
        T.assertEqual(#missing, 0, "All events have translations")
    end)
    
end)

T.describe("i18n UI Strings", function()
    
    T.it("should have essential UI strings", function()
        local en = require("src.locales.en")
        
        local requiredKeys = {
            "ui_continue",
            "ui_shop",
            "ui_buy",
            "ui_sell",
            "ui_inventory",
            "ui_spins_unit",
            "ui_symbols_unit",
            "ui_floor",
            "ui_press_spin",
            "ui_spinning",
        }
        
        local missing = {}
        for _, key in ipairs(requiredKeys) do
            if not en[key] then
                table.insert(missing, key)
            end
        end
        
        if #missing > 0 then
            print("  Missing UI translations: " .. table.concat(missing, ", "))
        end
        
        T.assertEqual(#missing, 0, "All essential UI strings exist")
    end)
    
end)

return T
