-- src/character_loader.lua
-- Universal character loader supporting multiple formats:
-- 1. Spine (.json + .atlas)
-- 2. PNG parts (multiple images)
-- 3. Spritesheet (frame animation)
-- 4. Procedural (code-drawn, current default)

local CharacterLoader = {}
local ModScripting = require("src.core.mod_scripting")

--------------------------------------------------------------------------------
-- Format Detection
--------------------------------------------------------------------------------

CharacterLoader.FORMAT = {
    PROCEDURAL = "procedural",
    SPINE = "spine",
    PARTS = "parts",
    SPRITESHEET = "spritesheet",
}

function CharacterLoader.detectFormat(path)
    if love.filesystem.getInfo(path .. "/skeleton.json") then
        return CharacterLoader.FORMAT.SPINE
    elseif love.filesystem.getInfo(path .. "/parts.lua") then
        return CharacterLoader.FORMAT.PARTS
    elseif love.filesystem.getInfo(path .. "/spritesheet.png") then
        return CharacterLoader.FORMAT.SPRITESHEET
    end
    return CharacterLoader.FORMAT.PROCEDURAL
end

--------------------------------------------------------------------------------
-- Spine Loader
--------------------------------------------------------------------------------

local SpineCharacter = {}
SpineCharacter.__index = SpineCharacter

function SpineCharacter.new(path)
    local self = setmetatable({}, SpineCharacter)
    
    self.path = path
    self.x = 80
    self.y = 500
    self.scale = 0.5
    self.time = 0
    self.parameters = {}
    
    -- Try to load spine-love runtime
    local ok, spine = pcall(require, "lib.spine-love.spine")
    if not ok then
        print("[Spine] spine-love library not found, using fallback")
        self.fallback = true
        return self
    end
    
    self.spine = spine
    
    -- Load skeleton data
    local atlasPath = path .. "/skeleton.atlas"
    local jsonPath = path .. "/skeleton.json"
    
    if love.filesystem.getInfo(atlasPath) and love.filesystem.getInfo(jsonPath) then
        self.atlas = spine.TextureAtlas.new(love.filesystem.read(atlasPath), path)
        local json = spine.SkeletonJson.new(spine.AtlasAttachmentLoader.new(self.atlas))
        self.skeletonData = json:readSkeletonDataFile(jsonPath)
        self.skeleton = spine.Skeleton.new(self.skeletonData)
        self.animationState = spine.AnimationState.new(spine.AnimationStateData.new(self.skeletonData))
        
        -- Play idle animation if exists
        if self.skeletonData:findAnimation("idle") then
            self.animationState:setAnimationByName(0, "idle", true)
        end
        
        print("[Spine] Loaded skeleton from " .. path)
    else
        print("[Spine] Skeleton files not found in " .. path)
        self.fallback = true
    end
    
    return self
end

function SpineCharacter:update(dt)
    self.time = self.time + dt
    
    if self.skeleton and self.animationState then
        self.animationState:update(dt)
        self.animationState:apply(self.skeleton)
        self.skeleton:updateWorldTransform()
    end
end

function SpineCharacter:setParameter(name, value)
    self.parameters[name] = value
    
    -- Apply to skeleton if loaded
    if self.skeleton then
        local bone = self.skeleton:findBone(name)
        if bone then
            bone.scaleX = value
            bone.scaleY = value
        end
    end
end

function SpineCharacter:draw()
    if self.fallback then
        -- Draw placeholder
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.rectangle("fill", self.x - 30, self.y - 80, 60, 100)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Spine\n(no lib)", self.x - 30, self.y - 50, 60, "center")
        return
    end
    
    if self.skeleton then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.scale(self.scale, self.scale)
        self.skeleton:draw()
        love.graphics.pop()
    end
end

function SpineCharacter:react(eventType, data)
    if self.animationState then
        if eventType == "win" or eventType == "big_win" then
            if self.skeletonData:findAnimation("happy") then
                self.animationState:setAnimationByName(0, "happy", false)
                self.animationState:addAnimationByName(0, "idle", true, 0)
            end
        elseif eventType == "spin" then
            if self.skeletonData:findAnimation("excited") then
                self.animationState:setAnimationByName(0, "excited", false)
                self.animationState:addAnimationByName(0, "idle", true, 0)
            end
        end
    end
