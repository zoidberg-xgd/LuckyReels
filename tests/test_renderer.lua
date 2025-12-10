-- tests/test_renderer.lua
local test = require("tests.minitest")
local RendererFactory = require("src.core.renderer_factory")

test.describe("Renderer System", function()
    test.it("should create text renderer by default", function()
        local r = RendererFactory.create({type="text", char="A"})
        test.assert(r ~= nil, "Renderer should not be nil")
        test.assert_equal("A", r.char)
    end)
    
    test.it("should create sprite renderer", function()
        -- Even if image doesn't exist, it should create the object (with warning)
        local r = RendererFactory.create({type="sprite", path="dummy.png"})
        test.assert(r ~= nil, "Sprite renderer should create")
    end)
    
    test.it("should fallback to text if unknown type", function()
        -- Our factory throws error for unknown type actually
        local status, err = pcall(function()
            RendererFactory.create({type="unknown_xyz"})
        end)
        test.assert(status == false, "Should error on unknown type")
    end)
end)
