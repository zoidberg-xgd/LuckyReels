-- src/core/engine.lua
local Grid = require("src.core.grid")
local Registry = require("src.core.registry")
local i18n = require("src.i18n")
local EventBus = require("src.core.event_bus")

local Engine = {}
Engine.__index = Engine

function Engine.new()
    local self = setmetatable({}, Engine)
    self.grid = nil
    self.money = 0
    self.rent = 0
    self.spins_max = 5
    self.spins_left = 0
    self.inventory = {}
    self.logs = {}
    self.state = "IDLE" -- IDLE, DRAFT, GAME_OVER
    self.draft_options = {}
    self.config = {}
    return self
end

-- Initialize the engine with rules and starting inventory
function Engine:init(config)
    self.config = config or {}
    
    -- Config defaults
    local rows = self.config.rows or 4
    local cols = self.config.cols or 5
    self.grid = Grid.new(rows, cols)
    
    self.money = self.config.starting_money or 10
    self.rent = self.config.starting_rent or 25
    self.spins_left = self.config.spins_per_round or 5
    self.spins_max = self.spins_left
    self.floor = 1  -- Current floor/level
    
    self.inventory = {}
    self.inventory_max = 20  -- Max symbols in inventory
    self.relics = {} -- New: Relics container
    self.consumables = {} -- New: Consumables container
    self.active_consumable_index = nil -- Track which item is being used
    self.logs = {}
    self.state = "IDLE" -- IDLE, DRAFT, GAME_OVER, REMOVING, SPINNING, COLLECTING
    
    -- Collecting state timer (wait for coin animations)
    self.collect_timer = 0
    self.collect_min_wait = 0.8  -- Shorter wait, animations are faster now
    
    -- Animation state - more dramatic timing for satisfying slot feel
    self.spin_timer = 0
    self.spin_duration = 2.5 -- Total spin time (longer for anticipation)
    -- Staggered delays: first reels stop quick, last reel builds suspense
    self.reel_delays = {0.6, 0.85, 1.15, 1.55, 2.1} -- Stop time for each col (if 5 cols)
    
    -- Load starting inventory
    if self.config.starting_inventory then
        for _, key in ipairs(self.config.starting_inventory) do
            table.insert(self.inventory, Registry.createSymbol(key))
        end
    end
    
    -- Initial placement of symbols on grid (this IS the first spin result)
    self.grid:placeSymbols(self.inventory)
    self.firstSpin = true  -- First spin uses current placement, no re-shuffle
end

-- Update loop for animations
function Engine:update(dt)
    if self.state == "SPINNING" then
        self.spin_timer = self.spin_timer + dt
        if self.spin_timer >= self.spin_duration then
            self:resolveSpin()
        end
    end
end

-- Helper: Remove symbol from inventory
function Engine:removeSymbolFromInventory(index)
    if self.inventory[index] then
        local sym = table.remove(self.inventory, index)
        table.insert(self.logs, 1, i18n.t("log_symbol_removed", sym.name))
        return true
    end
    return false
end

-- Helper: Use consumable
function Engine:useConsumable(index)
    local item = self.consumables[index]
    if item and item.on_use then
        self.active_consumable_index = index
        -- Execute effect. If returns true, consume it.
        local consumed = item:on_use(self)
        if consumed then
            table.remove(self.consumables, index)
            self.active_consumable_index = nil
        end
    end
end

-- Helper: Finish deferred consumption (call this after selection)
function Engine:finishConsumable()
    if self.active_consumable_index then
        table.remove(self.consumables, self.active_consumable_index)
        self.active_consumable_index = nil
    end
    self.state = "IDLE"
end

-- Helper: Trigger hooks on all entities (Relics, Symbols)
function Engine:triggerHooks(hook_name, context)
    context = context or {}
    
    -- 1. Check Relics
    for _, relic in ipairs(self.relics) do
        if relic[hook_name] then
            relic[hook_name](relic, self, context)
        end
    end
    
    -- 2. Check Symbols in Inventory (Passive effects even if not on grid?)
    -- Typically in this game, symbols only act when on grid.
    -- But some might have global passives. For now, let's keep symbols strictly Grid-based for calculate, 
    -- but maybe we want "on_add" hooks later.
end

function Engine:spin()
    if self.spins_left <= 0 then return false end
    
    self:triggerHooks("on_spin_start")
    
    -- Emit event
    EventBus.emit(EventBus.Events.SPIN_START, {engine = self})
    
    -- 1. Start Spin Animation
    self.state = "SPINNING"
    self.spin_timer = 0
    
    -- First spin uses the initial placement (already on grid)
    -- Subsequent spins re-shuffle
    if self.firstSpin then
        self.firstSpin = false
        -- Don't re-shuffle, just use current grid placement
    else
        -- Pre-calculate the result (so we know what to stop on)
        self.grid:spin(self.inventory)
    end
    
    return true
end

