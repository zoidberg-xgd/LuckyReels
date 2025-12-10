-- tests/test_relics.lua
local test = require("tests.minitest")
local Engine = require("src.core.engine")
-- Load contents
require("src.content.symbols")
require("src.content.relics")
local Registry = require("src.core.registry")

test.describe("Relic System", function()
    test.it("should trigger hooks on spin", function()
        local e = Engine.new()
        e:init()
        
        -- Create a mock relic manually
        local triggered = false
        local mock_relic = {
            on_spin_start = function() triggered = true end
        }
        table.insert(e.relics, mock_relic)
        
        e:spin()
        
        test.assert(triggered, "Hook on_spin_start should be called")
    end)
    
    test.it("lucky cat should give money", function()
        local e = Engine.new()
        e:init()
        -- Add Lucky Cat
        table.insert(e.relics, Registry.createRelic("lucky_cat"))
        
        -- Record money before
        e.inventory = {} 
        e.money = 0
        
        e:spin()
        -- Fast forward animation
        e:update(100.0)
        
        -- Inventory is empty -> Grid value 0.
        -- Lucky cat -> +1.
        test.assert_equal(1, e.money, "Should get exactly 1 coin from Lucky Cat")
    end)
end)
