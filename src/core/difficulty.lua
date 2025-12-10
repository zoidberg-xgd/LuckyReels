-- src/core/difficulty.lua
-- Difficulty scaling and random events system

local i18n = require("src.i18n")

local Difficulty = {}

--------------------------------------------------------------------------------
-- Difficulty Curve
--------------------------------------------------------------------------------

-- Rent calculation based on floor
-- Design: Start easy, gradual increase, matches symbol economy
-- Reference: Lucky Landlord style progression
function Difficulty.calculateRent(floor)
    -- Base rent starts low, increases smoothly
    -- Floor 1: 15 (3 coins/spin avg with 5 spins = easy)
    -- Floor 5: 35 (7 coins/spin avg = need some combos)
    -- Floor 10: 75 (15 coins/spin avg = need upgrades)
    -- Floor 15: 150 (30 coins/spin avg = need strong build)
    
    if floor <= 5 then
        -- Tutorial phase: very forgiving
        return 10 + floor * 5  -- 15, 20, 25, 30, 35
    elseif floor <= 10 then
        -- Growth phase: steady increase
        return 35 + (floor - 5) * 8  -- 43, 51, 59, 67, 75
    elseif floor <= 15 then
        -- Challenge phase: steeper curve
        return 75 + (floor - 10) * 15  -- 90, 105, 120, 135, 150
    elseif floor <= 20 then
        -- Mastery phase: demanding
        return 150 + (floor - 15) * 25  -- 175, 200, 225, 250, 275
    else
        -- Endless: exponential but manageable
        return math.floor(275 * (1.12 ^ (floor - 20)))
    end
end

-- Spins per floor - more spins early game
function Difficulty.getSpins(floor)
    if floor <= 5 then
        return 6  -- Extra spin for learning
    elseif floor <= 10 then
        return 5
    elseif floor <= 15 then
        return 5
    else
        return 4  -- Harder in endless
    end
end

-- Check if floor is a boss floor
function Difficulty.isBossFloor(floor)
    return floor % 5 == 0  -- Every 5th floor is a boss
end

-- Get boss requirement (extra money needed)
function Difficulty.getBossRequirement(floor)
    if not Difficulty.isBossFloor(floor) then return nil end
    return {
        type = "money",
        amount = Difficulty.calculateRent(floor) * 2,  -- Need 2x rent
        name = "Boss: 房东亲自来收租!"
    }
end

-- Check if floor is a checkpoint (safe floor)
function Difficulty.isCheckpoint(floor)
    return floor == 3 or floor == 7  -- Checkpoints at floor 3 and 7
end

--------------------------------------------------------------------------------
-- Random Events
--------------------------------------------------------------------------------

-- Load events from data file
local i18n = require("src.i18n")
local eventData = require("data.events")

-- Effect handlers
local effectHandlers = {
    add_random_symbol = function(engine, value)
        local Registry = require("src.core.registry")
        local key = Registry.getRandomSymbolKey()
        local sym = Registry.createSymbol(key)
        table.insert(engine.inventory, sym)
        return sym.name
    end,
    add_spin = function(engine, value)
        engine.spins_left = engine.spins_left + (value or 1)
    end,
    remove_spin = function(engine, value)
        if engine.spins_left > 1 then
            engine.spins_left = engine.spins_left - (value or 1)
        end
    end,
    add_money = function(engine, value)
        engine.money = engine.money + (value or 0)
    end,
    remove_money = function(engine, value)
        engine.money = math.max(0, engine.money - (value or 0))
    end,
    multiply_rent = function(engine, value)
        engine.rent = math.floor(engine.rent * (value or 1))
    end,
    shuffle_inventory = function(engine, value)
        for i = #engine.inventory, 2, -1 do
            local j = math.random(i)
            engine.inventory[i], engine.inventory[j] = engine.inventory[j], engine.inventory[i]
        end
    end,
    shop_discount = function(engine, value)
        engine.shop_discount = value or 0.5
    end,
}

-- Build events with localized names and apply functions
Difficulty.events = {}
for _, data in ipairs(eventData) do
    local event = {
        id = data.id,
        name = i18n.t(data.name_key) or data.name_key,
        desc = i18n.t(data.desc_key) or data.desc_key,
        weight = data.weight,
        type = data.type,
        apply = function(engine)
            local handler = effectHandlers[data.effect]
            if handler then
                return handler(engine, data.value)
            end
        end
    }
    table.insert(Difficulty.events, event)
end

print("[Events] Loaded " .. #Difficulty.events .. " events")

-- Roll for a random event (chance based on floor)
function Difficulty.rollEvent(floor)
    local Config = require("src.core.config")
    local eventConfig = Config.difficulty.events
    
    -- Event chance increases with floor (use Config values)
    local eventChance = eventConfig.base_chance + floor * eventConfig.chance_per_floor
    eventChance = math.min(eventChance, eventConfig.max_chance)
    
    if math.random() > eventChance then
        return nil  -- No event
    end
    
    -- Weight-based selection
    local totalWeight = 0
    for _, event in ipairs(Difficulty.events) do
        totalWeight = totalWeight + event.weight
    end
    
    local roll = math.random() * totalWeight
    local cumulative = 0
    
    for _, event in ipairs(Difficulty.events) do
        cumulative = cumulative + event.weight
        if roll <= cumulative then
            return event
        end
    end
    
    return nil
end

-- Get floor description
function Difficulty.getFloorInfo(floor)
    local info = {
        floor = floor,
        rent = Difficulty.calculateRent(floor),
        spins = Difficulty.getSpins(floor),
        isBoss = Difficulty.isBossFloor(floor),
        isCheckpoint = Difficulty.isCheckpoint(floor),
    }
    
    if info.isBoss then
        info.bossReq = Difficulty.getBossRequirement(floor)
    end
    
    return info
end

return Difficulty
