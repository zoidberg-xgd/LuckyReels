-- examples/state_sprite_demo.lua
-- State-Driven Sprite System 使用示例
--
-- 运行: lua examples/state_sprite_demo.lua

package.path = package.path .. ";?.lua;?/init.lua"
local StateSprite = require("lib.state_sprite")

print("========================================")
print("State-Driven Sprite System Demo")
print("========================================\n")

--------------------------------------------------------------------------------
-- 示例 1: 基础状态切换
--------------------------------------------------------------------------------
print("--- 示例 1: 基础状态切换 ---")

local character = StateSprite.new({
    states = {
        neutral = {sprite = "neutral.png", priority = 0},
        happy = {sprite = "happy.png", priority = 1},
        sad = {sprite = "sad.png", priority = 1},
    },
    defaultState = "neutral",
})

print("初始状态: " .. character:getState())

character:setState("happy")
print("切换后: " .. character:getState())

character:setState("sad")
print("再次切换: " .. character:getState())

print()

--------------------------------------------------------------------------------
-- 示例 2: 条件自动切换
--------------------------------------------------------------------------------
print("--- 示例 2: 条件自动切换 ---")

local npc = StateSprite.new({
    states = {
        neutral = {sprite = "neutral.png"},
        happy = {sprite = "happy.png"},
        worried = {sprite = "worried.png"},
        critical = {sprite = "critical.png"},
    },
    conditions = {
        {state = "critical", when = function(ctx) return ctx.hp < 20 end, priority = 10},
        {state = "happy", when = function(ctx) return ctx.money > 100 end, priority = 1},
        {state = "worried", when = function(ctx) return ctx.money < 20 end, priority = 1},
    },
    defaultState = "neutral",
})

print("上下文: hp=100, money=50")
npc:updateContext({hp = 100, money = 50})
print("状态: " .. npc:getState())

print("\n上下文: hp=100, money=150")
npc:updateContext({hp = 100, money = 150})
print("状态: " .. npc:getState())

print("\n上下文: hp=100, money=10")
npc:updateContext({hp = 100, money = 10})
print("状态: " .. npc:getState())

print("\n上下文: hp=15, money=150 (critical 优先级更高)")
npc:updateContext({hp = 15, money = 150})
print("状态: " .. npc:getState())

print()

--------------------------------------------------------------------------------
-- 示例 3: 临时状态
--------------------------------------------------------------------------------
print("--- 示例 3: 临时状态 ---")

local player = StateSprite.new({
    states = {
        idle = {sprite = "idle.png"},
        surprised = {sprite = "surprised.png"},
        hurt = {sprite = "hurt.png"},
    },
    defaultState = "idle",
})

print("初始状态: " .. player:getState())

player:setState("surprised", {duration = 2.0})
print("触发惊讶 (2秒): " .. player:getState())

player:update(1.0)
print("1秒后: " .. player:getState())

player:update(1.5)
print("2.5秒后 (恢复): " .. player:getState())

print()

--------------------------------------------------------------------------------
-- 示例 4: 过渡动画
--------------------------------------------------------------------------------
print("--- 示例 4: 过渡动画 ---")

local sprite = StateSprite.new({
    states = {
        a = {sprite = "a.png"},
        b = {sprite = "b.png"},
    },
    transitions = {
        default = {duration = 1.0, easing = "linear"},
    },
    defaultState = "a",
})

print("初始状态: " .. sprite:getState())
print("过渡中: " .. tostring(sprite:isTransitioning()))

sprite:setState("b")
print("\n切换到 b")
print("过渡中: " .. tostring(sprite:isTransitioning()))
print("过渡进度: " .. string.format("%.0f%%", sprite.transitionProgress * 100))

sprite:update(0.3)
print("\n0.3秒后")
print("过渡进度: " .. string.format("%.0f%%", sprite.transitionProgress * 100))

sprite:update(0.5)
print("\n0.8秒后")
print("过渡进度: " .. string.format("%.0f%%", sprite.transitionProgress * 100))

sprite:update(0.3)
print("\n1.1秒后")
print("过渡中: " .. tostring(sprite:isTransitioning()))
print("过渡进度: " .. string.format("%.0f%%", sprite.transitionProgress * 100))

print()

--------------------------------------------------------------------------------
-- 示例 5: 状态变化监听
--------------------------------------------------------------------------------
print("--- 示例 5: 状态变化监听 ---")

