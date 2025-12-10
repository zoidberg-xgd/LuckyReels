-- src/core/content_loader.lua
-- Data-driven content loading system
-- Loads symbols, relics, and consumables from data files

local Registry = require("src.core.registry")

-- Lua 5.1 compatibility
local unpack = unpack or table.unpack

local ContentLoader = {}

--------------------------------------------------------------------------------
-- Interaction Effect Definitions
--------------------------------------------------------------------------------

-- Predefined interaction types with visual effects
ContentLoader.InteractionTypes = {
    -- Consume: target is destroyed, particles fly to source
    consume = {
        line_color = {1, 0.5, 0.3},
        particle_type = "absorb",
        sound = "consume",
        shake = 3,
    },
    -- Boost: source gets powered up by target
    boost = {
        line_color = {1, 0.9, 0.3},
        particle_type = "sparkle",
        sound = "boost",
        glow = true,
    },
    -- Transform: target changes into something else
    transform = {
        line_color = {0.7, 0.3, 1},
        particle_type = "magic",
        sound = "transform",
        flash = true,
    },
    -- Destroy: target is destroyed with explosion
    destroy = {
        line_color = {1, 0.3, 0.2},
        particle_type = "explosion",
        sound = "explode",
        shake = 6,
    },
    -- Synergy: both symbols benefit
    synergy = {
        line_color = {0.3, 1, 0.5},
        particle_type = "link",
        sound = "synergy",
        glow = true,
    },
}

--------------------------------------------------------------------------------
-- Helper: Create interaction effect
--------------------------------------------------------------------------------

function ContentLoader.createInteraction(type, sourceR, sourceC, targetR, targetC, value, customColor)
    local config = ContentLoader.InteractionTypes[type] or ContentLoader.InteractionTypes.boost
    return {
        type = type,
        targetR = targetR,
        targetC = targetC,
        sourceR = sourceR,
        sourceC = sourceC,
        value = value or 0,
        color = customColor or config.line_color,
        particle_type = config.particle_type,
        shake = config.shake,
        glow = config.glow,
        flash = config.flash,
    }
end

--------------------------------------------------------------------------------
-- Symbol Behavior Templates
--------------------------------------------------------------------------------

