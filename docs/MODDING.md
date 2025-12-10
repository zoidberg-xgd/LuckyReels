# Mod 开发指南

## 概述

LuckyReels 提供完整的 Mod API，允许玩家：
- 添加/修改符号、事件、协同效果
- 修改游戏数值和平衡
- 创建自定义动态角色
- 添加多语言翻译

---

## 快速开始

### 创建 Mod

1. 在 `mods/` 目录创建文件 `my_mod.lua` 或文件夹 `my_mod/init.lua`
2. 使用 ModAPI 注册你的 mod：

```lua
return function(ModAPI)
    ModAPI.register({
        id = "my_mod",
        name = "My Awesome Mod",
        version = "1.0.0",
        author = "YourName",
        description = "Does cool stuff",
    })
    
    -- 你的 mod 代码...
end
```

---

## API 参考

### 符号 API (ModAPI.Symbols)

#### 添加新符号
```lua
ModAPI.Symbols.add({
    key = "my_symbol",
    char = "★",              -- 显示字符
    color = {1, 0.9, 0.3},   -- RGB颜色
    base_value = 5,
    rarity = 2,  -- 1=普通, 2=稀有, 3=史诗
    tags = {"lucky", "gem"},
})

-- 添加翻译
ModAPI.i18n.add("en", "symbol_my_symbol_name", "My Symbol")
ModAPI.i18n.add("en", "symbol_my_symbol_desc", "+5 coins")
ModAPI.i18n.add("zh", "symbol_my_symbol_name", "我的符号")
ModAPI.i18n.add("zh", "symbol_my_symbol_desc", "+5金币")
```

#### 修改现有符号
```lua
ModAPI.Symbols.modify("coin", {
    base_value = 3,  -- 金币价值改为3
})
```

### 事件 API (ModAPI.Events)

#### 添加新事件
```lua
ModAPI.Events.add({
    id = "jackpot",
    name = "Jackpot!",
    desc = "Win big!",
    weight = 5,  -- 权重越高越常见
    type = "positive",  -- positive/negative/neutral
    
    apply = function(engine)
        engine.money = engine.money + 50
        return "Won 50 coins!"
    end,
})
```

#### 修改事件权重
```lua
ModAPI.Events.setWeight("tax", 0)  -- 禁用税收事件
```

### 协同 API (ModAPI.Synergies)

#### 添加新分类
```lua
ModAPI.Synergies.addCategory("magic", {"witch", "diamond", "lucky_seven"})
```

#### 添加协同加成
```lua
ModAPI.Synergies.addBonus("magic", 3, 2.0, "synergy_magic_power")
-- 3个魔法符号 = 2倍加成
```

#### 添加组合
```lua
ModAPI.Synergies.addCombo("triple_diamond", {
    symbols = {"diamond", "diamond", "diamond"},
    multiplier = 5,
    name_key = "combo_triple_diamond",
})
```

### 配置 API (ModAPI.Config)

```lua
-- 修改平衡
ModAPI.Config.setBalance("starting_money", 20)
ModAPI.Config.setBalance("starting_rent", 10)

-- 修改难度
ModAPI.Config.setDifficulty("events", {
    base_chance = 0.1,
    max_chance = 0.5,
})

-- 修改商店
ModAPI.Config.setShop("reroll_cost", 3)
```

### 翻译 API (ModAPI.i18n)

```lua
-- 添加翻译
ModAPI.i18n.add("en", "symbol_my_symbol_name", "My Symbol")
ModAPI.i18n.add("zh", "symbol_my_symbol_name", "我的符号")

-- 批量添加
ModAPI.i18n.addTranslations("en", {
    my_key1 = "Value 1",
    my_key2 = "Value 2",
})
```

### 钩子 API (ModAPI.Hooks)

```lua
-- 监听游戏事件
ModAPI.Hooks.on("game:spin", function()
    print("Player spinning!")
end)

ModAPI.Hooks.on("game:score", function(score, symbols)
    print("Scored: " .. score)
end)

ModAPI.Hooks.on("game:floor", function(oldFloor, newFloor)
    print("Advanced to floor " .. newFloor)
end)
```

