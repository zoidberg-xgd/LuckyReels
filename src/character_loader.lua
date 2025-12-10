-- src/character_loader.lua
-- Universal character loader supporting multiple formats:
-- 1. Spine (.json + .atlas)
-- 2. PNG parts (multiple images)
-- 3. Spritesheet (frame animation)
-- 4. Procedural (code-drawn, current default)

local CharacterLoader = {}

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
    
    -- Apply parameter bindings to parts
    for name, part in pairs(self.parts) do
        for param, binding in pairs(part.bindings) do
            local value = self.parameters[param] or 0
            
            if binding.scaleX then
                part.scaleX = 1 + value * binding.scaleX
            end
            if binding.scaleY then
                part.scaleY = 1 + value * binding.scaleY
            end
            if binding.rotation then
                part.rotation = value * binding.rotation
            end
            if binding.y then
                part.y = (self.partsDef.parts[name].y or 0) + value * binding.y
            end
        end
    end
    
    -- Idle animation
    local breathOffset = math.sin(self.time * 2) * 2
    if self.parts.body then
        self.parts.body.y = (self.partsDef.parts.body.y or 0) + breathOffset
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
    if eventType == "win" or eventType == "big_win" then
        self.expression = "happy"
    elseif eventType == "spin" then
        self.expression = "excited"
    end
end

function PartsCharacter:lookAt(x, y) end

function PartsCharacter:updateFromGameState(gameState)
    if not gameState then return end
    
    local money = gameState.money or 0
    local rent = gameState.rent or 15
    local floor = gameState.floor or 1
    
    -- Map to parameters
    self:setParameter("belly", money / 50)
    self:setParameter("tired", floor / 20)
    self:setParameter("happy", (money / rent) - 1)
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