-- Common behavior patterns that can be reused
ContentLoader.Behaviors = {
    -- Consume adjacent symbols of specific type (DELAYED - marks for removal after animation)
    consume_adjacent_delayed = function(targetKey, bonusPerTarget, consumeColor)
        return function(self, grid, r, c)
            local bonus = 0
            local interactions = {}
            for dr = -1, 1 do
                for dc = -1, 1 do
                    if dr == 0 and dc == 0 then goto continue end
                    local nr, nc = r + dr, c + dc
                    local neighbor = grid:getSymbol(nr, nc)
                    if neighbor and neighbor.key == targetKey and not neighbor._markedForRemoval then
                        bonus = bonus + bonusPerTarget
                        table.insert(interactions, ContentLoader.createInteraction(
                            "consume", r, c, nr, nc, bonusPerTarget, consumeColor
                        ))
                        -- Mark for delayed removal instead of immediate
                        grid:markForRemoval(nr, nc)
                    end
                    ::continue::
                end
            end
            return self.base_value + bonus, {}, interactions
        end
    end,
    
    -- Legacy: immediate consume (for backwards compatibility)
    consume_adjacent = function(targetKey, bonusPerTarget, consumeColor)
        return function(self, grid, r, c)
            local bonus = 0
            local interactions = {}
            for dr = -1, 1 do
                for dc = -1, 1 do
                    if dr == 0 and dc == 0 then goto continue end
                    local nr, nc = r + dr, c + dc
                    local neighbor = grid:getSymbol(nr, nc)
                    if neighbor and neighbor.key == targetKey and not neighbor._markedForRemoval then
                        bonus = bonus + bonusPerTarget
                        table.insert(interactions, ContentLoader.createInteraction(
                            "consume", r, c, nr, nc, bonusPerTarget, consumeColor
                        ))
                        grid:markForRemoval(nr, nc)
                    end
                    ::continue::
                end
            end
            return self.base_value + bonus, {}, interactions
        end
    end,
    
    -- Boost from adjacent symbols of specific type
    boost_from_adjacent = function(targetKey, multiplierPerTarget, boostColor)
        return function(self, grid, r, c)
            local multiplier = 1
            local interactions = {}
            for dr = -1, 1 do
                for dc = -1, 1 do
                    if dr == 0 and dc == 0 then goto continue end
                    local nr, nc = r + dr, c + dc
                    local neighbor = grid:getSymbol(nr, nc)
                    if neighbor and neighbor.key == targetKey then
                        multiplier = multiplier + multiplierPerTarget
                        table.insert(interactions, ContentLoader.createInteraction(
                            "boost", r, c, nr, nc, multiplierPerTarget, boostColor
                        ))
                    end
                    ::continue::
                end
            end
            return self.base_value * multiplier, {}, interactions
        end
    end,
    
    -- Count same type on grid
    count_same_type = function(bonusPerSame)
        return function(self, grid, r, c)
            local count = 0
            for gr = 1, grid.rows do
                for gc = 1, grid.cols do
                    local sym = grid:getSymbol(gr, gc)
                    if sym and sym.key == self.key and not (gr == r and gc == c) then
                        count = count + 1
                    end
                end
            end
            return self.base_value * (1 + count * bonusPerSame), {}, {}
        end
    end,
    
    -- Destroy all adjacent (delayed removal for proper animation)
    destroy_all_adjacent = function(bonusPerDestroyed, destroySelf)
        return function(self, grid, r, c)
            local destroyed = 0
            local interactions = {}
            for dr = -1, 1 do
                for dc = -1, 1 do
                    if dr == 0 and dc == 0 then goto continue end
                    local nr, nc = r + dr, c + dc
                    local neighbor = grid:getSymbol(nr, nc)
                    if neighbor and not neighbor._markedForRemoval then
                        destroyed = destroyed + bonusPerDestroyed
                        table.insert(interactions, ContentLoader.createInteraction(
                            "destroy", r, c, nr, nc, bonusPerDestroyed, {1, 0.5, 0.2}
                        ))
                        -- Mark for delayed removal
                        grid:markForRemoval(nr, nc)
                    end
                    ::continue::
                end
            end
            if destroySelf then
                -- Mark self for removal too
                grid:markForRemoval(r, c)
            end
            return destroyed, {}, interactions
        end
    end,
    
    -- Copy adjacent values
    copy_adjacent_values = function(copyColor)
        return function(self, grid, r, c)
            local bonus = 0
            local interactions = {}
            for dr = -1, 1 do
                for dc = -1, 1 do
                    if dr == 0 and dc == 0 then goto continue end
                    local nr, nc = r + dr, c + dc
                    local neighbor = grid:getSymbol(nr, nc)
                    if neighbor then
                        bonus = bonus + neighbor.base_value
                        table.insert(interactions, ContentLoader.createInteraction(
                            "synergy", r, c, nr, nc, neighbor.base_value, copyColor
                        ))
                    end
                    ::continue::
                end
            end
            return self.base_value + bonus, {}, interactions
        end
    end,
    
    -- Bonus per empty adjacent
    bonus_per_empty = function(bonusPerEmpty)
        return function(self, grid, r, c)
            local bonus = 0
            for dr = -1, 1 do
                for dc = -1, 1 do
                    if dr == 0 and dc == 0 then goto continue end
                    local nr, nc = r + dr, c + dc
                    if nr >= 1 and nr <= grid.rows and nc >= 1 and nc <= grid.cols then
                        if not grid:getSymbol(nr, nc) then
                            bonus = bonus + bonusPerEmpty
                        end
                    end
                    ::continue::
                end
            end
            return bonus, {}, {}
        end
    end,
    
    -- Row bonus
    row_bonus = function(bonusPerSymbol)
        return function(self, grid, r, c)
            local bonus = 0
            for gc = 1, grid.cols do
                if gc ~= c then
                    local sym = grid:getSymbol(r, gc)
                    if sym then
                        bonus = bonus + bonusPerSymbol
                    end
                end
            end
            return self.base_value + bonus, {}, {}
        end
    end,
    
    -- Random value
    random_value = function(min, max)
        return function(self, grid, r, c)
            return math.random(min, max), {}, {}
        end
    end,
    
    -- Conditional multiplier
    conditional_multiplier = function(condition, multiplier)
        return function(self, grid, r, c)
            if condition(self, grid, r, c) then
                return self.base_value * multiplier, {}, {}
            end
            return self.base_value, {}, {}
        end
    end,
}

