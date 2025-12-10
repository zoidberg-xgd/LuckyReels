-- examples/proc_shape_demo.lua
-- Procedural Shape System 使用示例
--
-- 运行: lua examples/proc_shape_demo.lua

package.path = package.path .. ";?.lua;?/init.lua"
local ProcShape = require("lib.proc_shape")
local Resource = require("lib.resource")

print("========================================")
print("Procedural Shape System Demo")
print("========================================\n")

--------------------------------------------------------------------------------
-- Mock Resource for testing
--------------------------------------------------------------------------------
local MockResource = {}
MockResource.__index = MockResource

function MockResource.new(value)
    return setmetatable({value = value}, MockResource)
end

function MockResource:get()
    return self.value
end

function MockResource:set(v)
    self.value = v
end

--------------------------------------------------------------------------------
-- 示例 1: 基础椭圆形状
--------------------------------------------------------------------------------
print("--- 示例 1: 基础椭圆形状 ---")

local ellipse = ProcShape.new({
    type = "ellipse",
    baseWidth = 100,
    baseHeight = 80,
})

local w, h = ellipse:getSize()
print(string.format("基础尺寸: %dx%d", w, h))

ellipse:setParam("scale", 1.5)
w, h = ellipse:getSize()
print(string.format("scale=1.5 后: %dx%d", w, h))

ellipse:setParam("stretchX", 2.0)
w, h = ellipse:getSize()
print(string.format("stretchX=2.0 后: %dx%d", w, h))

print()

--------------------------------------------------------------------------------
-- 示例 2: 参数绑定
--------------------------------------------------------------------------------
print("--- 示例 2: 参数绑定 ---")

local shape = ProcShape.new({
    type = "ellipse",
    baseWidth = 50,
    baseHeight = 40,
})

local volume = MockResource.new(500)

shape:bindParam("scale", volume, function(v)
    return 1 + (v / 1000) * 0.5
end)

print(string.format("volume=%d -> scale=%.2f", volume:get(), shape:getParam("scale")))

volume:set(1000)
shape:update(0.1)
print(string.format("volume=%d -> scale=%.2f", volume:get(), shape:getParam("scale")))

volume:set(2000)
shape:update(0.1)
print(string.format("volume=%d -> scale=%.2f", volume:get(), shape:getParam("scale")))

print()

--------------------------------------------------------------------------------
-- 示例 3: 轮廓点
--------------------------------------------------------------------------------
print("--- 示例 3: 轮廓点 ---")

local circle = ProcShape.new({
    type = "ellipse",
    baseWidth = 100,
    baseHeight = 100,
})

local points = circle:getOutlinePoints(8)
print(string.format("8 个轮廓点:"))
for i, p in ipairs(points) do
    print(string.format("  点 %d: (%.1f, %.1f)", i, p.x, p.y))
end

print()

--------------------------------------------------------------------------------
-- 示例 4: 点包含检测
--------------------------------------------------------------------------------
print("--- 示例 4: 点包含检测 ---")

local testShape = ProcShape.new({
    type = "ellipse",
    baseWidth = 100,
    baseHeight = 100,
})

local testPoints = {
    {x = 100, y = 100, desc = "中心"},
    {x = 120, y = 100, desc = "右侧内部"},
    {x = 150, y = 100, desc = "右侧边缘"},
    {x = 200, y = 100, desc = "外部"},
}

for _, tp in ipairs(testPoints) do
    local inside = testShape:contains(tp.x, tp.y, 100, 100)
    print(string.format("  %s (%d, %d): %s", tp.desc, tp.x, tp.y, inside and "内部" or "外部"))
end

print()

--------------------------------------------------------------------------------
-- 示例 5: 物理晃动
--------------------------------------------------------------------------------
print("--- 示例 5: 物理晃动 ---")

local jiggleShape = ProcShape.new({
    type = "ellipse",
    baseWidth = 50,
    baseHeight = 50,
    physics = {
        jiggle = true,
        stiffness = 100,
        damping = 10,
    },
})

print("初始位移: x=" .. jiggleShape.physics.displacement.x .. ", y=" .. jiggleShape.physics.displacement.y)

jiggleShape:poke(0, 10, 2)
print("戳后速度: x=" .. string.format("%.1f", jiggleShape.physics.velocity.x) .. 
      ", y=" .. string.format("%.1f", jiggleShape.physics.velocity.y))

-- 模拟几帧
for i = 1, 5 do
    jiggleShape:update(0.1)
    print(string.format("  帧 %d: 位移=(%.2f, %.2f), 速度=(%.2f, %.2f)",
        i,
        jiggleShape.physics.displacement.x,
        jiggleShape.physics.displacement.y,
        jiggleShape.physics.velocity.x,
        jiggleShape.physics.velocity.y
    ))
end

print()

