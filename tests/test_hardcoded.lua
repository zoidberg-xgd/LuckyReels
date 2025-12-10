-- tests/test_hardcoded.lua
-- Tests to detect hardcoded Chinese strings in source files

package.path = package.path .. ";./?.lua;./?/init.lua"

local T = require("tests.minitest")

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function readFile(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    return content
end

local function containsChinese(str)
    -- Check for Chinese characters (Unicode range)
    return str:match("[\228-\233][\128-\191][\128-\191]") ~= nil
end

local function findChineseStrings(content, filename)
    local issues = {}
    local lineNum = 0
    
    for line in content:gmatch("[^\n]+") do
        lineNum = lineNum + 1
        
        -- Skip comments
        if not line:match("^%s*%-%-") then
            -- Look for Chinese in string literals
            for str in line:gmatch('"([^"]*)"') do
                if containsChinese(str) then
                    table.insert(issues, {
                        file = filename,
                        line = lineNum,
                        text = str:sub(1, 30) .. (str:len() > 30 and "..." or "")
                    })
                end
            end
            for str in line:gmatch("'([^']*)'") do
                if containsChinese(str) then
                    table.insert(issues, {
                        file = filename,
                        line = lineNum,
                        text = str:sub(1, 30) .. (str:len() > 30 and "..." or "")
                    })
                end
            end
        end
    end
    
    return issues
end

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

T.describe("Hardcoded String Detection", function()
    
    T.it("should not have hardcoded Chinese in ui.lua", function()
        local content = readFile("src/ui.lua")
        T.assertNotNil(content, "File exists")
        
        local issues = findChineseStrings(content, "ui.lua")
        
        if #issues > 0 then
            print("  Found hardcoded Chinese in ui.lua:")
            for _, issue in ipairs(issues) do
                print(string.format("    Line %d: %s", issue.line, issue.text))
            end
        end
        
        T.assertEqual(#issues, 0, "No hardcoded Chinese in ui.lua")
    end)
    
    T.it("should not have hardcoded Chinese in game.lua", function()
        local content = readFile("src/game.lua")
        T.assertNotNil(content, "File exists")
        
        local issues = findChineseStrings(content, "game.lua")
        
        if #issues > 0 then
            print("  Found hardcoded Chinese in game.lua:")
            for _, issue in ipairs(issues) do
                print(string.format("    Line %d: %s", issue.line, issue.text))
            end
        end
        
        T.assertEqual(#issues, 0, "No hardcoded Chinese in game.lua")
    end)
    
    T.it("should not have hardcoded Chinese in core modules", function()
        local coreFiles = {
            "src/core/engine.lua",
            "src/core/synergy.lua",
            "src/core/difficulty.lua",
            "src/core/shop.lua",
            "src/core/upgrade.lua",
        }
        
        local allIssues = {}
        
        for _, filepath in ipairs(coreFiles) do
            local content = readFile(filepath)
            if content then
                local issues = findChineseStrings(content, filepath)
                for _, issue in ipairs(issues) do
                    table.insert(allIssues, issue)
                end
            end
        end
        
        if #allIssues > 0 then
            print("  Found hardcoded Chinese in core modules:")
            for _, issue in ipairs(allIssues) do
                print(string.format("    %s:%d: %s", issue.file, issue.line, issue.text))
            end
        end
        
        T.assertEqual(#allIssues, 0, "No hardcoded Chinese in core modules")
    end)
    
end)

T.describe("Data File Validation", function()
    
    T.it("should have valid synergy data", function()
        local data = require("data.synergies")
        
        T.assertNotNil(data.categories, "Has categories")
        T.assertNotNil(data.bonuses, "Has bonuses")
        T.assertNotNil(data.combos, "Has combos")
        
        -- Check bonuses use i18n keys
        for category, bonuses in pairs(data.bonuses) do
            for _, bonus in ipairs(bonuses) do
                local nameKey = bonus[3]
                T.assertTrue(nameKey:match("^synergy_"), 
                    "Bonus name is i18n key: " .. tostring(nameKey))
            end
        end
        
        -- Check combos use i18n keys
        for id, combo in pairs(data.combos) do
            T.assertTrue(combo.name_key:match("^combo_"),
                "Combo name is i18n key: " .. tostring(combo.name_key))
        end
    end)
    
    T.it("should have valid event data", function()
        local data = require("data.events")
        
        T.assertTrue(#data > 0, "Has events")
        
        for _, event in ipairs(data) do
            T.assertNotNil(event.id, "Event has id")
            T.assertTrue(event.name_key:match("^event_"),
                "Event name is i18n key: " .. tostring(event.name_key))
            T.assertTrue(event.desc_key:match("^event_"),
                "Event desc is i18n key: " .. tostring(event.desc_key))
        end
    end)
    
end)

return T
