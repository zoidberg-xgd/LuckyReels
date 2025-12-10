# Mod 开发指南

## 概述

LuckClone 采用数据驱动设计，可以通过修改数据文件或添加新文件来扩展游戏内容。

---

## 添加新符号

### 1. 基础符号

在 `data/symbols_base.lua` 中添加：

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
