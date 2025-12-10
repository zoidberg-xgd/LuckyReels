-- src/core/grid.lua
local Grid = {}
Grid.__index = Grid

function Grid.new(rows, cols)
    local self = setmetatable({}, Grid)
    self.rows = rows or 4
    self.cols = cols or 5
    self.cells = {} -- 2D array [row][col]
    
    for r = 1, self.rows do
        self.cells[r] = {}
        for c = 1, self.cols do
            self.cells[r][c] = nil
        end
    end
    
    return self
end

-- Place symbols on grid randomly (like original game)
function Grid:placeSymbols(inventory)
    -- Clear all cells
    for r = 1, self.rows do
        for c = 1, self.cols do
            self.cells[r][c] = nil
        end
    end
    
    -- Get all available positions
    local positions = {}
    for r = 1, self.rows do
        for c = 1, self.cols do
            table.insert(positions, {r = r, c = c})
        end
    end
    
    -- Shuffle positions (Fisher-Yates)
    for i = #positions, 2, -1 do
        local j = math.random(i)
        positions[i], positions[j] = positions[j], positions[i]
    end
    
    -- Place each symbol at a random position
    for i, sym in ipairs(inventory) do
        if i <= #positions then
            local pos = positions[i]
            sym._markedForRemoval = nil
            sym._deathTimer = nil
            self.cells[pos.r][pos.c] = sym
        end
    end
end

function Grid:spin(inventory)
    -- Clear all cells
    for r = 1, self.rows do
        for c = 1, self.cols do
            self.cells[r][c] = nil
        end
    end

    -- Create pool of all available positions
    local positions = {}
    for r = 1, self.rows do
        for c = 1, self.cols do
            table.insert(positions, {r = r, c = c})
        end
    end
    
    -- Shuffle positions (Fisher-Yates)
    for i = #positions, 2, -1 do
        local j = math.random(i)
        positions[i], positions[j] = positions[j], positions[i]
    end
    
    -- Place each inventory symbol at a random position
    for i, sym in ipairs(inventory) do
        if i <= #positions then
            local pos = positions[i]
            -- Clear any death animation state from previous spin
            sym._markedForRemoval = nil
            sym._deathTimer = nil
            self.cells[pos.r][pos.c] = sym
        end
    end
end

function Grid:calculateTotalValue()
    local total = 0
    local log = {}
    local interactions = {}  -- Store interaction events for animations
    
    for r = 1, self.rows do
        for c = 1, self.cols do
            local sym = self.cells[r][c]
            if sym then
                -- Assume sym has getValue method (provided by Registry instance)
                local val, item_logs, item_interactions = sym:getValue(self, r, c)
                total = total + val
                
                -- Collect interactions
                if item_interactions then
                    for _, interaction in ipairs(item_interactions) do
                        interaction.sourceR = r
                        interaction.sourceC = c
                        interaction.sourceKey = sym.key
                        table.insert(interactions, interaction)
                    end
                end
                
                if item_logs and #item_logs > 0 then
                   for _, l in ipairs(item_logs) do
                        if type(l) == "table" then
                           local i18n = require("src.i18n")
                           table.insert(log, i18n.t(l.key, l.val))
                       else
                           table.insert(log, l)
                       end
                   end
                end
            end
        end
    end
    -- Apply synergy bonuses
    local Synergy = require("src.core.synergy")
    local synergyResult = Synergy.calculate(self)
    
    if synergyResult.multiplier > 1 or synergyResult.bonus > 0 then
        local oldTotal = total
        total = math.floor(total * synergyResult.multiplier) + synergyResult.bonus
        
        -- Log active synergies
        for _, syn in ipairs(synergyResult.synergies) do
            if syn.multiplier and syn.multiplier > 1 then
                table.insert(log, "[" .. syn.name .. "] x" .. syn.multiplier)
            elseif syn.bonus then
                table.insert(log, "[" .. syn.name .. "] +" .. syn.bonus)
            end
        end
    end
    
    return total, log, interactions
end

-- API: Get symbol at position
function Grid:getSymbol(r, c)
    if r < 1 or r > self.rows or c < 1 or c > self.cols then return nil end
    return self.cells[r][c]
end

-- API: Remove symbol at position
function Grid:removeSymbol(r, c)
    if r < 1 or r > self.rows or c < 1 or c > self.cols then return end
    self.cells[r][c] = nil
end

-- API: Mark symbol for delayed removal (used during calculation)
-- The actual removal happens after animations play
function Grid:markForRemoval(r, c)
    if r < 1 or r > self.rows or c < 1 or c > self.cols then return end
    local sym = self.cells[r][c]
    if sym then
        sym._markedForRemoval = true
    end
end

-- API: Remove all marked symbols (call after animations)
function Grid:removeMarkedSymbols()
    local removed = {}
    for r = 1, self.rows do
        for c = 1, self.cols do
            local sym = self.cells[r][c]
            if sym and sym._markedForRemoval then
                table.insert(removed, {r = r, c = c, sym = sym})
                self.cells[r][c] = nil
            end
        end
    end
    return removed
end

-- API: Check if symbol is marked for removal
function Grid:isMarkedForRemoval(r, c)
    local sym = self.cells[r][c]
    return sym and sym._markedForRemoval
end

return Grid
