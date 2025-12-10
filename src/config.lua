-- src/config.lua
-- Centralized configuration for the game
-- All magic numbers and tunable parameters should be defined here

local Config = {}

--------------------------------------------------------------------------------
-- GRID LAYOUT
--------------------------------------------------------------------------------
Config.grid = {
    rows = 4,
    cols = 5,
    offsetX = 300,
    offsetY = 100,
    cellSize = 80,
    padding = 5,
}

-- Helper to calculate screen position from grid position
function Config.grid.toScreen(r, c)
    local x = Config.grid.offsetX + (c - 1) * (Config.grid.cellSize + Config.grid.padding) + Config.grid.cellSize / 2
    local y = Config.grid.offsetY + (r - 1) * (Config.grid.cellSize + Config.grid.padding) + Config.grid.cellSize / 2
    return x, y
end

--------------------------------------------------------------------------------
-- GAME BALANCE
--------------------------------------------------------------------------------
Config.balance = {
    starting_money = 10,
    starting_rent = 25,
    spins_per_rent = 5,
    rent_multiplier = 1.5,
    rent_base_increase = 25,
    draft_choices = 3,
}

--------------------------------------------------------------------------------
-- ANIMATION TIMING
--------------------------------------------------------------------------------
Config.animation = {
    -- Spin animation
    spin_duration = 2.5,
    reel_delays = {0.6, 0.85, 1.15, 1.55, 2.1},
    spin_accel_duration = 0.12,
    spin_decel_duration = 0.4,
    spin_max_speed = 2200,
    
    -- Reel stop effects
    slam_duration = 0.05,
    bounce_duration = 0.2,
    slam_offset = 30,
    shake_intensity = 6,
    
    -- Coin collection
    coin_flight_duration_min = 0.7,
    coin_flight_duration_max = 1.0,
    coin_spawn_delay = 0.08,
    coin_symbol_delay = 0.12,
    coin_initial_delay = 0.3,
    collect_min_wait = 1.5,
    
    -- Interactions
    interaction_line_duration = 0.25,
    interaction_effect_duration = 0.35,
    interaction_delay = 0.2,
    interaction_stagger = 0.2,
}

--------------------------------------------------------------------------------
-- VISUAL EFFECTS
--------------------------------------------------------------------------------
Config.effects = {
    -- Screen shake
    shake_decay = true,
    
    -- Coins
    coin_size_min = 14,
    coin_size_max = 22,
    coin_arc_height = 120,
    
    -- Particles
    sparkle_count = 5,
    coin_burst_count = 15,
    
    -- Win thresholds
    big_win_threshold = 20,
    medium_win_threshold = 10,
}

--------------------------------------------------------------------------------
-- UI LAYOUT
--------------------------------------------------------------------------------
Config.ui = {
    -- HUD
    hud_x = 30,
    hud_y = 35,
    hud_width = 200,
    hud_height = 130,
    
    -- Spin button
    spin_button_width = 420,
    spin_button_height = 70,
    spin_button_y = 545,
    
    -- Draft cards
    draft_card_width = 180,
    draft_card_height = 260,
    draft_card_gap = 220,
    draft_start_x = 180,
    draft_start_y = 160,
}

--------------------------------------------------------------------------------
-- COLORS
--------------------------------------------------------------------------------
Config.colors = {
    -- Rarity colors
    common = {0.5, 0.5, 0.5},
    uncommon = {0.3, 0.7, 0.3},
    rare = {0.6, 0.3, 0.8},
    
    -- UI colors
    money = {1, 0.85, 0.2},
    rent = {1, 0.5, 0.5},
    spins = {0.5, 1, 0.5},
    inventory = {0.7, 0.7, 1},
    
    -- Effect colors
    coin = {1, 0.75, 0.1},
    sparkle = {1, 1, 0.5},
    glow = {1, 1, 0.5},
}

--------------------------------------------------------------------------------
-- RARITY WEIGHTS
--------------------------------------------------------------------------------
Config.rarity = {
    weights = {
        [1] = 100,  -- Common
        [2] = 30,   -- Uncommon
        [3] = 10,   -- Rare
    },
    names = {
        [1] = "普通",
        [2] = "罕见", 
        [3] = "稀有",
    }
}

--------------------------------------------------------------------------------
-- DEBUG
--------------------------------------------------------------------------------
Config.debug = {
    show_fps = false,
    show_grid_coords = false,
    instant_spin = false,
    skip_animations = false,
}

return Config
