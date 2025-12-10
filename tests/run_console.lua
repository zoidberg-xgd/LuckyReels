-- tests/run_console.lua
-- Run with: lua tests/run_console.lua

-- Setup paths to find src modules
-- Assuming we run from project root
package.path = package.path .. ";./?.lua;./src/?.lua"

-- Mock love global if needed by some modules (though our core logic tries to be independent)
love = {
    filesystem = {
        getInfo = function() return nil end
    },
    graphics = {
        newFont = function() return {getWidth=function() return 0 end, getHeight=function() return 0 end} end,
        setFont = function() end,
        setColor = function() end,
        print = function() end,
        printf = function() end,
        rectangle = function() end,
        getWidth = function() return 800 end,
        getHeight = function() return 600 end
    },
    window = {
        title = "",
        width = 0,
        height = 0
    }
}

local minitest = require("tests.minitest")

-- Load i18n
local i18n = require("src.i18n")
i18n.load("en")

print("========================================")
print("   LuckClone Unit Tests (Console)       ")
print("========================================")

-- Run Tests
minitest.run()

-- Require all test files
-- We use pcall to catch errors during loading
require("tests.test_grid")
require("tests.test_symbol")
require("tests.test_game")
require("tests.test_relics") -- New

print("\n----------------------------------------")
print("Results:")
print("Passed: " .. minitest.results.passed)
print("Failed: " .. minitest.results.failed)

for _, log in ipairs(minitest.results.logs) do
    if log.type == "fail" then
        print(log.msg)
    end
end

if minitest.results.failed > 0 then
    os.exit(1)
else
    print("\nALL TESTS PASSED! ✨")
    os.exit(0)
end
