-- main.lua
local Game = require("src.game")
local i18n = require("src.i18n")
local Effects = require("src.effects")
local ModAPI = require("src.core.mod_api")

function love.load()
    math.randomseed(os.time())
    -- Set a nice background color (dark blue-ish)
    love.graphics.setBackgroundColor(0.08, 0.08, 0.12)
    
    -- Debug flag for character (press F1 to toggle)
    _G.DEBUG_CHARACTER = false
    
    -- Initialize effects system
    Effects.init()
    
    -- Initialize i18n
    i18n.load("zh")

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

    Game:init()
end

function love.update(dt)
    Game:update(dt)
end

function love.draw()
    Game:draw()
end

function love.keypressed(key)
    -- F1 toggles character debug
    if key == "f1" then
        _G.DEBUG_CHARACTER = not _G.DEBUG_CHARACTER
        print("Character debug: " .. tostring(_G.DEBUG_CHARACTER))
    end
    Game:keypressed(key)
end

function love.mousepressed(x, y, button, istouch, presses)
    if Game.mousepressed then
        Game:mousepressed(x, y, button)
    end
end
