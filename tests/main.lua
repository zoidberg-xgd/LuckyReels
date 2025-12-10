-- tests/main.lua
-- This is the entry point when running `love tests/`

-- Setup paths
package.path = package.path .. ";../?.lua;./?.lua"

local minitest = require("tests.minitest")

function love.load()
    love.window.setTitle("LuckClone Test Runner")
    love.window.setMode(800, 600)
    
    -- Load i18n mock or real
    local i18n = require("src.i18n")
    i18n.load("en")
    
    -- Run Tests
    minitest.run()
    
    require("tests.test_grid")
    require("tests.test_symbol")
    require("tests.test_game")
    
    print("Tests Completed.")
end

function love.draw()
    local y = 10
    local passColor = {0, 1, 0}
    local failColor = {1, 0, 0}
    local suiteColor = {0.5, 0.5, 1}
    
    love.graphics.setFont(love.graphics.newFont(14))
    
    love.graphics.print("Test Results:", 10, y)
    y = y + 20
    
    for _, log in ipairs(minitest.results.logs) do
        if log.type == "suite" then
            love.graphics.setColor(suiteColor)
            y = y + 5
        elseif log.type == "pass" then
            love.graphics.setColor(passColor)
        elseif log.type == "fail" then
            love.graphics.setColor(failColor)
        end
        
        love.graphics.print(log.msg, 10, y)
        y = y + 18
        
        if y > 580 then break end -- Simple scroll limit
    end
    
    y = y + 10
    love.graphics.setColor(1, 1, 1)
    local summary = string.format("Passed: %d   Failed: %d", minitest.results.passed, minitest.results.failed)
    love.graphics.print(summary, 10, y)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
