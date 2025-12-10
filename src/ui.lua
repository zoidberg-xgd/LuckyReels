-- src/ui.lua
local i18n = require("src.i18n")
local Effects = require("src.effects")
local Config = require("src.config")

local UI = {}

-- Animation time tracker
UI.time = 0

-- Button hover states and animations
UI.hoverStates = {}
UI.buttonScales = {}
UI.symbolPulse = {}  -- Per-symbol pulse animation
UI.lastScore = 0
UI.scoreDisplayed = 0
UI.scorePulse = 0

-- Store interactive zones: {id="action_id", x=0, y=0, w=0, h=0}
UI.click_zones = {}

function UI.resetZones()
    UI.click_zones = {}
end

function UI.registerZone(id, x, y, w, h)
    table.insert(UI.click_zones, {id=id, x=x, y=y, w=w, h=h})
end

function UI.getClickedId(mx, my)
    -- Iterate in reverse order so later-registered zones have priority
    for i = #UI.click_zones, 1, -1 do
        local z = UI.click_zones[i]
        if mx >= z.x and mx <= z.x + z.w and my >= z.y and my <= z.y + z.h then
            return z.id
        end
    end
    return nil
end

-- Alias for state machine
UI.getZoneAt = UI.getClickedId

-- Smooth interpolation helper
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Smooth damp (for smooth following)
local function smoothDamp(current, target, velocity, smoothTime, dt)
    local omega = 2 / smoothTime
    local x = omega * dt
    local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
    local change = current - target
    local temp = (velocity + omega * change) * dt
    velocity = (velocity - omega * temp) * exp
    local output = target + (change + temp) * exp
    return output, velocity
end

-- Easing function for bounce effect: c * ((t=t/d-1)*t*((s+1)*t + s) + 1)
local function easeOutBack(t, b, c, d, s)
    s = s or 1.70158
    t = t / d - 1
    return c * (t * t * ((s + 1) * t + s) + 1) + b
end

-- Elastic bounce for slot machine "slam" effect
local function easeOutElastic(t, b, c, d)
    if t == 0 then return b end
    t = t / d
    if t == 1 then return b + c end
    local p = d * 0.3
    local s = p / 4
    return c * math.pow(2, -10 * t) * math.sin((t * d - s) * (2 * math.pi) / p) + c + b
end

-- Ease out cubic for smooth deceleration
local function easeOutCubic(t, b, c, d)
    t = t / d - 1
    return c * (t * t * t + 1) + b
end

-- Ease in quad for acceleration
local function easeInQuad(t, b, c, d)
    t = t / d
    return c * t * t + b
end

