-- src/character.lua
-- Animated pixel art character (Japanese anime style)

local Character = {}
Character.__index = Character

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local CONFIG = {
    -- Position
    baseX = 80,
    baseY = 500,
    
    -- Animation speeds
    breathSpeed = 2,
    blinkInterval = {3, 6},  -- Random blink every 3-6 seconds
    blinkDuration = 0.15,
    idleSwaySpeed = 1.5,
    
    -- Colors (pixel art palette)
    colors = {
        skin = {1, 0.85, 0.75},
        skinShadow = {0.9, 0.7, 0.6},
        hair = {0.2, 0.15, 0.3},       -- Dark purple
        hairHighlight = {0.4, 0.3, 0.5},
        eyes = {0.3, 0.5, 0.9},        -- Blue
        eyeHighlight = {1, 1, 1},
        outfit = {0.9, 0.3, 0.4},      -- Red
        outfitShadow = {0.7, 0.2, 0.3},
        outfitAccent = {1, 0.85, 0.3}, -- Gold
        outline = {0.15, 0.1, 0.2},
    },
    
    -- Expressions
    expressions = {
        neutral = {eyeScale = 1, mouthType = "neutral"},
        happy = {eyeScale = 0.7, mouthType = "smile"},
        excited = {eyeScale = 1.2, mouthType = "open"},
        sad = {eyeScale = 0.8, mouthType = "frown"},
        surprised = {eyeScale = 1.4, mouthType = "o"},
        worried = {eyeScale = 0.9, mouthType = "worried"},
    },
}

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

function Character.new()
    local self = setmetatable({}, Character)
    
    self.x = CONFIG.baseX
    self.y = CONFIG.baseY
    self.scale = 2  -- Pixel art scale
    
    -- Animation state
    self.time = 0
    self.breathOffset = 0
    self.swayOffset = 0
    self.blinkTimer = math.random() * 4 + 2
    self.isBlinking = false
    self.blinkProgress = 0
    
    -- Expression
    self.expression = "neutral"
    self.expressionTimer = 0
    
    -- Look direction (follows mouse or random)
    self.lookX = 0
    self.lookY = 0
    self.targetLookX = 0
    self.targetLookY = 0
    
    -- Bounce effect (for reactions)
    self.bounceY = 0
    self.bounceVel = 0
    
    -- Hair physics
    self.hairSwing = 0
    self.hairVel = 0
    
    -- Game state awareness
    self.mood = "neutral"
    self.gameState = nil
    self.hasLuckyCat = false
    self.hasDiamond = false
    self.energyLevel = 1.0
    
    -- Sweat drop for worried state
    self.sweatDrop = 0
    
    return self
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

function Character:update(dt)
    self.time = self.time + dt
    
    -- Get mood-based animation speed
    local moodMod = self:getMoodModifier()
    
    -- Breathing animation (faster when worried)
    self.breathOffset = math.sin(self.time * CONFIG.breathSpeed * moodMod) * 2
    
    -- Idle sway (more when worried)
    local swayAmount = self.mood == "worried" and 2.5 or 1.5
    self.swayOffset = math.sin(self.time * CONFIG.idleSwaySpeed * moodMod) * swayAmount
    
    -- Sweat drop animation when worried
    if self.mood == "worried" then
        self.sweatDrop = self.sweatDrop + dt * 2
        if self.sweatDrop > 1 then
            self.sweatDrop = 0
        end
    else
        self.sweatDrop = 0
    end
    
    -- Blinking
    self.blinkTimer = self.blinkTimer - dt
    if self.blinkTimer <= 0 and not self.isBlinking then
        self.isBlinking = true
        self.blinkProgress = 0
    end
    
    if self.isBlinking then
        self.blinkProgress = self.blinkProgress + dt / CONFIG.blinkDuration
        if self.blinkProgress >= 1 then
            self.isBlinking = false
            self.blinkTimer = math.random() * (CONFIG.blinkInterval[2] - CONFIG.blinkInterval[1]) + CONFIG.blinkInterval[1]
        end
    end
    
    -- Expression timer
    if self.expressionTimer > 0 then
        self.expressionTimer = self.expressionTimer - dt
        if self.expressionTimer <= 0 then
            self.expression = "neutral"
        end
    end
    
    -- Look direction (smooth follow)
    self.lookX = self.lookX + (self.targetLookX - self.lookX) * dt * 5
    self.lookY = self.lookY + (self.targetLookY - self.lookY) * dt * 5
    
    -- Random look
    if math.random() < dt * 0.3 then
        self.targetLookX = (math.random() - 0.5) * 2
        self.targetLookY = (math.random() - 0.5) * 1
    end
    
    -- Bounce physics
    self.bounceVel = self.bounceVel - self.bounceY * 20 * dt
    self.bounceVel = self.bounceVel * 0.9
    self.bounceY = self.bounceY + self.bounceVel * dt
    
    -- Hair physics
    local targetHairSwing = self.swayOffset * 0.5 + self.bounceVel * 0.1
    self.hairVel = self.hairVel + (targetHairSwing - self.hairSwing) * 30 * dt
    self.hairVel = self.hairVel * 0.85
    self.hairSwing = self.hairSwing + self.hairVel * dt
