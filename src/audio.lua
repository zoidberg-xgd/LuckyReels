-- src/audio.lua
-- Procedural audio generation for game sounds
-- Generates simple sound effects without external files

local Audio = {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

Audio.sfxVolume = 0.8
Audio.musicVolume = 0.7
Audio.enabled = true

-- Generated sounds cache
Audio.sounds = {}

--------------------------------------------------------------------------------
-- Procedural Sound Generation
--------------------------------------------------------------------------------

-- Generate a simple sine wave beep
local function generateBeep(frequency, duration, volume, fadeOut)
    local sampleRate = 44100
    local samples = math.floor(sampleRate * duration)
    local data = love.sound.newSoundData(samples, sampleRate, 16, 1)
    
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local envelope = 1.0
        
        if fadeOut then
            envelope = 1.0 - (i / samples)
        end
        
        local sample = math.sin(2 * math.pi * frequency * t) * volume * envelope
        data:setSample(i, sample)
    end
    
    return love.audio.newSource(data, "static")
end

-- Generate a coin sound (rising pitch)
local function generateCoin()
    local sampleRate = 44100
    local duration = 0.15
    local samples = math.floor(sampleRate * duration)
    local data = love.sound.newSoundData(samples, sampleRate, 16, 1)
    
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local progress = i / samples
        
        -- Rising frequency
        local freq = 800 + progress * 400
        local envelope = (1.0 - progress) * 0.5
        
        local sample = math.sin(2 * math.pi * freq * t) * envelope
        data:setSample(i, sample)
    end
    
    return love.audio.newSource(data, "static")
end

-- Generate a click sound
local function generateClick()
    local sampleRate = 44100
    local duration = 0.05
    local samples = math.floor(sampleRate * duration)
    local data = love.sound.newSoundData(samples, sampleRate, 16, 1)
    
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local progress = i / samples
        local envelope = (1.0 - progress) * 0.8
        
        local sample = (math.random() * 2 - 1) * envelope * 0.3
        sample = sample + math.sin(2 * math.pi * 1000 * t) * envelope * 0.2
        data:setSample(i, sample)
    end
    
    return love.audio.newSource(data, "static")
end

-- Generate a spin/reel sound
local function generateSpin()
    local sampleRate = 44100
    local duration = 0.1
    local samples = math.floor(sampleRate * duration)
    local data = love.sound.newSoundData(samples, sampleRate, 16, 1)
    
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local progress = i / samples
        
        local freq = 200 + math.sin(progress * 20) * 100
        local envelope = 0.3 * (1.0 - progress * 0.5)
        
        local sample = math.sin(2 * math.pi * freq * t) * envelope
        sample = sample + (math.random() * 2 - 1) * 0.1 * envelope
        data:setSample(i, sample)
    end
    
    return love.audio.newSource(data, "static")
end

-- Generate reel stop sound
local function generateReelStop()
    local sampleRate = 44100
    local duration = 0.12
    local samples = math.floor(sampleRate * duration)
    local data = love.sound.newSoundData(samples, sampleRate, 16, 1)
    
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local progress = i / samples
        
        -- Thump with quick decay
        local freq = 150 - progress * 50
        local envelope = math.exp(-progress * 15) * 0.6
        
        local sample = math.sin(2 * math.pi * freq * t) * envelope
        sample = sample + (math.random() * 2 - 1) * envelope * 0.3
        data:setSample(i, sample)
    end
    
    return love.audio.newSource(data, "static")
end

-- Generate win sound (happy jingle)
local function generateWin()
    local sampleRate = 44100
    local duration = 0.4
    local samples = math.floor(sampleRate * duration)
    local data = love.sound.newSoundData(samples, sampleRate, 16, 1)
    
    local notes = {523, 659, 784, 1047}  -- C5, E5, G5, C6
    
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local progress = i / samples
        
        local noteIndex = math.floor(progress * #notes) + 1
        noteIndex = math.min(noteIndex, #notes)
        local freq = notes[noteIndex]
        
        local envelope = 0.4 * (1.0 - progress * 0.7)
        
        local sample = math.sin(2 * math.pi * freq * t) * envelope
        sample = sample + math.sin(2 * math.pi * freq * 2 * t) * envelope * 0.3
        data:setSample(i, sample)
    end
    
    return love.audio.newSource(data, "static")
end

-- Generate big win sound
local function generateBigWin()
    local sampleRate = 44100
    local duration = 0.6
    local samples = math.floor(sampleRate * duration)
    local data = love.sound.newSoundData(samples, sampleRate, 16, 1)
    
    local notes = {523, 659, 784, 1047, 1319}  -- C5, E5, G5, C6, E6
    
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local progress = i / samples
        
        local noteIndex = math.floor(progress * #notes) + 1
        noteIndex = math.min(noteIndex, #notes)
        local freq = notes[noteIndex]
        
        local envelope = 0.5 * (1.0 - progress * 0.5)
        
        local sample = math.sin(2 * math.pi * freq * t) * envelope
        sample = sample + math.sin(2 * math.pi * freq * 1.5 * t) * envelope * 0.4
        sample = sample + math.sin(2 * math.pi * freq * 2 * t) * envelope * 0.2
        data:setSample(i, sample)
    end
    
    return love.audio.newSource(data, "static")
end

-- Generate error/negative sound
local function generateError()
    local sampleRate = 44100
    local duration = 0.2
    local samples = math.floor(sampleRate * duration)
    local data = love.sound.newSoundData(samples, sampleRate, 16, 1)
    
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local progress = i / samples
        
        -- Descending buzz
        local freq = 300 - progress * 100
        local envelope = 0.4 * (1.0 - progress)
        
        local sample = math.sin(2 * math.pi * freq * t) * envelope
        sample = sample + math.sin(2 * math.pi * freq * 1.5 * t) * envelope * 0.5
        data:setSample(i, sample)
    end
    
    return love.audio.newSource(data, "static")
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function Audio.init()
    -- Check if love.sound is available (not in tests)
    if not love or not love.sound then
        print("[Audio] LÖVE audio not available, skipping sound generation")
        return
    end
    
    -- Generate all sounds
    Audio.sounds = {
        coin = generateCoin(),
        click = generateClick(),
        spin = generateSpin(),
        reel_stop = generateReelStop(),
        win = generateWin(),
        big_win = generateBigWin(),
        error = generateError(),
        buy = generateCoin(),
        sell = generateClick(),
    }
    
    -- Count sounds
    local count = 0
    for _ in pairs(Audio.sounds) do count = count + 1 end
    print("[Audio] Generated " .. count .. " procedural sounds")
end

--------------------------------------------------------------------------------
-- Playback
--------------------------------------------------------------------------------

function Audio.play(name, volume, pitch)
    if not Audio.enabled then return end
    
    local sound = Audio.sounds[name]
    if sound then
        local clone = sound:clone()
        clone:setVolume((volume or 1.0) * Audio.sfxVolume)
        if pitch then
            clone:setPitch(pitch)
        end
        clone:play()
        return clone
    end
end

function Audio.setVolume(sfx, music)
    if sfx then Audio.sfxVolume = sfx end
    if music then Audio.musicVolume = music end
end

function Audio.setEnabled(enabled)
    Audio.enabled = enabled
end

return Audio