end

function SpineCharacter:lookAt(x, y) end

function SpineCharacter:updateFromGameState(gameState)
    if not gameState then return end
    
    -- Map game state to Spine parameters
    local money = gameState.money or 0
    local rent = gameState.rent or 15
    local floor = gameState.floor or 1
    
    -- Example: belly grows with money
    self:setParameter("belly", 1 + money / 50)
    
    -- Example: tiredness with floor
    self:setParameter("tired", floor / 20)
end

--------------------------------------------------------------------------------
-- PNG Parts Loader
--------------------------------------------------------------------------------

local PartsCharacter = {}
PartsCharacter.__index = PartsCharacter

function PartsCharacter.new(path)
    local self = setmetatable({}, PartsCharacter)
    
    self.path = path
    self.x = 80
    self.y = 500
    self.scale = 1
    self.time = 0
    self.parts = {}
    self.parameters = {}
    self.expression = "neutral"
    
    -- Load parts definition
    local partsFile = path .. "/parts.lua"
    if love.filesystem.getInfo(partsFile) then
        local ok, partsDef = pcall(love.filesystem.load, partsFile)
        if ok then
            local def = partsDef()
            self:loadParts(def)
        end
    else
        print("[Parts] parts.lua not found in " .. path)
    end
    
    return self
end

function PartsCharacter:loadParts(def)
    self.partsDef = def
    
    for name, partInfo in pairs(def.parts or {}) do
        local imgPath = self.path .. "/" .. partInfo.image
        if love.filesystem.getInfo(imgPath) then
            self.parts[name] = {
                image = love.graphics.newImage(imgPath),
                x = partInfo.x or 0,
                y = partInfo.y or 0,
                ox = partInfo.ox or 0,  -- origin x
                oy = partInfo.oy or 0,  -- origin y
                rotation = partInfo.rotation or 0,
                scaleX = partInfo.scaleX or 1,
                scaleY = partInfo.scaleY or 1,
                z = partInfo.z or 0,  -- draw order
                
                -- Parameter bindings
                bindings = partInfo.bindings or {},
            }
        end
    end
    
    print("[Parts] Loaded " .. self:countParts() .. " parts from " .. self.path)
end

function PartsCharacter:countParts()
    local count = 0
    for _ in pairs(self.parts) do count = count + 1 end
    return count
end

function PartsCharacter:update(dt)
    self.time = self.time + dt
    
    -- Smooth parameter transitions
    self.smoothParams = self.smoothParams or {}
    for param, target in pairs(self.parameters) do
        self.smoothParams[param] = self.smoothParams[param] or target
        self.smoothParams[param] = self.smoothParams[param] + (target - self.smoothParams[param]) * dt * 3
    end
    
    -- Apply parameter bindings to parts
    for name, part in pairs(self.parts) do
        local baseDef = self.partsDef.parts[name] or {}
        
        -- Reset to base values
        part.scaleX = baseDef.scaleX or 1
        part.scaleY = baseDef.scaleY or 1
        part.rotation = baseDef.rotation or 0
        part.x = baseDef.x or 0
        part.y = baseDef.y or 0
        
        -- Apply bindings
        for param, binding in pairs(part.bindings) do
            local value = self.smoothParams[param] or 0
            
            if binding.scaleX then
                part.scaleX = part.scaleX + value * binding.scaleX
            end
            if binding.scaleY then
                part.scaleY = part.scaleY + value * binding.scaleY
            end
            if binding.rotation then
                part.rotation = part.rotation + value * binding.rotation
            end
            if binding.x then
                part.x = part.x + value * binding.x
            end
            if binding.y then
                part.y = part.y + value * binding.y
            end
        end
    end
    
    -- Apply dynamic animations
    self:applyAnimations(dt)
    
    -- Update expression images
    self:updateExpression()
end

--------------------------------------------------------------------------------
-- Dynamic Animations
--------------------------------------------------------------------------------

