-- Example parts definition
-- Place PNG files in this folder and define them here

return {
    -- Frame size for reference
    width = 100,
    height = 150,
    
    -- Parts definition
    parts = {
        -- Body (main part)
        body = {
            image = "body.png",
            x = 0,
            y = 0,
            ox = 50,  -- origin at center
            oy = 75,
            z = 1,    -- draw order
            
            -- Parameter bindings: how this part responds to game state
            bindings = {
                -- "belly" parameter affects scaleX and scaleY
                belly = {
                    scaleX = 0.3,  -- +30% width per unit
                    scaleY = 0.2,  -- +20% height per unit
                },
            },
        },
        
        -- Head
        head = {
            image = "head.png",
            x = 0,
            y = -60,
            ox = 25,
            oy = 25,
            z = 2,
            
            bindings = {
                -- Head bobs when tired
                tired = {
                    rotation = 0.1,  -- slight tilt
                },
            },
        },
        
        -- Eyes (changes with expression)
        eyes_normal = {
            image = "eyes_normal.png",
            x = 0,
            y = -65,
            ox = 20,
            oy = 10,
            z = 3,
        },
        
        -- Arms
        arm_left = {
            image = "arm_left.png",
            x = -40,
            y = -20,
            ox = 10,
            oy = 5,
            z = 0,  -- behind body
        },
        
        arm_right = {
            image = "arm_right.png",
            x = 40,
            y = -20,
            ox = 10,
            oy = 5,
            z = 0,
        },
    },
    
    -- Expressions (swap parts based on expression)
    expressions = {
        neutral = {
            eyes = "eyes_normal",
        },
        happy = {
            eyes = "eyes_happy",
        },
        worried = {
            eyes = "eyes_worried",
        },
    },
}
