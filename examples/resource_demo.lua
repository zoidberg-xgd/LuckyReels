-- examples/resource_demo.lua
-- Resource System 使用示例
--
-- 运行: lua examples/resource_demo.lua

package.path = package.path .. ";?.lua;?/init.lua"
local Resource = require("lib.resource")

print("========================================")
print("Resource System Demo")
print("========================================\n")

--------------------------------------------------------------------------------
-- 示例 1: 基础资源
--------------------------------------------------------------------------------
print("--- 示例 1: 基础 HP 资源 ---")

local hp = Resource.new({
    id = "hp",
    value = 100,
    min = 0,
    max = 100,
    regen = 5,  -- 每秒恢复 5 点
})

print("初始 HP: " .. hp:get())
hp:subtract(30)
print("受伤后 HP: " .. hp:get())
print("HP 百分比: " .. string.format("%.0f%%", hp:getPercent() * 100))

-- 模拟 2 秒恢复
hp:update(2.0)
print("2秒后 HP: " .. hp:get())

print()

--------------------------------------------------------------------------------
-- 示例 2: 修改器 (Buff/Debuff)
--------------------------------------------------------------------------------
print("--- 示例 2: 修改器 ---")

local mp = Resource.new({
    id = "mp",
    value = 50,
    min = 0,
    max = 100,
    regen = 2,
})

print("初始 MP: " .. mp:get())
print("基础恢复: " .. mp.baseRegen .. "/秒")

-- 添加冥想 buff
mp:addModifier({
    id = "meditation",
    type = "regen",
    value = 8,
    duration = 5,  -- 5秒后消失
})

print("冥想后有效恢复: " .. mp:getEffectiveRegen() .. "/秒")

-- 模拟 3 秒
mp:update(3.0)
print("3秒后 MP: " .. mp:get())
print("冥想 buff 存在: " .. tostring(mp:hasModifier("meditation")))

-- 再过 3 秒，buff 消失
mp:update(3.0)
print("6秒后 MP: " .. mp:get())
print("冥想 buff 存在: " .. tostring(mp:hasModifier("meditation")))

print()

--------------------------------------------------------------------------------
-- 示例 3: 事件监听
--------------------------------------------------------------------------------
print("--- 示例 3: 事件监听 ---")

local stamina = Resource.new({
    id = "stamina",
    value = 100,
    min = 0,
    max = 100,
})

stamina:onChange(function(old, new)
    print(string.format("  [onChange] %d -> %d", old, new))
end)

stamina:onThreshold(30, "below", function()
    print("  [阈值] 体力不足！")
end)

stamina:onMin(function()
    print("  [最小值] 体力耗尽！")
end)

print("消耗体力...")
stamina:subtract(50)
stamina:subtract(30)
stamina:subtract(20)

print()

--------------------------------------------------------------------------------
-- 示例 4: 派生资源
--------------------------------------------------------------------------------
print("--- 示例 4: 派生资源 ---")

local volume = Resource.new({id = "volume", value = 500, max = 2000})
local capacity = Resource.new({id = "capacity", value = 1000, max = 2000})
local elasticity = Resource.new({id = "elasticity", value = 1, max = 10})

local tension = Resource.newDerived({
    id = "tension",
    dependencies = {
        volume = volume,
        capacity = capacity,
        elasticity = elasticity,
    },
    formula = function(deps)
        local ratio = deps.volume / deps.capacity
        return math.pow(ratio, 1.5) * 100 / deps.elasticity
    end,
    min = 0,
    max = 100,
})

print(string.format("Volume: %d, Capacity: %d", volume:get(), capacity:get()))
print(string.format("Tension: %.1f%%", tension:get()))

volume:set(800)
print(string.format("\nVolume 增加到 %d", volume:get()))
print(string.format("Tension: %.1f%%", tension:get()))

elasticity:set(2)
print(string.format("\nElasticity 增加到 %d", elasticity:get()))
print(string.format("Tension: %.1f%%", tension:get()))

print()

--------------------------------------------------------------------------------
-- 示例 5: 资源管理器
--------------------------------------------------------------------------------
print("--- 示例 5: 资源管理器 ---")

local manager = Resource.newManager()

manager:register(Resource.new({id = "gold", value = 100, max = 99999}))
manager:register(Resource.new({id = "gems", value = 10, max = 999}))
manager:register(Resource.new({id = "energy", value = 50, max = 100, regen = 1}))

print("初始资源:")
print("  Gold: " .. manager:get("gold"):get())
print("  Gems: " .. manager:get("gems"):get())
print("  Energy: " .. manager:get("energy"):get())

-- 消费
manager:get("gold"):subtract(50)
manager:get("gems"):subtract(5)
manager:get("energy"):subtract(30)

print("\n消费后:")
print("  Gold: " .. manager:get("gold"):get())
print("  Gems: " .. manager:get("gems"):get())
print("  Energy: " .. manager:get("energy"):get())

-- 更新（恢复能量）
manager:update(10.0)

print("\n10秒后:")
print("  Energy: " .. manager:get("energy"):get())

-- 序列化
local saveData = manager:serialize()
print("\n序列化数据:")
for id, data in pairs(saveData) do
    print(string.format("  %s: value=%d", id, data.value))
end

print()

--------------------------------------------------------------------------------
-- 示例 6: 游戏场景 - 中毒效果
--------------------------------------------------------------------------------
print("--- 示例 6: 中毒效果模拟 ---")

local playerHp = Resource.new({
    id = "player_hp",
    value = 100,
    min = 0,
    max = 100,
    regen = 1,
})

playerHp:onThreshold(30, "below", function()
    print("  ⚠️ HP 危险！")
end)

playerHp:onMin(function()
    print("  💀 玩家死亡！")
end)

print("玩家中毒！")
playerHp:addModifier({
    id = "poison",
    type = "decay",
    value = 15,  -- 每秒 -15
    duration = 8,
})

print("有效恢复: " .. playerHp:getEffectiveRegen() .. "/秒")
print("有效衰减: " .. playerHp:getEffectiveDecay() .. "/秒")
print("净变化: " .. (playerHp:getEffectiveRegen() - playerHp:getEffectiveDecay()) .. "/秒")

-- 模拟时间流逝
for i = 1, 10 do
    playerHp:update(1.0)
    local status = playerHp:hasModifier("poison") and "🤢" or "😊"
    print(string.format("  第%d秒: HP=%d %s", i, playerHp:get(), status))
    if playerHp:get() <= 0 then
        break
    end
end

print()
print("========================================")
print("Demo 完成!")
print("========================================")