function PartsCharacter:applyAnimations(dt)
    local t = self.time
    local anims = self.partsDef.animations or {}
    
    -- Helper to get animation config with defaults
    local function getAnim(name, defaults)
        local cfg = anims[name] or {}
        local result = {}
        for k, v in pairs(defaults) do
            result[k] = cfg[k] ~= nil and cfg[k] or v
        end
        return result
    end
    
    -- 1. Breathing animation (身体呼吸)
    local breathing = getAnim("breathing", {enabled = true, speed = 2, amount = 2, scale = 0.01})
    if breathing.enabled then
        local breath = math.sin(t * breathing.speed) * breathing.amount
        if self.parts.body then
            self.parts.body.y = self.parts.body.y + breath
            self.parts.body.scaleY = self.parts.body.scaleY + math.sin(t * breathing.speed) * breathing.scale
        end
        if self.parts.clothes then
            self.parts.clothes.y = self.parts.clothes.y + breath * 0.8
        end
    end
    
    -- 2. Hair sway animation (头发飘动)
    local hairSway = getAnim("hair_sway", {enabled = true, speed = 1.5, amount = 0.03})
    if hairSway.enabled then
        local sway = math.sin(t * hairSway.speed) * hairSway.amount
        local swayFast = math.sin(t * hairSway.speed * 2) * hairSway.amount * 0.3
        if self.parts.front_hair then
            self.parts.front_hair.rotation = sway + swayFast
        end
        if self.parts.back_hair then
            self.parts.back_hair.rotation = sway * 0.5
            self.parts.back_hair.scaleX = 1 + math.sin(t * hairSway.speed * 1.3) * 0.02
        end
    end
    
    -- 3. Idle sway (身体轻微摇摆)
    local idleSway = getAnim("idle_sway", {enabled = true, speed = 0.8, amount = 0.5})
    if idleSway.enabled then
        local sway = math.sin(t * idleSway.speed) * idleSway.amount
        if self.parts.body then
            self.parts.body.x = self.parts.body.x + sway
        end
        if self.parts.head then
            self.parts.head.x = self.parts.head.x + sway * 0.8
            self.parts.head.rotation = self.parts.head.rotation + math.sin(t * idleSway.speed * 0.75) * 0.02
        end
    end
    
    -- 4. Blinking animation (眨眼)
    local blinking = getAnim("blinking", {enabled = true, min_interval = 3, max_interval = 6, speed = 8})
    if blinking.enabled then
        self.blinkTimer = self.blinkTimer or (blinking.min_interval + math.random() * (blinking.max_interval - blinking.min_interval))
        self.blinkTimer = self.blinkTimer - dt
        if self.blinkTimer <= 0 then
            self.isBlinking = true
            self.blinkProgress = 0
            self.blinkTimer = blinking.min_interval + math.random() * (blinking.max_interval - blinking.min_interval)
        end
        
        if self.isBlinking then
            self.blinkProgress = self.blinkProgress + dt * blinking.speed
            if self.blinkProgress >= 1 then
                self.isBlinking = false
            end
            if self.parts.eyes then
                local blinkScale = 1
                if self.blinkProgress < 0.5 then
                    blinkScale = 1 - self.blinkProgress * 2
                else
                    blinkScale = (self.blinkProgress - 0.5) * 2
                end
                self.parts.eyes.scaleY = self.parts.eyes.scaleY * math.max(0.1, blinkScale)
            end
        end
    end
    
    -- 5. Arm idle animation (手臂轻微摆动)
    local armSwing = getAnim("arm_swing", {enabled = true, speed = 1.2, amount = 0.05})
    if armSwing.enabled then
        local swing = math.sin(t * armSwing.speed) * armSwing.amount
        if self.parts.arm_left then
            self.parts.arm_left.rotation = self.parts.arm_left.rotation + swing
        end
        if self.parts.arm_right then
            self.parts.arm_right.rotation = self.parts.arm_right.rotation - swing
        end
    end
    
    -- 6. Expression-based animations
    if self.expression == "happy" then
        local bounce = math.abs(math.sin(t * 4)) * 3
        if self.parts.body then self.parts.body.y = self.parts.body.y - bounce end
        if self.parts.head then self.parts.head.y = self.parts.head.y - bounce * 1.2 end
    elseif self.expression == "worried" then
        local shake = math.sin(t * 8) * 1
        if self.parts.body then self.parts.body.x = self.parts.body.x + shake end
    end
    
    -- 7. Reaction animations (临时动画)
    if self.reactionTimer and self.reactionTimer > 0 then
        self.reactionTimer = self.reactionTimer - dt
        local intensity = self.reactionTimer / self.reactionDuration
        
        if self.reactionType == "jump" then
            local jump = math.sin(self.reactionTimer * 10) * 10 * intensity
            if self.parts.body then self.parts.body.y = self.parts.body.y - jump end
            if self.parts.head then self.parts.head.y = self.parts.head.y - jump end
        elseif self.reactionType == "shake" then
            local shake = math.sin(self.reactionTimer * 20) * 5 * intensity
            if self.parts.body then self.parts.body.x = self.parts.body.x + shake end
        elseif self.reactionType == "nod" then
            local nod = math.sin(self.reactionTimer * 8) * 0.1 * intensity
            if self.parts.head then self.parts.head.rotation = self.parts.head.rotation + nod end
        elseif self.reactionType == "bounce" then
            local bounce = math.abs(math.sin(self.reactionTimer * 15)) * 8 * intensity
            if self.parts.body then self.parts.body.y = self.parts.body.y - bounce end
        elseif self.reactionType == "spin" then
            local spin = self.reactionTimer * 10 * intensity
            if self.parts.body then self.parts.body.rotation = spin end
        end
    end
    
    -- 8. Custom script animations
    self:applyScriptAnimations(dt)
    
    -- 9. Run mod update hooks
    ModScripting.runUpdates(self, dt, self.gameState)
