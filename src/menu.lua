-- src/menu.lua
-- Main menu system

local i18n = require("src.i18n")
local Config = require("src.core.config")
local Save = require("src.core.save")
local Effects = require("src.effects")

local Menu = {}
Menu.__index = Menu

--------------------------------------------------------------------------------
-- Menu States
--------------------------------------------------------------------------------

Menu.STATE = {
    MAIN = "main",
    SETTINGS = "settings",
    CREDITS = "credits",
}

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

function Menu.new()
    local self = setmetatable({}, Menu)
    
    self.state = Menu.STATE.MAIN
    self.time = 0
    self.hasSave = Save.hasSave()
    
    -- Button hover states
    self.hoverButton = nil
    self.buttonScales = {}
    
    -- Settings
    self.settings = Save.loadSettings() or {
        language = "zh",
        musicVolume = 0.7,
        sfxVolume = 0.8,
    }
    
    -- Animation
    self.titleY = -100
    self.buttonsAlpha = 0
    self.logoRotation = 0
    
    -- Floating symbols for background
    self.floatingSymbols = {}
    self:initFloatingSymbols()
    
    return self
end

function Menu:initFloatingSymbols()
    local symbols = {"🍒", "💎", "⭐", "🎰", "💰", "🍀", "7️⃣", "🎲"}
    for i = 1, 15 do
        table.insert(self.floatingSymbols, {
            char = symbols[math.random(#symbols)],
            x = math.random(0, love.graphics.getWidth()),
            y = math.random(0, love.graphics.getHeight()),
            speed = math.random(20, 50),
            size = math.random(20, 40),
            alpha = math.random(10, 30) / 100,
            rotation = math.random() * math.pi * 2,
            rotSpeed = (math.random() - 0.5) * 0.5,
        })
    end
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

function Menu:update(dt)
    self.time = self.time + dt
    
    -- Animate title
    self.titleY = self.titleY + (80 - self.titleY) * dt * 3
    self.buttonsAlpha = math.min(1, self.buttonsAlpha + dt * 2)
    self.logoRotation = math.sin(self.time * 0.5) * 0.05
    
    -- Update floating symbols
    for _, sym in ipairs(self.floatingSymbols) do
        sym.y = sym.y - sym.speed * dt
        sym.rotation = sym.rotation + sym.rotSpeed * dt
        if sym.y < -50 then
            sym.y = love.graphics.getHeight() + 50
            sym.x = math.random(0, love.graphics.getWidth())
        end
    end
    
    -- Update button scales
    for id, scale in pairs(self.buttonScales) do
        local target = (self.hoverButton == id) and 1.08 or 1.0
        self.buttonScales[id] = scale + (target - scale) * dt * 10
    end
    
    -- Check for save file
    self.hasSave = Save.hasSave()
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function Menu:draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    -- Background gradient
    self:drawBackground()
    
    -- Floating symbols
    self:drawFloatingSymbols()
    
    if self.state == Menu.STATE.MAIN then
        self:drawMainMenu()
    elseif self.state == Menu.STATE.SETTINGS then
        self:drawSettings()
    elseif self.state == Menu.STATE.CREDITS then
        self:drawCredits()
    end
end

function Menu:drawBackground()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    -- Dark gradient background
    for i = 0, screenH, 4 do
        local t = i / screenH
        local r = 0.05 + t * 0.05
        local g = 0.05 + t * 0.03
        local b = 0.12 + t * 0.05
        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", 0, i, screenW, 4)
    end
    
    -- Subtle pattern overlay
    love.graphics.setColor(1, 1, 1, 0.02)
    for x = 0, screenW, 40 do
        for y = 0, screenH, 40 do
            if (x + y) % 80 == 0 then
                love.graphics.rectangle("fill", x, y, 20, 20)
            end
        end
    end
end

function Menu:drawFloatingSymbols()
    love.graphics.setFont(_G.Fonts.big)
    for _, sym in ipairs(self.floatingSymbols) do
        love.graphics.push()
        love.graphics.translate(sym.x, sym.y)
        love.graphics.rotate(sym.rotation)
        love.graphics.setColor(1, 1, 1, sym.alpha)
        love.graphics.print(sym.char, -sym.size/2, -sym.size/2)
        love.graphics.pop()
    end
end

function Menu:drawMainMenu()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    -- Title
    love.graphics.push()
    love.graphics.translate(screenW/2, self.titleY)
    love.graphics.rotate(self.logoRotation)
    
    -- Title shadow
    love.graphics.setFont(_G.Fonts.big)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf("LuckyReels", -202, 2, 400, "center")
    
    -- Title glow
    local glowAlpha = 0.3 + math.sin(self.time * 2) * 0.1
    love.graphics.setColor(1, 0.8, 0.2, glowAlpha)
    love.graphics.printf("LuckyReels", -200, 0, 400, "center")
    
    -- Title main
    love.graphics.setColor(1, 0.95, 0.8)
    love.graphics.printf("LuckyReels", -200, 0, 400, "center")
    
    love.graphics.pop()
    
    -- Subtitle
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(0.7, 0.7, 0.8, self.buttonsAlpha)
    love.graphics.printf(i18n.t("menu_subtitle") or "幸运转轴", 0, self.titleY + 50, screenW, "center")
    
    -- Buttons
    local buttonY = screenH / 2 - 20
    local buttonSpacing = 60
    
    -- Continue button (if save exists)
    if self.hasSave then
        self:drawButton("continue", screenW/2, buttonY, i18n.t("menu_continue") or "继续游戏")
        buttonY = buttonY + buttonSpacing
    end
    
    -- New Game
    self:drawButton("new_game", screenW/2, buttonY, i18n.t("menu_new_game") or "新游戏")
    buttonY = buttonY + buttonSpacing
    
    -- Settings
    self:drawButton("settings", screenW/2, buttonY, i18n.t("menu_settings") or "设置")
    buttonY = buttonY + buttonSpacing
    
    -- Credits
    self:drawButton("credits", screenW/2, buttonY, i18n.t("menu_credits") or "制作人员")
    buttonY = buttonY + buttonSpacing
    
    -- Quit
    self:drawButton("quit", screenW/2, buttonY, i18n.t("menu_quit") or "退出")
    
    -- Version
    love.graphics.setFont(_G.Fonts.small)
    love.graphics.setColor(0.5, 0.5, 0.6, 0.5)
    love.graphics.printf("v1.0.0", 0, screenH - 30, screenW - 10, "right")
end

function Menu:drawButton(id, x, y, text)
    local w, h = 200, 45
    
    -- Initialize scale
    if not self.buttonScales[id] then
        self.buttonScales[id] = 1.0
    end
    
    local scale = self.buttonScales[id]
    local isHovered = self.hoverButton == id
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(scale, scale)
    
    -- Button background
    if isHovered then
        love.graphics.setColor(0.3, 0.5, 0.7, 0.9 * self.buttonsAlpha)
    else
        love.graphics.setColor(0.15, 0.2, 0.3, 0.8 * self.buttonsAlpha)
    end
    love.graphics.rectangle("fill", -w/2, -h/2, w, h, 8, 8)
    
    -- Button border
    if isHovered then
        love.graphics.setColor(0.5, 0.8, 1, self.buttonsAlpha)
    else
        love.graphics.setColor(0.3, 0.4, 0.5, self.buttonsAlpha)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -w/2, -h/2, w, h, 8, 8)
    
    -- Button text
    love.graphics.setFont(_G.Fonts.normal)
    if isHovered then
        love.graphics.setColor(1, 1, 1, self.buttonsAlpha)
    else
        love.graphics.setColor(0.8, 0.8, 0.9, self.buttonsAlpha)
    end
    love.graphics.printf(text, -w/2, -10, w, "center")
    
    love.graphics.pop()
    
    -- Register click zone
    local zoneX = x - w/2 * scale
    local zoneY = y - h/2 * scale
    local zoneW = w * scale
    local zoneH = h * scale
    
    -- Store for click detection
    self._zones = self._zones or {}
    self._zones[id] = {x = zoneX, y = zoneY, w = zoneW, h = zoneH}
end

function Menu:drawSettings()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    -- Panel background
    local panelW, panelH = 400, 350
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setColor(0.3, 0.4, 0.5)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    
    -- Title
    love.graphics.setFont(_G.Fonts.big)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(i18n.t("menu_settings") or "设置", panelX, panelY + 20, panelW, "center")
    
    -- Language setting
    local settingY = panelY + 100
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.print(i18n.t("settings_language") or "语言", panelX + 40, settingY)
    
    -- Language buttons (side by side)
    self:drawSmallButton("lang_zh", panelX + 200, settingY, "中文", self.settings.language == "zh")
    self:drawSmallButton("lang_en", panelX + 290, settingY, "EN", self.settings.language == "en")
    
    -- Back button
    self:drawButton("back", screenW/2, panelY + panelH - 50, i18n.t("menu_back") or "返回")
end

function Menu:drawSmallButton(id, x, y, text, selected)
    local w, h = 70, 35
    
    if not self.buttonScales[id] then
        self.buttonScales[id] = 1.0
    end
    
    local isHovered = self.hoverButton == id
    
    -- Button background
    if selected then
        love.graphics.setColor(0.3, 0.6, 0.4, 0.9)
    elseif isHovered then
        love.graphics.setColor(0.3, 0.4, 0.5, 0.9)
    else
        love.graphics.setColor(0.15, 0.2, 0.25, 0.8)
    end
    love.graphics.rectangle("fill", x, y - 5, w, h, 6, 6)
    
    -- Border
    if selected then
        love.graphics.setColor(0.5, 0.9, 0.6)
    else
        love.graphics.setColor(0.3, 0.4, 0.5)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y - 5, w, h, 6, 6)
    
    -- Text
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(text, x, y + 2, w, "center")
    
    -- Register zone
    self._zones = self._zones or {}
    self._zones[id] = {x = x, y = y - 5, w = w, h = h}
