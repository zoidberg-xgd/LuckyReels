-- main.lua
local Game = require("src.game")
local Menu = require("src.menu")
local Save = require("src.core.save")
local i18n = require("src.i18n")
local Effects = require("src.effects")
local ModAPI = require("src.core.mod_api")

-- Game state
local currentScreen = "menu"  -- "menu" or "game"
local menu = nil

function love.load()
    math.randomseed(os.time())
    -- Set a nice background color (dark blue-ish)
    love.graphics.setBackgroundColor(0.08, 0.08, 0.12)
    
    -- Debug flag for character (press F1 to toggle)
    _G.DEBUG_CHARACTER = false
    
    -- Initialize effects system
    Effects.init()
    
    -- Load settings and set language
    local settings = Save.loadSettings()
    local lang = settings and settings.language or "zh"
    i18n.load(lang)

    -- Try to load a Chinese font
    -- Common paths on macOS
    local font_paths = {
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/Library/Fonts/Arial Unicode.ttf"
    }
    
    local font = nil
    for _, path in ipairs(font_paths) do
        local info = love.filesystem.getInfo(path)
        -- Note: love.filesystem only sees files in save directory or source directory
        -- To load system fonts, we might need to rely on users putting a font file in the game dir.
        -- BUT, creating a newFont with a file object might work if we can read it.
        -- Actually, LÖVE sandboxing prevents reading absolute paths easily unless we mount it.
        -- FOR NOW: We will assume a font file named 'font.ttf' exists, or fallback to default.
        -- To make this work on your machine immediately without you moving files, 
        -- I will try to use the default font, but bear in mind CHINESE WONT RENDER without a custom font.
    end
    
    -- IMPORTANT FOR USER: Please drop a Chinese font file named "font.ttf" in the project folder.
    -- I will check if "font.ttf" exists in the game directory.
    local fontPath = nil
    if love.filesystem.getInfo("font.ttc") then
        fontPath = "font.ttc"
    elseif love.filesystem.getInfo("font.ttf") then
        fontPath = "font.ttf"
    end

    _G.Fonts = {}

    if fontPath then
        print("Loading font from: " .. fontPath)
        _G.Fonts.small = love.graphics.newFont(fontPath, 14)
        _G.Fonts.normal = love.graphics.newFont(fontPath, 20)
        _G.Fonts.big = love.graphics.newFont(fontPath, 32)
    else
        -- Fallback
        print("WARNING: No font file found. Using default.")
        _G.Fonts.small = love.graphics.newFont(14)
        _G.Fonts.normal = love.graphics.newFont(20)
        _G.Fonts.big = love.graphics.newFont(32)
    end
    
    -- Set default
    love.graphics.setFont(_G.Fonts.normal)
    
    -- Load mods
    ModAPI.loadMods()

    -- Create menu
    menu = Menu.new()
    
    -- Don't init game yet - wait for menu
end

function love.update(dt)
    if currentScreen == "menu" then
        menu:update(dt)
    else
        Game:update(dt)
    end
    
    -- Always update effects
    Effects.update(dt)
end

function love.draw()
    if currentScreen == "menu" then
        menu:draw()
    else
        Game:draw()
    end
end

function love.keypressed(key)
    -- F1 toggles character debug
    if key == "f1" then
        _G.DEBUG_CHARACTER = not _G.DEBUG_CHARACTER
        print("Character debug: " .. tostring(_G.DEBUG_CHARACTER))
    end
    
    -- Escape to return to menu from game
    if key == "escape" and currentScreen == "game" then
        -- Save before returning to menu
        Save.saveGame(Game)
        currentScreen = "menu"
        menu = Menu.new()
        return
    end
    
    if currentScreen == "menu" then
        local action = menu:keypressed(key)
        handleMenuAction(action)
    else
        Game:keypressed(key)
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if currentScreen == "menu" then
        local action = menu:mousepressed(x, y, button)
        handleMenuAction(action)
    elseif Game.mousepressed then
        Game:mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    if currentScreen == "menu" then
        menu:mousemoved(x, y)
    end
end

function handleMenuAction(action)
    if action == "new_game" then
        -- Delete old save and start fresh
        Save.deleteSave()
        Game:init()
        currentScreen = "game"
    elseif action == "continue" then
        -- Load saved game
        Game:init()
        local saveData = Save.loadGame()
        if saveData then
            Save.applyToEngine(Game, saveData)
        end
        currentScreen = "game"
    end
end

-- Auto-save when quitting
function love.quit()
    if currentScreen == "game" then
        Save.saveGame(Game)
        print("Game auto-saved on quit")
    end
    return false
end