function UI.drawGrid(grid, offsetX, offsetY, cellSize, animState)
    local padding = 5
    local reelHeight = grid.rows * (cellSize + padding) - padding
    local gridWidth = grid.cols * (cellSize + padding) - padding
    
    -- Draw grid frame/background
    local frameX = offsetX - 15
    local frameY = offsetY - 15
    local frameW = gridWidth + 30
    local frameH = reelHeight + 30
    
    -- Outer glow
    love.graphics.setColor(0.15, 0.2, 0.35, 0.5)
    love.graphics.rectangle("fill", frameX - 10, frameY - 10, frameW + 20, frameH + 20, 20, 20)
    
    -- Frame shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", frameX + 5, frameY + 5, frameW, frameH, 12, 12)
    
    -- Frame background
    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", frameX, frameY, frameW, frameH, 12, 12)
    
    -- Frame inner border (metallic effect)
    love.graphics.setColor(0.25, 0.25, 0.35)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", frameX, frameY, frameW, frameH, 12, 12)
    love.graphics.setLineWidth(1)
    
    -- Top highlight
    love.graphics.setColor(0.3, 0.3, 0.4, 0.3)
    love.graphics.rectangle("fill", frameX + 5, frameY + 5, frameW - 10, 8, 6, 6)
    
    -- Track which columns just stopped (for effects)
    local justStopped = {}
    
    for c = 1, grid.cols do
        local isSpinning = false
        local isSlamming = false
        local isBouncing = false
        local reelOffsetY = 0
        local shakeX = 0
        local flashAlpha = 0
        local spinPhase = "idle"
        local spinSpeed = 0
        
        if animState and animState.isSpinning then
            local delay = animState.delays[c] or 0
            local timer = animState.timer
            local prevTimer = timer - (1/60)  -- Approximate previous frame
            
            -- Detect when reel just stopped
            if prevTimer < delay and timer >= delay then
                justStopped[c] = true
            end
            
            if timer < delay then
                isSpinning = true
                local spinTime = timer
                local accelDuration = 0.12
                local decelStart = delay - 0.4
                
                if spinTime < accelDuration then
                    spinPhase = "accelerating"
                    spinSpeed = easeInQuad(spinTime, 0, 2200, accelDuration)
                elseif spinTime > decelStart and decelStart > accelDuration then
                    spinPhase = "decelerating"
                    local decelTime = spinTime - decelStart
                    local decelDuration = delay - decelStart
                    spinSpeed = easeOutCubic(decelTime, 2200, -2000, decelDuration)
                else
                    spinPhase = "full_speed"
                    spinSpeed = 2200
                end
            elseif timer < delay + 0.05 then
                isSlamming = true
                local t = timer - delay
                local d = 0.05
                reelOffsetY = easeOutCubic(t, -30, 30, d)
                local shakeIntensity = (1 - t/d) * 6
                shakeX = math.sin(t * 120) * shakeIntensity
                flashAlpha = (1 - t/d) * 0.8
            elseif timer < delay + 0.25 then
                isBouncing = true
                local t = timer - delay - 0.05
                local d = 0.2
                local bounceAmp = 10 * math.pow(0.2, t / d * 3)
                reelOffsetY = math.sin(t * 40) * bounceAmp
            end
        end
        
        -- Trigger effects when reel stops
        if justStopped[c] then
            Effects.screenShake(8, 0.15)
            Effects.playSound("reel_stop", 0.7, 0.9 + c * 0.05)
            -- Add sparkles along the column
            for r = 1, grid.rows do
                local sym = grid.cells[r][c]
                if sym then
                    local cellX = offsetX + (c - 1) * (cellSize + padding)
                    local cellY = offsetY + (r - 1) * (cellSize + padding)
                    Effects.addSparkles(cellX + cellSize/2, cellY + cellSize/2, 3, {1, 1, 0.6})
                end
            end
        end
        
        local reelX = offsetX + (c - 1) * (cellSize + padding) + shakeX
        
        for r = 1, grid.rows do
            local cellX = reelX
            local cellY = offsetY + (r - 1) * (cellSize + padding)
            
            -- Cell background with gradient effect
            if flashAlpha > 0 then
                love.graphics.setColor(1, 1, 0.8, flashAlpha)
                love.graphics.rectangle("fill", cellX - 4, cellY - 4, cellSize + 8, cellSize + 8, 4, 4)
            end
            
            -- Darker cell background
            love.graphics.setColor(0.12, 0.12, 0.2)
            love.graphics.rectangle("fill", cellX, cellY, cellSize, cellSize, 3, 3)
            
            -- Inner shadow effect
            love.graphics.setColor(0.08, 0.08, 0.15)
            love.graphics.rectangle("fill", cellX + 2, cellY + 2, cellSize - 4, cellSize - 4, 2, 2)
            
            love.graphics.setScissor(cellX, cellY, cellSize, cellSize)
            
            if isSpinning then
                local stripCellHeight = cellSize + padding
                local totalStripHeight = stripCellHeight * 10
                local scrollOffset = (animState.timer * spinSpeed + c * 300) % totalStripHeight
                
                local chars = {"🍒", "💎", "7️⃣", "🍀", "⭐", "🎰", "💰", "🔔", "🍋", "🍇"}
                
                if _G.Fonts and _G.Fonts.big then
                    love.graphics.setFont(_G.Fonts.big)
                end
                
                local numToDraw = 3
                local baseIndex = math.floor(scrollOffset / stripCellHeight)
                local fractionalOffset = scrollOffset % stripCellHeight
                
                local blurLayers = spinPhase == "full_speed" and 4 or 2
                
                for blur = 0, blurLayers do
                    local blurOffset = blur * 15
                    local alpha = 1 - blur * 0.25
                    
                    if spinPhase == "full_speed" then
                        local pulse = 0.6 + math.sin(animState.timer * 30 + c * 0.5) * 0.4
                        local hue = (animState.timer * 2 + c * 0.3) % 1
                        love.graphics.setColor(pulse, pulse * 0.7 + 0.3, 0.3, alpha)
                    elseif spinPhase == "decelerating" then
                        love.graphics.setColor(1, 1, 1, alpha)
                    else
                        love.graphics.setColor(0.8, 0.8, 0.8, alpha)
                    end
                    
                    for i = -1, numToDraw do
                        local charIndex = ((baseIndex + i) % #chars) + 1
                        local char = chars[charIndex]
                        local drawY = cellY + (i * stripCellHeight) - fractionalOffset + cellSize/2 - 15 - blurOffset
                        love.graphics.print(char, cellX + cellSize/2 - 15, drawY)
                    end
                end
            else
                local sym = grid.cells[r][c]
                local drawY = cellY + reelOffsetY
                
                if sym and sym.renderer then
                    -- Check if symbol is marked for removal (fading out)
                    local alpha = 1
                    local scale = 1
                    local deathTint = nil
                    local shouldDraw = true
                    if sym._markedForRemoval then
                        -- Progressive fade and shrink effect for dying symbols
                        sym._deathTimer = (sym._deathTimer or 0) + 0.02  -- Faster update
                        local t = math.min(sym._deathTimer / 0.4, 1)  -- 0.4 second fade (faster)
                        alpha = 1 - t  -- Fade to 0% opacity
                        scale = 1 - t * 0.8  -- Shrink to 20%
                        deathTint = {1, 0.2, 0.2, alpha}  -- Red tint
                        -- Don't draw if fully faded
                        if t >= 1 then
                            shouldDraw = false
                        end
                    end
                    
                    if not shouldDraw then
                        -- Skip drawing this symbol entirely
                        goto continue_cell
                    end
                    
                    -- Glow effect for symbols
                    if isSlamming then
                        love.graphics.setColor(1, 1, 0.8, 0.5 * alpha)
                    end
                    
                    -- Apply scale and tint for marked symbols
                    if scale ~= 1 then
                        love.graphics.push()
                        local cx = cellX + cellSize/2
                        local cy = drawY + cellSize/2
                        love.graphics.translate(cx, cy)
                        love.graphics.scale(scale, scale)
                        love.graphics.translate(-cx, -cy)
                    end
                    
                    -- Apply death tint if dying
                    if deathTint then
                        love.graphics.setColor(deathTint)
                    end
                    
                    sym.renderer:draw(cellX, drawY, cellSize, cellSize)
                    
                    if scale ~= 1 then
                        love.graphics.pop()
                    end
                    
                    if not isSlamming and (not isBouncing or math.abs(reelOffsetY) < 2) and not sym._markedForRemoval then
                        -- Value badge (don't show for dying symbols)
                        love.graphics.setColor(0, 0, 0, 0.7)
                        love.graphics.rectangle("fill", cellX + 2, drawY + 2, 20, 16, 3, 3)
                        love.graphics.setColor(1, 1, 0.4)
                        love.graphics.setFont(_G.Fonts.small)
                        love.graphics.print(tostring(sym.base_value), cellX + 5, drawY + 3)
                    end
                end
                ::continue_cell::
            end
            
            love.graphics.setScissor()
            
            -- Cell border with glow
            if isSlamming then
                love.graphics.setLineWidth(4)
                love.graphics.setColor(1, 0.9, 0.5, 0.9)
            else
                love.graphics.setLineWidth(1)
                love.graphics.setColor(0.4, 0.4, 0.5, 0.8)
            end
            love.graphics.rectangle("line", cellX, cellY, cellSize, cellSize, 3, 3)
            love.graphics.setLineWidth(1)
        end
    end
    
    love.graphics.setFont(_G.Fonts.normal)
end

function UI.drawHUD(money, rent, turns, inventoryCount, isSpinning, floor)
    local screenW = love.graphics.getWidth()
    floor = floor or 1
    
    -- HUD Panel with gradient effect
    local hudX, hudY, hudW, hudH = 25, 30, 220, 175
    
    -- Panel shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", hudX + 4, hudY + 4, hudW, hudH, 10, 10)
    
    -- Panel background gradient (simulated)
    love.graphics.setColor(0.12, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", hudX, hudY, hudW, hudH, 10, 10)
    
    -- Panel inner highlight
    love.graphics.setColor(0.2, 0.2, 0.28, 0.5)
    love.graphics.rectangle("fill", hudX + 3, hudY + 3, hudW - 6, 30, 8, 8)
    
    -- Panel border
    love.graphics.setColor(0.35, 0.35, 0.45)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", hudX, hudY, hudW, hudH, 10, 10)
    love.graphics.setLineWidth(1)
    
    love.graphics.setFont(_G.Fonts.normal)
    
    -- Get animated money display
    local displayMoney = Effects.getDisplayedMoney()
    local isPending = Effects.pendingCoins > 0.5
    
    -- Money row with icon
    local rowY = hudY + 12
    local iconX = hudX + 15
    local textX = hudX + 45
    
    -- Get bounce scale from Effects
    local bounceScale = Effects.getHudBounce()
    local coinPulse = isPending and (1 + math.sin(UI.time * 12) * 0.2) or bounceScale
    
    -- Money icon (animated coin with bounce)
    love.graphics.setColor(1 * coinPulse, 0.8 * coinPulse, 0.1)
    love.graphics.circle("fill", iconX + 8, rowY + 10, 10 * coinPulse)
    love.graphics.setColor(1, 0.95, 0.4)
    love.graphics.circle("fill", iconX + 6, rowY + 8, 4)
    love.graphics.setColor(0.8, 0.6, 0)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", iconX + 8, rowY + 10, 10 * coinPulse)
    love.graphics.setLineWidth(1)
    
    -- Money text with bounce effect
    love.graphics.push()
    local textCenterX = textX + 30
    local textCenterY = rowY + 10
    love.graphics.translate(textCenterX, textCenterY)
    love.graphics.scale(bounceScale, bounceScale)
    love.graphics.translate(-textCenterX, -textCenterY)
    
    if bounceScale > 1.01 then
        -- Bright flash when bouncing
        love.graphics.setColor(1, 1, 0.5)
    elseif isPending then
        local pulse = 1 + math.sin(UI.time * 15) * 0.1
        love.graphics.setColor(1 * pulse, 0.9 * pulse, 0.3)
    else
        love.graphics.setColor(1, 0.9, 0.3)
    end
    love.graphics.print(tostring(displayMoney), textX, rowY)
    love.graphics.pop()
    
    -- Pending coins indicator
    if isPending then
        love.graphics.setColor(0.4, 1, 0.4, 0.9)
        love.graphics.setFont(_G.Fonts.small)
        local pendingText = "+" .. math.ceil(Effects.pendingCoins)
        love.graphics.print(pendingText, textX + 60, rowY + 3)
        love.graphics.setFont(_G.Fonts.normal)
    end
    
    -- Rent row
    rowY = rowY + 30
    local rentProgress = math.min(displayMoney / rent, 1)
    
    -- Rent icon (house)
    love.graphics.setColor(1, 0.5, 0.5)
    love.graphics.polygon("fill", iconX + 8, rowY + 2, iconX + 2, rowY + 10, iconX + 14, rowY + 10)
    love.graphics.rectangle("fill", iconX + 4, rowY + 10, 8, 8)
    
    -- Rent text
    love.graphics.setColor(1, 0.6, 0.5)
    love.graphics.print(tostring(rent), textX, rowY)
    
    -- Progress bar
    local barX, barW, barH = textX + 50, 80, 12
    love.graphics.setColor(0.2, 0.15, 0.15)
    love.graphics.rectangle("fill", barX, rowY + 4, barW, barH, 3, 3)
    
    if rentProgress >= 1 then
        love.graphics.setColor(0.3, 0.8, 0.3)
    else
        love.graphics.setColor(0.9, 0.5, 0.2)
    end
    love.graphics.rectangle("fill", barX, rowY + 4, barW * rentProgress, barH, 3, 3)
    love.graphics.setColor(0.5, 0.4, 0.4)
    love.graphics.rectangle("line", barX, rowY + 4, barW, barH, 3, 3)
    
    -- Spins row
    rowY = rowY + 30
    
    -- Spin icons (dots)
    for i = 1, 5 do
        local dotX = iconX + (i - 1) * 8
        if i <= turns then
            love.graphics.setColor(0.4, 1, 0.5)
            love.graphics.circle("fill", dotX + 4, rowY + 10, 5)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.circle("fill", dotX + 4, rowY + 10, 4)
        end
    end
    
    love.graphics.setColor(0.5, 1, 0.6)
    love.graphics.print(turns .. " " .. i18n.t("ui_spins_unit"), textX + 10, rowY)
    
    -- Inventory row
    rowY = rowY + 30
    
    -- Inventory icon (box)
    love.graphics.setColor(0.6, 0.6, 1)
    love.graphics.rectangle("fill", iconX + 2, rowY + 4, 12, 10, 2, 2)
    love.graphics.rectangle("fill", iconX, rowY + 2, 16, 4, 2, 2)
    
    love.graphics.setColor(0.7, 0.7, 1)
    love.graphics.print(inventoryCount .. " " .. i18n.t("ui_symbols_unit"), textX, rowY)
    
    -- Floor row
    rowY = rowY + 30
    love.graphics.setColor(0.9, 0.7, 0.4)
    love.graphics.print(string.format(i18n.t("ui_floor"), floor), textX, rowY)
    
    -- ========== SPIN BUTTON ==========
    local btnW, btnH = 440, 75
    local btnX, btnY = (screenW - btnW) / 2, 540
    
    local mx, my = love.mouse.getPosition()
    local isHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
    
    -- Smooth button scale animation
    UI.buttonScales.spin = UI.buttonScales.spin or 1
    local targetScale = isHovered and 1.03 or (1 + math.sin(UI.time * 3) * 0.015)
    UI.buttonScales.spin = lerp(UI.buttonScales.spin, targetScale, 0.15)
    
    local btnScale = UI.buttonScales.spin
    local scaledW = btnW * btnScale
    local scaledH = btnH * btnScale
    local scaledX = btnX - (scaledW - btnW) / 2
    local scaledY = btnY - (scaledH - btnH) / 2
    
    -- Button outer glow (pulsing)
    if not isSpinning then
        local glowAlpha = 0.25 + math.sin(UI.time * 2.5) * 0.15
        love.graphics.setColor(0.2, 0.9, 0.4, glowAlpha)
        love.graphics.rectangle("fill", scaledX - 8, scaledY - 8, scaledW + 16, scaledH + 16, 18, 18)
        love.graphics.setColor(0.3, 1, 0.5, glowAlpha * 0.5)
        love.graphics.rectangle("fill", scaledX - 4, scaledY - 4, scaledW + 8, scaledH + 8, 15, 15)
    end
    
    -- Button shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", scaledX + 3, scaledY + 3, scaledW, scaledH, 14, 14)
    
    -- Button background
    if isSpinning then
        love.graphics.setColor(0.25, 0.25, 0.25)
    elseif isHovered then
        love.graphics.setColor(0.28, 0.72, 0.35)
    else
        love.graphics.setColor(0.22, 0.58, 0.28)
    end
    love.graphics.rectangle("fill", scaledX, scaledY, scaledW, scaledH, 14, 14)
    
    -- Button top highlight
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.rectangle("fill", scaledX + 5, scaledY + 5, scaledW - 10, scaledH * 0.35, 10, 10)
    
    -- Button border
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setLineWidth(2.5)
    love.graphics.rectangle("line", scaledX, scaledY, scaledW, scaledH, 14, 14)
    love.graphics.setLineWidth(1)
    
    -- Button text
    love.graphics.setFont(_G.Fonts.big)
    local btnText = isSpinning and i18n.t("ui_spinning") or i18n.t("ui_press_spin")
    
    -- Text shadow
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.printf(btnText, scaledX + 2, scaledY + scaledH/2 - 12, scaledW, "center")
    
    -- Text
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(btnText, scaledX, scaledY + scaledH/2 - 14, scaledW, "center")
    
    -- Spinning indicator dots
    if isSpinning then
        local dotCount = 3
        local dotSpacing = 15
        local baseX = scaledX + scaledW/2 - (dotCount - 1) * dotSpacing / 2
        local baseY = scaledY + scaledH/2 + 15
        
        for i = 1, dotCount do
            local phase = (UI.time * 8 + i * 0.5) % 1
            local bounce = math.abs(math.sin(phase * math.pi)) * 8
            love.graphics.setColor(1, 1, 1, 0.7 + phase * 0.3)
            love.graphics.circle("fill", baseX + (i - 1) * dotSpacing, baseY - bounce, 4)
        end
    end
    
    love.graphics.setFont(_G.Fonts.normal)
    UI.registerZone("SPIN", btnX, btnY, btnW, btnH)
end

-- Update UI animations
function UI.update(dt)
    UI.time = UI.time + dt
end

function UI.drawLogs(logs, x, y)
    love.graphics.setFont(_G.Fonts.small)
    love.graphics.setColor(0.8, 0.8, 0.8)
    for i, log in ipairs(logs) do
        love.graphics.print(log, x, y + (i-1) * 18)
    end
    love.graphics.setFont(_G.Fonts.normal)
end

function UI.drawGameOver(money, rent)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    -- Dark overlay with vignette effect
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    -- Red tint for failure
    local isWin = money >= rent
    if not isWin then
        local pulse = 0.1 + math.sin(UI.time * 2) * 0.05
        love.graphics.setColor(0.3, 0, 0, pulse)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end
    
    -- Central panel
    local panelW, panelH = 400, 280
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2 - 30
    
    -- Panel shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX + 8, panelY + 8, panelW, panelH, 15, 15)
    
    -- Panel background
    if isWin then
        love.graphics.setColor(0.1, 0.15, 0.1, 0.95)
    else
        love.graphics.setColor(0.15, 0.1, 0.1, 0.95)
    end
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 15, 15)
    
    -- Panel border
    if isWin then
        love.graphics.setColor(0.3, 0.7, 0.3)
    else
        love.graphics.setColor(0.7, 0.3, 0.3)
    end
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 15, 15)
    love.graphics.setLineWidth(1)
    
    -- Title
    love.graphics.setFont(_G.Fonts.big)
    if isWin then
        love.graphics.setColor(0.4, 1, 0.4)
        love.graphics.printf("恭喜过关!", panelX, panelY + 30, panelW, "center")
    else
        -- Animated shake for game over text
        local shakeX = math.sin(UI.time * 15) * 2
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf(i18n.t("ui_game_over"), panelX + shakeX, panelY + 30, panelW, "center")
    end
    
    -- Stats
    love.graphics.setFont(_G.Fonts.normal)
    local statsY = panelY + 100
    
    love.graphics.setColor(1, 0.85, 0.2)
    love.graphics.printf("金币: " .. money, panelX, statsY, panelW, "center")
    
    love.graphics.setColor(1, 0.5, 0.5)
    love.graphics.printf("房租: " .. rent, panelX, statsY + 35, panelW, "center")
    
    if not isWin then
        love.graphics.setColor(0.8, 0.4, 0.4)
        love.graphics.printf("差额: " .. (rent - money), panelX, statsY + 70, panelW, "center")
    end
    
    -- Restart hint
    local hintY = panelY + panelH - 50
    local hintPulse = 0.6 + math.sin(UI.time * 3) * 0.3
    love.graphics.setColor(1, 1, 1, hintPulse)
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.printf("按 R 重新开始", panelX, hintY, panelW, "center")
    
    love.graphics.setFont(_G.Fonts.normal)
