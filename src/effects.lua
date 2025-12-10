-- src/effects.lua
-- Visual and Audio Effects System

local Config = require("src.config")
local Utils = require("src.utils")

local Effects = {}

-- Screen shake state
Effects.shake = {
    intensity = 0,
    duration = 0,
    timer = 0,
    offsetX = 0,
    offsetY = 0
}

-- Particles system
Effects.particles = {}

-- Flash overlay
Effects.flash = {
    alpha = 0,
    color = {1, 1, 1},
    duration = 0,
    timer = 0
}

-- Score popup animations
Effects.popups = {}

-- Glow effects for winning symbols
Effects.glows = {}

-- Flying coins animation
Effects.flyingCoins = {}

-- Symbol interaction animations (lines, consume effects, etc.)
Effects.interactions = {}

-- Sound effects (placeholder - will need actual audio files)
Effects.sounds = {}

-- Target position for coin collection (HUD money position)
-- Coin target will be set from Config.hud
Effects.coinTargetX = 50  -- Default, updated by setCoinTarget or from Config
Effects.coinTargetY = 50

-- Pending coin value to add (for animated counting)
Effects.pendingCoins = 0
Effects.displayedMoney = 0
Effects.moneyCountSpeed = 0

-- Initialize effects system
function Effects.init()
    Effects.particles = {}
    Effects.popups = {}
    Effects.glows = {}
    Effects.flyingCoins = {}
    Effects.interactions = {}
    Effects.shake = {intensity = 0, duration = 0, timer = 0, offsetX = 0, offsetY = 0}
    Effects.flash = {alpha = 0, color = {1, 1, 1}, duration = 0, timer = 0}
    Effects.pendingCoins = 0
    Effects.displayedMoney = 0
    Effects.moneyCountSpeed = 0
    Effects.hudBounce = 0  -- For HUD number bounce effect
    Effects.scoringQueue = {}
    Effects.currentScoring = nil
    
    -- Try to load sounds (gracefully fail if not present)
    Effects.loadSounds()
end

function Effects.loadSounds()
    local Config = require("src.core.config")
    
    -- Load sound effects from Config
    for name, path in pairs(Config.audio.sounds) do
        if love.filesystem.getInfo(path) then
            Effects.sounds[name] = love.audio.newSource(path, "static")
        end
    end
    
    -- Load BGM from Config
    local bgmConfig = Config.audio.bgm
    if love.filesystem.getInfo(bgmConfig.path) then
        Effects.bgm = love.audio.newSource(bgmConfig.path, "stream")
        Effects.bgm:setLooping(bgmConfig.looping)
        Effects.bgm:setVolume(bgmConfig.volume)
    end
end

-- Start BGM
function Effects.playBGM()
    if Effects.bgm and not Effects.bgm:isPlaying() then
        Effects.bgm:play()
    end
end

-- Stop BGM
function Effects.stopBGM()
    if Effects.bgm then
        Effects.bgm:stop()
    end
end

-- Set BGM volume
function Effects.setBGMVolume(vol)
    if Effects.bgm then
        Effects.bgm:setVolume(vol)
    end
end

-- Play a sound effect
function Effects.playSound(name, volume, pitch)
    if Effects.sounds[name] then
        local sound = Effects.sounds[name]:clone()
        sound:setVolume(volume or 1.0)
        if pitch then sound:setPitch(pitch) end
        sound:play()
    end
end

-- Trigger screen shake
function Effects.screenShake(intensity, duration)
    Effects.shake.intensity = intensity
    Effects.shake.duration = duration
    Effects.shake.timer = 0
end

-- Trigger screen flash
function Effects.screenFlash(r, g, b, alpha, duration)
    Effects.flash.color = {r or 1, g or 1, b or 1}
    Effects.flash.alpha = alpha or 0.5
    Effects.flash.duration = duration or 0.1
    Effects.flash.timer = 0
end

-- Add floating score popup
function Effects.addPopup(x, y, text, color, size, delay)
    table.insert(Effects.popups, {
        x = x,
        y = y,
        text = tostring(text),
        color = color or {1, 1, 0.3},
        size = size or 24,
        timer = -(delay or 0),  -- Negative timer for delay
        duration = 1.2,
        velocityY = -80,
        scale = 1.5  -- Start big, shrink to normal
    })
end