end

function Menu:drawCredits()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    -- Panel
    local panelW, panelH = 400, 320
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setColor(0.3, 0.4, 0.5)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    
    -- Title
    love.graphics.setFont(_G.Fonts.big)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(i18n.t("menu_credits") or "制作人员", panelX, panelY + 20, panelW, "center")
    
    -- Credits content
    love.graphics.setFont(_G.Fonts.normal)
    love.graphics.setColor(0.8, 0.8, 0.9)
    
    local credits = {
        "LuckyReels",
        "",
        "Inspired by Luck be a Landlord",
        "",
        "Made with LÖVE2D",
    }
    
    local y = panelY + 75
    for _, line in ipairs(credits) do
        love.graphics.printf(line, panelX, y, panelW, "center")
        y = y + 28
    end
    
    -- Thank you message
    love.graphics.setColor(0.6, 0.7, 0.8)
    love.graphics.printf("Thank you for playing!", panelX, panelY + panelH - 100, panelW, "center")
    
    -- Back button
    self:drawButton("back", screenW/2, panelY + panelH - 45, i18n.t("menu_back") or "返回")
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function Menu:mousemoved(x, y)
    self.hoverButton = nil
    self._zones = self._zones or {}
    
    for id, zone in pairs(self._zones) do
        if x >= zone.x and x <= zone.x + zone.w and
           y >= zone.y and y <= zone.y + zone.h then
            self.hoverButton = id
            break
        end
    end
