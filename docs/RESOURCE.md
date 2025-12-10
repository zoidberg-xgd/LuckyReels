# Resource System API

通用资源管理系统，支持基础资源、派生资源、修改器和事件监听。

## 快速开始

```lua
local Resource = require("lib.resource")

-- 创建 HP 资源
local hp = Resource.new({
    id = "hp",
    value = 100,
    min = 0,
    max = 100,
    regen = 1,  -- 每秒恢复 1 点
})

-- 基础操作
hp:subtract(20)      -- 扣血
hp:add(10)           -- 加血
print(hp:get())      -- 90
print(hp:getPercent()) -- 0.9

-- 每帧更新（应用 regen/decay）
hp:update(dt)
```

## API 参考

### Resource.new(config)

创建新资源。

**参数:**
| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `id` | string | "unnamed" | 资源唯一标识 |
| `value` | number | 0 | 初始值 |
| `min` | number | 0 | 最小值 |
| `max` | number | 100 | 最大值 |
| `regen` | number | 0 | 每秒自动恢复量 |
| `decay` | number | 0 | 每秒自动衰减量 |

**返回:** `Resource`

---

### Resource 实例方法

#### 基础操作

| 方法 | 说明 |
|------|------|
| `get()` | 获取当前值 |
| `getPercent()` | 获取百分比 (0-1) |
| `set(value)` | 设置值（自动 clamp） |
| `add(amount)` | 增加值 |
| `subtract(amount)` | 减少值 |
| `setMax(value)` | 设置最大值 |
| `setMin(value)` | 设置最小值 |
| `reset(value?)` | 重置资源（清除修改器） |
| `update(dt)` | 每帧更新 |

#### 修改器

```lua
-- 添加修改器
hp:addModifier({
    id = "poison",       -- 唯一标识
    type = "decay",      -- 类型: "flat", "percent", "decay", "regen"
    value = 5,           -- 值
    duration = 10,       -- 持续时间（秒），nil = 永久
    priority = 0,        -- 优先级
})

-- 移除修改器
hp:removeModifier("poison")

-- 检查修改器
hp:hasModifier("poison")  -- true/false

-- 获取有效值
hp:getEffectiveRegen()  -- 基础 + 所有 regen 修改器
hp:getEffectiveDecay()  -- 基础 + 所有 decay 修改器
```

**修改器类型:**
- `regen`: 增加每秒恢复量
- `decay`: 增加每秒衰减量
- `flat`: 预留，用于直接加减
- `percent`: 预留，用于百分比修改

#### 事件监听

```lua
-- 值变化时触发
hp:onChange(function(oldValue, newValue)
    print("HP changed: " .. oldValue .. " -> " .. newValue)
end)

-- 到达最小值时触发
hp:onMin(function()
    print("Death!")
end)

-- 到达最大值时触发
hp:onMax(function()
    print("Full HP!")
end)

-- 阈值触发
hp:onThreshold(30, "below", function(old, new)
    print("HP critical!")
end)

hp:onThreshold(50, "above", function(old, new)
    print("HP recovered!")
end)

hp:onThreshold(0, "equal", function(old, new)
    print("HP is exactly 0!")
end)

hp:onThreshold(50, "cross", function(old, new)
    print("HP crossed 50!")
end)
```

**阈值方向:**
- `below`: 从 >= 阈值变为 < 阈值
- `above`: 从 <= 阈值变为 > 阈值
- `equal`: 值变为恰好等于阈值
- `cross`: 任意方向穿越阈值

#### 序列化

```lua
-- 保存
local data = hp:serialize()

-- 加载
local hp2 = Resource.deserialize(data)
```

---

### Resource.newDerived(config)

创建派生资源，其值由其他资源计算得出。

```lua
local volume = Resource.new({id = "volume", value = 500, max = 1000})
local capacity = Resource.new({id = "capacity", value = 1000, max = 2000})

local tension = Resource.newDerived({
    id = "tension",
    dependencies = {
        volume = volume,
        capacity = capacity,
    },
    formula = function(deps)
        return (deps.volume / deps.capacity) * 100
    end,
    min = 0,
    max = 100,
})

print(tension:get())  -- 50
volume:set(750)
print(tension:get())  -- 75
```

**方法:**
- `get()`: 重新计算并返回值
- `getPercent()`: 获取百分比
- `setDependency(name, resource)`: 更新依赖
- `onChange(callback)`: 监听值变化

---

### Resource.newManager()

创建资源管理器，统一管理多个资源。

```lua
local manager = Resource.newManager()

local hp = Resource.new({id = "hp", value = 100})
local mp = Resource.new({id = "mp", value = 50})

manager:register(hp)
manager:register(mp)

-- 获取资源
local myHp = manager:get("hp")

-- 统一更新
manager:update(dt)

-- 序列化/反序列化
local data = manager:serialize()
manager:deserialize(data)
```

---

## 使用示例

### 游戏角色属性

```lua
local Resource = require("lib.resource")

local player = {
    hp = Resource.new({id = "hp", value = 100, max = 100, regen = 0.5}),
    mp = Resource.new({id = "mp", value = 50, max = 50, regen = 1}),
    stamina = Resource.new({id = "stamina", value = 100, max = 100, regen = 5}),
}

-- 受伤
player.hp:subtract(30)

-- 中毒
player.hp:addModifier({
    id = "poison",
    type = "decay",
    value = 2,
    duration = 10,
})

-- 死亡检测
player.hp:onMin(function()
    gameOver()
end)

-- 每帧更新
function love.update(dt)
    player.hp:update(dt)
    player.mp:update(dt)
    player.stamina:update(dt)
end
```

### 经济系统

```lua
local money = Resource.new({
    id = "money",
    value = 100,
    min = 0,
    max = 999999,
})

local rent = Resource.new({
    id = "rent",
    value = 50,
    min = 0,
    max = 1000,
})

-- 租金到期检测
money:onThreshold(rent:get(), "below", function()
    print("Warning: Not enough money for rent!")
end)
```

### 派生属性

```lua
local strength = Resource.new({id = "str", value = 10, max = 100})
local weapon = Resource.new({id = "weapon", value = 5, max = 50})

local damage = Resource.newDerived({
    id = "damage",
    dependencies = {str = strength, weapon = weapon},
    formula = function(deps)
        return deps.str * 2 + deps.weapon * 3
    end,
})

print(damage:get())  -- 35 (10*2 + 5*3)
```

---

## 与现有系统集成

Resource System 可以替代 LuckyReels 中的硬编码资源管理：

```lua
-- 替代 Game.state.money
Game.resources = Resource.newManager()
Game.resources:register(Resource.new({
    id = "money",
    value = Config.STARTING_MONEY,
    min = 0,
    max = 999999,
}))

-- 使用
local money = Game.resources:get("money")
money:add(winAmount)
money:subtract(spinCost)
```
