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

Difficulty.events = {
    -- Positive events
    {
        id = "discount",
        name = "商店特价",
        desc = "本次商店所有物品半价!",
        weight = 15,
        type = "positive",
        apply = function(engine)
            engine.shop_discount = 0.5
        end
    },
    {
        id = "free_symbol",
        name = "意外收获",
        desc = "获得一个免费符号!",
        weight = 10,
        type = "positive",
        apply = function(engine)
            local Registry = require("src.core.registry")
            local key = Registry.getRandomSymbolKey()
            local sym = Registry.createSymbol(key)
            table.insert(engine.inventory, sym)
            return sym.name
        end
    },
    {
        id = "extra_spin",
        name = "额外机会",
        desc = "本轮多一次旋转!",
        weight = 12,
        type = "positive",
        apply = function(engine)
            engine.spins_left = engine.spins_left + 1
        end
    },
    {
        id = "rent_reduction",
        name = "房东心情好",
        desc = "本次房租减少20%!",
        weight = 8,
        type = "positive",
        apply = function(engine)
            engine.rent = math.floor(engine.rent * 0.8)
        end
    },
    {
        id = "bonus_coins",
        name = "路边捡钱",
        desc = "获得5金币!",
        weight = 15,
        type = "positive",
        apply = function(engine)
            engine.money = engine.money + 5
        end
    },
    
    -- Negative events
    {
        id = "rent_increase",
        name = "房东涨价",
        desc = "本次房租增加15%!",
        weight = 10,
        type = "negative",
        apply = function(engine)
            engine.rent = math.floor(engine.rent * 1.15)
        end
    },
    {
        id = "lose_spin",
        name = "睡过头了",
        desc = "本轮少一次旋转!",
        weight = 8,
        type = "negative",
        apply = function(engine)
            if engine.spins_left > 1 then
                engine.spins_left = engine.spins_left - 1
            end
        end
    },
    {
        id = "tax",
        name = "意外税收",
        desc = "失去3金币!",
        weight = 10,
        type = "negative",
        apply = function(engine)
            engine.money = math.max(0, engine.money - 3)
        end
    },
    
    -- Neutral events
    {
        id = "shuffle",
        name = "命运之轮",
        desc = "所有符号随机重排!",
        weight = 5,
        type = "neutral",
        apply = function(engine)
            -- Shuffle inventory
            for i = #engine.inventory, 2, -1 do
                local j = math.random(i)
                engine.inventory[i], engine.inventory[j] = engine.inventory[j], engine.inventory[i]
            end
        end
    },
}

-- Roll for a random event (chance based on floor)
function Difficulty.rollEvent(floor)
    -- Event chance increases with floor
    local eventChance = 0.2 + floor * 0.05  -- 25% at floor 1, 70% at floor 10
    eventChance = math.min(eventChance, 0.7)  -- Cap at 70%
    
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
