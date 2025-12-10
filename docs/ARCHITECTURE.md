# 架构设计

## 概述

LuckyReels (幸运转轴) 采用模块化架构，核心系统与内容数据分离，便于扩展和维护。

## 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        main.lua                              │
│                    (LÖVE2D 入口)                             │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                       game.lua                               │
│                    (游戏主循环)                              │
│  - 输入处理  - 状态更新  - 渲染调度                          │
└───────┬─────────────────┬─────────────────┬─────────────────┘
        │                 │                 │
┌───────▼───────┐ ┌───────▼───────┐ ┌───────▼───────┐
│   engine.lua  │ │    ui.lua     │ │  effects.lua  │
│   (游戏引擎)  │ │   (UI渲染)    │ │  (视觉特效)   │
└───────┬───────┘ └───────────────┘ └───────────────┘
        │
┌───────▼─────────────────────────────────────────────────────┐
│                      核心系统 (src/core/)                    │
├─────────────┬─────────────┬─────────────┬───────────────────┤
│ config.lua  │  api.lua    │ registry.lua│  event_bus.lua   │
│ (集中配置)  │ (统一API)   │ (内容注册)  │  (事件通信)      │
├─────────────┼─────────────┼─────────────┼───────────────────┤
│  grid.lua   │  shop.lua   │ upgrade.lua │  synergy.lua     │
│ (符号网格)  │ (商店系统)  │ (升级系统)  │  (协同系统)      │
├─────────────┴─────────────┴─────────────┴───────────────────┤
│                      difficulty.lua (难度曲线)               │
└─────────────────────────────────────────────────────────────┘
```

## 核心模块

### 1. Config (`src/core/config.lua`)

集中管理所有配置常量，避免硬编码。

```lua
Config.grid       -- 网格设置 (尺寸、位置)
Config.balance    -- 游戏平衡 (初始值、上限)
Config.shop       -- 商店配置 (价格、数量)
Config.difficulty -- 难度曲线 (租金、旋转次数)
Config.animation  -- 动画时间
Config.visual     -- 视觉设置 (颜色)
```

### 2. API (`src/core/api.lua`)

提供统一的对外接口，隐藏内部实现。

```lua
API.Game       -- 游戏状态访问
API.Inventory  -- 背包操作
API.Grid       -- 网格操作
API.Shop       -- 商店操作
API.Relics     -- 遗物操作
API.Effects    -- 特效触发
API.Symbols    -- 符号创建
```

### 3. Engine (`src/core/engine.lua`)

游戏核心逻辑，管理状态机和游戏流程。

**状态机:**
```
IDLE        - 等待玩家操作
SPINNING    - 老虎机旋转中
COLLECTING  - 收集金币动画
RENT_PAID   - 租金已付，显示结算
EVENT       - 随机事件
SHOP        - 商店界面
DRAFT       - 选择符号 (特殊情况)
GAME_OVER   - 游戏结束
```

### 4. EventBus (`src/core/event_bus.lua`)

松耦合的事件通信系统。

```lua
-- 预定义事件
EventBus.Events = {
    SPIN_START, SPIN_END,
    MONEY_CHANGE,
    SYMBOL_ADD, SYMBOL_REMOVE,
    RELIC_TRIGGER,
    ...
}

-- 使用
EventBus.on(event, callback)  -- 监听
EventBus.emit(event, data)    -- 触发
EventBus.off(event, id)       -- 取消
```

### 5. Registry (`src/core/registry.lua`)

内容注册中心，管理所有符号、遗物、消耗品。

```lua
Registry.registerSymbol(key, definition)
Registry.createSymbol(key)  -- 创建实例
Registry.getSymbol(key)     -- 获取定义
```

### 6. Grid (`src/core/grid.lua`)

符号网格管理，处理旋转和计算。

```lua
Grid:spin(inventory)        -- 旋转填充
Grid:calculateTotalValue()  -- 计算收益
Grid:getSymbol(r, c)        -- 获取符号
Grid:getAdjacent(r, c)      -- 获取相邻
```

## 数据流

### 旋转流程
```
1. 玩家按空格
2. Engine:spin() 触发
3. Grid:spin() 随机填充符号
4. 状态变为 SPINNING
5. 动画播放完毕
6. Engine:resolveSpin() 计算收益
7. Grid:calculateTotalValue() 执行
8. 状态变为 COLLECTING
9. Effects 播放金币动画
10. Engine:finishCollecting() 完成
11. 检查租金/游戏结束
```

### 购买流程
```
1. 玩家点击商店符号
2. Shop:buySymbol() 调用
3. 检查金钱、背包容量
4. 扣除金钱
5. 创建符号实例
6. 添加到背包
7. 触发 SYMBOL_ADD 事件
```

## 扩展点

### 添加新符号
1. 在 `data/symbols_base.lua` 定义
2. 自动被 `src/content/symbols.lua` 加载
3. 自动注册到 Registry

### 添加新遗物
1. 在 `data/relics_base.lua` 定义
2. 实现 `on_trigger` 钩子
3. 自动被加载和注册

### 添加新事件
1. 在 `EventBus.Events` 添加常量
2. 在相应位置 `emit`
3. 在需要的地方 `on` 监听

## 设计原则

1. **数据驱动** - 内容定义与代码分离
2. **松耦合** - 模块间通过事件通信
3. **集中配置** - 所有常量在 Config
4. **统一接口** - 对外使用 API 模块
5. **可测试** - 核心逻辑可单元测试
