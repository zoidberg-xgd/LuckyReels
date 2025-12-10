-- Example spritesheet definition
-- Place spritesheet.png in this folder

return {
    -- Frame dimensions
    frameWidth = 64,
    frameHeight = 64,
    
    -- Animation speed
    frameDuration = 0.1,  -- seconds per frame
    
    -- Animations (frame indices, 1-based)
    animations = {
        idle = {1, 2, 3, 4, 3, 2},           -- Breathing loop
        happy = {5, 6, 7, 8, 7, 6, 5},       -- Happy bounce
        worried = {9, 10, 11, 10},           -- Worried shake
        spin = {12, 13, 14, 15, 14, 13, 12}, -- Excited
    },
}