-- Add coin burst particles
function Effects.addCoinBurst(x, y, count)
    for i = 1, (count or 10) do
        local angle = math.random() * math.pi * 2
        local speed = 100 + math.random() * 150
        table.insert(Effects.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 50,  -- Upward bias
            gravity = 400,
            size = 4 + math.random() * 4,
            color = {1, 0.8 + math.random() * 0.2, 0.2},
            timer = 0,
            duration = 0.8 + math.random() * 0.4,
            rotation = math.random() * math.pi * 2,
            rotationSpeed = (math.random() - 0.5) * 10
        })
    end
end

-- Add sparkle particles
function Effects.addSparkles(x, y, count, color)
    for i = 1, (count or 5) do
        local angle = math.random() * math.pi * 2
        local speed = 30 + math.random() * 50
        table.insert(Effects.particles, {
            x = x + (math.random() - 0.5) * 40,
            y = y + (math.random() - 0.5) * 40,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            gravity = 0,
            size = 2 + math.random() * 3,
            color = color or {1, 1, 0.5},
            timer = 0,
            duration = 0.4 + math.random() * 0.3,
            type = "sparkle"
        })
    end
end

-- Add glow effect to a position
function Effects.addGlow(x, y, w, h, color, duration)
    table.insert(Effects.glows, {
        x = x, y = y, w = w, h = h,
        color = color or {1, 1, 0.5},
        timer = 0,
        duration = duration or 0.5,
        pulseSpeed = 15
    })
end

-- Balatro-style symbol scoring animation
-- Queues a symbol to "score" with punch effect, value popup, and coins
Effects.scoringQueue = {}
Effects.currentScoring = nil
Effects.scoringTimer = 0

function Effects.queueSymbolScore(x, y, w, h, value, color, delay)
    table.insert(Effects.scoringQueue, {
        x = x, y = y, w = w, h = h,
        value = value,
        color = color or {1, 0.9, 0.3},
        delay = delay or 0,
        phase = "waiting",  -- waiting, punch, hold, coins, done
        timer = 0,
        punchScale = 1,
    })
end

function Effects.updateScoring(dt)
    -- Process delay for queued items
    for i = #Effects.scoringQueue, 1, -1 do
        local item = Effects.scoringQueue[i]
        if item.phase == "waiting" then
            item.delay = item.delay - dt
            if item.delay <= 0 then
                item.phase = "punch"
                item.timer = 0
            end
        end
    end
    
    -- Find next item to score (first one in punch phase)
    if not Effects.currentScoring then
        for i, item in ipairs(Effects.scoringQueue) do
            if item.phase == "punch" then
                Effects.currentScoring = item
                table.remove(Effects.scoringQueue, i)
                break
            end
        end
    end
    
    -- Update current scoring animation
    if Effects.currentScoring then
        local s = Effects.currentScoring
        s.timer = s.timer + dt
        
        if s.phase == "punch" then
            -- Quick punch up (0.08s)
            local t = s.timer / 0.08
            if t < 1 then
                s.punchScale = 1 + 0.3 * math.sin(t * math.pi)
            else
                s.phase = "hold"
                s.timer = 0
                s.punchScale = 1
                -- Show value popup
                Effects.addPopup(s.x + s.w/2 - 10, s.y - 10, "+" .. s.value, s.color, 22, 0)
                -- Play sound
                Effects.playSound("score", 0.5, 1.0 + s.value * 0.02)
            end
        elseif s.phase == "hold" then
            -- Brief hold (0.05s)
            if s.timer > 0.05 then
                s.phase = "coins"
                s.timer = 0
                -- Spawn coins
                local coinCount = math.min(math.max(1, math.floor(s.value)), 3)
                for i = 1, coinCount do
                    Effects.addFlyingCoin(
                        s.x + s.w/2 + (math.random() - 0.5) * 20,
                        s.y + s.h/2 + (math.random() - 0.5) * 20,
                        s.value / coinCount,
                        (i - 1) * 0.03
                    )
                end
            end
        elseif s.phase == "coins" then
            -- Wait for coins (0.15s then done)
            if s.timer > 0.15 then
                s.phase = "done"
                Effects.currentScoring = nil
            end
        end
    end
end

