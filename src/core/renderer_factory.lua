-- src/core/renderer_factory.lua
local TextRenderer = require("src.core.renderers.text_renderer")
local SpriteRenderer = require("src.core.renderers.sprite_renderer")
-- local Live2DRenderer = require("src.core.renderers.live2d_renderer")

local Factory = {}

function Factory.create(config)
    config = config or {}
    local type = config.type or "text"
    
    if type == "text" then
        return TextRenderer.new(config)
    elseif type == "sprite" then
        return SpriteRenderer.new(config)
    elseif type == "live2d" then
        -- return Live2DRenderer.new(config)
        print("Live2D not implemented yet, fallback to text")
        return TextRenderer.new(config)
    else
        error("Unknown renderer type: " .. tostring(type))
    end
end

return Factory
