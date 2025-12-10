# 测试指南

## 概述

LuckyReels 使用自定义的轻量级测试框架，支持无头运行（不需要 LÖVE2D）。

---

## 运行测试

### 运行所有测试
```bash
cd /path/to/LuckClone
lua tests/run_all.lua
```

### 运行单个测试文件
```bash
lua -e "package.path=package.path..';./?.lua'" tests/test_money_system.lua
```

---

## 测试结构

```
tests/
├── run_all.lua           # 测试入口
├── test_runner.lua       # 测试框架
├── test_money_system.lua # 金币系统测试
├── test_engine.lua       # 引擎测试
├── test_difficulty.lua   # 难度系统测试
├── test_shop.lua         # 商店测试
├── test_upgrade.lua      # 升级系统测试
└── test_synergy.lua      # 协同系统测试
```

---

## 测试框架 API

### 基本结构

```lua
local T = require("tests.test_runner")

T.describe("模块名称", function()
    
    T.it("应该做某事", function()
        -- 测试代码
        T.assertEqual(actual, expected, "错误信息")
    end)
    
end)

return T
```

### 断言方法

```lua
-- 相等
T.assertEqual(actual, expected, message)

-- 不为 nil
T.assertNotNil(value, message)

-- 布尔
T.assertTrue(value, message)
T.assertFalse(value, message)

-- 近似相等 (浮点数)
T.assertApprox(actual, expected, tolerance, message)

-- 表相等
T.assertTableEqual(actual, expected, message)
```

---

## 测试覆盖

### 金币系统 (test_money_system.lua)

| 测试项 | 说明 |
|--------|------|
| displayedMoney 初始化 | 确保初始为 0 |
| setDisplayedMoney | 设置显示金额 |
| syncDisplayedMoney | 同步（租金支付） |
| pendingCoins 追踪 | 待处理金币 |
| isCollecting 状态 | 收集状态检测 |
| 飞行金币创建 | 金币动画 |
| 金币收集回调 | 回调触发 |
| 计分队列 | Balatro 风格动画 |
| HUD 弹跳效果 | 视觉反馈 |

### 引擎测试 (test_engine.lua)

| 测试项 | 说明 |
|--------|------|
| 初始化配置 | 默认值正确 |
| 背包容量限制 | 最大 20 |
| 初始背包加载 | 起始符号 |
| 金钱操作 | 增减金钱 |
| pending_score | 待处理分数 |
| 租金支付 | 扣除租金 |
| 游戏结束 | 金钱不足 |
| 楼层推进 | 付租后升层 |
| 旋转系统 | 状态变化 |
| 商店系统 | 打开/关闭 |

### 难度测试 (test_difficulty.lua)

| 测试项 | 说明 |
|--------|------|
| 教学期租金 | 1-5 层 |
| 成长期租金 | 6-10 层 |
| 挑战期租金 | 11-15 层 |
| 精通期租金 | 16-20 层 |
| 无尽期租金 | 指数增长 |
| 旋转次数 | 各阶段不同 |
| Boss 层检测 | 每 5 层 |
| 检查点检测 | 3, 7 层 |
| 随机事件 | 事件系统 |

### 商店测试 (test_shop.lua)

| 测试项 | 说明 |
|--------|------|
| 商店初始化 | 符号/遗物生成 |
| 价格设置 | 稀有度定价 |
| 购买成功 | 扣钱加符号 |
| 购买失败-金钱 | 金钱不足 |
| 购买失败-背包 | 背包已满 |
| 购买失败-已售 | 重复购买 |
| 出售符号 | 获得金钱 |
| 出售价格 | 稀有度影响 |
| 刷新商店 | 扣费刷新 |

### 升级测试 (test_upgrade.lua)

| 测试项 | 说明 |
|--------|------|
| 配置值 | 3 合 1，最高 3 级 |
| 等级检测 | 新符号为 1 级 |
| 候选查找 | 找到可升级符号 |
| 同级限制 | 只能同级升级 |
| 升级进度 | 当前/需要 |
| 升级执行 | 合成新符号 |
| 价值提升 | 升级后价值增加 |
| 最高级限制 | 3 级无法再升 |

### 协同测试 (test_synergy.lua)

| 测试项 | 说明 |
|--------|------|
| 类别定义 | 水果/动物/宝石 |
| 加成层级 | 3/5/7 个阈值 |
| 无协同计算 | 倍率为 1 |
| 宝石协同 | 3+ 宝石触发 |
| 特殊组合 | 猫+牛奶 |
| 协同预览 | 背包预览 |

---

## 编写新测试

### 1. 创建测试文件

```lua
-- tests/test_my_feature.lua
local T = require("tests.test_runner")

-- Mock 必要的全局变量
if not love then
    love = {
        graphics = {
            getWidth = function() return 1024 end,
            getHeight = function() return 768 end,
        }
    }
end

-- 加载被测模块
local MyModule = require("src.my_module")

T.describe("My Feature", function()
    
    T.it("should do something", function()
        local result = MyModule.doSomething()
        T.assertEqual(result, expected)
    end)
    
end)

return T
```

### 2. 添加到 run_all.lua

```lua
local suites = {
    "tests.test_money_system",
    "tests.test_engine",
    -- ...
    "tests.test_my_feature",  -- 添加这行
}
```

### 3. 运行验证

```bash
lua tests/run_all.lua
```

---

## Mock 技巧

### Mock LÖVE2D

```lua
love = {
    graphics = {
        getWidth = function() return 1024 end,
        getHeight = function() return 768 end,
        setColor = function() end,
        rectangle = function() end,
        -- ...
    },
    audio = {
        newSource = function() 
            return {
                play = function() end,
                setVolume = function() end,
            } 
        end,
    },
}
```

### Mock 全局字体

```lua
_G.Fonts = {
    small = {},
    normal = {},
    big = {},
}
```

### Mock 游戏引擎

```lua
local mockEngine = {
    money = 100,
    inventory = {},
    inventory_max = 20,
    floor = 1,
    state = "IDLE",
}
```

---

## 持续集成

可以在 CI 中运行测试：

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: leafo/gh-actions-lua@v8
      - run: lua tests/run_all.lua
```

---

## 调试失败的测试

1. **查看错误信息** - 测试框架会打印具体错误
2. **添加打印** - 在测试中 `print()` 调试
3. **隔离测试** - 单独运行失败的测试文件
4. **检查 Mock** - 确保 Mock 完整