function Engine:resolveSpin()
    -- 2. Calculate (but DON'T add money yet - let animations do it)
    local score, logs, interactions = self.grid:calculateTotalValue()
    self.logs = logs
    self.last_interactions = interactions or {}
    self.pending_score = score  -- Will be added coin by coin via animations
    
    table.insert(self.logs, 1, i18n.t("log_total_gain") .. score)
    
    -- Emit spin result event
    EventBus.emit(EventBus.Events.SPIN_RESULT, {
        score = score,
        interactions = interactions,
        engine = self
    })
    
    -- Hook: Post Calculate
    self:triggerHooks("on_calculate_end", {score=score})
    
    -- 3. Decrement
    self.spins_left = self.spins_left - 1
    
    self:triggerHooks("on_spin_end")
    EventBus.emit(EventBus.Events.SPIN_END, {engine = self})
    
    -- 4. Enter COLLECTING state
    self.state = "COLLECTING"
    self.collect_timer = 0
    EventBus.emit(EventBus.Events.COLLECT_START, {engine = self})
end

-- Called when collecting is done
function Engine:finishCollecting()
    -- Clear pending score (already added in resolveSpin)
    self.pending_score = 0
    
    -- Remove symbols that were marked during calculation
    -- They should already be visually gone by now
    local removed = self.grid:removeMarkedSymbols()
    
    -- Also remove from inventory
    if #removed > 0 then
        for _, item in ipairs(removed) do
            for i = #self.inventory, 1, -1 do
                if self.inventory[i] == item.sym then
                    table.remove(self.inventory, i)
                    break
                end
            end
        end
    end
    
    EventBus.emit(EventBus.Events.COLLECT_END, {engine = self})
    
    -- Check Rent
    if self.spins_left == 0 then
        if self.money >= self.rent then
            local oldMoney = self.money
            local paidRent = self.rent
            self.money = self.money - paidRent
            
            -- Advance floor
            self.floor = (self.floor or 1) + 1
            
            -- Calculate next rent using difficulty curve
            local Difficulty = require("src.core.difficulty")
            local nextRent = Difficulty.calculateRent(self.floor)
            self.spins_max = Difficulty.getSpins(self.floor)
            
            -- Store rent info for display
            self.rent_info = {
                paid = paidRent,
                remaining = self.money,
                next_rent = nextRent,
                next_spins = self.spins_max,
                new_floor = self.floor
            }
            
            -- Apply changes
            self.rent = nextRent
            self.spins_left = self.spins_max
            
            -- Emit rent paid event
            EventBus.emit(EventBus.Events.RENT_PAY, {
                amount = paidRent,
                newRent = self.rent,
                moneyLeft = self.money
            })
            EventBus.emit(EventBus.Events.MONEY_CHANGE, {
                old = oldMoney,
                new = self.money,
                delta = -paidRent
            })
            
            -- Enter rent summary state (will go to shop after)
            self.state = "RENT_PAID"
            return
        else
            self.state = "GAME_OVER"
            EventBus.emit(EventBus.Events.RENT_FAIL, {
                money = self.money,
                rent = self.rent
            })
            EventBus.emit(EventBus.Events.GAME_OVER, {engine = self})
            return
        end
    end

    -- Go directly to shop (no more free draft)
    self:openShop()
end

-- Called when player confirms rent paid screen
function Engine:confirmRentPaid()
    if self.state == "RENT_PAID" then
        -- Skip draft, go directly to shop
        self:openShop()
    end
end

function Engine:startDraft()
    self.state = "DRAFT"
    self.draft_options = {}
    local count = self.config.draft_choices or 3
    for i = 1, count do
        local type_key = Registry.getRandomSymbolKey()
        table.insert(self.draft_options, Registry.createSymbol(type_key))
    end
    
    -- Emit draft start event
    EventBus.emit(EventBus.Events.DRAFT_START, {
        options = self.draft_options,
        engine = self
    })
end

function Engine:pickDraft(index)
    local pickedSymbol = nil
    if index and self.draft_options[index] then
        pickedSymbol = self.draft_options[index]
        table.insert(self.inventory, pickedSymbol)
        table.insert(self.logs, 1, i18n.t("log_drafted") .. pickedSymbol.name)
        
        -- Emit pick event
        EventBus.emit(EventBus.Events.DRAFT_PICK, {
            symbol = pickedSymbol,
            index = index
        })
        EventBus.emit(EventBus.Events.SYMBOL_ADD, {
            symbol = pickedSymbol
        })
    else
        table.insert(self.logs, 1, i18n.t("ui_skip"))
        EventBus.emit(EventBus.Events.DRAFT_SKIP, {})
    end
    self.draft_options = {}
    
    -- Return to idle (draft is now optional/special event only)
    self.state = "IDLE"
end

-- Open shop
function Engine:openShop()
    local Shop = require("src.core.shop")
    local Difficulty = require("src.core.difficulty")
    
    -- Roll for random event
    self.current_event = Difficulty.rollEvent(self.floor or 1)
    if self.current_event then
        -- Apply event effect
        local result = self.current_event.apply(self)
        self.current_event.result = result
        self.state = "EVENT"
        return
    end
    
    self.shop = Shop.new(self.floor or 1)
    self.state = "SHOP"
end

-- Confirm event and proceed to shop
function Engine:confirmEvent()
    if self.state == "EVENT" then
        local Shop = require("src.core.shop")
        self.shop = Shop.new(self.floor or 1)
        self.current_event = nil
        self.state = "SHOP"
    end
end

-- Close shop and return to idle
function Engine:closeShop()
    self.state = "IDLE"
    self.shop = nil
end

return Engine
