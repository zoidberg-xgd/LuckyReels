# Procedural Shape System API

程序化形状系统，支持动态变形、物理晃动和参数绑定。

## 快速开始

```lua
local ProcShape = require("lib.proc_shape")
local Resource = require("lib.resource")

-- 创建椭圆形状
local shape = ProcShape.new({
    type = "ellipse",
    baseWidth = 100,
    baseHeight = 80,
    physics = {
        jiggle = true,
        stiffness = 100,
        damping = 10,
    },
})

-- 绑定参数到资源
local volume = Resource.new({id = "volume", value = 500, max = 2000})

shape:bindParam("scale", volume, function(v)
    return 1 + (v / 1000) * 0.5
end)

-- 戳一下触发晃动
shape:poke(0, 10, 1)

-- 每帧更新
shape:update(dt)

-- 绘制
shape:draw(400, 300)
```

## API 参考

### ProcShape.new(config)

创建程序化形状。

**配置:**
```lua
{
    type = "ellipse",      -- "ellipse", "polygon"
    baseWidth = 50,        -- 基础宽度
    baseHeight = 40,       -- 基础高度
    params = {
        scale = 1.0,       -- 整体缩放
        stretchX = 1.0,    -- X轴拉伸
        stretchY = 1.0,    -- Y轴拉伸
        sag = 0,           -- 下垂
        bulge = 0,         -- 凸起
        rotation = 0,      -- 旋转（弧度）
    },
    physics = {
        jiggle = false,    -- 是否启用晃动
        stiffness = 100,   -- 刚度
        damping = 10,      -- 阻尼
    },
    color = {1, 1, 1, 1},      -- 轮廓颜色
    fillColor = {0.8, 0.8, 0.8, 1},  -- 填充颜色
    lineWidth = 2,             -- 线宽
}
```

---

### ProcShape 实例方法

#### 参数管理

```lua
-- 设置参数
shape:setParam("scale", 1.5)
shape:setParam("sag", 0.3)

-- 获取参数
local scale = shape:getParam("scale")

-- 绑定参数到资源
shape:bindParam("scale", volumeResource, function(v)
    return 1 + v / 1000
end)

-- 解绑参数
shape:unbindParam("scale")
```

**可用参数:**
- `scale` - 整体缩放
- `stretchX` - X轴拉伸
- `stretchY` - Y轴拉伸
- `sag` - 下垂（底部向下偏移）
- `bulge` - 凸起（中间向外扩张）
- `rotation` - 旋转角度（弧度）

#### 物理交互

```lua
-- 戳一下（触发晃动）
shape:poke(x, y, force)

-- x, y: 相对于形状中心的位置
-- force: 力度（默认 1）
```

#### 几何查询

```lua
-- 获取当前尺寸
local width, height = shape:getSize()

-- 获取轮廓点
local points = shape:getOutlinePoints(32)  -- 32 个点
for _, p in ipairs(points) do
    print(p.x, p.y)
end

-- 检测点是否在形状内
local inside = shape:contains(px, py, centerX, centerY)
```

#### 更新与绘制

```lua
-- 每帧更新（更新物理和绑定参数）
shape:update(dt)

-- 绘制
shape:draw(centerX, centerY)

-- 带选项绘制
shape:draw(centerX, centerY, {
    fill = true,      -- 是否填充
    outline = true,   -- 是否绘制轮廓
})

-- 设置颜色
shape:setColor(1, 0, 0, 1)       -- 轮廓颜色
shape:setFillColor(0.5, 0, 0, 1) -- 填充颜色
```

---

## BezierShape (贝塞尔形状)

使用贝塞尔曲线定义的可变形形状。

### 创建

```lua
local shape = ProcShape.newBezier({
    controlPoints = {
        {x = 0, y = -50, fixed = true},   -- 顶部锚点（固定）
        {x = 50, y = -25, fixed = false}, -- 右上控制点
        {x = 50, y = 25, fixed = false},  -- 右下控制点
        {x = 0, y = 50, fixed = false},   -- 底部
        {x = -50, y = 25, fixed = false}, -- 左下控制点
        {x = -50, y = -25, fixed = false},-- 左上控制点
    },
    deformRules = {
        -- 当 scale 增加时，右侧点向外移动
        {point = 2, axis = "x", param = "scale", formula = function(s) return 50 * s end},
        {point = 3, axis = "x", param = "scale", formula = function(s) return 50 * s end},
        -- 当 sag 增加时，底部点向下移动
        {point = 4, axis = "y", param = "sag", formula = function(s) return 50 + s * 50 end},
    },
    physics = {
        jiggle = true,
        stiffness = 100,
        damping = 10,
    },
    segments = 32,
})
```

