-- mods/custom_character/init.lua
-- Example mod: Custom pixel art character
-- Demonstrates how to add your own animated character

return function(ModAPI)
    
    ModAPI.register({
        id = "custom_character",
        name = "Custom Character Mod",
        version = "1.0.0",
        author = "Modder",
        description = "Adds a custom robot character",
    })
    
    ----------------------------------------------------------------------------
    -- Define Custom Character: Robot
    ----------------------------------------------------------------------------
    
    local Robot = {}
    Robot.__index = Robot
    
    -- Colors
    local COLORS = {
        body = {0.6, 0.6, 0.7},
        bodyDark = {0.4, 0.4, 0.5},
        eye = {0.2, 0.8, 1},
        eyeGlow = {0.4, 0.9, 1},
        accent = {1, 0.5, 0.2},
        outline = {0.2, 0.2, 0.25},
    }
    
    function Robot.new()
        local self = setmetatable({}, Robot)
        
        self.x = 80
        self.y = 520
        self.scale = 2
        
        self.time = 0
        self.expression = "neutral"
        self.expressionTimer = 0
        
        -- Animation
        self.bobOffset = 0
        self.antennaAngle = 0
        self.eyeGlow = 0
        
        -- Look direction
        self.lookX = 0
        self.lookY = 0
        
        return self
    end
    
    function Robot:update(dt)
        self.time = self.time + dt
        
        -- Floating bob animation
        self.bobOffset = math.sin(self.time * 2) * 3
        
        -- Antenna wiggle
        self.antennaAngle = math.sin(self.time * 4) * 0.2
        
        -- Eye glow pulse
        self.eyeGlow = 0.5 + math.sin(self.time * 3) * 0.3
        
        -- Expression timer
        if self.expressionTimer > 0 then
            self.expressionTimer = self.expressionTimer - dt
            if self.expressionTimer <= 0 then
                self.expression = "neutral"
            end
        end
    end
    
    function Robot:react(eventType)
        if eventType == "win" or eventType == "coin" then
            self.expression = "happy"
            self.expressionTimer = 2
        elseif eventType == "big_win" then
            self.expression = "excited"
            self.expressionTimer = 3
        elseif eventType == "spin" then
            self.expression = "alert"
            self.expressionTimer = 1
        end
    end
    
    function Robot:lookAt(x, y)
        local dx = x - self.x
        local dy = y - self.y
        self.lookX = math.max(-1, math.min(1, dx / 200))
        self.lookY = math.max(-1, math.min(1, dy / 150))
    end
    
    function Robot:draw()
        local s = self.scale
        local x = self.x
        local y = self.y + self.bobOffset
        
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.scale(s, s)
        
        -- Antenna
        love.graphics.push()
        love.graphics.rotate(self.antennaAngle)
        love.graphics.setColor(COLORS.bodyDark)
        love.graphics.rectangle("fill", -2, -35, 4, 15)
        love.graphics.setColor(COLORS.accent)
        love.graphics.circle("fill", 0, -38, 5)
        love.graphics.pop()
        
        -- Head
        love.graphics.setColor(COLORS.body)
        love.graphics.rectangle("fill", -18, -25, 36, 30, 4, 4)
        love.graphics.setColor(COLORS.bodyDark)
        love.graphics.rectangle("fill", -18, -25, 10, 30, 4, 4)
        
        -- Eyes
        local eyeY = -12 + self.lookY * 2
        local eyeX = self.lookX * 3
        
        -- Eye sockets
        love.graphics.setColor(0.1, 0.1, 0.15)
        love.graphics.rectangle("fill", -12 + eyeX, eyeY, 10, 8, 2, 2)
        love.graphics.rectangle("fill", 2 + eyeX, eyeY, 10, 8, 2, 2)
        
        -- Eye glow
        local glowColor = COLORS.eyeGlow
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], self.eyeGlow)
        love.graphics.rectangle("fill", -10 + eyeX, eyeY + 2, 6, 4, 1, 1)
        love.graphics.rectangle("fill", 4 + eyeX, eyeY + 2, 6, 4, 1, 1)
        
        -- Expression overlay
        if self.expression == "happy" then
            love.graphics.setColor(COLORS.eye)
            love.graphics.arc("fill", -7 + eyeX, eyeY + 4, 4, 0, math.pi)
            love.graphics.arc("fill", 7 + eyeX, eyeY + 4, 4, 0, math.pi)
        elseif self.expression == "excited" then
            love.graphics.setColor(1, 1, 0.5, 0.5)
            love.graphics.circle("fill", -7 + eyeX, eyeY + 3, 6)
            love.graphics.circle("fill", 7 + eyeX, eyeY + 3, 6)
        end
        
        -- Mouth (LED display)
        love.graphics.setColor(0.1, 0.1, 0.15)
        love.graphics.rectangle("fill", -8, 0, 16, 6, 1, 1)
        
        if self.expression == "happy" or self.expression == "excited" then
            love.graphics.setColor(0.2, 1, 0.4)
            love.graphics.rectangle("fill", -6, 2, 4, 2)
            love.graphics.rectangle("fill", 2, 2, 4, 2)
        else
            love.graphics.setColor(COLORS.eye)
            love.graphics.rectangle("fill", -4, 2, 8, 2)
        end
        
        -- Body
        love.graphics.setColor(COLORS.body)
        love.graphics.rectangle("fill", -14, 8, 28, 25, 3, 3)
        love.graphics.setColor(COLORS.bodyDark)
        love.graphics.rectangle("fill", -14, 8, 8, 25, 3, 3)
        
        -- Chest light
        love.graphics.setColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.5 + self.eyeGlow * 0.5)
        love.graphics.circle("fill", 0, 18, 5)
        
        -- Arms
        love.graphics.setColor(COLORS.bodyDark)
        love.graphics.rectangle("fill", -20, 12, 6, 18, 2, 2)
        love.graphics.rectangle("fill", 14, 12, 6, 18, 2, 2)
        
        -- Outline
        love.graphics.setColor(COLORS.outline)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", -18, -25, 36, 30, 4, 4)
        love.graphics.rectangle("line", -14, 8, 28, 25, 3, 3)
        
        love.graphics.pop()
    end
    
    ----------------------------------------------------------------------------
    -- Register the character
    ----------------------------------------------------------------------------
    
    ModAPI.Character.register({
        id = "robot",
        name = "Robot",
        new = Robot.new,
        update = Robot.update,
        draw = Robot.draw,
        react = Robot.react,
        lookAt = Robot.lookAt,
    })
    
    -- Uncomment to make this the active character:
    -- ModAPI.Character.setActive("robot")
    
    print("Robot character registered! Use ModAPI.Character.setActive('robot') to enable.")
    
end
