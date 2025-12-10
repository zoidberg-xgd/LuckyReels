# API 参考

## 概述

`src/core/api.lua` 提供统一的游戏接口，推荐通过 API 模块访问游戏系统。

```lua
local API = require("src.core.api")
```

---

## API.Game

游戏状态访问。

### API.Game.getMoney()
获取当前金钱。
```lua
local money = API.Game.getMoney()  -- 返回 number
```

### API.Game.setMoney(amount)
设置金钱（会触发 MONEY_CHANGE 事件）。
```lua
API.Game.setMoney(100)
```

### API.Game.addMoney(amount)
增加金钱。
```lua
API.Game.addMoney(10)  -- 加 10
API.Game.addMoney(-5)  -- 减 5
```

### API.Game.getFloor()
获取当前楼层。
```lua
local floor = API.Game.getFloor()  -- 返回 number
```

### API.Game.getState()
获取当前游戏状态。
```lua
local state = API.Game.getState()
-- 可能值: "IDLE", "SPINNING", "COLLECTING", "SHOP", "GAME_OVER", ...
```

### API.Game.getRent()
获取当前租金。
```lua
local rent = API.Game.getRent()
```

### API.Game.getSpinsLeft()
获取剩余旋转次数。
```lua
local spins = API.Game.getSpinsLeft()
```

---

## API.Inventory

背包操作。

### API.Inventory.getAll()
获取所有背包符号。
```lua
local symbols = API.Inventory.getAll()  -- 返回 table
for i, sym in ipairs(symbols) do
    print(sym.key, sym.base_value)
end
```

### API.Inventory.count()
获取背包符号数量。
```lua
local count = API.Inventory.count()
```

### API.Inventory.isFull()
检查背包是否已满。
```lua
if API.Inventory.isFull() then
    print("背包已满!")
end
```

### API.Inventory.add(symbol)
添加符号到背包。
```lua
local sym = API.Symbols.create("coin")
local success = API.Inventory.add(sym)  -- 返回 boolean
```

### API.Inventory.remove(index)
移除指定位置的符号。
```lua
local removed = API.Inventory.remove(1)  -- 返回被移除的符号或 nil
```

### API.Inventory.findByKey(key)
查找指定类型的符号。
```lua
local coins = API.Inventory.findByKey("coin")
-- 返回 {{index=1, symbol=...}, {index=3, symbol=...}}
```

### API.Inventory.countByKey(key)
统计指定类型符号数量。
```lua
local coinCount = API.Inventory.countByKey("coin")
```

---

## API.Grid

网格操作。

### API.Grid.get()
获取网格对象。
```lua
local grid = API.Grid.get()
```

### API.Grid.getSymbol(r, c)
获取指定位置的符号。
```lua
local sym = API.Grid.getSymbol(1, 1)  -- 第1行第1列
```

### API.Grid.setSymbol(r, c, symbol)
设置指定位置的符号。
```lua
API.Grid.setSymbol(1, 1, API.Symbols.create("diamond"))
```

### API.Grid.forEachSymbol(callback)
遍历所有符号。
```lua
API.Grid.forEachSymbol(function(sym, r, c)
    print(r, c, sym.key)
end)
```

### API.Grid.toScreen(r, c)
网格坐标转屏幕坐标。
```lua
local x, y = API.Grid.toScreen(1, 1)
```

### API.Grid.toCenterScreen(r, c)
网格坐标转屏幕中心坐标。
```lua
local cx, cy = API.Grid.toCenterScreen(2, 3)
```

---

## API.Shop

商店操作。

### API.Shop.get()
获取当前商店对象。
```lua
local shop = API.Shop.get()
if shop then
    print("商店已打开")
end
```

### API.Shop.buySymbol(index)
购买商店中的符号。
```lua
local success, reason = API.Shop.buySymbol(1)
-- reason: "not_enough_money", "inventory_full", "already_sold"
```

### API.Shop.sellSymbol(inventoryIndex)
出售背包中的符号。
```lua
local success = API.Shop.sellSymbol(1)
```

### API.Shop.reroll()
刷新商店。
```lua
local success = API.Shop.reroll()
```

---

## API.Relics

遗物操作。

### API.Relics.getAll()
获取所有遗物。
```lua
local relics = API.Relics.getAll()
```