end

-- Draw rent paid summary screen
function UI.drawRentPaid(rentInfo)
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    -- Panel
    local panelW, panelH = 400, 360
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    
    -- Panel shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX + 6, panelY + 6, panelW, panelH, 15, 15)
    
    -- Panel background with gradient effect
    love.graphics.setColor(0.15, 0.2, 0.15, 0.98)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 15, 15)
    
    -- Success highlight at top
    love.graphics.setColor(0.3, 0.6, 0.3, 0.5)
    love.graphics.rectangle("fill", panelX, panelY, panelW, 60, 15, 15)
    love.graphics.rectangle("fill", panelX, panelY + 45, panelW, 15)
    
    -- Panel border
    love.graphics.setColor(0.4, 0.7, 0.4)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 15, 15)
    love.graphics.setLineWidth(1)
    
    -- Title with checkmark and floor
    love.graphics.setFont(_G.Fonts.big)
    love.graphics.setColor(0.4, 1, 0.4)
    if rentInfo.new_floor then
        love.graphics.printf("✓ " .. string.format(i18n.t("ui_floor_complete"), rentInfo.new_floor - 1), panelX, panelY + 15, panelW, "center")
    else
        love.graphics.printf("✓ " .. i18n.t("ui_rent_paid_title"), panelX, panelY + 15, panelW, "center")
    end
    
    -- Rent paid amount
    local contentY = panelY + 80
    love.graphics.setFont(_G.Fonts.normal)
    
    love.graphics.setColor(1, 0.5, 0.5)
    love.graphics.printf(i18n.t("ui_rent_paid_amount"), panelX, contentY, panelW, "center")
    love.graphics.setFont(_G.Fonts.big)
    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.printf("-$" .. rentInfo.paid, panelX, contentY + 25, panelW, "center")
    
    -- Remaining money
    contentY = contentY + 70
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.printf(i18n.t("ui_money_remaining"), panelX, contentY, panelW, "center")
    love.graphics.setFont(_G.Fonts.big)
    love.graphics.setColor(1, 0.85, 0.2)
    love.graphics.printf("$" .. rentInfo.remaining, panelX, contentY + 25, panelW, "center")
    
    -- Next rent info
    contentY = contentY + 75
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(0.7, 0.7, 0.9)
    love.graphics.printf(i18n.t("ui_next_rent"), panelX, contentY, panelW, "center")
    love.graphics.setColor(1, 0.6, 0.6)
    love.graphics.printf("$" .. rentInfo.next_rent .. "  (" .. rentInfo.next_spins .. " " .. i18n.t("ui_spins_unit") .. ")", panelX, contentY + 25, panelW, "center")
    
    -- Continue button
    local btnW, btnH = 200, 50
    local btnX = (screenW - btnW) / 2
    local btnY = panelY + panelH - 70
    
    local mx, my = love.mouse.getPosition()
    local hovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
    
    if hovered then
        love.graphics.setColor(0.3, 0.5, 0.3)
    else
        love.graphics.setColor(0.2, 0.35, 0.2)
    end
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 10, 10)
    love.graphics.setColor(0.5, 0.8, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 10, 10)
    love.graphics.setLineWidth(1)
    
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(i18n.t("ui_continue"), btnX, btnY + 14, btnW, "center")
    
    -- Register button zone
    UI.registerZone("RENT_CONTINUE", btnX, btnY, btnW, btnH)