end

--------------------------------------------------------------------------------
-- Reactions
--------------------------------------------------------------------------------

function Character:react(eventType, data)
    if eventType == "win" or eventType == "coin" then
        self.expression = "happy"
        self.expressionTimer = 2
        self.bounceVel = -150
    elseif eventType == "big_win" then
        self.expression = "excited"
        self.expressionTimer = 3
        self.bounceVel = -200
    elseif eventType == "lose" or eventType == "game_over" then
        self.expression = "sad"
        self.expressionTimer = 2
    elseif eventType == "spin" then
        self.expression = "excited"
        self.expressionTimer = 1
    elseif eventType == "event" then
        self.expression = "surprised"
        self.expressionTimer = 1.5
        self.bounceVel = -100
    elseif eventType == "rent_paid" then
        self.expression = "happy"
        self.expressionTimer = 2
        self.bounceVel = -120
    elseif eventType == "danger" then
        -- When money is low compared to rent
        self.expression = "worried"
        self.expressionTimer = 1
    elseif eventType == "rich" then
        -- When player has lots of money
        self.expression = "excited"
        self.expressionTimer = 2
    end
end

--------------------------------------------------------------------------------
-- Game State Awareness
--------------------------------------------------------------------------------

function Character:updateFromGameState(gameState)
    if not gameState then return end
    
    local money = gameState.money or 0
    local rent = gameState.rent or 15
    local floor = gameState.floor or 1
    local state = gameState.state or "IDLE"
    local inventory = gameState.inventory or {}
    
    -- Store for reference
    self.gameState = gameState
    
    -- React to money situation
    local rentRatio = rent > 0 and (money / rent) or 1
    
    -- Update mood based on financial situation
    local oldMood = self.mood
    if rentRatio < 0.5 then
        -- Worried when money is low
        self.mood = "worried"
        if self.expression == "neutral" then
            self.expression = "worried"
        end
    elseif rentRatio >= 2 then
        -- Happy when rich
        self.mood = "confident"
    else
        self.mood = "neutral"
    end
    
    -- Special items affect appearance
    self.hasLuckyCat = false
    self.hasDiamond = false
    for _, sym in ipairs(inventory) do
        if sym.key == "lucky_cat" then
            self.hasLuckyCat = true
        elseif sym.key == "diamond" then
            self.hasDiamond = true
        end
    end
    
    -- Floor affects energy level
    self.energyLevel = math.max(0.5, 1 - (floor - 1) * 0.05)
end

-- Get mood-based idle animation speed
function Character:getMoodModifier()
    if self.mood == "worried" then
        return 1.5  -- Faster, nervous movement
    elseif self.mood == "confident" then
        return 0.7  -- Slower, relaxed movement
    end
    return 1.0