### API.Relics.add(relic)
添加遗物。
```lua
local relic = Registry.createRelic("lucky_cat")
API.Relics.add(relic)
```

### API.Relics.hasRelic(key)
检查是否拥有指定遗物。
```lua
if API.Relics.hasRelic("lucky_cat") then
    print("有幸运猫!")
end
```

---

## API.Difficulty

难度系统。

### API.Difficulty.getRent(floor)
获取指定楼层的租金。
```lua
local rent = API.Difficulty.getRent(5)  -- 第5层租金
local currentRent = API.Difficulty.getRent()  -- 当前层租金
```

### API.Difficulty.getSpins(floor)
获取指定楼层的旋转次数。
```lua
local spins = API.Difficulty.getSpins(10)
```

### API.Difficulty.isBossFloor(floor)
检查是否为 Boss 层。
```lua
if API.Difficulty.isBossFloor(5) then
    print("Boss 层!")
end
```

### API.Difficulty.getPhase(floor)
获取当前阶段。
```lua
local phase = API.Difficulty.getPhase()
-- 返回: "tutorial", "growth", "challenge", "mastery", "endless"
```

---

## API.Effects

特效触发。

### API.Effects.addPopup(x, y, text, color, size, delay)
添加弹出文字。
```lua
API.Effects.addPopup(400, 300, "+10", {1, 1, 0}, 24, 0)
```

### API.Effects.addCoinBurst(x, y, count)
添加金币爆发效果。
```lua
API.Effects.addCoinBurst(400, 300, 10)
```

### API.Effects.screenShake(intensity, duration)
屏幕震动。
```lua
API.Effects.screenShake(10, 0.3)
```

### API.Effects.screenFlash(r, g, b, alpha, duration)
屏幕闪烁。
```lua
API.Effects.screenFlash(1, 1, 1, 0.5, 0.1)
```

---

## API.Symbols

符号创建。

### API.Symbols.create(key)
创建符号实例。
```lua
local coin = API.Symbols.create("coin")
```

### API.Symbols.createRandom()
创建随机符号。
```lua
local sym = API.Symbols.createRandom()
```

### API.Symbols.getDefinition(key)
获取符号定义。
```lua
local def = API.Symbols.getDefinition("coin")
print(def.value, def.rarity)
```

### API.Symbols.getAllKeys()
获取所有符号 key。
```lua
local keys = API.Symbols.getAllKeys()
```

---

## 事件系统

### API.on(event, callback)
监听事件。
```lua
local id = API.on(API.Events.SPIN_END, function(data)
    print("旋转结束!")
end)
```

### API.emit(event, data)
触发事件。
```lua
API.emit("custom:event", {value = 100})
```

### API.off(event, id)
取消监听。
```lua
API.off(API.Events.SPIN_END, id)
```

### 预定义事件 (API.Events)

| 事件 | 数据 | 说明 |
|------|------|------|
| SPIN_START | {engine} | 旋转开始 |
| SPIN_END | {engine} | 旋转结束 |
| SPIN_RESULT | {score, interactions} | 旋转结果 |
| COLLECT_START | {engine} | 收集开始 |
| COLLECT_END | {engine} | 收集结束 |
| MONEY_CHANGE | {old, new, delta} | 金钱变化 |
| SYMBOL_ADD | {symbol} | 符号添加 |
| SYMBOL_REMOVE | {symbol} | 符号移除 |
| RELIC_TRIGGER | {relic, context} | 遗物触发 |
| FLOOR_CHANGE | {old, new} | 楼层变化 |
| GAME_OVER | {reason} | 游戏结束 |

---

## Config 配置

通过 `require("src.core.config")` 访问。

```lua
local Config = require("src.core.config")

-- 网格
Config.grid.rows          -- 4
Config.grid.cols          -- 5
Config.grid.cellSize      -- 80
Config.grid.toScreen(r,c) -- 坐标转换

-- 平衡
Config.balance.starting_money    -- 5
Config.balance.inventory_max     -- 20

-- 商店
Config.shop.symbol_prices[1]     -- 普通符号价格
Config.shop.reroll_cost          -- 刷新费用

-- 动画
Config.animation.spin_duration   -- 旋转时长
Config.animation.scoring.symbol_delay  -- 符号计分间隔

-- 视觉
Config.visual.colors.money       -- 金钱颜色
Config.visual.rarity_colors[1]   -- 普通稀有度颜色
```
