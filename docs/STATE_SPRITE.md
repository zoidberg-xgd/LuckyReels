# State-Driven Sprite System API

状态驱动精灵系统，支持条件切换、过渡动画和分层组合。

## 快速开始

```lua
local StateSprite = require("lib.state_sprite")

-- 创建角色精灵
local character = StateSprite.new({
    states = {
        neutral = {sprite = "neutral.png", priority = 0},
        happy = {sprite = "happy.png", priority = 1},
        sad = {sprite = "sad.png", priority = 1},
        critical = {sprite = "critical.png", priority = 10},
    },
    conditions = {
        {state = "critical", when = function(ctx) return ctx.hp < 20 end},
        {state = "happy", when = function(ctx) return ctx.money > 100 end},
        {state = "sad", when = function(ctx) return ctx.money < 10 end},
    },
    transitions = {
        default = {duration = 0.3, easing = "outQuad"},
        ["neutral->critical"] = {duration = 0.1, easing = "linear"},
    },
    defaultState = "neutral",
})

-- 更新上下文（自动切换状态）
character:updateContext({hp = 15, money = 50})

-- 每帧更新
character:update(dt)

-- 绘制
character:draw(x, y)
```

## API 参考

### StateSprite.new(config)

创建状态精灵。

**配置:**
```lua
{
    states = {
        [stateName] = {
            sprite = "path/to/image.png",  -- 或 love.Image
            priority = 0,                   -- 状态优先级
            offset = {x = 0, y = 0},       -- 偏移
            scale = {x = 1, y = 1},        -- 缩放
            rotation = 0,                   -- 旋转（弧度）
            color = {1, 1, 1, 1},          -- 颜色
        },
    },
    conditions = {
        {
            state = "stateName",
            when = function(ctx) return ctx.value > 10 end,
            priority = 0,  -- 条件优先级（越高越先检查）
        },
    },
    transitions = {
        default = {duration = 0.3, easing = "outQuad"},
        ["stateA->stateB"] = {duration = 0.1, easing = "linear"},
    },
    defaultState = "neutral",
}
```

---

### StateSprite 实例方法

#### 状态管理

| 方法 | 说明 |
|------|------|
| `getState()` | 获取当前状态名 |
| `getStateData()` | 获取当前状态配置 |
| `setState(name, options?)` | 设置状态 |
| `isTransitioning()` | 是否在过渡中 |

**临时状态:**
```lua
-- 临时切换到 surprised，2秒后恢复
character:setState("surprised", {duration = 2})
```

#### 上下文与条件

```lua
-- 更新上下文（合并）
character:updateContext({hp = 50, money = 100})

-- 设置上下文（替换）
character:setContext({hp = 50, money = 100})

-- 动态添加条件
character:addCondition({
    state = "angry",
    when = function(ctx) return ctx.damage > 50 end,
    priority = 5,
})
```

#### 过渡动画

```lua
-- 设置过渡
character:setTransition("neutral->happy", {
    duration = 0.5,
    easing = "outElastic",
})

-- 设置默认过渡
character:setTransition("default", {
    duration = 0.3,
    easing = "outQuad",
})
```

**可用缓动函数:**
- `linear` - 线性
- `inQuad`, `outQuad`, `inOutQuad` - 二次
- `inCubic`, `outCubic`, `inOutCubic` - 三次
- `inElastic`, `outElastic` - 弹性
- `outBounce` - 弹跳

#### 事件监听

```lua
character:onStateChange(function(oldState, newState)
    print("State changed: " .. oldState .. " -> " .. newState)
end)
```

#### 更新与绘制

```lua
-- 每帧更新
character:update(dt)

-- 绘制
character:draw(x, y)

-- 带选项绘制
character:draw(x, y, {
    scale = 2,              -- 或 {x = 2, y = 2}
    rotation = math.pi/4,
    color = {1, 0.5, 0.5, 1},
})
```

#### 图像加载

```lua
-- 加载单个图像
character:loadImage("happy", "assets/happy.png")

-- 预加载所有状态图像
character:preloadImages()
```

