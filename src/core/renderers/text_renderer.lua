-- src/core/renderers/text_renderer.lua
local TextRenderer = {}
TextRenderer.__index = TextRenderer

function TextRenderer.new(config)
    local self = setmetatable({}, TextRenderer)
    self.char = config.char or "?"
    self.color = config.color or {1, 1, 1}
    self.font_scale = 1.0
    return self
end

function TextRenderer:update(dt)
    -- Text usually has no animation, but could add bobbing here
end

function TextRenderer:play(anim_name)
    -- No-op for static text
end

function TextRenderer:draw(x, y, w, h)
    love.graphics.setColor(self.color)
    
    -- Font handling should ideally be passed in or global
    -- Assuming _G.Fonts exists for now
    if _G.Fonts and _G.Fonts.big then
        love.graphics.setFont(_G.Fonts.big)
    end
    
    -- Center text
    local font = love.graphics.getFont()
    -- Calculate vertical center offset manually if needed, or use printf
    -- printf centers horizontally easily. Vertically we guess.
    local th = font:getHeight()
    local offset_y = (h - th) / 2
    
    love.graphics.printf(self.char, x, y + offset_y, w, "center")
end

return TextRenderer
