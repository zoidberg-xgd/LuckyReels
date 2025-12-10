-- src/game.lua
local Engine = require("src.core.engine")
local Registry = require("src.core.registry")
local Effects = require("src.effects")
local Config = require("src.core.config")
local API = require("src.core.api")
local i18n = require("src.i18n")

-- Load Content
require("src.content.symbols")
require("src.content.relics")
require("src.content.consumables")

local Game = Engine.new()

-- Override init to inject our specific config
local original_init = Game.init
function Game:init()
    -- Use centralized config
    local config = {
        rows = Config.grid.rows,
        cols = Config.grid.cols,
        starting_money = Config.balance.starting_money,
        starting_rent = Config.balance.starting_rent,
        spins_per_rent = Config.balance.starting_spins,
        starting_inventory = Config.balance.starting_inventory
    }
    original_init(self, config)
    
    -- Register this game instance with API
    API.Game.setInstance(self)
    
    -- Initialize displayed money for effects
    Effects.setDisplayedMoney(self.money)
    
    -- Set coin target to HUD position (from Config)
    Effects.setCoinTarget(Config.hud.coinTargetX, Config.hud.coinTargetY)
    
    -- Set up coin collection callback - adds money when coins arrive
    Effects.onCoinCollected = function(value)
        self.money = self.money + value
    end
    
    -- Give a starter relic for testing
    table.insert(self.relics, Registry.createRelic("lucky_cat"))
    -- Give a starter removal token
    table.insert(self.consumables, Registry.createConsumable("removal_token"))
    
    -- Start BGM
    Effects.playBGM()
end

-- Input handling (Adapter)
local UI = require("src.ui")

function Game:keypressed(key)
    if self.state == "GAME_OVER" then
        if key == "r" then
            self:init()
            return
        end
    end
    
    if self.state == "IDLE" then
        if key == "space" then self:spin() end
    elseif self.state == "RENT_PAID" then
        if key == "space" or key == "return" then
            self:confirmRentPaid()
        end
    elseif self.state == "DRAFT" then
        if key == "1" then self:pickDraft(1) end
        if key == "2" then self:pickDraft(2) end
        if key == "3" then self:pickDraft(3) end
        if key == "4" then self:pickDraft(nil) end -- Skip
    elseif self.state == "REMOVING" then
        if key == "escape" then
            self.state = "IDLE"
            self.active_consumable_index = nil
        end
    end
    
    -- Toggle inventory with Tab or I
    if key == "tab" or key == "i" then
        UI.toggleInventory()
    end
end

