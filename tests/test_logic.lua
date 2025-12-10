-- tests/test_logic.lua
-- This script simulates the game logic without opening a window
-- Run with: lua tests/test_logic.lua

-- Mock the love table and graphics module since we are running in plain lua
love = {
    graphics = {
        getWidth = function() return 800 end,
        getHeight = function() return 600 end,
        print = function() end,
        printf = function() end,
        rectangle = function() end,
        setColor = function() end,
        getFont = function() 
            return {
                getWidth = function() return 10 end,
                getHeight = function() return 10 end
            } 
        end,
        setFont = function() end,
        setBackgroundColor = function() end,
        newFont = function() end
    },
    window = {
        title = "",
        width = 0,
        height = 0,
    }
}

-- Add the project root to package path so we can require src.*
package.path = package.path .. ";../?.lua;./?.lua"

local Game = require("src.game")
local Symbol = require("src.symbol")
local Grid = require("src.grid")
local i18n = require("src.i18n")
i18n.load("en") -- Use English for testing assertions easier

print("=== Starting Advanced Logic Test ===")

-- 1. Init Game
Game:init()
print("[PASS] Game initialized")

-- 2. Test Spin -> Draft Transition
print("\n--- Testing Draft State Transition ---")
Game:spin()

if Game.state == "DRAFT" then
    print("[PASS] Game entered DRAFT state after spin")
    print("Draft Options generated: " .. #Game.draft_options)
    assert(#Game.draft_options == 3, "Should have 3 draft options")
else
    print("[FAIL] Game did not enter DRAFT state. State: " .. Game.state)
end

-- 3. Test Picking a Draft
print("\n--- Testing Pick Draft ---")
local initial_inv = #Game.inventory
local choice = Game.draft_options[1]
Game:pickDraft(1)

if #Game.inventory == initial_inv + 1 then
    print("[PASS] Inventory increased. Added: " .. choice.name)
else
    print("[FAIL] Inventory size mismatch")
end

assert(Game.state == "IDLE", "Game should return to IDLE after picking")

-- 4. Test Cat & Milk Interaction
print("\n--- Testing Cat & Milk Interaction ---")
-- Manually setup the grid to test specific interaction
-- Row 1, Col 1: Cat
-- Row 1, Col 2: Milk
local testGrid = Grid.new(4, 5)
testGrid.cells[1][1] = Symbol.new("cat")
testGrid.cells[1][2] = Symbol.new("milk")

print("Placed Cat at [1,1] and Milk at [1,2]")

-- Calculate
local total, logs = testGrid:calculateTotalValue()

print("Total Value: " .. total)
-- Expected: Cat Base(1) + Milk Base(1) + Cat Bonus(10) = 12
-- Note: Order matters. If Milk is calculated first, it gives 1. Then Cat drinks it.
-- Or if Cat is calculated first, it drinks Milk. Does Milk still give value?
-- My code logic: 
-- Loop r=1..4, c=1..5
-- [1,1] is Cat. Cat checks neighbors. Finds Milk at [1,2]. Drinks it (Grid:removeSymbol). Returns 1+10.
-- [1,2] is now nil. Loop continues to [1,2], sees nil.
-- Total should be 11.

if total == 11 then
    print("[PASS] Cat drank milk! Total 11 (1 base + 10 bonus)")
else
    print("[FAIL] Unexpected total: " .. total .. ". Expected 11.")
end

if testGrid:getSymbol(1, 2) == nil then
    print("[PASS] Milk was removed from grid")
else
    print("[FAIL] Milk is still there!")
end

print("\n=== All Tests Finished ===")