### 方法

```lua
-- 参数管理（同 ProcShape）
shape:setParam("scale", 1.5)
shape:bindParam("volume", resource, transform)

-- 获取控制点（含物理位移）
local cps = shape:getControlPoints()

-- 戳一下
shape:poke(x, y, force)

-- 更新
shape:update(dt)

-- 绘制
shape:draw(centerX, centerY)
shape:draw(centerX, centerY, {
    fill = true,
    outline = true,
    showControlPoints = true,  -- 调试：显示控制点
})
```

---

## 使用示例

### 动态腹部形变

```lua
local ProcShape = require("lib.proc_shape")
local Resource = require("lib.resource")

-- 创建资源
local volume = Resource.new({id = "volume", value = 0, max = 2000})
local capacity = Resource.new({id = "capacity", value = 1000, max = 2000})

-- 创建腹部形状
local belly = ProcShape.new({
    type = "ellipse",
    baseWidth = 60,
    baseHeight = 50,
    physics = {
        jiggle = true,
        stiffness = 80,
        damping = 8,
    },
})

-- 绑定参数
belly:bindParam("scale", volume, function(v)
    return 1 + (v / 1000) * 0.8
end)

belly:bindParam("sag", volume, function(v)
    return math.pow(v / 1000, 2) * 30
end)

belly:bindParam("bulge", volume, function(v)
    return (v / 1000) * 0.3
end)

-- 游戏循环
function love.update(dt)
    volume:update(dt)
    belly:update(dt)
end

function love.draw()
    belly:draw(400, 350)
end

function love.mousepressed(x, y, button)
    -- 点击腹部触发晃动
    if belly:contains(x, y, 400, 350) then
        belly:poke(x - 400, y - 350, 1)
    end
end
```

### 贝塞尔曲线腹部

```lua
local belly = ProcShape.newBezier({
    controlPoints = {
        {x = 0, y = -40, fixed = true},    -- 顶部（连接胸部）
        {x = 30, y = -30, fixed = false},
        {x = 40, y = 0, fixed = false},    -- 右侧
        {x = 30, y = 30, fixed = false},
        {x = 0, y = 40, fixed = false},    -- 底部
        {x = -30, y = 30, fixed = false},
        {x = -40, y = 0, fixed = false},   -- 左侧
        {x = -30, y = -30, fixed = false},
    },
    deformRules = {
        -- 右侧随 volume 扩张
        {point = 3, axis = "x", param = "volume", formula = function(v) return 40 + v * 0.02 end},
        -- 左侧随 volume 扩张
        {point = 7, axis = "x", param = "volume", formula = function(v) return -40 - v * 0.02 end},
        -- 底部随 volume 下垂
        {point = 5, axis = "y", param = "volume", formula = function(v) return 40 + v * 0.03 end},
    },
    physics = {jiggle = true, stiffness = 60, damping = 6},
})

belly:bindParam("volume", volumeResource, function(v) return v end)
```

### 符号动画效果

```lua
-- 创建符号形状
local symbolShape = ProcShape.new({
    type = "ellipse",
    baseWidth = 40,
    baseHeight = 40,
    physics = {
        jiggle = true,
        stiffness = 200,
        damping = 15,
    },
})

-- 赢钱时触发弹跳
function onWin()
    symbolShape:poke(0, -20, 2)
end
```

---

## 与 Resource System 集成

```lua
local Resource = require("lib.resource")
local ProcShape = require("lib.proc_shape")

-- 创建派生资源：张力
local volume = Resource.new({id = "volume", value = 500, max = 2000})
local capacity = Resource.new({id = "capacity", value = 1000, max = 2000})

local tension = Resource.newDerived({
    id = "tension",
    dependencies = {volume = volume, capacity = capacity},
    formula = function(deps)
        return math.pow(deps.volume / deps.capacity, 1.5) * 100
    end,
    max = 100,
})

-- 形状根据张力变色
local shape = ProcShape.new({type = "ellipse", baseWidth = 80, baseHeight = 60})

function love.update(dt)
    volume:update(dt)
    shape:update(dt)
    
    -- 根据张力设置颜色
    local t = tension:get() / 100
    shape:setFillColor(
        0.8 + t * 0.2,  -- 红色增加
        0.8 - t * 0.3,  -- 绿色减少
        0.8 - t * 0.3,  -- 蓝色减少
        1
    )
end
```