end

-- Apply custom animations registered via ModScripting
function PartsCharacter:applyScriptAnimations(dt)
    local customAnims = self.partsDef.custom_animations or {}
    
    for partName, animList in pairs(customAnims) do
        local part = self.parts[partName]
        if part then
            for _, animDef in ipairs(animList) do
                local animFunc = ModScripting.getAnimation(animDef.name)
                if animFunc then
                    local ok, err = pcall(animFunc, part, self.time, animDef.intensity or 1)
                    if not ok then
                        print("[Character] Animation error: " .. tostring(err))
                    end
                end
            end
        end
    end
end

function PartsCharacter:updateExpression()
    if not self.partsDef.expressions then return end
    
    local exprDef = self.partsDef.expressions[self.expression]
    if not exprDef then return end
    
    -- Swap eye image
    if exprDef.eyes and self.parts.eyes then
        local imgPath = self.path .. "/" .. exprDef.eyes
        if love.filesystem.getInfo(imgPath) and self.parts.eyes.currentImage ~= exprDef.eyes then
            self.parts.eyes.image = love.graphics.newImage(imgPath)
            self.parts.eyes.currentImage = exprDef.eyes
        end
    end
    
    -- Swap mouth image
    if exprDef.mouth and self.parts.mouth then
        local imgPath = self.path .. "/" .. exprDef.mouth
        if love.filesystem.getInfo(imgPath) and self.parts.mouth.currentImage ~= exprDef.mouth then
            self.parts.mouth.image = love.graphics.newImage(imgPath)
            self.parts.mouth.currentImage = exprDef.mouth
        end
    end
end

function PartsCharacter:setParameter(name, value)
    self.parameters[name] = value
end

function PartsCharacter:draw()
    if self:countParts() == 0 then
        -- Draw placeholder
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.rectangle("fill", self.x - 30, self.y - 80, 60, 100)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Parts\n(no files)", self.x - 30, self.y - 50, 60, "center")
        return
    end
    
    -- Sort parts by z-order
    local sortedParts = {}
    for name, part in pairs(self.parts) do
        table.insert(sortedParts, {name = name, part = part})
    end
    table.sort(sortedParts, function(a, b) return a.part.z < b.part.z end)
    
    -- Draw parts
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.scale(self.scale, self.scale)
    
    for _, item in ipairs(sortedParts) do
        local part = item.part
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            part.image,
            part.x, part.y,
            part.rotation,
            part.scaleX, part.scaleY,
            part.ox, part.oy
        )
    end
    
    love.graphics.pop()
end

