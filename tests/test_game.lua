-- tests/test_game.lua
local test = require("tests.minitest")
-- src.game returns an INSTANCE now, not a class table
local Game = require("src.game")

test.describe("Game Logic", function()
    test.it("should initialize with defaults", function()
        Game:init()
        test.assert_equal(10, Game.money)
        test.assert_equal(25, Game.rent)
        test.assert_equal(5, Game.spins_left)
        test.assert_equal("IDLE", Game.state)
    end)
    
    test.it("should transition to DRAFT after spin", function()
        Game:init()
        Game:spin()
        
        -- After spin, we should be in DRAFT mode because spins_left > 0
        -- Wait, with animation, state is SPINNING first.
        -- spin() -> SPINNING. 
        -- We need to fast forward animation.
        
        test.assert_equal("SPINNING", Game.state, "State should be SPINNING")
        
        -- Simulate animation end
        Game:update(100.0) -- update with huge dt to finish spin
        
        test.assert_equal("DRAFT", Game.state, "State should be DRAFT")
        -- Default config says 3 draft choices
        test.assert_equal(3, #Game.draft_options, "Should have 3 options")
        test.assert_equal(4, Game.spins_left, "Spins should decrement")
    end)
    
    test.it("should add item on draft pick", function()
        Game:init()
        Game:spin() -- SPINNING
        Game:update(100.0) -- DRAFT
        
        local old_inv = #Game.inventory
        local option = Game.draft_options[1]
        
        Game:pickDraft(1)
        
        test.assert_equal(old_inv + 1, #Game.inventory, "Inventory size should increase")
        test.assert_equal("IDLE", Game.state, "Should return to IDLE")
        test.assert_equal(option.key, Game.inventory[#Game.inventory].key, "Should have added selected item")
    end)
    
    test.it("should game over if rent not paid", function()
        Game:init()
        Game.money = 0
        Game.rent = 1000
        Game.spins_left = 1 -- 1 turn left
        
        -- Force a spin that wont give enough money
        -- Hack grid to be empty
        Game.grid.cells = {}
        for r=1,4 do Game.grid.cells[r]={} end
        
        -- Spin (Draft happens first usually, but check logic order)
        -- spin() calls spin grid -> calc -> decrement -> check rent (if spins==0) -> draft
        
        Game:spin() 
        Game:update(100.0)
        
        -- After this spin, spins_left becomes 0.
        -- It checks rent. 0 < 1000. 
        -- State should be GAME_OVER.
        
        test.assert_equal("GAME_OVER", Game.state, "Should be Game Over")
    end)
    
    test.it("should scale rent correctly", function()
        Game:init()
        Game.money = 100
        Game.rent = 25
        Game.spins_left = 1
        
        -- Force pay rent
        -- Mock empty grid so no extra money earned confusion
        Game.grid.cells = {} 
        for r=1,4 do Game.grid.cells[r]={} end
        
        Game:spin()
        Game:update(100.0)
        
        -- spins_left becomes 0 -> pay rent -> spins reset
        test.assert(Game.money < 100, "Should have paid rent")
        test.assert_equal(5, Game.spins_left, "Spins should reset")
        
        -- Rent scaling: 25 * 1.5 + 25 = 37.5 + 25 = 62.5 -> floor(62) or similar
        -- My logic: floor(25 * 1.5 + 25) = floor(37.5 + 25) = floor(62.5) = 62
        test.assert_equal(62, Game.rent, "Rent should scale to 62")
    end)
end)