--------------------------------------------------------------------------------
-- 示例 6: 变形参数
--------------------------------------------------------------------------------
print("--- 示例 6: 变形参数 ---")

local deformShape = ProcShape.new({
    type = "ellipse",
    baseWidth = 100,
    baseHeight = 80,
})

print("测试不同参数对轮廓的影响:")

-- 下垂
deformShape:setParam("sag", 20)
local sagPoints = deformShape:getOutlinePoints(4)
print("  sag=20: 底部点 y=" .. string.format("%.1f", sagPoints[3].y))

-- 凸起
deformShape:setParam("sag", 0)
deformShape:setParam("bulge", 0.5)
local bulgePoints = deformShape:getOutlinePoints(4)
print("  bulge=0.5: 右侧点 x=" .. string.format("%.1f", bulgePoints[1].x))

-- 旋转
deformShape:setParam("bulge", 0)
deformShape:setParam("rotation", math.pi / 4)
local rotPoints = deformShape:getOutlinePoints(4)
print("  rotation=45°: 第一点 (" .. string.format("%.1f", rotPoints[1].x) .. ", " .. string.format("%.1f", rotPoints[1].y) .. ")")

print()

--------------------------------------------------------------------------------
-- 示例 7: 贝塞尔形状
--------------------------------------------------------------------------------
print("--- 示例 7: 贝塞尔形状 ---")

local bezier = ProcShape.newBezier({
    controlPoints = {
        {x = 0, y = -50, fixed = true},
        {x = 50, y = -25, fixed = false},
        {x = 50, y = 25, fixed = false},
        {x = 0, y = 50, fixed = false},
    },
    segments = 16,
})

print("控制点:")
local cps = bezier:getControlPoints()
for i, cp in ipairs(cps) do
    print(string.format("  点 %d: (%.1f, %.1f) %s", i, cp.x, cp.y, cp.fixed and "[固定]" or ""))
end

local curvePoints = bezier:getOutlinePoints()
print(string.format("曲线点数: %d", #curvePoints))

print()

--------------------------------------------------------------------------------
-- 示例 8: 贝塞尔变形规则
--------------------------------------------------------------------------------
print("--- 示例 8: 贝塞尔变形规则 ---")

local deformBezier = ProcShape.newBezier({
    controlPoints = {
        {x = 0, y = -50, fixed = true},
        {x = 50, y = 0, fixed = false},
        {x = 0, y = 50, fixed = false},
        {x = -50, y = 0, fixed = false},
    },
    deformRules = {
        {point = 2, axis = "x", param = "scale", formula = function(s) return 50 * s end},
        {point = 3, axis = "y", param = "sag", formula = function(s) return 50 + s end},
    },
})

print("初始控制点 2: x=" .. deformBezier.controlPoints[2].x)

deformBezier:setParam("scale", 2.0)
deformBezier:update(0.1)
print("scale=2.0 后控制点 2: x=" .. deformBezier.controlPoints[2].x)

deformBezier:setParam("sag", 30)
deformBezier:update(0.1)
print("sag=30 后控制点 3: y=" .. deformBezier.controlPoints[3].y)

print()

--------------------------------------------------------------------------------
-- 示例 9: 贝塞尔物理
--------------------------------------------------------------------------------
print("--- 示例 9: 贝塞尔物理 ---")

local physicsBezier = ProcShape.newBezier({
    controlPoints = {
        {x = 0, y = -50, fixed = true},
        {x = 50, y = 0, fixed = false},
        {x = 0, y = 50, fixed = false},
    },
    physics = {
        jiggle = true,
        stiffness = 100,
        damping = 10,
    },
})

print("戳非固定点...")
physicsBezier:poke(50, 0, 1)

print("点 1 (固定) 速度: " .. physicsBezier.physics.velocities[1].x)
print("点 2 (非固定) 速度: " .. string.format("%.1f", physicsBezier.physics.velocities[2].x))

print()

--------------------------------------------------------------------------------
-- 示例 10: 综合应用 - 动态腹部
--------------------------------------------------------------------------------
print("--- 示例 10: 综合应用 - 动态腹部 ---")

local volumeRes = MockResource.new(0)

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

belly:bindParam("scale", volumeRes, function(v)
    return 1 + (v / 1000) * 0.8
end)

belly:bindParam("sag", volumeRes, function(v)
    return math.pow(v / 1000, 2) * 30
end)

print("模拟填充过程:")
for vol = 0, 1000, 250 do
    volumeRes:set(vol)
    belly:update(0.1)
    
    local w, h = belly:getSize()
    local sag = belly:getParam("sag")
    print(string.format("  volume=%d: 尺寸=%.0fx%.0f, sag=%.1f", vol, w, h, sag))
end

print()
print("========================================")
print("Demo 完成!")
print("========================================")