---

## 自定义角色

### 创建角色

```lua
local MyChar = {}
MyChar.__index = MyChar

function MyChar.new()
    local self = setmetatable({}, MyChar)
    self.x = 80
    self.y = 500
    self.time = 0
    self.expression = "neutral"
    return self
end

function MyChar:update(dt)
    self.time = self.time + dt
    -- 动画逻辑
end

function MyChar:draw()
    -- 绘制角色
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", self.x, self.y, 30)
end

function MyChar:react(eventType, data)
    -- 对事件做出反应
    if eventType == "win" then
        self.expression = "happy"
    elseif eventType == "big_win" then
        self.expression = "excited"
    end
end

function MyChar:lookAt(x, y)
    -- 看向鼠标位置
end

-- 响应游戏状态变化
function MyChar:updateFromGameState(gameState)
    -- gameState 包含:
    -- money: 当前金币
    -- rent: 当前租金
    -- floor: 当前楼层
    -- state: 游戏状态
    -- inventory: 背包符号列表
    -- spins_left: 剩余旋转次数
    
    local ratio = gameState.money / gameState.rent
    if ratio < 0.5 then
        self.mood = "worried"
    elseif ratio >= 2 then
        self.mood = "confident"
    end
    
    -- 检查特定道具
    for _, sym in ipairs(gameState.inventory) do
        if sym.key == "diamond" then
            self.hasDiamond = true
        end
    end
end

-- 注册角色
ModAPI.Character.register({
    id = "my_char",
    name = "My Character",
    new = MyChar.new,
    update = MyChar.update,
    draw = MyChar.draw,
    react = MyChar.react,
    lookAt = MyChar.lookAt,
})

-- 激活角色
ModAPI.Character.setActive("my_char")
```

### 角色可访问的游戏数据

| 字段 | 类型 | 描述 |
|------|------|------|
| `money` | number | 当前金币 |
| `rent` | number | 当前租金 |
| `floor` | number | 当前楼层 |
| `state` | string | 游戏状态 (IDLE/SPINNING/等) |
| `inventory` | table | 背包符号列表 |
| `spins_left` | number | 剩余旋转次数 |

### 角色事件类型

| 事件 | 描述 |
|------|------|
| `spin` | 开始旋转 |
| `coin` | 获得少量金币 |
| `win` | 获得中等金币 |
| `big_win` | 获得大量金币 |
| `event` | 随机事件触发 |
| `lose` | 输掉 |

---

## 外部角色文件

支持从文件加载角色，支持以下格式：

### Spine 动画
```
assets/characters/my_char/
├── skeleton.json    # Spine 骨骼数据
├── skeleton.atlas   # 纹理图集
└── *.png           # 纹理图片
```

```lua
-- 在 mod 中加载
local char = ModAPI.Character.loadFromFile("assets/characters/my_char")
ModAPI.Character.setActive(char)
```

### PNG 部件
```
assets/characters/my_char/
├── parts.lua       # 部件定义
├── body.png        # 身体
├── head.png        # 头部
├── eyes_normal.png # 眼睛
└── ...
```

**parts.lua 示例：**
```lua
return {
    parts = {
        body = {
            image = "body.png",
            x = 0, y = 0,
            ox = 50, oy = 75,  -- 原点
            z = 1,             -- 绘制顺序
            
            -- 参数绑定：游戏数据影响外观
            bindings = {
                belly = {
                    scaleX = 0.3,  -- 金币越多，肚子越大
                    scaleY = 0.2,
                },
            },
        },
        head = {
            image = "head.png",
            x = 0, y = -60,
            z = 2,
        },
    },
}
```

### Spritesheet 帧动画
```
assets/characters/my_char/
├── spritesheet.png  # 精灵图
└── spritesheet.lua  # 动画定义
```

**spritesheet.lua 示例：**
```lua
return {
    frameWidth = 64,
    frameHeight = 64,
    frameDuration = 0.1,
    
    animations = {
        idle = {1, 2, 3, 4, 3, 2},
        happy = {5, 6, 7, 8},
        worried = {9, 10, 11, 10},
    },
}
```

