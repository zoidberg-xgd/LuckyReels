-- src/core/floor.lua
-- Floor/Level progression system

local EventBus = require("src.core.event_bus")

local Floor = {}
Floor.__index = Floor

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

Floor.CONFIG = {
    -- Rent calculation: base + (floor * multiplier)
    rent_base = 20,
    rent_per_floor = 15,
    rent_multiplier = 1.2,  -- Exponential growth factor
    
    -- Spins per floor
    spins_base = 5,
    spins_bonus_every = 3,  -- Extra spin every N floors
    
    -- Floor milestones (use i18n keys for messages)
    milestones = {
        [5] = {type = "relic", message_key = "milestone_floor5"},
        [10] = {type = "essence", amount = 5, message_key = "milestone_floor10"},
        [15] = {type = "relic", message_key = "milestone_floor15"},
        [20] = {type = "victory", message_key = "milestone_floor20"},
    },
    
    -- Difficulty scaling
    rarity_unlock = {
        [1] = {1},           -- Floor 1: only common
        [3] = {1, 2},        -- Floor 3: common + uncommon
        [6] = {1, 2, 3},     -- Floor 6: all rarities
    },
    
    -- Shop scaling
    shop_extra_slot_every = 5,  -- Extra shop slot every N floors
    
    -- Special floor types
    special_floors = {
        [5] = "elite",    -- Harder but better rewards
        [10] = "boss",    -- Boss floor
        [15] = "elite",
        [20] = "boss",
    }
}

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

function Floor.new()
    local self = setmetatable({}, Floor)
    
    self.current = 1
    self.highest = 1
    self.essence = 0  -- Special currency
    
    return self
end

--------------------------------------------------------------------------------
-- Core Methods
--------------------------------------------------------------------------------

--- Get current floor number
function Floor:getCurrent()
    return self.current
end

--- Calculate rent for current floor
function Floor:getRent()
    local base = Floor.CONFIG.rent_base
    local perFloor = Floor.CONFIG.rent_per_floor
    local multiplier = Floor.CONFIG.rent_multiplier
    
    -- Exponential growth with linear component
    local rent = base + (self.current * perFloor)
    rent = rent * math.pow(multiplier, math.floor(self.current / 5))
    
    return math.floor(rent)
end

--- Get spins for current floor
function Floor:getSpins()
    local base = Floor.CONFIG.spins_base
    local bonus = math.floor(self.current / Floor.CONFIG.spins_bonus_every)
    return base + bonus
end

--- Get floor type (normal, elite, boss)
function Floor:getFloorType()
    return Floor.CONFIG.special_floors[self.current] or "normal"
end

--- Check if floor has milestone reward
function Floor:getMilestone()
    return Floor.CONFIG.milestones[self.current]
end

--- Get available rarities for current floor
function Floor:getAvailableRarities()
    local rarities = {1}  -- Always have common
    
    for floor, rars in pairs(Floor.CONFIG.rarity_unlock) do
        if self.current >= floor then
            rarities = rars
        end
    end
    
    return rarities
end

--- Advance to next floor
function Floor:advance(engine)
    local oldFloor = self.current
    self.current = self.current + 1
    
    if self.current > self.highest then
        self.highest = self.current
    end
    
    -- Check for milestone
    local milestone = self:getMilestone()
    if milestone then
        self:applyMilestone(milestone, engine)
    end
    
    EventBus.emit("floor:advance", {
        from = oldFloor,
        to = self.current,
        type = self:getFloorType(),
        milestone = milestone
    })
    
    return self.current
end

--- Apply milestone reward
function Floor:applyMilestone(milestone, engine)
    if milestone.type == "essence" then
        self.essence = self.essence + (milestone.amount or 1)
    elseif milestone.type == "relic" then
        -- Grant a random relic (handled by engine)
        EventBus.emit("floor:grant_relic", {floor = self.current})
    elseif milestone.type == "victory" then
        EventBus.emit("game:victory", {floor = self.current})
    end
end

--- Reset to floor 1
function Floor:reset()
    self.current = 1
    -- Keep highest and essence for meta-progression
end

--- Get floor display info
function Floor:getDisplayInfo()
    local floorType = self:getFloorType()
    local typeName = "普通"
    local typeColor = {0.7, 0.7, 0.7}
    
    if floorType == "elite" then
        typeName = "精英"
        typeColor = {1, 0.6, 0.2}
    elseif floorType == "boss" then
        typeName = "首领"
        typeColor = {1, 0.3, 0.3}
    end
    
    return {
        number = self.current,
        type = floorType,
        typeName = typeName,
        typeColor = typeColor,
        rent = self:getRent(),
        spins = self:getSpins(),
        milestone = self:getMilestone()
    }
end

--- Get progress to next milestone
function Floor:getNextMilestone()
    for floor, milestone in pairs(Floor.CONFIG.milestones) do
        if floor > self.current then
            return {
                floor = floor,
                milestone = milestone,
                remaining = floor - self.current
            }
        end
    end
    return nil
end

--- Spend essence (for special purchases)
function Floor:spendEssence(amount)
    if self.essence >= amount then
        self.essence = self.essence - amount
        return true
    end
    return false
end

return Floor