function Effects.drawScoring()
    -- Draw current scoring highlight
    if Effects.currentScoring and Effects.currentScoring.phase ~= "done" then
        local s = Effects.currentScoring
        local scale = s.punchScale or 1
        local cx, cy = s.x + s.w/2, s.y + s.h/2
        local w, h = s.w * scale, s.h * scale
        
        -- Glow behind
        love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.4)
        love.graphics.rectangle("fill", cx - w/2 - 8, cy - h/2 - 8, w + 16, h + 16, 12, 12)
        
        -- Bright border
        love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.9)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", cx - w/2, cy - h/2, w, h, 8, 8)
        love.graphics.setLineWidth(1)
    end
    
    -- Draw queued items that are in punch phase (shouldn't happen but safety)
    for _, item in ipairs(Effects.scoringQueue) do
        if item.phase == "punch" then
            love.graphics.setColor(item.color[1], item.color[2], item.color[3], 0.3)
            love.graphics.rectangle("fill", item.x - 4, item.y - 4, item.w + 8, item.h + 8, 8, 8)
        end
    end
end

function Effects.hasActiveScoring()
    return Effects.currentScoring ~= nil or #Effects.scoringQueue > 0
end

function Effects.clearScoring()
    Effects.scoringQueue = {}
    Effects.currentScoring = nil
end

-- Add flying coin from source to target (HUD) - Balatro style
function Effects.addFlyingCoin(fromX, fromY, value, delay)
    delay = delay or 0
    local targetX = Effects.coinTargetX + 30
    local targetY = Effects.coinTargetY + 10
    
    table.insert(Effects.flyingCoins, {
        startX = fromX,
        startY = fromY,
        x = fromX,
        y = fromY,
        targetX = targetX,
        targetY = targetY,
        value = value or 1,
        timer = -delay,
        duration = 0.25 + math.random() * 0.1,  -- Fast: 0.25-0.35 seconds
        size = 10 + math.random() * 4,
        collected = false,
        -- Bezier curve - quick arc
        ctrlX = fromX + (targetX - fromX) * 0.3 + (math.random() - 0.5) * 40,
        ctrlY = math.min(fromY, targetY) - 40 - math.random() * 30,
        rotation = 0,
        rotationSpeed = 15 + math.random() * 10,
    })
end

-- Spawn multiple coins from a symbol position
function Effects.spawnCoinsFromSymbol(x, y, totalValue, coinCount)
    coinCount = coinCount or math.min(totalValue, 8)  -- Cap at 8 coins
    local valuePerCoin = totalValue / coinCount
    
    for i = 1, coinCount do
        local delay = (i - 1) * 0.05  -- Stagger spawns
        local offsetX = (math.random() - 0.5) * 30
        local offsetY = (math.random() - 0.5) * 30
        Effects.addFlyingCoin(x + offsetX, y + offsetY, valuePerCoin, delay)
    end
end

-- Set the target position for coin collection
function Effects.setCoinTarget(x, y)
    Effects.coinTargetX = x
    Effects.coinTargetY = y
end

-- Initialize displayed money (call when game starts)
function Effects.setDisplayedMoney(amount)
    Effects.displayedMoney = amount
    Effects.pendingCoins = 0
end

-- Sync displayed money with actual money (for instant changes like rent)
function Effects.syncDisplayedMoney(actualMoney)
    -- If actual money is less than displayed (e.g., rent paid), sync immediately
    if actualMoney < Effects.displayedMoney then
        Effects.displayedMoney = actualMoney
        Effects.pendingCoins = 0
    end
    -- Don't auto-sync upward - let coin animations handle that
end

-- Get the displayed money (for UI)
function Effects.getDisplayedMoney()
    return math.floor(Effects.displayedMoney)
end

-- Get HUD bounce scale (for pulsing effect when coins collected)
function Effects.getHudBounce()
    return 1 + (Effects.hudBounce or 0) * 0.3
end

-- Check if coin collection is still in progress
function Effects.isCollecting()
    return #Effects.flyingCoins > 0 or Effects.pendingCoins > 0.5 or #Effects.interactions > 0 or Effects.hasActiveScoring()
end

-- Convert grid position to screen position (uses Config)
function Effects.gridToScreen(r, c)
    return Config.grid.toScreen(r, c)
end

-- Add interaction animation from game's interaction data
function Effects.addInteraction(interaction, delay)
    delay = delay or 0
    local sourceX, sourceY = Effects.gridToScreen(interaction.sourceR, interaction.sourceC)
    local targetX, targetY = Effects.gridToScreen(interaction.targetR, interaction.targetC)
    
    table.insert(Effects.interactions, {
        type = interaction.type,  -- "boost", "consume", "destroy"
        sourceX = sourceX,
        sourceY = sourceY,
        targetX = targetX,
        targetY = targetY,
        sourceR = interaction.sourceR,
        sourceC = interaction.sourceC,
        targetR = interaction.targetR,
        targetC = interaction.targetC,
        value = interaction.value or 0,
        color = interaction.color or {1, 1, 1},
        timer = -delay,
        duration = 0.6,
        phase = "line",  -- "line" -> "effect" -> "done"
        lineProgress = 0,
        effectTimer = 0
    })
end

-- Process all interactions from a spin result
function Effects.processInteractions(interactions)
    local delay = 0.3  -- Initial delay after spin stops
    for i, interaction in ipairs(interactions) do
        Effects.addInteraction(interaction, delay)
        delay = delay + 0.2  -- Stagger each interaction
    end
end

-- Update all effects
function Effects.update(dt)
    -- Update screen shake
    if Effects.shake.timer < Effects.shake.duration then
        Effects.shake.timer = Effects.shake.timer + dt
        local progress = Effects.shake.timer / Effects.shake.duration
        local decay = 1 - progress
        local intensity = Effects.shake.intensity * decay
        Effects.shake.offsetX = (math.random() - 0.5) * 2 * intensity
        Effects.shake.offsetY = (math.random() - 0.5) * 2 * intensity
    else
        Effects.shake.offsetX = 0
        Effects.shake.offsetY = 0
    end
    
    -- Update flash
    if Effects.flash.timer < Effects.flash.duration then
        Effects.flash.timer = Effects.flash.timer + dt
    end
    
    -- Update Balatro-style scoring
    Effects.updateScoring(dt)
    
    -- Update particles
    for i = #Effects.particles, 1, -1 do
        local p = Effects.particles[i]
        p.timer = p.timer + dt
        
        if p.timer >= p.duration then
            table.remove(Effects.particles, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + (p.gravity or 0) * dt
            if p.rotation then
                p.rotation = p.rotation + (p.rotationSpeed or 0) * dt
            end
        end
    end
    
    -- Update popups
    for i = #Effects.popups, 1, -1 do
        local p = Effects.popups[i]
        p.timer = p.timer + dt
        
        if p.timer >= p.duration then
            table.remove(Effects.popups, i)
        else
            p.y = p.y + p.velocityY * dt
            p.velocityY = p.velocityY * 0.95  -- Slow down
            -- Scale animation
            local progress = p.timer / p.duration
            if progress < 0.2 then
                p.scale = 1.5 - (progress / 0.2) * 0.5  -- Shrink from 1.5 to 1.0
            else
                p.scale = 1.0
            end
        end
    end
    
    -- Update glows
    for i = #Effects.glows, 1, -1 do
        local g = Effects.glows[i]
        g.timer = g.timer + dt
        if g.timer >= g.duration then
            table.remove(Effects.glows, i)
        end
    end
    
    -- Update flying coins
    for i = #Effects.flyingCoins, 1, -1 do
        local coin = Effects.flyingCoins[i]
        coin.timer = coin.timer + dt
        
        if coin.timer >= 0 then  -- Only animate after delay
            local progress = math.min(coin.timer / coin.duration, 1)
            -- Ease out quad for smooth deceleration
            local eased = 1 - (1 - progress) * (1 - progress)
            
            -- Quadratic bezier curve for arc motion
            local t = eased
            local mt = 1 - t
            coin.x = mt * mt * coin.startX + 2 * mt * t * coin.ctrlX + t * t * coin.targetX
            coin.y = mt * mt * coin.startY + 2 * mt * t * coin.ctrlY + t * t * coin.targetY
            
            -- Rotation
            coin.rotation = coin.rotation + coin.rotationSpeed * dt
            
            -- Size shrinks as it approaches target
            coin.currentSize = coin.size * (1 - eased * 0.4)
            
            -- Check if reached target
            if progress >= 1 and not coin.collected then
                coin.collected = true
                -- Add value DIRECTLY to displayed money (instant feedback!)
                Effects.displayedMoney = Effects.displayedMoney + coin.value
                -- Trigger HUD bounce effect
                Effects.hudBounce = 0.15
                -- Also add to actual game money via callback
                if Effects.onCoinCollected then
                    Effects.onCoinCollected(coin.value)
                end
                -- Trigger small effects at collection point
                Effects.addSparkles(coin.targetX, coin.targetY, 8, {1, 0.9, 0.3})
                Effects.playSound("coin", 0.5, 0.85 + math.random() * 0.3)
            end
        end
        
        -- Remove collected coins
        if coin.collected then
            table.remove(Effects.flyingCoins, i)
        end
    end
    
    -- Animate money counter (faster)
    if Effects.pendingCoins > 0 then
        local addAmount = math.max(2, Effects.pendingCoins * dt * 15)  -- Much faster counting
        if addAmount > Effects.pendingCoins then
            addAmount = Effects.pendingCoins
        end
        Effects.displayedMoney = Effects.displayedMoney + addAmount
        Effects.pendingCoins = Effects.pendingCoins - addAmount
    end
    
    -- Update HUD bounce (decay quickly)
    if Effects.hudBounce > 0 then
        Effects.hudBounce = Effects.hudBounce - dt * 3
        if Effects.hudBounce < 0 then Effects.hudBounce = 0 end
    end
    
    -- Update interactions
    for i = #Effects.interactions, 1, -1 do
        local inter = Effects.interactions[i]
        inter.timer = inter.timer + dt
        
        if inter.timer >= 0 then
            local lineDuration = 0.2
            local effectDuration = 0.4
            
            if inter.phase == "line" then
                -- Eased line progress for smoother animation
                local t = math.min(inter.timer / lineDuration, 1)
                inter.lineProgress = 1 - math.pow(1 - t, 3)  -- Ease out cubic
                
                if t >= 1 then
                    inter.phase = "effect"
                    inter.effectTimer = 0
                    
                    -- Trigger effect based on type
                    Effects.triggerInteractionEffect(inter)
                end
            elseif inter.phase == "effect" then
                inter.effectTimer = inter.effectTimer + dt
                if inter.effectTimer >= effectDuration then
                    inter.phase = "done"
                end
            end
        end
        
        -- Remove completed interactions
        if inter.phase == "done" then
            table.remove(Effects.interactions, i)
        end
    end
end

-- Trigger visual effect for interaction
function Effects.triggerInteractionEffect(inter)
    local cellSize = Config.grid.cellSize
    
    if inter.type == "consume" then
        -- Consume: target dissolves, particles fly to source
        -- Dissolve particles
        for j = 1, 12 do
            local angle = (j / 12) * math.pi * 2 + math.random() * 0.5
            local speed = 80 + math.random() * 40
            table.insert(Effects.particles, {
                x = inter.targetX,
                y = inter.targetY,
                vx = math.cos(angle) * speed * 0.3 + (inter.sourceX - inter.targetX) * 1.5,
                vy = math.sin(angle) * speed * 0.3 + (inter.sourceY - inter.targetY) * 1.5,
                gravity = 0,
                size = 5 + math.random() * 5,
                color = inter.color,
                timer = 0,
                duration = 0.5,
                type = "absorb",
                targetX = inter.sourceX,
                targetY = inter.sourceY,
            })
        end
        Effects.addPopup(inter.targetX - 15, inter.targetY - 25, "+" .. inter.value, inter.color, 22)
        Effects.screenShake(4, 0.12)
        
    elseif inter.type == "boost" then
        -- Boost: source glows and sparkles
        Effects.addGlow(
            inter.sourceX - cellSize/2 - 8,
            inter.sourceY - cellSize/2 - 8,
            cellSize + 16,
            cellSize + 16,
            inter.color,
            0.6
        )
        -- Ring of sparkles
        for j = 1, 10 do
            local angle = (j / 10) * math.pi * 2
            local dist = cellSize * 0.6
            table.insert(Effects.particles, {
                x = inter.sourceX + math.cos(angle) * dist,
                y = inter.sourceY + math.sin(angle) * dist,
                vx = math.cos(angle) * 20,
                vy = math.sin(angle) * 20,
                gravity = 0,
                size = 4 + math.random() * 3,
                color = {inter.color[1], inter.color[2], inter.color[3]},
                timer = 0,
                duration = 0.4,
                type = "sparkle"
            })
        end
        Effects.addPopup(inter.sourceX - 20, inter.sourceY - 35, "x" .. (inter.value + 1), inter.color, 24)
        
    elseif inter.type == "destroy" then
        -- Destroy: explosion effect
        for j = 1, 16 do
            local angle = (j / 16) * math.pi * 2
            local speed = 100 + math.random() * 60
            table.insert(Effects.particles, {
                x = inter.targetX,
                y = inter.targetY,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                gravity = 200,
                size = 6 + math.random() * 6,
                color = {1, 0.6, 0.2},
                timer = 0,
                duration = 0.6,
                type = "explosion"
            })
        end
        -- Fire particles
        for j = 1, 8 do
            table.insert(Effects.particles, {
                x = inter.targetX + (math.random() - 0.5) * 30,
                y = inter.targetY + (math.random() - 0.5) * 30,
                vx = (math.random() - 0.5) * 40,
                vy = -50 - math.random() * 50,
                gravity = -100,
                size = 8 + math.random() * 8,
                color = {1, 0.3, 0.1},
                timer = 0,
                duration = 0.5,
                type = "fire"
            })
        end
        Effects.addPopup(inter.targetX - 15, inter.targetY - 25, "+" .. inter.value, {1, 0.5, 0.2}, 22)
        Effects.screenShake(8, 0.2)
        Effects.screenFlash(1, 0.6, 0.2, 0.3, 0.15)
        
    elseif inter.type == "synergy" then
        -- Synergy: both symbols connected with energy
        -- Energy particles along the line
        for j = 1, 8 do
            local t = j / 8
            local px = inter.sourceX + (inter.targetX - inter.sourceX) * t
            local py = inter.sourceY + (inter.targetY - inter.sourceY) * t
            table.insert(Effects.particles, {
                x = px + (math.random() - 0.5) * 20,
                y = py + (math.random() - 0.5) * 20,
                vx = (math.random() - 0.5) * 30,
                vy = -20 - math.random() * 20,
                gravity = 0,
                size = 4 + math.random() * 4,
                color = inter.color,
                timer = 0,
                duration = 0.5,
                type = "energy"
            })
        end
        -- Glow on both
        Effects.addGlow(
            inter.sourceX - cellSize/2 - 5,
            inter.sourceY - cellSize/2 - 5,
            cellSize + 10, cellSize + 10,
            inter.color, 0.4
        )
        Effects.addGlow(
            inter.targetX - cellSize/2 - 5,
            inter.targetY - cellSize/2 - 5,
            cellSize + 10, cellSize + 10,
            inter.color, 0.4
        )
        Effects.addPopup(inter.sourceX - 15, inter.sourceY - 30, "+" .. inter.value, inter.color, 20)
        
    elseif inter.type == "transform" then
        -- Transform: magic swirl effect
        for j = 1, 12 do
            local angle = (j / 12) * math.pi * 2
            local dist = 20 + math.random() * 20
            table.insert(Effects.particles, {
                x = inter.targetX + math.cos(angle) * dist,
                y = inter.targetY + math.sin(angle) * dist,
                vx = -math.sin(angle) * 80,
                vy = math.cos(angle) * 80,
                gravity = 0,
                size = 5 + math.random() * 4,
                color = {0.7, 0.3, 1},
                timer = 0,
                duration = 0.5,
                type = "magic",
                spiral = true,
                centerX = inter.targetX,
                centerY = inter.targetY,
            })
        end
        Effects.screenFlash(0.7, 0.3, 1, 0.25, 0.2)
        
    elseif inter.type == "dice_roll" then
        -- Dice roll: bouncing dice particles and number popup
        -- Tumbling dice particles
        for j = 1, 6 do
            local angle = (j / 6) * math.pi * 2
            local speed = 60 + math.random() * 40
            table.insert(Effects.particles, {
                x = inter.targetX,
                y = inter.targetY,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed - 50,
                gravity = 300,
                size = 8 + math.random() * 4,
                color = {1, 1, 1},
                timer = 0,
                duration = 0.6,
                type = "dice",
                rotation = math.random() * math.pi * 2,
                rotationSpeed = (math.random() - 0.5) * 20,
            })
        end
        -- Sparkle burst
        for j = 1, 8 do
            local angle = math.random() * math.pi * 2
            table.insert(Effects.particles, {
                x = inter.targetX + (math.random() - 0.5) * 30,
                y = inter.targetY + (math.random() - 0.5) * 30,
                vx = math.cos(angle) * 30,
                vy = math.sin(angle) * 30 - 20,
                gravity = 0,
                size = 3 + math.random() * 3,
                color = {1, 0.9, 0.3},
                timer = 0,
                duration = 0.4,
                type = "sparkle"
            })
        end
        -- Big number popup
        Effects.addPopup(inter.targetX - 10, inter.targetY - 40, tostring(inter.value), {1, 0.9, 0.2}, 32)
        -- Small shake
        Effects.screenShake(3, 0.1)
        
    elseif inter.type == "jackpot" then
        -- Jackpot: massive celebration effect!
        -- Explosion of golden particles
        for j = 1, 30 do
            local angle = (j / 30) * math.pi * 2
            local speed = 100 + math.random() * 80
            table.insert(Effects.particles, {
                x = inter.targetX,
                y = inter.targetY,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed - 30,
                gravity = 150,
                size = 6 + math.random() * 8,
                color = {1, 0.8, 0.1},
                timer = 0,
                duration = 1.0,
                type = "coin"
            })
        end
        -- Red "7" particles
        for j = 1, 12 do
            local angle = math.random() * math.pi * 2
            local dist = math.random() * 40
            table.insert(Effects.particles, {
                x = inter.targetX + math.cos(angle) * dist,
                y = inter.targetY + math.sin(angle) * dist,
                vx = (math.random() - 0.5) * 60,
                vy = -80 - math.random() * 60,
                gravity = 100,
                size = 10 + math.random() * 6,
                color = {1, 0.2, 0.2},
                timer = 0,
                duration = 0.8,
                type = "seven"
            })
        end
        -- Big glow
        Effects.addGlow(
            inter.targetX - cellSize,
            inter.targetY - cellSize,
            cellSize * 2, cellSize * 2,
            {1, 0.8, 0.2}, 1.0
        )
        -- Huge popup
        Effects.addPopup(inter.targetX - 30, inter.targetY - 50, "JACKPOT!", {1, 0.9, 0.2}, 28)
        Effects.addPopup(inter.targetX - 15, inter.targetY - 20, "x3", {1, 0.3, 0.3}, 36)
        -- Big shake and flash
        Effects.screenShake(12, 0.3)
        Effects.screenFlash(1, 0.9, 0.2, 0.5, 0.25)
    end
end

-- Draw all effects (call after main game draw)
function Effects.draw()
    -- Apply screen shake offset
    love.graphics.push()
    love.graphics.translate(Effects.shake.offsetX, Effects.shake.offsetY)
    
    -- Draw Balatro-style scoring highlights
    Effects.drawScoring()
    
    -- Draw interaction lines and effects
    for _, inter in ipairs(Effects.interactions) do
        if inter.timer >= 0 and inter.phase == "line" then
            local progress = inter.lineProgress
            
            -- Calculate current line end point
            local currentX = inter.sourceX + (inter.targetX - inter.sourceX) * progress
            local currentY = inter.sourceY + (inter.targetY - inter.sourceY) * progress
            
            -- Draw glowing line
            local lineWidth = 4
            local glowWidth = 12
            
            -- Outer glow
            love.graphics.setColor(inter.color[1], inter.color[2], inter.color[3], 0.3)
            love.graphics.setLineWidth(glowWidth)
            love.graphics.line(inter.sourceX, inter.sourceY, currentX, currentY)
            
            -- Inner line
            love.graphics.setColor(inter.color[1], inter.color[2], inter.color[3], 0.9)
            love.graphics.setLineWidth(lineWidth)
            love.graphics.line(inter.sourceX, inter.sourceY, currentX, currentY)
            
            -- Leading particle/dot
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.circle("fill", currentX, currentY, 6)
            love.graphics.setColor(inter.color[1], inter.color[2], inter.color[3], 1)
            love.graphics.circle("fill", currentX, currentY, 4)
            
            love.graphics.setLineWidth(1)
        end
        
        -- Draw effect phase (pulsing highlight on source/target)
        if inter.phase == "effect" then
            local pulse = 1 + math.sin(inter.effectTimer * 20) * 0.3
            local alpha = 1 - (inter.effectTimer / 0.35)
            
            if inter.type == "consume" then
                -- Highlight target being consumed
                love.graphics.setColor(inter.color[1], inter.color[2], inter.color[3], alpha * 0.5)
                local size = Config.grid.cellSize * pulse
                love.graphics.rectangle("fill", 
                    inter.targetX - size/2, inter.targetY - size/2, 
                    size, size, 5, 5)
            end
        end
    end
    
    -- Draw glows (behind everything)
    for _, g in ipairs(Effects.glows) do
        local progress = g.timer / g.duration
        local alpha = (1 - progress) * 0.6
        local pulse = 1 + math.sin(g.timer * g.pulseSpeed) * 0.2
        
        love.graphics.setColor(g.color[1], g.color[2], g.color[3], alpha * 0.3)
        local expand = 10 * pulse
        love.graphics.rectangle("fill", g.x - expand, g.y - expand, 
                                g.w + expand * 2, g.h + expand * 2, 8, 8)
        
        love.graphics.setColor(g.color[1], g.color[2], g.color[3], alpha)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", g.x - 2, g.y - 2, g.w + 4, g.h + 4, 4, 4)
        love.graphics.setLineWidth(1)
    end
    
    -- Draw particles
    for _, p in ipairs(Effects.particles) do
        local progress = p.timer / p.duration
        local alpha = 1 - progress
        
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        
        if p.type == "sparkle" then
            -- Draw star shape
            local size = p.size * (1 - progress * 0.5)
            love.graphics.push()
            love.graphics.translate(p.x, p.y)
            love.graphics.rotate(p.timer * 5)
            love.graphics.rectangle("fill", -size/2, -size/6, size, size/3)
            love.graphics.rectangle("fill", -size/6, -size/2, size/3, size)
            love.graphics.pop()
        else
            -- Draw coin/circle
            love.graphics.push()
            love.graphics.translate(p.x, p.y)
            if p.rotation then
                love.graphics.rotate(p.rotation)
            end
            local size = p.size * (1 - progress * 0.3)
            love.graphics.circle("fill", 0, 0, size)
            -- Inner highlight
            love.graphics.setColor(1, 1, 0.8, alpha * 0.5)
            love.graphics.circle("fill", -size * 0.2, -size * 0.2, size * 0.4)
            love.graphics.pop()
        end
    end
    
    -- Draw popups (only if timer >= 0, supports delay)
    for _, p in ipairs(Effects.popups) do
        if p.timer >= 0 then
            local progress = p.timer / p.duration
            local alpha = 1 - progress
            local scale = p.scale and (p.scale - (p.scale - 1) * progress) or 1
            
            love.graphics.setColor(0, 0, 0, alpha * 0.6)
            love.graphics.setFont(_G.Fonts.normal)
            love.graphics.print(p.text, p.x + 2, p.y + 2)
            
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
            love.graphics.print(p.text, p.x, p.y)
        end
    end
    
    -- Draw flying coins with trail effect
    for _, coin in ipairs(Effects.flyingCoins) do
        if coin.timer >= 0 then
            local size = coin.currentSize or coin.size
            local progress = math.min(coin.timer / coin.duration, 1)
            
            -- Draw trail
            if progress < 0.9 then
                local trailCount = 4
                for i = 1, trailCount do
                    local trailProgress = math.max(0, progress - i * 0.03)
                    if trailProgress > 0 then
                        local t = trailProgress
                        local mt = 1 - t
                        local trailX = mt * mt * coin.startX + 2 * mt * t * coin.ctrlX + t * t * coin.targetX
                        local trailY = mt * mt * coin.startY + 2 * mt * t * coin.ctrlY + t * t * coin.targetY
                        local trailAlpha = (1 - i / trailCount) * 0.4
                        local trailSize = size * (1 - i * 0.15)
                        
                        love.graphics.setColor(1, 0.8, 0.2, trailAlpha)
                        love.graphics.circle("fill", trailX, trailY, trailSize * 0.7)
                    end
                end
            end
            
            love.graphics.push()
            love.graphics.translate(coin.x, coin.y)
            love.graphics.rotate(coin.rotation)
            
            -- Coin glow
            love.graphics.setColor(1, 0.8, 0.2, 0.4)
            love.graphics.circle("fill", 0, 0, size * 1.4)
            
            -- Coin shadow
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.circle("fill", 2, 2, size)
            
            -- Coin body (golden)
            love.graphics.setColor(1, 0.78, 0.15)
            love.graphics.circle("fill", 0, 0, size)
            
            -- Coin edge (darker)
            love.graphics.setColor(0.85, 0.6, 0.05)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", 0, 0, size)
            love.graphics.setLineWidth(1)
            
            -- Coin highlight (top-left)
            love.graphics.setColor(1, 0.95, 0.6)
            love.graphics.circle("fill", -size * 0.3, -size * 0.3, size * 0.35)
            
            -- Coin inner ring
            love.graphics.setColor(0.9, 0.65, 0.1)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", 0, 0, size * 0.65)
            love.graphics.setLineWidth(1)
            
            -- Dollar sign
            love.graphics.setColor(0.75, 0.5, 0)
            love.graphics.setFont(_G.Fonts.small)
            love.graphics.print("$", -4, -8)
            
            love.graphics.pop()
        end
    end
    
    love.graphics.pop()
    
    -- Draw screen flash (on top of everything)
    if Effects.flash.timer < Effects.flash.duration then
        local progress = Effects.flash.timer / Effects.flash.duration
        local alpha = Effects.flash.alpha * (1 - progress * progress)  -- Quadratic fade
        love.graphics.setColor(Effects.flash.color[1], Effects.flash.color[2], Effects.flash.color[3], alpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Get shake offset for external use
function Effects.getShakeOffset()
    return Effects.shake.offsetX, Effects.shake.offsetY
end

-- Check if there are active interactions still playing
function Effects.hasActiveInteractions()
    return #Effects.interactions > 0
end

return Effects