function Game:mousepressed(x, y, button)
    if button ~= 1 then return end -- Only left click
    
    local id = UI.getClickedId(x, y)
    
    -- Handle inventory toggle
    if id == "INVENTORY_BTN" then
        UI.toggleInventory()
        return
    end
    
    -- Handle language switch
    if id == "LANG_BTN" then
        i18n.nextLang()
        return
    end
    
    if not id then 
        -- Click outside any zone - close inventory if open
        if UI.inventoryOpen then
            UI.inventoryOpen = false
        end
        return 
    end
    
    if self.state == "IDLE" then
        if id == "SPIN" then
            self:spin()
        elseif string.match(id, "CONSUMABLE_") then
            local index = tonumber(string.match(id, "CONSUMABLE_(%d+)"))
            self:useConsumable(index)
        end
    elseif self.state == "RENT_PAID" then
        if id == "RENT_CONTINUE" then
            self:confirmRentPaid()
        end
    elseif self.state == "EVENT" then
        if id == "EVENT_CONTINUE" then
            self:confirmEvent()
        end
    elseif self.state == "SHOP" then
        if id == "SHOP_LEAVE" then
            self:closeShop()
            self.selected_inv_index = nil
        elseif id == "SHOP_REROLL" then
            self.shop:reroll(self)
        elseif string.match(id, "SHOP_SYM_") then
            local index = tonumber(string.match(id, "SHOP_SYM_(%d+)"))
            self.shop:buySymbol(index, self)
        elseif string.match(id, "SHOP_RELIC_") then
            local index = tonumber(string.match(id, "SHOP_RELIC_(%d+)"))
            self.shop:buyRelic(index, self)
        elseif string.match(id, "INV_SYM_") then
            local index = tonumber(string.match(id, "INV_SYM_(%d+)"))
            self.selected_inv_index = index
            -- Store click position for menu
            self.selected_inv_x, self.selected_inv_y = love.mouse.getPosition()
        elseif id == "ACTION_SELL" and self.selected_inv_index then
            self.shop:sellSymbol(self.selected_inv_index, self)
            self.selected_inv_index = nil
        elseif id == "ACTION_UPGRADE" and self.selected_inv_index then
            local Upgrade = require("src.core.upgrade")
            local sym = self.inventory[self.selected_inv_index]
            if sym then
                Upgrade.upgradeSymbol(self.inventory, sym.key)
            end
            self.selected_inv_index = nil
        else
            -- Click elsewhere closes menu
            self.selected_inv_index = nil
        end
    elseif self.state == "DRAFT" then
        if id == "DRAFT_1" then self:pickDraft(1) end
        if id == "DRAFT_2" then self:pickDraft(2) end
        if id == "DRAFT_3" then self:pickDraft(3) end
        if id == "SKIP" then self:pickDraft(nil) end
    elseif self.state == "REMOVING" then
        if string.match(id, "REMOVE_") then
            local index = tonumber(string.match(id, "REMOVE_(%d+)"))
            local success = self:removeSymbolFromInventory(index)
            if success then
                self:finishConsumable()
            end
        elseif id == "CANCEL_REMOVE" then
            self.state = "IDLE"
            self.active_consumable_index = nil
        end
    end
end