--------------------------------------------------------------------------------
-- Load symbols from data table
--------------------------------------------------------------------------------

function ContentLoader.loadSymbols(symbolsData)
    for key, data in pairs(symbolsData) do
        local def = {
            name_key = data.name_key or ("symbol_" .. key .. "_name"),
            desc_key = data.desc_key or ("symbol_" .. key .. "_desc"),
            char = data.char or key:sub(1, 2):upper(),
            color = data.color or {1, 1, 1},
            value = data.value or 1,
            rarity = data.rarity or 1,
        }
        
        -- Apply behavior if specified
        if data.behavior then
            local behaviorType = data.behavior.type
            local behaviorFunc = ContentLoader.Behaviors[behaviorType]
            if behaviorFunc then
                def.on_calculate = behaviorFunc(unpack(data.behavior.args or {}))
            end
        elseif data.on_calculate then
            def.on_calculate = data.on_calculate
        end
        
        -- Custom renderer
        if data.renderer then
            def.renderer = data.renderer
        end
        
        Registry.registerSymbol(key, def)
    end
end

--------------------------------------------------------------------------------
-- Load relics from data table
--------------------------------------------------------------------------------

function ContentLoader.loadRelics(relicsData)
    for key, data in pairs(relicsData) do
        local def = {
            name_key = data.name_key or ("relic_" .. key .. "_name"),
            desc_key = data.desc_key or ("relic_" .. key .. "_desc"),
            char = data.char or "?",
            color = data.color or {1, 0.8, 0.2},
            on_spin_start = data.on_spin_start,
            on_spin_end = data.on_spin_end,
            on_calculate_end = data.on_calculate_end,
        }
        
        Registry.registerRelic(key, def)
    end
end

--------------------------------------------------------------------------------
-- Load consumables from data table
--------------------------------------------------------------------------------

function ContentLoader.loadConsumables(consumablesData)
    for key, data in pairs(consumablesData) do
        local def = {
            name_key = data.name_key or ("item_" .. key .. "_name"),
            desc_key = data.desc_key or ("item_" .. key .. "_desc"),
            char = data.char or "?",
            color = data.color or {0.5, 0.5, 1},
            on_use = data.on_use,
        }
        
        Registry.registerConsumable(key, def)
    end
end

--------------------------------------------------------------------------------
-- Load all content from a content pack
--------------------------------------------------------------------------------

function ContentLoader.loadContentPack(pack)
    if pack.symbols then
        ContentLoader.loadSymbols(pack.symbols)
    end
    if pack.relics then
        ContentLoader.loadRelics(pack.relics)
    end
    if pack.consumables then
        ContentLoader.loadConsumables(pack.consumables)
    end
end

--------------------------------------------------------------------------------
-- Load content from file
--------------------------------------------------------------------------------

function ContentLoader.loadFromFile(filepath)
    local ok, content = pcall(require, filepath)
    if ok and content then
        ContentLoader.loadContentPack(content)
        return true
    else
        print("[ContentLoader] Failed to load: " .. filepath)
        return false
    end
end

return ContentLoader
