-- src/core/config.lua
-- Centralized game configuration
-- All magic numbers and settings should be defined here

local Config = {}

--------------------------------------------------------------------------------
-- Display Settings
--------------------------------------------------------------------------------

Config.screen = {
    width = 1024,
    height = 768,
    title = "LuckyReels - 幸运转轴",
}

--------------------------------------------------------------------------------
-- Grid Settings
--------------------------------------------------------------------------------

Config.grid = {
    rows = 4,
    cols = 5,
    cellSize = 80,
    padding = 5,
    offsetX = 300,
    offsetY = 100,
    
    -- Helper function to get screen position from grid position
    toScreen = function(r, c)
        local x = Config.grid.offsetX + (c - 1) * (Config.grid.cellSize + Config.grid.padding)
        local y = Config.grid.offsetY + (r - 1) * (Config.grid.cellSize + Config.grid.padding)
        return x, y
    end,
    
    -- Get center of a cell
    toCenterScreen = function(r, c)
        local x, y = Config.grid.toScreen(r, c)
        return x + Config.grid.cellSize / 2, y + Config.grid.cellSize / 2
    end,
}

--------------------------------------------------------------------------------
-- HUD Settings
--------------------------------------------------------------------------------

Config.hud = {
    x = 25,
    y = 30,
    width = 220,
    height = 175,
    
    -- Coin target for flying coins
    coinTargetX = 25,
    coinTargetY = 30,
}

--------------------------------------------------------------------------------
-- Game Balance
--------------------------------------------------------------------------------

Config.balance = {
    -- Starting values
    starting_money = 5,
    starting_rent = 15,
    starting_spins = 6,
    
    -- Inventory
    inventory_max = 20,
    
    -- Starting symbols
    starting_inventory = {"coin", "coin", "coin", "cherry", "flower", "cat", "milk"},
    
    -- Upgrade system
    upgrade = {
        symbols_needed = 3,
        max_level = 3,
        value_multiplier = 2,
        destruction_reward_ratio = 0.5,
    },
}

--------------------------------------------------------------------------------
-- Shop Settings
--------------------------------------------------------------------------------

Config.shop = {
    symbol_slots = 3,
    relic_slots = 1,
    consumable_slots = 2,
    
    -- Base prices by rarity
    symbol_prices = {
        [1] = 3,   -- Common
        [2] = 8,   -- Uncommon
        [3] = 18,  -- Rare
    },
    
    relic_base_price = 12,
    consumable_base_price = 5,
    reroll_cost = 1,
    sell_ratio = 0.5,
    price_scale_per_floor = 0.05,
}

--------------------------------------------------------------------------------
-- Difficulty Curve
--------------------------------------------------------------------------------

Config.difficulty = {
    -- Rent by phase
    phases = {
        tutorial = {floors = {1, 5}, base = 10, increment = 5, spins = 6},
        growth = {floors = {6, 10}, base = 35, increment = 8, spins = 5},
        challenge = {floors = {11, 15}, base = 75, increment = 15, spins = 5},
        mastery = {floors = {16, 20}, base = 150, increment = 25, spins = 4},
    },
    
    -- Endless mode
    endless = {
        start_floor = 21,
        base_rent = 275,
        growth_rate = 1.12,
        spins = 4,
    },
    
    -- Boss floors
    boss_interval = 5,
    boss_multiplier = 2,
    
    -- Checkpoints
    checkpoints = {3, 7},
    
    -- Random events
    events = {
        base_chance = 0.2,
        chance_per_floor = 0.05,
        max_chance = 0.7,
    },
}

--------------------------------------------------------------------------------
-- Animation Timings
--------------------------------------------------------------------------------

Config.animation = {
    -- Spin animation
    spin_duration = 2.5,
    reel_delays = {0.6, 0.85, 1.15, 1.55, 2.1},
    
    -- Collecting phase
    collect_min_wait = 0.8,
    
    -- Coin animation
    coin_duration_min = 0.25,
    coin_duration_max = 0.35,
    coin_size_min = 10,
    coin_size_max = 14,
    
    -- Scoring animation (Balatro style)
    scoring = {
        punch_duration = 0.08,
        hold_duration = 0.05,
        coins_wait = 0.15,
        symbol_delay = 0.25,
    },
    
    -- HUD bounce
    hud_bounce_decay = 3,
    hud_bounce_scale = 0.3,
}

