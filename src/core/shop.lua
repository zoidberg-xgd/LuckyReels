-- src/core/shop.lua
-- Shop system for buying symbols, relics, and consumables

local Registry = require("src.core.registry")
local EventBus = require("src.core.event_bus")

local Shop = {}
Shop.__index = Shop

--------------------------------------------------------------------------------
-- Shop Configuration
--------------------------------------------------------------------------------

Shop.CONFIG = {
    -- Number of items per category
    symbol_slots = 3,
    relic_slots = 1,
    consumable_slots = 2,
    
    -- Base prices (affordable early game)
    symbol_base_price = {
        [1] = 3,   -- Common - cheap to build collection
        [2] = 8,   -- Uncommon - moderate investment
        [3] = 18,  -- Rare - significant but achievable
    },
    relic_base_price = 12,
    consumable_base_price = 5,
    
    -- Reroll cost (cheap to encourage exploration)
    reroll_cost = 1,
    
    -- Sell value (percentage of buy price)
    sell_ratio = 0.5,
    
    -- Price scaling per floor (gentler)
    price_scale_per_floor = 0.05,
}

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

function Shop.new(floor)
    local self = setmetatable({}, Shop)
    
    self.floor = floor or 1
    self.symbols = {}
    self.relics = {}
    self.consumables = {}
    self.reroll_count = 0
    
    self:refresh()
    
    return self
end

--------------------------------------------------------------------------------
-- Core Methods
--------------------------------------------------------------------------------

--- Refresh all shop items
function Shop:refresh()
    self.symbols = {}
    self.relics = {}
    self.consumables = {}
    
    -- Generate symbols
    for i = 1, Shop.CONFIG.symbol_slots do
        local key = Registry.getRandomSymbolKey()
        local symbol = Registry.createSymbol(key)
        symbol.price = self:calculateSymbolPrice(symbol)
        table.insert(self.symbols, symbol)
    end
    
    -- Generate relics (chance based)
    if math.random() < 0.6 then  -- 60% chance to have a relic
        local relicKeys = {}
        for k in pairs(Registry.relic_types) do
            table.insert(relicKeys, k)
        end
        if #relicKeys > 0 then
            local key = relicKeys[math.random(#relicKeys)]
            local relic = Registry.createRelic(key)
            relic.price = self:calculateRelicPrice(relic)
            table.insert(self.relics, relic)
        end
    end
    
    -- Generate consumables
    local consumableKeys = {}
    for k in pairs(Registry.consumable_types) do
        table.insert(consumableKeys, k)
    end
    for i = 1, math.min(Shop.CONFIG.consumable_slots, #consumableKeys) do
        if #consumableKeys > 0 then
            local idx = math.random(#consumableKeys)
            local key = consumableKeys[idx]
            local consumable = Registry.createConsumable(key)
            consumable.price = self:calculateConsumablePrice(consumable)
            table.insert(self.consumables, consumable)
            table.remove(consumableKeys, idx)
        end
    end
    
    EventBus.emit("shop:refresh", {shop = self})
end

--- Calculate symbol price
function Shop:calculateSymbolPrice(symbol)
    local base = Shop.CONFIG.symbol_base_price[symbol.rarity] or 5
    local floorScale = 1 + (self.floor - 1) * Shop.CONFIG.price_scale_per_floor
    return math.floor(base * floorScale)
end

--- Calculate relic price
function Shop:calculateRelicPrice(relic)
    local base = Shop.CONFIG.relic_base_price
    local floorScale = 1 + (self.floor - 1) * Shop.CONFIG.price_scale_per_floor
    return math.floor(base * floorScale)
end

--- Calculate consumable price
function Shop:calculateConsumablePrice(consumable)
    local base = Shop.CONFIG.consumable_base_price
    return math.floor(base)
end

--- Get reroll cost
function Shop:getRerollCost()
    return Shop.CONFIG.reroll_cost + self.reroll_count * 2
end

--- Reroll shop (costs money)
function Shop:reroll(engine)
    local cost = self:getRerollCost()
    if engine.money < cost then
        return false, "not_enough_money"
    end
    
    engine.money = engine.money - cost
    self.reroll_count = self.reroll_count + 1
    self:refresh()
    
    EventBus.emit("shop:reroll", {cost = cost})
    return true
end

--- Buy a symbol
function Shop:buySymbol(index, engine)
    local symbol = self.symbols[index]
    if not symbol then return false, "invalid_index" end
    if symbol.sold then return false, "already_sold" end
    if engine.money < symbol.price then return false, "not_enough_money" end
    
    -- Check inventory capacity
    local maxInventory = engine.inventory_max or 20
    if #engine.inventory >= maxInventory then
        return false, "inventory_full"
    end
    
    engine.money = engine.money - symbol.price
    table.insert(engine.inventory, symbol)
    symbol.sold = true
    
    EventBus.emit("shop:buy", {
        type = "symbol",
        item = symbol,
        price = symbol.price
    })
    EventBus.emit(EventBus.Events.SYMBOL_ADD, {symbol = symbol})
    
    return true
end

--- Buy a relic
function Shop:buyRelic(index, engine)
    local relic = self.relics[index]
    if not relic then return false, "invalid_index" end
    if relic.sold then return false, "already_sold" end
    if engine.money < relic.price then return false, "not_enough_money" end
    
    engine.money = engine.money - relic.price
    table.insert(engine.relics, relic)
    relic.sold = true
    
    EventBus.emit("shop:buy", {
        type = "relic",
        item = relic,
        price = relic.price
    })
    
    return true
end

--- Buy a consumable
function Shop:buyConsumable(index, engine)
    local consumable = self.consumables[index]
    if not consumable then return false, "invalid_index" end
    if consumable.sold then return false, "already_sold" end
    if engine.money < consumable.price then return false, "not_enough_money" end
    
    engine.money = engine.money - consumable.price
    table.insert(engine.consumables, consumable)
    consumable.sold = true
    
    EventBus.emit("shop:buy", {
        type = "consumable",
        item = consumable,
        price = consumable.price
    })
    
    return true
end

--- Calculate sell price for a symbol
function Shop:getSellPrice(symbol)
    local basePrice = Shop.CONFIG.symbol_base_price[symbol.rarity] or 5
    return math.floor(basePrice * Shop.CONFIG.sell_ratio)
end

--- Sell a symbol from inventory
function Shop:sellSymbol(index, engine)
    local symbol = engine.inventory[index]
    if not symbol then return false, "invalid_index" end
    
    local price = self:getSellPrice(symbol)
    engine.money = engine.money + price
    table.remove(engine.inventory, index)
    
    EventBus.emit("shop:sell", {
        type = "symbol",
        item = symbol,
        price = price
    })
    EventBus.emit(EventBus.Events.SYMBOL_REMOVE, {symbol = symbol})
    
    return true, price
end

return Shop