function PartsCharacter:react(eventType, data)
    -- Trigger script reactions first
    ModScripting.triggerReactions(eventType, self, data)
    
    -- Check for custom reaction config
    local reactions = self.partsDef.reactions or {}
    local reaction = reactions[eventType]
    
    if reaction then
        -- Use config from parts.lua
        if reaction.expression then
            self.expression = reaction.expression
        end
        if reaction.animation then
            self:triggerReaction(reaction.animation, reaction.duration or 0.5)
        end
        -- Run custom script if defined
        if reaction.script then
            local scriptFunc = ModScripting.getAnimation(reaction.script)
            if scriptFunc then
                pcall(scriptFunc, self, data)
            end
        end
    else
        -- Default reactions
        if eventType == "win" then
            self.expression = "happy"
            self:triggerReaction("jump", 0.5)
        elseif eventType == "big_win" then
            self.expression = "happy"
            self:triggerReaction("jump", 1.0)
        elseif eventType == "spin" then
            self:triggerReaction("nod", 0.3)
        elseif eventType == "lose" then
            self.expression = "worried"
            self:triggerReaction("shake", 0.5)
        end
    end
end

function PartsCharacter:triggerReaction(reactionType, duration)
    self.reactionType = reactionType
    self.reactionTimer = duration
    self.reactionDuration = duration
end

function PartsCharacter:lookAt(x, y) end

function PartsCharacter:updateFromGameState(gameState)
    if not gameState then return end
    
    local money = gameState.money or 0
    local rent = gameState.rent or 15
    local floor = gameState.floor or 1
    
    -- Use parameter mapping if defined
    if self.partsDef and self.partsDef.parameter_mapping then
        for paramName, mapping in pairs(self.partsDef.parameter_mapping) do
            local sourceValue = 0
            
            if mapping.source == "money" then
                sourceValue = money
            elseif mapping.source == "floor" then
                sourceValue = floor
            elseif mapping.source == "rent_ratio" then
                sourceValue = money / rent
            end
            
            -- Map value to output range
            local minIn = mapping.min_value or 0
            local maxIn = mapping.max_value or 100
            local minOut = mapping.min_output or 0
            local maxOut = mapping.max_output or 1
            
            local t = (sourceValue - minIn) / (maxIn - minIn)
            t = math.max(0, math.min(1, t))  -- Clamp to 0-1
            local output = minOut + t * (maxOut - minOut)
            
            self:setParameter(paramName, output)
        end
    else
        -- Default mapping
        self:setParameter("belly_size", math.min(1, money / 100))
        self:setParameter("tired", math.min(1, floor / 20))
        self:setParameter("happy", math.max(0, (money / rent) - 1))
    end
    
    -- Update expression based on game state
    local rentRatio = rent > 0 and (money / rent) or 1
    
    if rentRatio < 0.5 then
        self.expression = "worried"
    elseif rentRatio >= 2 then
        self.expression = "happy"
    elseif rentRatio >= 1.2 then
        self.expression = "surprised"  -- Pleasantly surprised
    else
        self.expression = "neutral"
    end
end

--------------------------------------------------------------------------------
-- Spritesheet Loader
--------------------------------------------------------------------------------

local SpritesheetCharacter = {}
SpritesheetCharacter.__index = SpritesheetCharacter

function SpritesheetCharacter.new(path)
    local self = setmetatable({}, SpritesheetCharacter)
    
    self.path = path
    self.x = 80
    self.y = 500
    self.scale = 1
    self.time = 0
    self.currentFrame = 1
    self.frameTime = 0
    self.animations = {}
    self.currentAnimation = "idle"
    self.parameters = {}
    
    -- Load spritesheet
    local imgPath = path .. "/spritesheet.png"
    local defPath = path .. "/spritesheet.lua"
    
    if love.filesystem.getInfo(imgPath) then
        self.image = love.graphics.newImage(imgPath)
        
        -- Load definition
        if love.filesystem.getInfo(defPath) then
            local ok, def = pcall(love.filesystem.load, defPath)
            if ok then
                self:loadDefinition(def())
            end
        else
            -- Default: assume 8 frames horizontal
            self:createDefaultFrames(8, 1)
        end
        
        print("[Spritesheet] Loaded from " .. path)
    else
        print("[Spritesheet] spritesheet.png not found in " .. path)
    end
    
    return self
