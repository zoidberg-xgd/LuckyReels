# GameLib

通用游戏系统库 - 一个轻量级、模块化的 Lua 游戏开发库。

## 特性

- **模块化设计**: 按需加载，零依赖
- **链式 API**: 流畅的接口设计
- **完整测试**: 180+ 单元测试覆盖
- **跨引擎**: 支持 LÖVE2D、Defold 或纯 Lua 环境

## 安装

将 `gamelib` 文件夹复制到项目中：

```
your_project/
├── lib/
│   └── gamelib/
│       ├── init.lua
│       ├── resource.lua
│       ├── state_sprite.lua
│       ├── proc_shape.lua
│       ├── interact_region.lua
│       ├── dialogue.lua
│       ├── weighted_event.lua
│       └── ecs.lua
└── main.lua
```

## 快速开始

```lua
-- 加载整个库
local GameLib = require("lib.gamelib")

-- 或加载单个模块
local Resource = require("lib.gamelib.resource")
local ECS = require("lib.gamelib.ecs")
```

## 模块概览

### Resource - 资源系统

管理游戏中的数值资源（HP、金币、能量等）。

```lua
local Resource = require("lib.gamelib.resource")

local hp = Resource.new({
    id = "hp",
    value = 100,
    max = 100,
    regen = 1,  -- 每秒恢复
})

hp:subtract(30)
hp:addModifier({id = "poison", type = "decay", value = 5, duration = 10})
hp:onThreshold(20, "below", function() print("HP 危险!") end)
hp:update(dt)
```

### StateSprite - 状态精灵

根据条件自动切换精灵状态。

```lua
local StateSprite = require("lib.gamelib.state_sprite")

local character = StateSprite.new({
    states = {
        neutral = {sprite = "neutral.png"},
        happy = {sprite = "happy.png"},
        critical = {sprite = "critical.png", priority = 10},
    },
    conditions = {
        {state = "critical", when = function(ctx) return ctx.hp < 20 end},
        {state = "happy", when = function(ctx) return ctx.money > 100 end},
    },
})

character:updateContext({hp = 15, money = 50})
character:update(dt)
character:draw(x, y)
```

### ProcShape - 程序化形状

动态变形的形状，支持物理晃动。

```lua
local ProcShape = require("lib.gamelib.proc_shape")

local shape = ProcShape.new({
    type = "ellipse",
    baseWidth = 100,
    baseHeight = 80,
    physics = {jiggle = true, stiffness = 100, damping = 10},
})

shape:bindParam("scale", volumeResource, function(v) return 1 + v/1000 end)
shape:poke(0, 10, 1)  -- 触发晃动
shape:update(dt)
shape:draw(x, y)
```

### InteractRegion - 交互区域

处理鼠标/触摸交互。

```lua
local InteractRegion = require("lib.gamelib.interact_region")

local button = InteractRegion.new({
    shape = "rect",
    bounds = {100, 100, 200, 50},
    interactions = {"click", "hover"},
})

button:on("click", function(x, y) print("Clicked!") end)
button:on("hover", function(x, y, entering) end)

-- 在 LÖVE 回调中
button:mousepressed(x, y, button)
button:mousereleased(x, y, button)
button:mousemoved(x, y)
```

### Dialogue - 对话系统

条件对话和对话树。

```lua
local Dialogue = require("lib.gamelib.dialogue")

-- 条件对话库
local dialogues = Dialogue.newLibrary({
    entries = {
        {id = "greeting", text = "你好，{name}!", conditions = {mood = "happy"}},
        {id = "warning", text = "HP 不足!", conditions = {hp = {"<", 20}}, priority = 10},
    },
    variables = {
        name = function(ctx) return ctx.playerName end,
    },
})

local entry, text = dialogues:get({mood = "happy", playerName = "玩家"})

-- 对话树
local tree = Dialogue.newTree({
    nodes = {
        start = {
            text = "你想做什么?",
            choices = {
                {text = "战斗", next = "fight"},
                {text = "离开", next = "leave"},
            },
        },
    },
})

tree:start()
tree:choose(1)
```

### WeightedEvent - 加权事件

带权重的随机事件系统。

```lua
local WeightedEvent = require("lib.gamelib.weighted_event")

local lootPool = WeightedEvent.newPool({
    events = {
        {id = "common", weight = 80, type = "item"},
        {id = "rare", weight = 15, type = "item"},
        {id = "legendary", weight = 5, type = "item"},
    },
    pity = {threshold = 50, guarantee = {id = "legendary"}},
})

local triggered, event = lootPool:roll({baseChance = 0.1})
```

### ECS - 实体组件系统

轻量级 ECS 架构。

```lua
local ECS = require("lib.gamelib.ecs")

-- 定义组件
ECS.defineComponent("Position", {x = 0, y = 0})
ECS.defineComponent("Velocity", {vx = 0, vy = 0})

-- 定义系统
ECS.defineSystem("Movement", {"Position", "Velocity"}, function(entity, dt)
    local pos = entity:get("Position")
    local vel = entity:get("Velocity")
    pos.x = pos.x + vel.vx * dt
    pos.y = pos.y + vel.vy * dt
end)

-- 创建实体
local player = ECS.createEntity()
    :add("Position", {x = 100, y = 100})
    :add("Velocity", {vx = 50, vy = 0})
    :tag("player")

-- 更新
ECS.update(dt)

-- 查询
local movingEntities = ECS.query({"Position", "Velocity"})
local players = ECS.queryByTag("player")
```

## API 文档

详细 API 文档请参考各模块的源码注释或 `docs/` 目录下的文档：

- [Resource API](../../docs/RESOURCE.md)
- [StateSprite API](../../docs/STATE_SPRITE.md)
- [ProcShape API](../../docs/PROC_SHAPE.md)

## 许可证

MIT License