end

function Character:lookAt(x, y)
    -- Convert screen position to look direction (-1 to 1)
    local dx = x - self.x
    local dy = y - self.y
    self.targetLookX = math.max(-1, math.min(1, dx / 200))
    self.targetLookY = math.max(-1, math.min(1, dy / 150))
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

function Character:draw()
    local s = self.scale
    local x = self.x
    local y = self.y + self.breathOffset + self.bounceY
    local c = CONFIG.colors
    local expr = CONFIG.expressions[self.expression]
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(s, s)
    
    -- Apply sway rotation
    love.graphics.rotate(math.rad(self.swayOffset))
    
    -- Draw order: back hair, body, face, front hair, accessories
    self:drawBackHair(c)
    self:drawBody(c)
    self:drawHead(c)
    self:drawFace(c, expr)
    self:drawFrontHair(c)
    self:drawAccessories(c)
    
    love.graphics.pop()
    
    -- Debug: show mood (can be removed later)
    if _G.DEBUG_CHARACTER then
        love.graphics.setFont(_G.Fonts.small)
        local debugY = self.y + 70
        -- Draw background for readability
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", self.x - 35, debugY - 2, 100, 50, 4, 4)
        -- Draw text
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Mood: " .. (self.mood or "?"), self.x - 30, debugY)
        love.graphics.print("Expr: " .. (self.expression or "?"), self.x - 30, debugY + 15)
        if self.gameState then
            local ratio = self.gameState.rent > 0 and (self.gameState.money / self.gameState.rent) or 0
            love.graphics.print(string.format("Ratio: %.1f", ratio), self.x - 30, debugY + 30)
        end
    end
end

function Character:drawBody(c)
    -- Simple dress/outfit
    local bodyY = 20
    
    -- Outfit body
    love.graphics.setColor(c.outfit)
    love.graphics.rectangle("fill", -12, bodyY, 24, 35)
    
    -- Shadow
    love.graphics.setColor(c.outfitShadow)
    love.graphics.rectangle("fill", -12, bodyY, 8, 35)
    
    -- Collar accent
    love.graphics.setColor(c.outfitAccent)
    love.graphics.rectangle("fill", -8, bodyY, 16, 4)
    
    -- Outline
    love.graphics.setColor(c.outline)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", -12, bodyY, 24, 35)
    
    -- Shoulders
    love.graphics.setColor(c.skin)
    love.graphics.rectangle("fill", -16, bodyY + 2, 6, 10)
    love.graphics.rectangle("fill", 10, bodyY + 2, 6, 10)
end

function Character:drawHead(c)
    -- Face base
    love.graphics.setColor(c.skin)
    love.graphics.rectangle("fill", -14, -20, 28, 28)
    
    -- Cheek shadow
    love.graphics.setColor(c.skinShadow)
    love.graphics.rectangle("fill", -14, -20, 6, 28)
    
    -- Blush (always slightly visible, more when happy)
    local blushAlpha = self.expression == "happy" and 0.5 or 0.2
    love.graphics.setColor(1, 0.5, 0.5, blushAlpha)
    love.graphics.rectangle("fill", -12, 0, 4, 3)
    love.graphics.rectangle("fill", 8, 0, 4, 3)
    
    -- Outline
    love.graphics.setColor(c.outline)
    love.graphics.rectangle("line", -14, -20, 28, 28)
end

