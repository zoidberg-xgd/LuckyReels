#!/usr/bin/env lua
-- tests/run_all.lua
-- Run all unit tests

-- Set up package path
package.path = package.path .. ";./?.lua"

-- Mock love for headless testing
love = {
    graphics = {
        getWidth = function() return 1024 end,
        getHeight = function() return 768 end,
        setColor = function() end,
        rectangle = function() end,
        circle = function() end,
        print = function() end,
        printf = function() end,
        setFont = function() end,
        setLineWidth = function() end,
        push = function() end,
        pop = function() end,
        translate = function() end,
        scale = function() end,
        rotate = function() end,
        line = function() end,
    },
    audio = {
        newSource = function() return {play = function() end, setVolume = function() end, setPitch = function() end} end,
    },
    filesystem = {
        getInfo = function() return nil end,
    },
    mouse = {
        getPosition = function() return 0, 0 end,
    },
}

-- Mock global fonts
_G.Fonts = {
    small = {},
    normal = {},
    big = {},
}

print("=" .. string.rep("=", 60))
print("  LuckyReels Unit Tests")
print("=" .. string.rep("=", 60))

local T = require("tests.test_runner")

-- Run all test suites
local suites = {
    "tests.test_money_system",
    "tests.test_engine",
    "tests.test_difficulty",
    "tests.test_shop",
    "tests.test_upgrade",
    "tests.test_synergy",
}

for _, suite in ipairs(suites) do
    local success, err = pcall(function()
        require(suite)
    end)
    if not success then
        print("\n!!! Error loading test suite: " .. suite)
        print("    " .. tostring(err))
    end
end

-- Print summary
local allPassed = T.printSummary()

-- Exit with appropriate code
if allPassed then
    print("\n✓ All tests passed!")
    os.exit(0)
else
    print("\n✗ Some tests failed!")
    os.exit(1)
end