end

function UI.drawDraft(options, gameState)
    -- Dark overlay - semi-transparent to show grid behind
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    local screenW = love.graphics.getWidth()
    
    -- Top status bar
    local barY = 20
    local barH = 50
    love.graphics.setColor(0.15, 0.15, 0.2, 0.95)
    love.graphics.rectangle("fill", 50, barY, screenW - 100, barH, 8, 8)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", 50, barY, screenW - 100, barH, 8, 8)
    
    -- Display game state info
    if gameState then
        love.graphics.setFont(_G.Fonts.normal)
        local infoY = barY + 12
        
        -- Money
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.print("$ " .. (gameState.money or 0), 80, infoY)
        
        -- Rent due
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.print("租金: " .. (gameState.rent or 0), 200, infoY)
        
        -- Spins left
        love.graphics.setColor(0.5, 1, 0.5)
        love.graphics.print("剩余: " .. (gameState.spins_left or 0) .. " 转", 350, infoY)
        
        -- Inventory count
        love.graphics.setColor(0.7, 0.7, 1)
        love.graphics.print("库存: " .. (gameState.inventory_count or 0), 500, infoY)
        
        -- Progress indicator
        local progress = 0
        if gameState.rent and gameState.rent > 0 then
            progress = math.min((gameState.money or 0) / gameState.rent, 1)
        end
        local progressBarX = 620
        local progressBarW = 150
        local progressBarH = 16
        
        -- Progress bar background
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", progressBarX, infoY + 5, progressBarW, progressBarH, 4, 4)
        
        -- Progress bar fill
        if progress >= 1 then
            love.graphics.setColor(0.3, 0.8, 0.3)
        else
            love.graphics.setColor(0.8, 0.5, 0.2)
        end
        love.graphics.rectangle("fill", progressBarX, infoY + 5, progressBarW * progress, progressBarH, 4, 4)
        
        -- Progress bar border
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle("line", progressBarX, infoY + 5, progressBarW, progressBarH, 4, 4)
        
        -- Progress text
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(_G.Fonts.small)
        local percentText = math.floor(progress * 100) .. "%"
        love.graphics.printf(percentText, progressBarX, infoY + 6, progressBarW, "center")
    end
    
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(_G.Fonts.big)
    love.graphics.printf(i18n.t("ui_choose_symbol"), 0, 90, screenW, "center")
    
    local startX = 180
    local gap = 220
    local y = 160
    local w, h = 180, 260
    
    local mx, my = love.mouse.getPosition()
    
    for i, sym in ipairs(options) do
        local x = startX + (i-1) * gap
        local isHovered = mx >= x and mx <= x + w and my >= y and my <= y + h
        
        -- Card hover effect
        local cardScale = isHovered and 1.03 or 1
        local cardW = w * cardScale
        local cardH = h * cardScale
        local cardX = x - (cardW - w) / 2
        local cardY = y - (cardH - h) / 2
        
        -- Card glow on hover
        if isHovered then
            love.graphics.setColor(0.4, 0.6, 0.8, 0.4)
            love.graphics.rectangle("fill", cardX - 5, cardY - 5, cardW + 10, cardH + 10, 10, 10)
        end
        
        -- Card background
        love.graphics.setColor(0.2, 0.2, 0.3)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 6, 6)
        
        -- Card border (colored by rarity)
        local rColor = {0.5, 0.5, 0.5}
        if sym.rarity == 2 then 
            rColor = {0.3, 0.7, 0.3}
        elseif sym.rarity == 3 then
            rColor = {0.6, 0.3, 0.8}
        end
        love.graphics.setColor(rColor)
        love.graphics.setLineWidth(isHovered and 3 or 2)
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 6, 6)
        love.graphics.setLineWidth(1)
        
        -- Key number
        love.graphics.setFont(_G.Fonts.small)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("["..i.."]", cardX + 8, cardY + 8)
        
        -- Symbol Renderer
        if sym.renderer then
            sym.renderer:draw(cardX + 10, cardY + 40, cardW - 20, 70)
        end
        
        -- Name
        love.graphics.setFont(_G.Fonts.normal)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(sym.name, cardX, cardY + 115, cardW, "center")
        
        -- Desc
        love.graphics.setFont(_G.Fonts.small)
        love.graphics.setColor(0.85, 0.85, 0.85)
        love.graphics.printf(sym.desc, cardX + 10, cardY + 145, cardW - 20, "center")
        
        -- Rarity text
        local rText = "普通"
        if sym.rarity == 2 then 
            rText = "罕见"
        elseif sym.rarity == 3 then
            rText = "稀有"
        end
        love.graphics.setFont(_G.Fonts.small)
        love.graphics.setColor(rColor)
        love.graphics.printf(rText, cardX, cardY + cardH - 28, cardW, "center")
        
        -- Register Card Click Zone
        UI.registerZone("DRAFT_"..i, x, y, w, h)
    end
    
    -- Skip button - positioned below cards
    local skipY = 450
    local skipW = 180
    local skipH = 45
    local skipX = (screenW - skipW) / 2
    local skipHovered = mx >= skipX and mx <= skipX + skipW and my >= skipY and my <= skipY + skipH
    
    -- Skip button background with better visibility
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", skipX - 2, skipY - 2, skipW + 4, skipH + 4, 10, 10)
    
    if skipHovered then
        love.graphics.setColor(0.5, 0.35, 0.35)
    else
        love.graphics.setColor(0.3, 0.22, 0.22)
    end
    love.graphics.rectangle("fill", skipX, skipY, skipW, skipH, 8, 8)
    
    love.graphics.setColor(0.7, 0.5, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", skipX, skipY, skipW, skipH, 8, 8)
    love.graphics.setLineWidth(1)
    
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(i18n.t("ui_skip") .. " [4]", skipX, skipY + 12, skipW, "center")
    
    -- Register Skip Zone - make sure this is registered
    UI.registerZone("SKIP", skipX, skipY, skipW, skipH)
end

function UI.drawRelics(relics)
    if #relics == 0 then return end
    
    local iconSize = 40
    local gap = 10
    local startX = 50
    local startY = love.graphics.getHeight() - 80
    
    local mx, my = love.mouse.getPosition()
    local hoveredRelic = nil
    
    for i, relic in ipairs(relics) do
        local x = startX + (i-1) * (iconSize + gap)
        local y = startY
        
        -- Draw Background
        love.graphics.setColor(0.15, 0.15, 0.2)
        love.graphics.rectangle("fill", x, y, iconSize, iconSize, 6, 6)
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, iconSize, iconSize, 6, 6)
        love.graphics.setLineWidth(1)
        
        -- Draw icon directly
        if relic.renderer then
            relic.renderer:draw(x, y, iconSize, iconSize)
        else
            -- Fallback: draw char directly
            love.graphics.setColor(1, 0.8, 0.2)
            love.graphics.setFont(_G.Fonts.normal)
            love.graphics.printf(relic.name and relic.name:sub(1,1) or "?", x, y + 10, iconSize, "center")
        end
        
        -- Check hover
        if mx >= x and mx <= x + iconSize and my >= y and my <= y + iconSize then
            hoveredRelic = relic
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.rectangle("fill", x, y, iconSize, iconSize, 6, 6)
        end
    end
    
    -- Draw Tooltip if hovered
    if hoveredRelic then
        local tipW = 200
        local tipX = mx + 15
        local tipY = my - 100
        
        -- Clamp to screen
        if tipX + tipW > love.graphics.getWidth() then tipX = mx - tipW - 15 end
        if tipY < 0 then tipY = 10 end
        
        -- Calculate height based on text? Simplified for now.
        local tipH = 100 
        
        -- Tooltip BG
        love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
        love.graphics.rectangle("fill", tipX, tipY, tipW, tipH)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", tipX, tipY, tipW, tipH)
        
        -- Name
        love.graphics.setFont(_G.Fonts.normal)
        -- Use color from renderer if text renderer, else white
        local nameColor = {1, 1, 1}
        if hoveredRelic.renderer and hoveredRelic.renderer.color then
             nameColor = hoveredRelic.renderer.color
        end
        love.graphics.setColor(nameColor)
        love.graphics.printf(hoveredRelic.name, tipX, tipY + 10, tipW, "center")
        
        -- Desc
        love.graphics.setFont(_G.Fonts.small)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(hoveredRelic.desc, tipX + 5, tipY + 40, tipW - 10, "center")
    end