function Character:drawFace(c, expr)
    local eyeY = -8 + self.lookY * 2
    local eyeX = self.lookX * 3
    
    -- Eye scale for expression
    local eyeScale = expr.eyeScale or 1
    
    -- Blink effect
    local eyeHeight = 6 * eyeScale
    if self.isBlinking then
        local t = self.blinkProgress
        if t < 0.5 then
            eyeHeight = eyeHeight * (1 - t * 2)
        else
            eyeHeight = eyeHeight * ((t - 0.5) * 2)
        end
    end
    eyeHeight = math.max(1, eyeHeight)
    
    -- Eyes
    local leftEyeX = -8 + eyeX
    local rightEyeX = 4 + eyeX
    
    -- Eye whites
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", leftEyeX, eyeY, 6, eyeHeight)
    love.graphics.rectangle("fill", rightEyeX, eyeY, 6, eyeHeight)
    
    -- Pupils
    if eyeHeight > 2 then
        love.graphics.setColor(c.eyes)
        local pupilY = eyeY + 1 + self.lookY
        love.graphics.rectangle("fill", leftEyeX + 1 + self.lookX, pupilY, 4, eyeHeight - 2)
        love.graphics.rectangle("fill", rightEyeX + 1 + self.lookX, pupilY, 4, eyeHeight - 2)
        
        -- Highlights
        love.graphics.setColor(c.eyeHighlight)
        love.graphics.rectangle("fill", leftEyeX + 1, eyeY + 1, 2, 2)
        love.graphics.rectangle("fill", rightEyeX + 1, eyeY + 1, 2, 2)
    end
    
    -- Eye outlines
    love.graphics.setColor(c.outline)
    love.graphics.rectangle("line", leftEyeX, eyeY, 6, eyeHeight)
    love.graphics.rectangle("line", rightEyeX, eyeY, 6, eyeHeight)
    
    -- Mouth
    local mouthY = 4
    local mouthType = expr.mouthType or "neutral"
    
    love.graphics.setColor(c.outline)
    if mouthType == "neutral" then
        love.graphics.rectangle("fill", -2, mouthY, 4, 1)
    elseif mouthType == "smile" then
        love.graphics.rectangle("fill", -3, mouthY, 6, 1)
        love.graphics.rectangle("fill", -3, mouthY + 1, 1, 1)
        love.graphics.rectangle("fill", 2, mouthY + 1, 1, 1)
    elseif mouthType == "open" then
        love.graphics.setColor(0.3, 0.1, 0.1)
        love.graphics.rectangle("fill", -3, mouthY, 6, 4)
        love.graphics.setColor(c.outline)
        love.graphics.rectangle("line", -3, mouthY, 6, 4)
    elseif mouthType == "frown" then
        love.graphics.rectangle("fill", -3, mouthY + 1, 6, 1)
        love.graphics.rectangle("fill", -3, mouthY, 1, 1)
        love.graphics.rectangle("fill", 2, mouthY, 1, 1)
    elseif mouthType == "o" then
        love.graphics.setColor(0.3, 0.1, 0.1)
        love.graphics.circle("fill", 0, mouthY + 2, 3)
        love.graphics.setColor(c.outline)
        love.graphics.circle("line", 0, mouthY + 2, 3)
    elseif mouthType == "worried" then
        -- Wavy worried mouth
        love.graphics.rectangle("fill", -3, mouthY, 1, 1)
        love.graphics.rectangle("fill", -1, mouthY + 1, 2, 1)
        love.graphics.rectangle("fill", 2, mouthY, 1, 1)
    end
    
    -- Sweat drop when worried
    if self.mood == "worried" and self.sweatDrop > 0 then
        local dropY = -15 + self.sweatDrop * 20
        local dropAlpha = 1 - self.sweatDrop
        love.graphics.setColor(0.6, 0.8, 1, dropAlpha)
        love.graphics.ellipse("fill", 16, dropY, 2, 3)
        love.graphics.setColor(0.8, 0.9, 1, dropAlpha * 0.5)
        love.graphics.rectangle("fill", 15, dropY - 2, 1, 2)
    end
end

function Character:drawBackHair(c)
    local hairSwing = self.hairSwing
    
    -- Back hair (long)
    love.graphics.setColor(c.hair)
    
    -- Main back hair
    love.graphics.push()
    love.graphics.rotate(math.rad(hairSwing * 0.5))
    love.graphics.rectangle("fill", -16, -25, 32, 60)
    love.graphics.pop()
    
    -- Hair strands with physics
    for i = -2, 2 do
        love.graphics.push()
        local strandX = i * 6
        love.graphics.translate(strandX, 20)
        love.graphics.rotate(math.rad(hairSwing * (1 + math.abs(i) * 0.3)))
        love.graphics.rectangle("fill", -3, 0, 6, 25 + math.abs(i) * 3)
        love.graphics.pop()
    end