### 参数绑定

角色可以响应游戏数据：

| 参数 | 来源 | 示例效果 |
|------|------|----------|
| `belly` | money / 50 | 肚子变大 |
| `tired` | floor / 20 | 疲劳表情 |
| `happy` | money/rent - 1 | 开心程度 |

---

## 示例 Mod

查看 `mods/example_mod.lua` 和 `mods/custom_character/` 获取完整示例。

---

## 旧版数据文件方式

### 添加符号 (data/symbols_base.lua)

```lua
my_symbol = {
    char = "符",           -- 显示字符
    color = {1, 0.5, 0},   -- RGB 颜色 (0-1)
    value = 3,             -- 基础价值
    rarity = 2,            -- 稀有度 (1=普通, 2=稀有, 3=史诗)
},
```

### 2. 带行为的符号

```lua
my_consumer = {
    char = "吃",
    color = {0.8, 0.2, 0.2},
    value = 1,
    rarity = 2,
    behavior = {
        type = "consume_adjacent",  -- 行为类型
        args = {"food", 8, {1, 0.8, 0.3}}  -- 目标key, 收益, 特效颜色
    }
},
```

**可用行为类型:**
- `consume_adjacent` - 消耗相邻的指定符号
- `consume_adjacent_delayed` - 延迟消耗（下次旋转）
- `boost_from_adjacent` - 被相邻符号增益
- `boost_adjacent` - 增益相邻符号

### 3. 自定义计算逻辑

```lua
my_complex = {
    char = "复",
    color = {0.5, 0.5, 1},
    value = 1,
    rarity = 3,
    
    -- 自定义计算函数
    on_calculate = function(self, grid, r, c)
        local base = self.level or 1
        local bonus = 0
        local logs = {}
        
        -- 统计网格中所有同类符号
        for gr = 1, grid.rows do
            for gc = 1, grid.cols do
                local sym = grid:getSymbol(gr, gc)
                if sym and sym.key == self.key and (gr ~= r or gc ~= c) then
                    bonus = bonus + 1
                end
            end
        end
        
        table.insert(logs, "同类加成: +" .. bonus)
        return base + bonus, logs
    end,
},
```

### 4. 等级效果

```lua
leveled_symbol = {
    char = "升",
    color = {1, 1, 0},
    value = 1,
    rarity = 2,
    
    on_calculate = function(self, grid, r, c)
        local level = self.level or 1
        local base = level * 2  -- 等级越高基础越高
        local bonus = 0
        
        if level >= 2 then
            -- 2级效果: 相邻加成
            for dr = -1, 1 do
                for dc = -1, 1 do
                    if dr ~= 0 or dc ~= 0 then
                        local sym = grid:getSymbol(r + dr, c + dc)
                        if sym then bonus = bonus + 1 end
                    end
                end
            end
        end
        
        if level >= 3 then
            -- 3级效果: 全局加成
            bonus = bonus * 2
        end
        
        return base + bonus, {}
    end,
},
```

---

## 添加新遗物

在 `data/relics_base.lua` 中添加：

### 基础遗物

```lua
my_relic = {
    name = "我的遗物",
    desc = "每次旋转+2金币",
    rarity = 2,
    
    -- 钩子函数
    on_spin_end = function(self, ctx)
        ctx.engine.money = ctx.engine.money + 2
        return {
            triggered = true,
            message = "+2 金币"
        }
    end,
},
```

### 可用钩子

| 钩子 | 触发时机 | ctx 内容 |
|------|----------|----------|
| `on_spin_start` | 旋转开始 | {engine} |
| `on_spin_end` | 旋转结束 | {engine} |
| `on_calculate_start` | 计算开始 | {engine} |
| `on_calculate_end` | 计算结束 | {engine, score} |
| `on_symbol_add` | 符号添加 | {engine, symbol} |
| `on_symbol_remove` | 符号移除 | {engine, symbol} |
| `on_shop_enter` | 进入商店 | {engine, shop} |
| `on_floor_change` | 楼层变化 | {engine, old_floor, new_floor} |