---

## LayeredStateSprite (分层精灵)

支持多层组合的精灵系统。

### 创建

```lua
local character = StateSprite.newLayered({
    layers = {
        {name = "body", z = 0},
        {name = "face", z = 1},
        {name = "clothes", z = 2},
        {name = "effects", z = 3},
    },
    layerStates = {
        face = {
            neutral = "face_neutral.png",
            happy = "face_happy.png",
            blush = "face_blush.png",
        },
        clothes = {
            normal = "clothes_normal.png",
            torn = "clothes_torn.png",
        },
    },
})
```

### 方法

```lua
-- 设置层状态
character:setLayerState("face", "blush")
character:setLayerState("clothes", "torn")

-- 获取层状态
local faceState = character:getLayerState("face")

-- 设置层可见性
character:setLayerVisible("clothes", false)

-- 加载图像
character:loadImage("face", "happy", "assets/face_happy.png")
character:preloadImages()

-- 添加层条件
character:addCondition("face", {
    state = "blush",
    when = function(ctx) return ctx.embarrassed end,
})

-- 更新上下文
character:updateContext({embarrassed = true})

-- 更新和绘制
character:update(dt)
character:draw(x, y)
```

---

## 使用示例

### 角色表情系统

```lua
local StateSprite = require("lib.state_sprite")
local Resource = require("lib.resource")

-- 创建资源
local hp = Resource.new({id = "hp", value = 100, max = 100})
local money = Resource.new({id = "money", value = 50, max = 999})

-- 创建角色
local character = StateSprite.new({
    states = {
        neutral = {sprite = "neutral.png"},
        happy = {sprite = "happy.png"},
        worried = {sprite = "worried.png"},
        critical = {sprite = "critical.png", priority = 10},
    },
    conditions = {
        {state = "critical", when = function(ctx) return ctx.hp < 20 end, priority = 10},
        {state = "happy", when = function(ctx) return ctx.money > 100 end},
        {state = "worried", when = function(ctx) return ctx.money < 20 end},
    },
    defaultState = "neutral",
})

function love.update(dt)
    hp:update(dt)
    
    -- 同步资源到精灵上下文
    character:updateContext({
        hp = hp:get(),
        money = money:get(),
    })
    
    character:update(dt)
end

function love.draw()
    character:draw(400, 300)
end
```

### 服装破坏系统

```lua
local character = StateSprite.newLayered({
    layers = {
        {name = "body", z = 0},
        {name = "underwear", z = 1},
        {name = "clothes", z = 2},
    },
    layerStates = {
        clothes = {
            intact = "clothes_full.png",
            damaged = "clothes_damaged.png",
            torn = "clothes_torn.png",
            destroyed = nil,  -- 不显示
        },
    },
})

-- 根据耐久度切换
local durability = 100

function takeDamage(amount)
    durability = durability - amount
    
    if durability <= 0 then
        character:setLayerVisible("clothes", false)
    elseif durability < 30 then
        character:setLayerState("clothes", "torn")
    elseif durability < 60 then
        character:setLayerState("clothes", "damaged")
    end
end
```

### 临时表情

```lua
-- 赢钱时显示惊喜表情
function onWin(amount)
    if amount > 100 then
        character:setState("surprised", {duration = 1.5})
    end
end

-- 受伤时显示痛苦表情
function onDamage()
    character:setState("hurt", {duration = 0.5})
end
```

---

## 与现有系统集成

可以替代 LuckyReels 中的硬编码角色表情：

```lua
-- 替代 Character.setExpression
local characterSprite = StateSprite.new({
    states = {
        neutral = {sprite = character.sprites.neutral},
        happy = {sprite = character.sprites.happy},
        sad = {sprite = character.sprites.sad},
    },
    defaultState = "neutral",
})

-- 在 Game.update 中
characterSprite:updateContext({
    money = Game.state.money,
    lastWin = Game.state.lastWin,
})
characterSprite:update(dt)
```
