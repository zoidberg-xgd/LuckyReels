-- src/core/api.lua
-- Unified API for game systems
-- Provides clean interfaces for common operations

local Config = require("src.core.config")
local EventBus = require("src.core.event_bus")
local Registry = require("src.core.registry")

local API = {}

--------------------------------------------------------------------------------
-- Game State API
--------------------------------------------------------------------------------

API.Game = {}

-- Get current game instance (set by game.lua)
API.Game._instance = nil

function API.Game.setInstance(game)
    API.Game._instance = game
end

function API.Game.getInstance()
    return API.Game._instance
end

function API.Game.getMoney()
    local game = API.Game._instance
    return game and game.money or 0
end

function API.Game.setMoney(amount)
    local game = API.Game._instance
    if game then
        local old = game.money
        game.money = amount
        EventBus.emit(EventBus.Events.MONEY_CHANGE, {old = old, new = amount, delta = amount - old})
    end
end

function API.Game.addMoney(amount)
    API.Game.setMoney(API.Game.getMoney() + amount)
end

function API.Game.getFloor()
    local game = API.Game._instance
    return game and game.floor or 1
end

function API.Game.getState()
    local game = API.Game._instance
    return game and game.state or "IDLE"
end

function API.Game.getRent()
    local game = API.Game._instance
    return game and game.rent or Config.balance.starting_rent
end

function API.Game.getSpinsLeft()
    local game = API.Game._instance
    return game and game.spins_left or 0
end

--------------------------------------------------------------------------------
-- Inventory API
--------------------------------------------------------------------------------

API.Inventory = {}

function API.Inventory.getAll()
    local game = API.Game._instance
    return game and game.inventory or {}
end

function API.Inventory.count()
    return #API.Inventory.getAll()
end

function API.Inventory.isFull()
    return API.Inventory.count() >= Config.balance.inventory_max
end

function API.Inventory.add(symbol)
    local game = API.Game._instance
    if game and not API.Inventory.isFull() then
        table.insert(game.inventory, symbol)
        EventBus.emit(EventBus.Events.SYMBOL_ADD, {symbol = symbol})
        return true
    end
    return false
end

function API.Inventory.remove(index)
    local game = API.Game._instance
    if game and game.inventory[index] then
        local symbol = table.remove(game.inventory, index)
        EventBus.emit(EventBus.Events.SYMBOL_REMOVE, {symbol = symbol})
        return symbol
    end
    return nil
end

function API.Inventory.findByKey(key)
    local results = {}
    for i, sym in ipairs(API.Inventory.getAll()) do
        if sym.key == key then
            table.insert(results, {index = i, symbol = sym})
        end
    end
    return results
end

function API.Inventory.countByKey(key)
    return #API.Inventory.findByKey(key)
end

--------------------------------------------------------------------------------
-- Grid API
--------------------------------------------------------------------------------

API.Grid = {}

function API.Grid.get()
    local game = API.Game._instance
    return game and game.grid or nil
end

function API.Grid.getSymbol(r, c)
    local grid = API.Grid.get()
    return grid and grid:getSymbol(r, c) or nil
end

function API.Grid.setSymbol(r, c, symbol)
    local grid = API.Grid.get()
    if grid and r >= 1 and r <= grid.rows and c >= 1 and c <= grid.cols then
        grid.cells[r][c] = symbol
        return true
    end
    return false
end

function API.Grid.forEachSymbol(callback)
    local grid = API.Grid.get()
    if not grid then return end
    
    for r = 1, grid.rows do
        for c = 1, grid.cols do
            local sym = grid.cells[r][c]
            if sym then
                callback(sym, r, c)
            end
        end
    end
end

function API.Grid.toScreen(r, c)
    return Config.grid.toScreen(r, c)
end

function API.Grid.toCenterScreen(r, c)
    return Config.grid.toCenterScreen(r, c)
end

--------------------------------------------------------------------------------
-- Relics API
--------------------------------------------------------------------------------

API.Relics = {}

function API.Relics.getAll()
    local game = API.Game._instance
    return game and game.relics or {}
end

function API.Relics.add(relic)
    local game = API.Game._instance
    if game then
        table.insert(game.relics, relic)
        EventBus.emit("relic:add", {relic = relic})
        return true
    end
    return false
end

function API.Relics.hasRelic(key)
    for _, relic in ipairs(API.Relics.getAll()) do
        if relic.key == key then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Shop API
--------------------------------------------------------------------------------

API.Shop = {}

function API.Shop.get()
    local game = API.Game._instance
    return game and game.shop or nil
end

function API.Shop.buySymbol(index)
    local shop = API.Shop.get()
    local game = API.Game._instance
    if shop and game then
        return shop:buySymbol(index, game)
    end
    return false, "no_shop"
end

function API.Shop.sellSymbol(inventoryIndex)
    local shop = API.Shop.get()
    local game = API.Game._instance
    if shop and game then
        return shop:sellSymbol(inventoryIndex, game)
    end
    return false, "no_shop"
end

function API.Shop.reroll()
    local shop = API.Shop.get()
    local game = API.Game._instance
    if shop and game then
        return shop:reroll(game)
    end
    return false, "no_shop"
end

--------------------------------------------------------------------------------
-- Difficulty API
--------------------------------------------------------------------------------

API.Difficulty = {}

function API.Difficulty.getRent(floor)
    return Config.getRent(floor or API.Game.getFloor())
end

function API.Difficulty.getSpins(floor)
    return Config.getSpins(floor or API.Game.getFloor())
end

function API.Difficulty.isBossFloor(floor)
    return Config.isBossFloor(floor or API.Game.getFloor())
end

function API.Difficulty.getPhase(floor)
    floor = floor or API.Game.getFloor()
    
    if floor <= 5 then return "tutorial"
    elseif floor <= 10 then return "growth"
    elseif floor <= 15 then return "challenge"
    elseif floor <= 20 then return "mastery"
    else return "endless"
    end
end

--------------------------------------------------------------------------------
-- Effects API (for external use)
--------------------------------------------------------------------------------

API.Effects = {}

function API.Effects.addPopup(x, y, text, color, size, delay)
    local Effects = require("src.effects")
    Effects.addPopup(x, y, text, color, size, delay)
end

function API.Effects.addCoinBurst(x, y, count)
    local Effects = require("src.effects")
    Effects.addCoinBurst(x, y, count)
end

function API.Effects.screenShake(intensity, duration)
    local Effects = require("src.effects")
    Effects.screenShake(intensity, duration)
end

function API.Effects.screenFlash(r, g, b, alpha, duration)
    local Effects = require("src.effects")
    Effects.screenFlash(r, g, b, alpha, duration)
end

--------------------------------------------------------------------------------
-- Symbol Creation API
--------------------------------------------------------------------------------

API.Symbols = {}

function API.Symbols.create(key)
    return Registry.createSymbol(key)
end

function API.Symbols.createRandom()
    local key = Registry.getRandomSymbolKey()
    return Registry.createSymbol(key)
end

function API.Symbols.getDefinition(key)
    return Registry.getSymbol(key)
end

function API.Symbols.getAllKeys()
    return Registry.getAllSymbolKeys()
end

--------------------------------------------------------------------------------
-- Event Shortcuts
--------------------------------------------------------------------------------

API.Events = EventBus.Events

function API.on(event, callback)
    return EventBus.on(event, callback)
end

function API.emit(event, data)
    EventBus.emit(event, data)
end

function API.off(event, id)
    EventBus.off(event, id)
end

return API