### 遗物示例

```lua
-- 金币翻倍遗物
doubler = {
    name = "翻倍器",
    desc = "所有金币符号价值x2",
    rarity = 3,
    
    on_calculate_start = function(self, ctx)
        -- 遍历网格，给所有金币加倍
        for r = 1, ctx.engine.grid.rows do
            for c = 1, ctx.engine.grid.cols do
                local sym = ctx.engine.grid:getSymbol(r, c)
                if sym and sym.key == "coin" then
                    sym._relic_multiplier = 2
                end
            end
        end
    end,
},

-- 幸运遗物
lucky = {
    name = "幸运草",
    desc = "10%概率获得双倍收益",
    rarity = 2,
    
    on_calculate_end = function(self, ctx)
        if math.random() < 0.1 then
            ctx.engine.money = ctx.engine.money + ctx.score
            return {triggered = true, message = "幸运! 双倍!"}
        end
    end,
},
```

---

## 添加新消耗品

在 `data/consumables_base.lua` 中添加：

```lua
my_item = {
    name = "神秘药水",
    desc = "随机获得一个稀有符号",
    rarity = 2,
    
    on_use = function(self, engine)
        local Registry = require("src.core.registry")
        local sym = Registry.createSymbol("diamond")  -- 或随机选择
        table.insert(engine.inventory, sym)
        return true, "获得了钻石!"
    end,
},
```

---

## 添加协同效果

在 `src/core/synergy.lua` 中：

### 添加类别

```lua
Synergy.categories.my_category = {"symbol1", "symbol2", "symbol3"}
```

### 添加加成

```lua
Synergy.bonuses.my_category = {
    {3, 1.2, "3个+20%"},   -- 3个符号, 1.2倍, 描述
    {5, 1.5, "5个+50%"},
    {7, 2.0, "7个+100%"},
}
```

### 添加特殊组合

```lua
Synergy.combos.my_combo = {
    name = "我的组合",
    requires = {"symbol1", "symbol2"},  -- 需要的符号
    bonus = 10,                          -- 固定加成
    multiplier = 1.5,                    -- 倍率加成
}
```

---

## 添加随机事件

在 `src/core/difficulty.lua` 的 `Difficulty.events` 中添加：

```lua
{
    id = "my_event",
    name = "我的事件",
    desc = "发生了一些事情!",
    weight = 5,  -- 权重，越高越常见
    type = "positive",  -- positive/negative/neutral
    
    apply = function(engine)
        engine.money = engine.money + 20
        return "+20 金币"
    end
},
```

---

## 修改配置

在 `src/core/config.lua` 中修改：

```lua
-- 修改难度
Config.difficulty.phases.tutorial.base = 20  -- 提高初始租金

-- 修改商店
Config.shop.symbol_prices[1] = 5  -- 提高普通符号价格

-- 修改动画
Config.animation.spin_duration = 3.0  -- 更长的旋转时间
```

---

## 添加翻译

在 `src/locales/` 中添加或修改：

```lua
-- zh.lua
return {
    my_symbol_name = "我的符号",
    my_relic_desc = "这是一个很棒的遗物",
    ...
}
```

使用：
```lua
local i18n = require("src.i18n")
local text = i18n.t("my_symbol_name")
```

---

## 调试技巧

### 打印日志
```lua
print("[MyMod] 调试信息")
```

### 监听事件
```lua
local API = require("src.core.api")
API.on(API.Events.SPIN_END, function(data)
    print("旋转结束，分数:", data.score)
end)
```

### 运行测试
```bash
lua tests/run_all.lua
```

---

## 最佳实践

1. **不要修改核心文件** - 尽量只修改 `data/` 目录
2. **使用 API** - 通过 `API` 模块访问游戏系统
3. **测试你的改动** - 添加单元测试
4. **保持平衡** - 新内容不要太强或太弱
5. **写好描述** - 让玩家理解效果