--------------------------------------------------------------------------------
-- Visual Settings
--------------------------------------------------------------------------------

Config.visual = {
    -- Rarity colors
    rarity_colors = {
        [1] = {0.6, 0.6, 0.6},    -- Common: Gray
        [2] = {0.3, 0.7, 1},      -- Uncommon: Blue
        [3] = {1, 0.8, 0.2},      -- Rare: Gold
    },
    
    -- Quality colors (upgrade levels)
    quality_colors = {
        [1] = {0.7, 0.7, 0.7},    -- Normal
        [2] = {0.4, 0.8, 1},      -- Enhanced
        [3] = {1, 0.6, 0.9},      -- Perfected
    },
    
    -- UI colors
    colors = {
        money = {1, 0.9, 0.3},
        rent = {1, 0.4, 0.3},
        positive = {0.3, 1, 0.3},
        negative = {1, 0.3, 0.3},
        neutral = {0.8, 0.8, 0.3},
    },
}

--------------------------------------------------------------------------------
-- Audio Settings
--------------------------------------------------------------------------------

Config.audio = {
    master_volume = 1.0,
    sfx_volume = 0.7,
    music_volume = 0.5,
}

--------------------------------------------------------------------------------
-- Layout Settings (screen positioning)
--------------------------------------------------------------------------------

Config.layout = {
    -- Main game screen
    game = {
        logsX = 25,
        logsY = 235,
        inventoryBtnX = -130,  -- Negative = from right edge
        inventoryBtnY = 100,
    },
    
    -- Shop screen
    shop = {
        titleY = 30,
        moneyY = 70,
        cardsY = 120,
        cardWidth = 130,
        cardHeight = 180,
        cardGap = 15,
        
        -- Inventory in shop
        inventoryY = -130,  -- Negative = from bottom
        inventoryCellSize = 42,
        inventoryCellGap = 10,
        
        -- Buttons
        buttonY = -50,  -- Negative = from bottom
        buttonWidth = 120,
        buttonHeight = 35,
    },
}

--------------------------------------------------------------------------------
-- UI Component Settings
--------------------------------------------------------------------------------

Config.ui = {
    -- Inventory button
    inventoryBtn = {
        width = 80,
        height = 35,
    },
    
    -- Inventory panel
    inventoryPanel = {
        iconSize = 32,
        gap = 4,
        cols = 5,
        padding = 10,
    },
    
    -- Tooltips
    tooltip = {
        width = 200,
        padding = 10,
    },
    
    -- Buttons
    button = {
        cornerRadius = 6,
    },
}

--------------------------------------------------------------------------------
-- Effects Settings
--------------------------------------------------------------------------------

Config.effects = {
    -- Particles
    particle = {
        baseSpeed = 100,
        speedVariance = 50,
        gravity = 100,
    },
    
    -- Sparkles
    sparkle = {
        count = 8,
        speed = 80,
        speedVariance = 40,
    },
    
    -- Screen shake
    shake = {
        defaultIntensity = 10,
        defaultDuration = 0.3,
    },
    
    -- Coin burst
    coinBurst = {
        speed = 100,
        speedVariance = 80,
    },
}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

-- Get rent for a specific floor
function Config.getRent(floor)
    local d = Config.difficulty
    
    for name, phase in pairs(d.phases) do
        if floor >= phase.floors[1] and floor <= phase.floors[2] then
            return phase.base + (floor - phase.floors[1]) * phase.increment
        end
    end
    
    -- Endless mode
    if floor >= d.endless.start_floor then
        return math.floor(d.endless.base_rent * (d.endless.growth_rate ^ (floor - d.endless.start_floor)))
    end
    
    return 15  -- Fallback
end

-- Get spins for a specific floor
function Config.getSpins(floor)
    local d = Config.difficulty
    
    for name, phase in pairs(d.phases) do
        if floor >= phase.floors[1] and floor <= phase.floors[2] then
            return phase.spins
        end
    end
    
    return d.endless.spins
end

-- Check if floor is a boss floor
function Config.isBossFloor(floor)
    return floor % Config.difficulty.boss_interval == 0
end

-- Get symbol price by rarity
function Config.getSymbolPrice(rarity, floor)
    local base = Config.shop.symbol_prices[rarity] or 5
    local scale = 1 + (floor - 1) * Config.shop.price_scale_per_floor
    return math.floor(base * scale)
end

return Config