end

function Character:drawFrontHair(c)
    local hairSwing = self.hairSwing
    
    -- Bangs
    love.graphics.setColor(c.hair)
    love.graphics.rectangle("fill", -16, -28, 32, 15)
    
    -- Highlight
    love.graphics.setColor(c.hairHighlight)
    love.graphics.rectangle("fill", -8, -26, 8, 3)
    
    -- Side hair
    love.graphics.setColor(c.hair)
    love.graphics.push()
    love.graphics.translate(-14, -15)
    love.graphics.rotate(math.rad(-5 + hairSwing * 0.3))
    love.graphics.rectangle("fill", -4, 0, 6, 30)
    love.graphics.pop()
    
    love.graphics.push()
    love.graphics.translate(14, -15)
    love.graphics.rotate(math.rad(5 - hairSwing * 0.3))
    love.graphics.rectangle("fill", -2, 0, 6, 30)
    love.graphics.pop()
    
    -- Ahoge (antenna hair)
    love.graphics.push()
    love.graphics.translate(0, -28)
    love.graphics.rotate(math.rad(math.sin(self.time * 3) * 10 + hairSwing))
    love.graphics.setColor(c.hair)
    love.graphics.polygon("fill", 0, 0, -3, -12, 3, -8)
    love.graphics.setColor(c.hairHighlight)
    love.graphics.line(0, -2, 0, -10)
    love.graphics.pop()
end

function Character:drawAccessories(c)
    -- Hair ribbon/bow
    love.graphics.setColor(c.outfitAccent)
    love.graphics.rectangle("fill", -4, -25, 8, 4)
    
    -- Bow loops
    love.graphics.push()
    love.graphics.translate(-6, -23)
    love.graphics.rotate(math.rad(-20))
    love.graphics.ellipse("fill", 0, 0, 5, 3)
    love.graphics.pop()
    
    love.graphics.push()
    love.graphics.translate(6, -23)
    love.graphics.rotate(math.rad(20))
    love.graphics.ellipse("fill", 0, 0, 5, 3)
    love.graphics.pop()
    
    -- Outline
    love.graphics.setColor(c.outline)
    love.graphics.rectangle("line", -4, -25, 8, 4)
    
    -- Diamond sparkle effect when player has diamond
    if self.hasDiamond then
        local sparkleTime = self.time * 3
        for i = 1, 3 do
            local angle = sparkleTime + i * 2.1
            local dist = 20 + math.sin(sparkleTime * 2 + i) * 5
            local sx = math.cos(angle) * dist
            local sy = math.sin(angle) * dist - 10
            local alpha = 0.5 + math.sin(sparkleTime * 4 + i) * 0.3
            love.graphics.setColor(0.8, 0.9, 1, alpha)
            love.graphics.circle("fill", sx, sy, 2)
        end
    end
    
    -- Lucky cat aura when player has lucky cat
    if self.hasLuckyCat then
        local auraAlpha = 0.2 + math.sin(self.time * 2) * 0.1
        love.graphics.setColor(1, 0.9, 0.3, auraAlpha)
        love.graphics.circle("line", 0, 0, 35 + math.sin(self.time * 3) * 3)
    end
    
    -- Mood indicator (small icon above head)
    if self.mood == "confident" then
        -- Star above head
        love.graphics.setColor(1, 0.9, 0.3, 0.8)
        local starY = -45 + math.sin(self.time * 2) * 2
        love.graphics.circle("fill", 0, starY, 4)
    end
end

--------------------------------------------------------------------------------
-- Singleton instance
--------------------------------------------------------------------------------

local instance = nil

function Character.getInstance()
    if not instance then
        instance = Character.new()
    end
    return instance
end

return Character