-- Draw handling (Adapter)
function Game:draw()
    -- Apply screen shake
    local shakeX, shakeY = Effects.getShakeOffset()
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)
    
    -- Reset click zones for this frame
    UI.resetZones()
    
    -- Prepare Animation State
    local animState = nil
    if self.state == "SPINNING" then
        animState = {
            isSpinning = true,
            timer = self.spin_timer,
            delays = self.reel_delays
        }
    end
    
    -- Draw Game Area (use Config for positions)
    UI.drawGrid(self.grid, Config.grid.offsetX, Config.grid.offsetY, Config.grid.cellSize, animState)
    
    -- Only draw HUD and Logs when not in overlay states
    if self.state ~= "DRAFT" and self.state ~= "GAME_OVER" and self.state ~= "RENT_PAID" and self.state ~= "SHOP" then
        UI.drawHUD(self.money, self.rent, self.spins_left, #self.inventory, self.state == "SPINNING", self.floor)
        UI.drawLogs(self.logs, Config.layout.game.logsX, Config.layout.game.logsY)
        -- Draw inventory button (collapsible) - on right side
        local invBtnX = love.graphics.getWidth() + Config.layout.game.inventoryBtnX
        UI.drawInventoryButton(self.inventory, invBtnX, Config.layout.game.inventoryBtnY)
    end
    
    if self.state == "DRAFT" then
        UI.drawDraft(self.draft_options, {
            money = self.money,
            rent = self.rent,
            spins_left = self.spins_left,
            inventory_count = #self.inventory
        })
    elseif self.state == "GAME_OVER" then
        UI.drawGameOver(self.money, self.rent)
    elseif self.state == "REMOVING" then
        UI.drawRemovalSelect(self.inventory)
    elseif self.state == "RENT_PAID" then
        UI.drawRentPaid(self.rent_info)
    elseif self.state == "SHOP" then
        UI.drawShop(self.shop, self)
        -- Draw action menu if symbol selected (at stored position)
        if self.selected_inv_index and self.inventory[self.selected_inv_index] then
            local sym = self.inventory[self.selected_inv_index]
            UI.drawSymbolActionMenu(sym, self.selected_inv_index, self, self.selected_inv_x or 100, self.selected_inv_y or 100)
        end
    elseif self.state == "EVENT" then
        UI.drawEvent(self.current_event)
    end
    
    -- Draw Relics
    UI.drawRelics(self.relics)
    UI.drawConsumables(self.consumables)
    
    -- Draw language button (always visible)
    UI.drawLanguageButton()
    
    love.graphics.pop()
    
    -- Draw effects on top (not affected by main shake)
    Effects.draw()
end

-- Update handling (Adapter)
function Game:update(dt)
    local EngineClass = require("src.core.engine")
    
    -- Track previous state for effect triggers
    local wasSpinning = self.state == "SPINNING"
    local prevMoney = self.money
    
    -- Update engine
    EngineClass.update(self, dt)
    
    -- Update effects
    Effects.update(dt)
    UI.update(dt)
    
    -- Sync displayed money with actual money (handles rent payment, etc.)
    Effects.syncDisplayedMoney(self.money)
    
    -- Handle COLLECTING state - wait for coins and death animations to finish
    if self.state == "COLLECTING" then
        self.collect_timer = self.collect_timer + dt
        
        -- Check if any symbols are still dying (have death timer < 0.4)
        local stillDying = false
        for r = 1, self.grid.rows do
            for c = 1, self.grid.cols do
                local sym = self.grid.cells[r][c]
                if sym and sym._markedForRemoval then
                    local t = sym._deathTimer or 0
                    if t < 0.5 then  -- Wait for death animation to complete
                        stillDying = true
                        break
                    end
                end
            end
            if stillDying then break end
        end
        
        -- Dynamic wait time based on interactions
        local interactionCount = self.last_interactions and #self.last_interactions or 0
        local dynamicWait = self.collect_min_wait + interactionCount * 0.3
        
        -- Wait for: minimum time, coins collected, effects done, AND death animations complete
        if self.collect_timer >= dynamicWait and not Effects.isCollecting() and not Effects.hasActiveInteractions() and not stillDying then
            self:finishCollecting()
        end
    end
    
    -- Trigger effects on spin end
    if wasSpinning and self.state == "COLLECTING" then
        -- First, process any symbol interactions (consume, boost, etc.)
        if self.last_interactions and #self.last_interactions > 0 then
            Effects.processInteractions(self.last_interactions)
        end
        
        -- Use pending_score for win amount
        local winAmount = self.pending_score or 0
        if winAmount > 0 then
            -- Use Config for grid settings
            local cellSize = Config.grid.cellSize
            
            -- Calculate delay based on interactions
            local interactionDelay = self.last_interactions and #self.last_interactions * 0.25 or 0
            local baseDelay = 0.1 + interactionDelay
            
            -- Clear any previous scoring
            Effects.clearScoring()
            
            -- Queue each symbol for Balatro-style scoring animation
            local symbolIndex = 0
            for r = 1, self.grid.rows do
                for c = 1, self.grid.cols do
                    local sym = self.grid.cells[r][c]
                    if sym and sym.base_value and sym.base_value > 0 then
                        local cellX, cellY = Config.grid.toScreen(r, c)
                        local symValue = sym.base_value
                        
                        -- Queue this symbol for scoring (Balatro style!)
                        Effects.queueSymbolScore(
                            cellX, cellY, cellSize, cellSize,
                            symValue,
                            Config.visual.colors.money,
                            baseDelay + symbolIndex * Config.animation.scoring.symbol_delay
                        )
                        
                        symbolIndex = symbolIndex + 1
                    end
                end
            end
            
            -- Additional effects based on win size
            if winAmount >= 20 then
                Effects.screenShake(12, 0.3)
                Effects.screenFlash(1, 0.9, 0.3, 0.3, 0.15)
                Effects.addPopup(love.graphics.getWidth()/2 - 50, 200, "+" .. winAmount .. "!", {1, 0.8, 0.2}, 32)
                Effects.playSound("big_win")
            elseif winAmount >= 10 then
                Effects.screenShake(6, 0.2)
                Effects.addPopup(love.graphics.getWidth()/2 - 30, 220, "+" .. winAmount, {1, 1, 0.4}, 28)
                Effects.playSound("win")
            end
        end
    end
end

return Game