local monitored = StateSprite.new({
    states = {
        idle = {sprite = "idle.png"},
        walking = {sprite = "walking.png"},
        running = {sprite = "running.png"},
    },
    defaultState = "idle",
})

monitored:onStateChange(function(old, new)
    print(string.format("  [监听] %s -> %s", old, new))
end)

print("切换状态...")
monitored:setState("walking")
monitored:setState("running")
monitored:setState("idle")

print()

--------------------------------------------------------------------------------
-- 示例 6: 缓动函数
--------------------------------------------------------------------------------
print("--- 示例 6: 缓动函数 ---")

local easings = {"linear", "outQuad", "outCubic", "outElastic", "outBounce"}

for _, name in ipairs(easings) do
    local fn = StateSprite.Easing[name]
    local values = {}
    for t = 0, 1, 0.25 do
        table.insert(values, string.format("%.2f", fn(t)))
    end
    print(string.format("  %s: %s", name, table.concat(values, " -> ")))
end

print()

--------------------------------------------------------------------------------
-- 示例 7: 分层精灵
--------------------------------------------------------------------------------
print("--- 示例 7: 分层精灵 ---")

local layered = StateSprite.newLayered({
    layers = {
        {name = "body", z = 0},
        {name = "face", z = 1},
        {name = "clothes", z = 2},
        {name = "accessory", z = 3},
    },
    layerStates = {
        face = {
            neutral = "face_neutral.png",
            happy = "face_happy.png",
            blush = "face_blush.png",
        },
        clothes = {
            normal = "clothes_normal.png",
            damaged = "clothes_damaged.png",
            torn = "clothes_torn.png",
        },
    },
})

print("层顺序 (按 z):")
for i, layer in ipairs(layered.layers) do
    print(string.format("  %d. %s (z=%d)", i, layer.name, layer.z))
end

print("\n初始层状态:")
print("  face: " .. tostring(layered:getLayerState("face")))
print("  clothes: " .. tostring(layered:getLayerState("clothes")))

layered:setLayerState("face", "happy")
layered:setLayerState("clothes", "damaged")

print("\n修改后:")
print("  face: " .. layered:getLayerState("face"))
print("  clothes: " .. layered:getLayerState("clothes"))

print("\n隐藏 clothes 层:")
layered:setLayerVisible("clothes", false)
print("  clothes visible: " .. tostring(layered.layersByName.clothes.visible))

print()

--------------------------------------------------------------------------------
-- 示例 8: 分层精灵条件
--------------------------------------------------------------------------------
print("--- 示例 8: 分层精灵条件 ---")

local character2 = StateSprite.newLayered({
    layers = {
        {name = "face", z = 0},
    },
    layerStates = {
        face = {
            neutral = "neutral.png",
            blush = "blush.png",
            angry = "angry.png",
        },
    },
})

character2:addCondition("face", {
    state = "blush",
    when = function(ctx) return ctx.embarrassed end,
})

character2:addCondition("face", {
    state = "angry",
    when = function(ctx) return ctx.angry end,
})

print("初始 face: " .. tostring(character2:getLayerState("face")))

character2:updateContext({embarrassed = true})
print("embarrassed=true -> face: " .. character2:getLayerState("face"))

character2:updateContext({embarrassed = false, angry = true})
print("angry=true -> face: " .. character2:getLayerState("face"))

print()

--------------------------------------------------------------------------------
-- 示例 9: 动态添加状态和条件
--------------------------------------------------------------------------------
print("--- 示例 9: 动态添加 ---")

local dynamic = StateSprite.new({
    states = {
        idle = {sprite = "idle.png"},
    },
    defaultState = "idle",
})

print("初始状态数: " .. (function()
    local count = 0
    for _ in pairs(dynamic.states) do count = count + 1 end
    return count
end)())

-- 动态添加状态
dynamic:addState("special", {sprite = "special.png", priority = 5})
dynamic:addState("ultra", {sprite = "ultra.png", priority = 10})

print("添加后状态数: " .. (function()
    local count = 0
    for _ in pairs(dynamic.states) do count = count + 1 end
    return count
end)())

-- 动态添加条件
dynamic:addCondition({
    state = "special",
    when = function(ctx) return ctx.power > 50 end,
})

dynamic:updateContext({power = 60})
print("power=60 -> 状态: " .. dynamic:getState())

print()
print("========================================")
print("Demo 完成!")
print("========================================")
