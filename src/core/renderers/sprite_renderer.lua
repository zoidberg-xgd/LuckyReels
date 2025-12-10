-- src/core/renderers/sprite_renderer.lua
local SpriteRenderer = {}
SpriteRenderer.__index = SpriteRenderer

-- Cache images to avoid reloading
local image_cache = {}

function SpriteRenderer.new(config)
    local self = setmetatable({}, SpriteRenderer)
    self.path = config.path
    self.color = config.color or {1, 1, 1}
    
    if self.path then
        if not image_cache[self.path] then
            if love.filesystem.getInfo(self.path) then
                image_cache[self.path] = love.graphics.newImage(self.path)
            else
                print("Warning: Image not found: " .. self.path)
            end
        end
        self.image = image_cache[self.path]
    end
    
    return self
end

function SpriteRenderer:update(dt)
    -- Animation logic would go here
end

function SpriteRenderer:play(anim_name)
end

function SpriteRenderer:draw(x, y, w, h)
    love.graphics.setColor(self.color)
    if self.image then
        -- Scale to fit w, h
        local iw, ih = self.image:getDimensions()
        local sx = w / iw
        local sy = h / ih
        -- Keep aspect ratio? usually yes.
        local scale = math.min(sx, sy)
        
        -- Center
        local drawX = x + (w - iw * scale) / 2
        local drawY = y + (h - ih * scale) / 2
        
        love.graphics.draw(self.image, drawX, drawY, 0, scale, scale)
    else
        -- Fallback if image missing
        love.graphics.rectangle("line", x, y, w, h)
        love.graphics.print("IMG?", x, y)
    end
end

return SpriteRenderer