end

function SpritesheetCharacter:loadDefinition(def)
    self.frameWidth = def.frameWidth or 64
    self.frameHeight = def.frameHeight or 64
    self.animations = def.animations or {}
    self.frameDuration = def.frameDuration or 0.1
    
    -- Create quads
    self.quads = {}
    local cols = self.image:getWidth() / self.frameWidth
    local rows = self.image:getHeight() / self.frameHeight
    
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            table.insert(self.quads, love.graphics.newQuad(
                col * self.frameWidth,
                row * self.frameHeight,
                self.frameWidth,
                self.frameHeight,
                self.image:getDimensions()
            ))
        end
    end
end

function SpritesheetCharacter:createDefaultFrames(cols, rows)
    self.frameWidth = self.image:getWidth() / cols
    self.frameHeight = self.image:getHeight() / rows
    self.frameDuration = 0.1
    self.animations = {
        idle = {1, 2, 3, 4, 5, 6, 7, 8},
    }
    
    self.quads = {}
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            table.insert(self.quads, love.graphics.newQuad(
                col * self.frameWidth,
                row * self.frameHeight,
                self.frameWidth,
                self.frameHeight,
                self.image:getDimensions()
            ))
        end
    end
end

function SpritesheetCharacter:update(dt)
    self.time = self.time + dt
    self.frameTime = self.frameTime + dt
    
    local anim = self.animations[self.currentAnimation]
    if anim and self.frameTime >= self.frameDuration then
        self.frameTime = 0
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #anim then
            self.currentFrame = 1
        end
    end
end

function SpritesheetCharacter:setParameter(name, value)
    self.parameters[name] = value
end

function SpritesheetCharacter:draw()
    if not self.image then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.rectangle("fill", self.x - 30, self.y - 80, 60, 100)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Sprite\n(no file)", self.x - 30, self.y - 50, 60, "center")
        return
    end
    
    local anim = self.animations[self.currentAnimation]
    if anim and self.quads then
        local frameIndex = anim[self.currentFrame] or 1
        local quad = self.quads[frameIndex]
        
        if quad then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(
                self.image, quad,
                self.x, self.y,
                0,
                self.scale, self.scale,
                self.frameWidth / 2, self.frameHeight
            )
        end
    end
end

function SpritesheetCharacter:react(eventType, data)
    if eventType == "win" and self.animations.happy then
        self.currentAnimation = "happy"
        self.currentFrame = 1
    elseif eventType == "spin" and self.animations.spin then
        self.currentAnimation = "spin"
        self.currentFrame = 1
    end
end

function SpritesheetCharacter:lookAt(x, y) end

function SpritesheetCharacter:updateFromGameState(gameState)
    -- Spritesheet doesn't support dynamic parameters
    -- But can switch animations based on state
    if not gameState then return end
    
    local money = gameState.money or 0
    local rent = gameState.rent or 15
    
    if money < rent * 0.5 and self.animations.worried then
        self.currentAnimation = "worried"
    elseif money > rent * 2 and self.animations.happy then
        self.currentAnimation = "happy"
    else
        self.currentAnimation = "idle"
    end
end

--------------------------------------------------------------------------------
-- Main Loader
--------------------------------------------------------------------------------

function CharacterLoader.load(path)
    local format = CharacterLoader.detectFormat(path)
    
    print("[CharacterLoader] Loading " .. path .. " as " .. format)
    
    if format == CharacterLoader.FORMAT.SPINE then
        return SpineCharacter.new(path)
    elseif format == CharacterLoader.FORMAT.PARTS then
        return PartsCharacter.new(path)
    elseif format == CharacterLoader.FORMAT.SPRITESHEET then
        return SpritesheetCharacter.new(path)
    else
        -- Return procedural character
        local Character = require("src.character")
        return Character.getInstance()
    end
end

-- Export classes for direct use
CharacterLoader.SpineCharacter = SpineCharacter
CharacterLoader.PartsCharacter = PartsCharacter
CharacterLoader.SpritesheetCharacter = SpritesheetCharacter

return CharacterLoader