end

function Menu:mousepressed(x, y, button)
    if button ~= 1 then return nil end
    
    self._zones = self._zones or {}
    
    for id, zone in pairs(self._zones) do
        if x >= zone.x and x <= zone.x + zone.w and
           y >= zone.y and y <= zone.y + zone.h then
            return self:handleButton(id)
        end
    end
    
    return nil
end

function Menu:handleButton(id)
    Effects.playSound("click")
    
    if id == "new_game" then
        return "new_game"
    elseif id == "continue" then
        return "continue"
    elseif id == "settings" then
        self.state = Menu.STATE.SETTINGS
        self._zones = {}
    elseif id == "credits" then
        self.state = Menu.STATE.CREDITS
        self._zones = {}
    elseif id == "quit" then
        love.event.quit()
    elseif id == "back" then
        self.state = Menu.STATE.MAIN
        self._zones = {}
    elseif id == "lang_zh" then
        i18n.setLanguage("zh")
        self.settings.language = "zh"
        Save.saveSettings(self.settings)
    elseif id == "lang_en" then
        i18n.setLanguage("en")
        self.settings.language = "en"
        Save.saveSettings(self.settings)
    end
    
    return nil
end

function Menu:keypressed(key)
    if key == "escape" then
        if self.state ~= Menu.STATE.MAIN then
            self.state = Menu.STATE.MAIN
            self._zones = {}
        end
    elseif key == "return" or key == "space" then
        if self.hasSave then
            return "continue"
        else
            return "new_game"
        end
    end
    return nil
end

return Menu