end

function UI.drawConsumables(items)
    if #items == 0 then return end
    
    local iconSize = 40
    local gap = 10
    -- Bottom Right area
    local startX = love.graphics.getWidth() - 50 - (#items * (iconSize + gap))
    local startY = love.graphics.getHeight() - 80 
    
    local mx, my = love.mouse.getPosition()
    local hovered = nil
    
    for i, item in ipairs(items) do
        local x = startX + (i-1) * (iconSize + gap)
        local y = startY
        
        -- Draw Background
        love.graphics.setColor(0.2, 0.15, 0.15)
        love.graphics.rectangle("fill", x, y, iconSize, iconSize, 6, 6)
        love.graphics.setColor(0.8, 0.4, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, iconSize, iconSize, 6, 6)
        love.graphics.setLineWidth(1)
        
        -- Draw icon directly
        if item.renderer then
            item.renderer:draw(x, y, iconSize, iconSize)
        else
            -- Fallback
            love.graphics.setColor(0.8, 0.4, 0.4)
            love.graphics.setFont(_G.Fonts.normal)
            love.graphics.printf(item.name and item.name:sub(1,1) or "?", x, y + 10, iconSize, "center")
        end
        
        -- Register Click
        UI.registerZone("CONSUMABLE_"..i, x, y, iconSize, iconSize)
        
        -- Check hover
        if mx >= x and mx <= x + iconSize and my >= y and my <= y + iconSize then
            hovered = item
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.rectangle("fill", x, y, iconSize, iconSize, 6, 6)
        end
    end
    
    -- Tooltip
    if hovered then
        local tipW = 200
        local tipH = 100
        local tipX = mx - tipW - 15
        local tipY = my - 100
        
        if tipY < 0 then tipY = 10 end
        
        love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
        love.graphics.rectangle("fill", tipX, tipY, tipW, tipH)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", tipX, tipY, tipW, tipH)
        
        love.graphics.setFont(_G.Fonts.normal)
        local nameColor = {1, 1, 1}
        if hovered.renderer and hovered.renderer.color then
             nameColor = hovered.renderer.color
        end
        love.graphics.setColor(nameColor)
        love.graphics.printf(hovered.name, tipX, tipY + 10, tipW, "center")
        
        love.graphics.setFont(_G.Fonts.small)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(hovered.desc, tipX + 5, tipY + 40, tipW - 10, "center")
    end
end

-- Inventory panel state
UI.inventoryOpen = false

-- Draw inventory button and expandable panel
function UI.drawInventoryButton(inventory, x, y)
    if not inventory then return end
    
    local btnW = 80
    local btnH = 35
    local mx, my = love.mouse.getPosition()
    local hovered = mx >= x and mx <= x + btnW and my >= y and my <= y + btnH
    
    -- Button background
    if hovered then
        love.graphics.setColor(0.25, 0.25, 0.35)
    else
        love.graphics.setColor(0.15, 0.15, 0.22)
    end
    love.graphics.rectangle("fill", x, y, btnW, btnH, 6, 6)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", x, y, btnW, btnH, 6, 6)
    
    -- Button text
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(_G.Fonts.small)
    love.graphics.printf("背包(" .. #inventory .. ")", x, y + 10, btnW, "center")
    
    -- Register click zone
    UI.registerZone("INVENTORY_BTN", x, y, btnW, btnH)
    
    -- Draw expanded panel if open (expand to the left since button is on right)
    if UI.inventoryOpen and #inventory > 0 then
        local iconSize = 32
        local gap = 4
        local cols = 5
        local panelPadding = 10
        local rows = math.ceil(#inventory / cols)
        local panelW = cols * (iconSize + gap) - gap + panelPadding * 2
        -- Position panel to the left of the button
        UI.drawInventoryPanel(inventory, x + btnW - panelW, y + btnH + 5)
    end
end

-- Draw the expanded inventory panel
function UI.drawInventoryPanel(inventory, x, y)
    local iconSize = 32
    local gap = 4
    local cols = 5
    local panelPadding = 10
    
    local rows = math.ceil(#inventory / cols)
    local panelW = cols * (iconSize + gap) - gap + panelPadding * 2
    local panelH = rows * (iconSize + gap) - gap + panelPadding * 2
    
    -- Panel background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", x, y, panelW, panelH, 8, 8)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", x, y, panelW, panelH, 8, 8)
    
    local mx, my = love.mouse.getPosition()
    local hoveredSym = nil
    
    local cols = 5
    for i, sym in ipairs(inventory) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local sx = x + panelPadding + col * (iconSize + gap)
        local sy = y + panelPadding + row * (iconSize + gap)
        
        -- Symbol background based on rarity
        local rarityColors = {
            [1] = {0.25, 0.25, 0.3},
            [2] = {0.2, 0.3, 0.4},
            [3] = {0.4, 0.35, 0.2},
        }
        local bgColor = rarityColors[sym.rarity] or rarityColors[1]
        love.graphics.setColor(bgColor)
        love.graphics.rectangle("fill", sx, sy, iconSize, iconSize, 4, 4)
        
        -- Draw symbol
        if sym.renderer then
            sym.renderer:draw(sx, sy, iconSize, iconSize)
        end
        
        -- Level indicator
        if sym.level and sym.level > 1 then
            love.graphics.setColor(1, 0.8, 0.2)
            love.graphics.setFont(_G.Fonts.small)
            love.graphics.print("+" .. (sym.level - 1), sx + 2, sy + 2)
        end
        
        -- Hover check
        if mx >= sx and mx <= sx + iconSize and my >= sy and my <= sy + iconSize then
            hoveredSym = sym
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.rectangle("fill", sx, sy, iconSize, iconSize, 4, 4)
        end
    end
    
    -- Tooltip for hovered symbol (wider for text)
    if hoveredSym then
        local tipW = 180
        local tipH = 90
        local tipX = mx + 15
        local tipY = my
        
        if tipX + tipW > love.graphics.getWidth() then tipX = mx - tipW - 15 end
        if tipY + tipH > love.graphics.getHeight() then tipY = love.graphics.getHeight() - tipH - 5 end
        
        love.graphics.setColor(0.08, 0.08, 0.12, 0.98)
        love.graphics.rectangle("fill", tipX, tipY, tipW, tipH, 6, 6)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("line", tipX, tipY, tipW, tipH, 6, 6)
        
        -- Name (truncate if too long)
        love.graphics.setFont(_G.Fonts.normal)
        local nameColor = hoveredSym.renderer and hoveredSym.renderer.color or {1,1,1}
        love.graphics.setColor(nameColor)
        local name = hoveredSym.name or "???"
        if #name > 10 then name = name:sub(1, 10) .. ".." end
        love.graphics.printf(name, tipX, tipY + 5, tipW, "center")
        
        -- Value
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.setFont(_G.Fonts.small)
        love.graphics.printf("+" .. (hoveredSym.base_value or 1), tipX, tipY + 28, tipW, "center")
        
        -- Desc (with word wrap)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.printf(hoveredSym.desc or "", tipX + 5, tipY + 45, tipW - 10, "center")
    end
end

-- Draw language switch button
function UI.drawLanguageButton()
    local btnW = 60
    local btnH = 28
    local x = love.graphics.getWidth() - btnW - 10
    local y = 10
    
    local mx, my = love.mouse.getPosition()
    local hovered = mx >= x and mx <= x + btnW and my >= y and my <= y + btnH
    
    -- Button background
    if hovered then
        love.graphics.setColor(0.3, 0.3, 0.4)
    else
        love.graphics.setColor(0.2, 0.2, 0.28)
    end
    love.graphics.rectangle("fill", x, y, btnW, btnH, 5, 5)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.rectangle("line", x, y, btnW, btnH, 5, 5)
    
    -- Language name
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(_G.Fonts.small)
    love.graphics.printf(i18n.getCurrentLangName(), x, y + 7, btnW, "center")
    
    -- Register click zone
    UI.registerZone("LANG_BTN", x, y, btnW, btnH)
end

-- Toggle inventory panel
function UI.toggleInventory()
    UI.inventoryOpen = not UI.inventoryOpen
end

function UI.drawRemovalSelect(inventory)
    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.95)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(_G.Fonts.big)
    love.graphics.printf(i18n.t("ui_choose_removal"), 0, 50, love.graphics.getWidth(), "center")
    
    -- Draw inventory grid
    local cols = 8
    local cellSize = 60
    local gap = 10
    local startX = (love.graphics.getWidth() - (cols * (cellSize + gap))) / 2
    local startY = 150
    
    for i, sym in ipairs(inventory) do
        local r = math.ceil(i / cols)
        local c = (i - 1) % cols
        
        local x = startX + c * (cellSize + gap)
        local y = startY + (r - 1) * (cellSize + gap)
        
        -- Bg
        love.graphics.setColor(0.2, 0.2, 0.3)
        love.graphics.rectangle("fill", x, y, cellSize, cellSize)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", x, y, cellSize, cellSize)
        
        -- Symbol Renderer
        if sym.renderer then
            sym.renderer:draw(x, y + 10, cellSize, cellSize - 20)
        end
        
        -- Value
        love.graphics.setColor(1, 1, 0.5)
        love.graphics.setFont(_G.Fonts.small)
        love.graphics.print(sym.base_value, x + 2, y + 2)
        
        UI.registerZone("REMOVE_"..i, x, y, cellSize, cellSize)
    end
    
    -- Cancel Button
    local btnW, btnH = 200, 50
    local btnX, btnY = (love.graphics.getWidth() - btnW)/2, love.graphics.getHeight() - 100
    
    love.graphics.setColor(0.5, 0.2, 0.2)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
    
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.printf(i18n.t("ui_cancel"), btnX, btnY + 15, btnW, "center")
    
    UI.registerZone("CANCEL_REMOVE", btnX, btnY, btnW, btnH)
end

-- Draw Shop Screen
function UI.drawShop(shop, engine)
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    -- Title
    love.graphics.setFont(_G.Fonts.big)
    love.graphics.setColor(1, 0.85, 0.3)
    love.graphics.printf(i18n.t("ui_shop"), 0, 30, screenW, "center")
    
    -- Money display
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.printf("$" .. engine.money, 0, 70, screenW, "center")
    
    -- Symbols section
    local cardW, cardH = 130, 180
    local startX = (screenW - (#shop.symbols * (cardW + 15) - 15)) / 2
    local symbolY = 120
    
    -- Check inventory capacity
    local maxInventory = engine.inventory_max or 20
    local inventoryFull = #engine.inventory >= maxInventory
    
    love.graphics.setFont(_G.Fonts.small)
    if inventoryFull then
        love.graphics.setColor(1, 0.4, 0.4)
        love.graphics.print(i18n.t("ui_symbols_unit") .. " (" .. i18n.t("ui_inventory_full") .. ")", startX, symbolY - 20)
    else
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(i18n.t("ui_symbols_unit"), startX, symbolY - 20)
    end
    
    local mx, my = love.mouse.getPosition()
    
    for i, sym in ipairs(shop.symbols) do
        local x = startX + (i - 1) * (cardW + 15)
        local y = symbolY
        
        if sym.sold then
            -- Sold out
            love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
            love.graphics.rectangle("fill", x, y, cardW, cardH, 8, 8)
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.setFont(_G.Fonts.normal)
            love.graphics.printf(i18n.t("ui_sold"), x, y + cardH/2 - 10, cardW, "center")
        else
            local hovered = mx >= x and mx <= x + cardW and my >= y and my <= y + cardH
            local canAfford = engine.money >= sym.price and not inventoryFull
            
            -- Card background
            if hovered then
                love.graphics.setColor(0.25, 0.25, 0.35)
            else
                love.graphics.setColor(0.18, 0.18, 0.25)
            end
            love.graphics.rectangle("fill", x, y, cardW, cardH, 8, 8)
            
            -- Border by rarity
            local rColor = {0.5, 0.5, 0.5}
            if sym.rarity == 2 then rColor = {0.3, 0.7, 0.3}
            elseif sym.rarity == 3 then rColor = {0.7, 0.4, 0.9} end
            love.graphics.setColor(rColor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, cardW, cardH, 8, 8)
            love.graphics.setLineWidth(1)
            
            -- Symbol
            if sym.renderer then
                sym.renderer:draw(x + 15, y + 15, cardW - 30, 60)
            end
            
            -- Name
            love.graphics.setFont(_G.Fonts.small)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(sym.name, x, y + 80, cardW, "center")
            
            -- Desc
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf(sym.desc, x + 5, y + 100, cardW - 10, "center")
            
            -- Price
            love.graphics.setFont(_G.Fonts.normal)
            if canAfford then
                love.graphics.setColor(0.3, 1, 0.3)
            else
                love.graphics.setColor(1, 0.3, 0.3)
            end
            love.graphics.printf("$" .. sym.price, x, y + cardH - 30, cardW, "center")
            
            UI.registerZone("SHOP_SYM_" .. i, x, y, cardW, cardH)
        end
    end
    
    -- Relics section
    if #shop.relics > 0 then
        local relicY = symbolY + cardH + 30
        love.graphics.setFont(_G.Fonts.small)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(i18n.t("ui_relics"), startX, relicY - 20)
        
        for i, relic in ipairs(shop.relics) do
            local x = startX + (i - 1) * (cardW + 15)
            local y = relicY
            local smallH = 140
            
            if relic.sold then
                love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
                love.graphics.rectangle("fill", x, y, cardW, smallH, 8, 8)
            else
                local hovered = mx >= x and mx <= x + cardW and my >= y and my <= y + smallH
                local canAfford = engine.money >= relic.price
                
                love.graphics.setColor(hovered and 0.3 or 0.2, 0.25, 0.15)
                love.graphics.rectangle("fill", x, y, cardW, smallH, 8, 8)
                love.graphics.setColor(1, 0.8, 0.3)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", x, y, cardW, smallH, 8, 8)
                love.graphics.setLineWidth(1)
                
                if relic.renderer then
                    relic.renderer:draw(x + 35, y + 8, 60, 35)
                end
                
                love.graphics.setFont(_G.Fonts.small)
                love.graphics.setColor(1, 0.9, 0.5)
                love.graphics.printf(relic.name, x, y + 48, cardW, "center")
                
                -- Use full description (let printf handle wrapping)
                local desc = relic.desc or ""
                love.graphics.setColor(0.8, 0.8, 0.7)
                love.graphics.printf(desc, x + 5, y + 65, cardW - 10, "center")
                
                love.graphics.setFont(_G.Fonts.normal)
                love.graphics.setColor(canAfford and {0.3, 1, 0.3} or {1, 0.3, 0.3})
                love.graphics.printf("$" .. relic.price, x, y + smallH - 28, cardW, "center")
                
                UI.registerZone("SHOP_RELIC_" .. i, x, y, cardW, smallH)
            end
        end
    end
    
    -- Inventory section (above buttons, below shop cards)
    local Upgrade = require("src.core.upgrade")
    local Config = require("src.core.config")
    local invY = screenH + Config.layout.shop.inventoryY  -- From bottom
    local invCellSize = Config.layout.shop.inventoryCellSize
    local invCellGap = Config.layout.shop.inventoryCellGap
    local invStartX = 50
    
    love.graphics.setFont(_G.Fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.print(i18n.t("ui_your_symbols") .. " (" .. #engine.inventory .. ")", invStartX, invY - 18)
    
    -- Draw inventory symbols
    local maxVisible = math.floor((screenW - 100) / (invCellSize + invCellGap))
    for i, sym in ipairs(engine.inventory) do
        if i > maxVisible then break end
        
        local x = invStartX + (i - 1) * (invCellSize + invCellGap)
        local y = invY
        
        local hovered = mx >= x and mx <= x + invCellSize and my >= y and my <= y + invCellSize
        
        -- Check if upgradeable
        local progress = Upgrade.getUpgradeProgress(engine.inventory, sym.key)
        local canUpgrade = progress.canUpgrade
        
        -- Background
        if hovered then
            love.graphics.setColor(0.3, 0.3, 0.4)
        else
            love.graphics.setColor(0.2, 0.2, 0.28)
        end
        love.graphics.rectangle("fill", x, y, invCellSize, invCellSize, 4, 4)
        
        -- Border (gold if upgradeable)
        if canUpgrade then
            love.graphics.setColor(1, 0.8, 0.2)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.4, 0.4, 0.5)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", x, y, invCellSize, invCellSize, 4, 4)
        love.graphics.setLineWidth(1)
        
        -- Symbol (draw character directly for small cells)
        local Registry = require("src.core.registry")
        local def = Registry.symbol_types[sym.key]
        love.graphics.setFont(_G.Fonts.normal)
        love.graphics.setColor(def and def.color or {1, 1, 1})
        love.graphics.printf(def and def.char or "?", x, y + 5, invCellSize, "center")
        
        -- Level badge
        local level = Upgrade.getLevel(sym)
        if level > 1 then
            love.graphics.setColor(1, 0.8, 0.2)
            love.graphics.setFont(_G.Fonts.small)
            love.graphics.print("+" .. (level - 1), x + 2, y + 2)
        end
        
        -- Upgrade progress indicator
        if progress.current >= 2 then
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle("fill", x + 2, y + invCellSize - 12, 18, 10, 2, 2)
            love.graphics.setColor(0.3, 1, 0.3)
            love.graphics.setFont(_G.Fonts.small)
            love.graphics.print(progress.current .. "/3", x + 3, y + invCellSize - 12)
        end
        
        UI.registerZone("INV_SYM_" .. i, x, y, invCellSize, invCellSize)
    end
    
    -- Bottom buttons
    local btnY = screenH - 50
    local btnW, btnH = 120, 35
    
    -- Reroll button
    local rerollCost = shop:getRerollCost()
    local canReroll = engine.money >= rerollCost
    local rerollX = screenW / 2 - btnW - 20
    
    love.graphics.setColor(canReroll and {0.2, 0.3, 0.5} or {0.2, 0.2, 0.2})
    love.graphics.rectangle("fill", rerollX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(canReroll and {0.4, 0.6, 0.9} or {0.3, 0.3, 0.3})
    love.graphics.rectangle("line", rerollX, btnY, btnW, btnH, 8, 8)
    
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(canReroll and {1, 1, 1} or {0.5, 0.5, 0.5})
    love.graphics.printf(i18n.t("ui_reroll") .. " $" .. rerollCost, rerollX, btnY + 8, btnW, "center")
    UI.registerZone("SHOP_REROLL", rerollX, btnY, btnW, btnH)
    
    -- Leave button
    local leaveX = screenW / 2 + 20
    love.graphics.setColor(0.3, 0.5, 0.3)
    love.graphics.rectangle("fill", leaveX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(0.5, 0.8, 0.5)
    love.graphics.rectangle("line", leaveX, btnY, btnW, btnH, 8, 8)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(i18n.t("ui_continue"), leaveX, btnY + 8, btnW, "center")
    UI.registerZone("SHOP_LEAVE", leaveX, btnY, btnW, btnH)
end

-- Draw random event screen
function UI.drawEvent(event)
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    -- Panel
    local panelW, panelH = 350, 220
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    
    -- Panel background
    local bgColor = {0.15, 0.15, 0.2}
    if event.type == "positive" then
        bgColor = {0.1, 0.2, 0.1}
    elseif event.type == "negative" then
        bgColor = {0.2, 0.1, 0.1}
    end
    
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX + 5, panelY + 5, panelW, panelH, 12, 12)
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    
    -- Border color based on type
    local borderColor = {0.5, 0.5, 0.6}
    if event.type == "positive" then
        borderColor = {0.3, 0.8, 0.3}
    elseif event.type == "negative" then
        borderColor = {0.8, 0.3, 0.3}
    end
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setLineWidth(1)
    
    -- Event icon
    local iconY = panelY + 25
    love.graphics.setFont(_G.Fonts.big)
    if event.type == "positive" then
        love.graphics.setColor(0.3, 1, 0.3)
        love.graphics.printf("★", panelX, iconY, panelW, "center")
    elseif event.type == "negative" then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf("!", panelX, iconY, panelW, "center")
    else
        love.graphics.setColor(0.8, 0.8, 0.3)
        love.graphics.printf("?", panelX, iconY, panelW, "center")
    end
    
    -- Event name
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(event.name, panelX, panelY + 70, panelW, "center")
    
    -- Event description
    love.graphics.setFont(_G.Fonts.small)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf(event.desc, panelX + 20, panelY + 100, panelW - 40, "center")
    
    -- Result if any
    if event.result then
        love.graphics.setColor(1, 0.9, 0.4)
        love.graphics.printf("获得: " .. event.result, panelX, panelY + 130, panelW, "center")
    end
    
    -- Continue button
    local btnW, btnH = 150, 40
    local btnX = (screenW - btnW) / 2
    local btnY = panelY + panelH - 55
    
    love.graphics.setColor(0.3, 0.4, 0.5)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(0.5, 0.6, 0.7)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 8, 8)
    
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(i18n.t("ui_continue"), btnX, btnY + 10, btnW, "center")
    
    UI.registerZone("EVENT_CONTINUE", btnX, btnY, btnW, btnH)
end

-- Draw symbol action menu (sell/upgrade)
function UI.drawSymbolActionMenu(sym, index, engine, x, y)
    local Upgrade = require("src.core.upgrade")
    local Shop = require("src.core.shop")
    
    local menuW, menuH = 120, 100
    local menuX = math.min(x, love.graphics.getWidth() - menuW - 10)
    local menuY = math.max(y - menuH - 10, 10)
    
    -- Background
    love.graphics.setColor(0.15, 0.15, 0.2, 0.98)
    love.graphics.rectangle("fill", menuX, menuY, menuW, menuH, 8, 8)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.rectangle("line", menuX, menuY, menuW, menuH, 8, 8)
    
    -- Symbol name
    love.graphics.setFont(_G.Fonts.small)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(sym.name, menuX, menuY + 5, menuW, "center")
    
    local btnW, btnH = menuW - 20, 28
    local btnX = menuX + 10
    
    -- Sell button
    local sellPrice = Shop.new(1):getSellPrice(sym)
    local sellY = menuY + 30
    love.graphics.setColor(0.5, 0.3, 0.3)
    love.graphics.rectangle("fill", btnX, sellY, btnW, btnH, 4, 4)
    love.graphics.setColor(0.8, 0.5, 0.5)
    love.graphics.rectangle("line", btnX, sellY, btnW, btnH, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(i18n.t("ui_sell") .. " +$" .. sellPrice, btnX, sellY + 6, btnW, "center")
    UI.registerZone("ACTION_SELL", btnX, sellY, btnW, btnH)
    
    -- Upgrade button (if possible)
    local progress = Upgrade.getUpgradeProgress(engine.inventory, sym.key)
    local upgradeY = menuY + 65
    if progress.canUpgrade then
        love.graphics.setColor(0.3, 0.5, 0.3)
        love.graphics.rectangle("fill", btnX, upgradeY, btnW, btnH, 4, 4)
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.rectangle("line", btnX, upgradeY, btnW, btnH, 4, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(i18n.t("ui_upgrade") .. " (3→1)", btnX, upgradeY + 6, btnW, "center")
        UI.registerZone("ACTION_UPGRADE", btnX, upgradeY, btnW, btnH)
    else
        love.graphics.setColor(0.25, 0.25, 0.25)
        love.graphics.rectangle("fill", btnX, upgradeY, btnW, btnH, 4, 4)
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.printf(progress.current .. "/3", btnX, upgradeY + 6, btnW, "center")
    end
end

return UI
