---@class ProcShapeParams
---@field scale number 整体缩放
---@field stretchX number X轴拉伸
---@field stretchY number Y轴拉伸
---@field sag number 下垂
---@field bulge number 凸起
---@field rotation number 旋转

---@class ProcShapePhysics
---@field jiggle boolean 是否启用晃动
---@field stiffness number 刚度
---@field damping number 阻尼
---@field velocity table {x, y} 当前速度
---@field displacement table {x, y} 当前位移

---@class ProcShapeConfig
---@field type "ellipse"|"bezier"|"polygon"
---@field baseWidth number
---@field baseHeight number
---@field params ProcShapeParams
---@field physics ProcShapePhysics|nil
---@field color table|nil

---@class ProcShape
---@field type string
---@field baseWidth number
---@field baseHeight number
---@field params ProcShapeParams
---@field physics ProcShapePhysics
---@field bindings table
---@field color table
local ProcShape = {}
ProcShape.__index = ProcShape

---创建程序化形状
---@param config ProcShapeConfig
---@return ProcShape
function ProcShape.new(config)
    local self = setmetatable({}, ProcShape)
    
    self.type = config.type or "ellipse"
    self.baseWidth = config.baseWidth or 50
    self.baseHeight = config.baseHeight or 40
    
    self.params = {
        scale = 1.0,
        stretchX = 1.0,
        stretchY = 1.0,
        sag = 0,
        bulge = 0,
        rotation = 0,
    }
    
    -- 合并配置参数
    if config.params then
        for k, v in pairs(config.params) do
            self.params[k] = v
        end
    end
    
    -- 物理属性
    self.physics = {
        jiggle = false,
        stiffness = 100,
        damping = 10,
        velocity = {x = 0, y = 0},
        displacement = {x = 0, y = 0},
    }
    
    if config.physics then
        for k, v in pairs(config.physics) do
            if type(v) == "table" then
                self.physics[k] = {x = v.x or 0, y = v.y or 0}
            else
                self.physics[k] = v
            end
        end
    end
    
    self.bindings = {}
    self.color = config.color or {1, 1, 1, 1}
    self.fillColor = config.fillColor or {0.8, 0.8, 0.8, 1}
    self.lineWidth = config.lineWidth or 2
    
    return self
end

---绑定参数到资源
---@param paramName string
---@param resource table 资源对象（需要有 get 方法）
---@param transform function|nil 转换函数
---@return ProcShape self
function ProcShape:bindParam(paramName, resource, transform)
    self.bindings[paramName] = {
        resource = resource,
        transform = transform or function(v) return v end,
    }
    return self
end

---解绑参数
---@param paramName string
---@return ProcShape self
function ProcShape:unbindParam(paramName)
    self.bindings[paramName] = nil
    return self
end

---设置参数
---@param paramName string
---@param value number
---@return ProcShape self
function ProcShape:setParam(paramName, value)
    self.params[paramName] = value
    return self
end

---获取参数（考虑绑定）
---@param paramName string
---@return number
function ProcShape:getParam(paramName)
    local binding = self.bindings[paramName]
    if binding then
        local value = binding.resource:get()
        return binding.transform(value)
    end
    return self.params[paramName] or 0
end

---戳一下（触发晃动）
---@param x number 相对于中心的 x
---@param y number 相对于中心的 y
---@param force number|nil 力度
---@return ProcShape self
function ProcShape:poke(x, y, force)
    if not self.physics.jiggle then
        return self
    end
    
    force = force or 1
    
    -- 根据戳的位置计算速度方向
    local dist = math.sqrt(x * x + y * y)
    if dist > 0 then
        local nx, ny = x / dist, y / dist
        self.physics.velocity.x = self.physics.velocity.x - nx * force * 50
        self.physics.velocity.y = self.physics.velocity.y - ny * force * 50
    else
        self.physics.velocity.y = self.physics.velocity.y + force * 50
    end
    
    return self
end

---更新（每帧调用）
---@param dt number
---@return ProcShape self
function ProcShape:update(dt)
    -- 更新绑定参数
    for paramName, binding in pairs(self.bindings) do
        local value = binding.resource:get()
        self.params[paramName] = binding.transform(value)
    end
    
    -- 更新物理（弹簧阻尼系统）
    if self.physics.jiggle then
        local stiffness = self.physics.stiffness
        local damping = self.physics.damping
        local disp = self.physics.displacement
        local vel = self.physics.velocity
        
        -- 先更新位移（使用当前速度）
        disp.x = disp.x + vel.x * dt
        disp.y = disp.y + vel.y * dt
        
        -- 弹簧力: F = -kx - cv
        local ax = -stiffness * disp.x - damping * vel.x
        local ay = -stiffness * disp.y - damping * vel.y
        
        -- 更新速度
        vel.x = vel.x + ax * dt
        vel.y = vel.y + ay * dt
        
        -- 衰减小振动
        if math.abs(disp.x) < 0.1 and math.abs(vel.x) < 1 then
            disp.x = 0
            vel.x = 0
        end
        if math.abs(disp.y) < 0.1 and math.abs(vel.y) < 1 then
            disp.y = 0
            vel.y = 0
        end
    end
    
    return self
end

---获取当前尺寸
---@return number width, number height
function ProcShape:getSize()
    local scale = self:getParam("scale")
    local stretchX = self:getParam("stretchX")
    local stretchY = self:getParam("stretchY")
    
    local width = self.baseWidth * scale * stretchX
    local height = self.baseHeight * scale * stretchY
    
    return width, height
end

---获取轮廓点
---@param segments number|nil 分段数
---@return table points {{x, y}, ...}
function ProcShape:getOutlinePoints(segments)
    segments = segments or 32
    local points = {}
    
    local scale = self:getParam("scale")
    local stretchX = self:getParam("stretchX")
    local stretchY = self:getParam("stretchY")
    local sag = self:getParam("sag")
    local bulge = self:getParam("bulge")
    local rotation = self:getParam("rotation")
    
    local w = self.baseWidth * scale * stretchX / 2
    local h = self.baseHeight * scale * stretchY / 2
    
    -- 物理位移
    local dispX = self.physics.displacement.x
    local dispY = self.physics.displacement.y
    
    if self.type == "ellipse" then
        for i = 0, segments - 1 do
            local angle = (i / segments) * math.pi * 2
            local x = math.cos(angle) * w
            local y = math.sin(angle) * h
            
            -- 应用下垂（底部更多）
            if y > 0 then
                y = y + sag * (y / h)
            end
            
            -- 应用凸起（中间更多）
            local bulgeFactor = 1 - math.abs(y / h)
            x = x * (1 + bulge * bulgeFactor * 0.5)
            
            -- 应用物理位移
            x = x + dispX * (1 - math.abs(y / h) * 0.5)
            y = y + dispY * (1 - math.abs(x / w) * 0.5)
            
            -- 应用旋转
            if rotation ~= 0 then
                local cos_r = math.cos(rotation)
                local sin_r = math.sin(rotation)
                local rx = x * cos_r - y * sin_r
                local ry = x * sin_r + y * cos_r
                x, y = rx, ry
            end
            
            table.insert(points, {x = x, y = y})
        end
    elseif self.type == "polygon" then
        -- 简单多边形
        local sides = segments
        for i = 0, sides - 1 do
            local angle = (i / sides) * math.pi * 2 - math.pi / 2
            local x = math.cos(angle) * w
            local y = math.sin(angle) * h
            
            if rotation ~= 0 then
                local cos_r = math.cos(rotation)
                local sin_r = math.sin(rotation)
                local rx = x * cos_r - y * sin_r
                local ry = x * sin_r + y * cos_r
                x, y = rx, ry
            end
            
            table.insert(points, {x = x, y = y})
        end
    end
    
    return points
end

---检测点是否在形状内
---@param px number
---@param py number
---@param cx number 形状中心 x
---@param cy number 形状中心 y
---@return boolean
function ProcShape:contains(px, py, cx, cy)
    local localX = px - cx
    local localY = py - cy
    
    local scale = self:getParam("scale")
    local stretchX = self:getParam("stretchX")
    local stretchY = self:getParam("stretchY")
    
    local w = self.baseWidth * scale * stretchX / 2
    local h = self.baseHeight * scale * stretchY / 2
    
    if self.type == "ellipse" then
        -- 椭圆方程: (x/a)^2 + (y/b)^2 <= 1
        local nx = localX / w
        local ny = localY / h
        return (nx * nx + ny * ny) <= 1
    elseif self.type == "polygon" then
        -- 使用射线法
        local points = self:getOutlinePoints()
        return self:_pointInPolygon(localX, localY, points)
    end
    
    return false
end

---@private
function ProcShape:_pointInPolygon(x, y, points)
    local inside = false
    local j = #points
    
    for i = 1, #points do
        local xi, yi = points[i].x, points[i].y
        local xj, yj = points[j].x, points[j].y
        
        if ((yi > y) ~= (yj > y)) and
           (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        
        j = i
    end
    
    return inside
end

---绘制（LÖVE 环境）
---@param cx number 中心 x
---@param cy number 中心 y
---@param options table|nil {fill, outline, color}
function ProcShape:draw(cx, cy, options)
    if not love or not love.graphics then
        return
    end
    
    options = options or {}
    local fill = options.fill ~= false
    local outline = options.outline ~= false
    
    local points = self:getOutlinePoints()
    
    -- 转换为 LÖVE 格式
    local vertices = {}
    for _, p in ipairs(points) do
        table.insert(vertices, cx + p.x)
        table.insert(vertices, cy + p.y)
    end
    
    -- 填充
    if fill and #vertices >= 6 then
        love.graphics.setColor(self.fillColor)
        love.graphics.polygon("fill", vertices)
    end
    
    -- 轮廓
    if outline and #vertices >= 4 then
        love.graphics.setColor(self.color)
        love.graphics.setLineWidth(self.lineWidth)
        love.graphics.polygon("line", vertices)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

---设置颜色
---@param r number
---@param g number
---@param b number
---@param a number|nil
---@return ProcShape self
function ProcShape:setColor(r, g, b, a)
    self.color = {r, g, b, a or 1}
    return self
end

---设置填充颜色
---@param r number
---@param g number
---@param b number
---@param a number|nil
---@return ProcShape self
function ProcShape:setFillColor(r, g, b, a)
    self.fillColor = {r, g, b, a or 1}
    return self
end

--------------------------------------------------------------------------------
-- BezierShape: 贝塞尔曲线形状
--------------------------------------------------------------------------------

---@class BezierControlPoint
---@field x number
---@field y number
---@field fixed boolean 是否固定

---@class BezierDeformRule
---@field point number 控制点索引
---@field axis "x"|"y"
---@field param string 参数名
---@field formula function(value): number

---@class BezierShape
---@field controlPoints BezierControlPoint[]
---@field deformRules BezierDeformRule[]
---@field params table
---@field bindings table
---@field physics table
local BezierShape = {}
BezierShape.__index = BezierShape

---创建贝塞尔形状
---@param config table
---@return BezierShape
function ProcShape.newBezier(config)
    local self = setmetatable({}, BezierShape)
    
    self.controlPoints = {}
    for i, cp in ipairs(config.controlPoints or {}) do
        self.controlPoints[i] = {
            x = cp.x or 0,
            y = cp.y or 0,
            fixed = cp.fixed or false,
            baseX = cp.x or 0,
            baseY = cp.y or 0,
        }
    end
    
    self.deformRules = config.deformRules or {}
    self.params = config.params or {}
    self.bindings = {}
    
    self.physics = {
        jiggle = false,
        stiffness = 100,
        damping = 10,
        velocities = {},
        displacements = {},
    }
    
    if config.physics then
        for k, v in pairs(config.physics) do
            self.physics[k] = v
        end
    end
    
    -- 初始化每个控制点的物理状态
    for i = 1, #self.controlPoints do
        self.physics.velocities[i] = {x = 0, y = 0}
        self.physics.displacements[i] = {x = 0, y = 0}
    end
    
    self.color = config.color or {1, 1, 1, 1}
    self.fillColor = config.fillColor or {0.8, 0.8, 0.8, 1}
    self.lineWidth = config.lineWidth or 2
    self.segments = config.segments or 32
    
    return self
end

---绑定参数
---@param paramName string
---@param resource table
---@param transform function|nil
---@return BezierShape self
function BezierShape:bindParam(paramName, resource, transform)
    self.bindings[paramName] = {
        resource = resource,
        transform = transform or function(v) return v end,
    }
    return self
end

---设置参数
---@param paramName string
---@param value number
---@return BezierShape self
function BezierShape:setParam(paramName, value)
    self.params[paramName] = value
    return self
end

---获取参数
---@param paramName string
---@return number
function BezierShape:getParam(paramName)
    local binding = self.bindings[paramName]
    if binding then
        local value = binding.resource:get()
        return binding.transform(value)
    end
    return self.params[paramName] or 0
end

---戳一下
---@param x number
---@param y number
---@param force number|nil
---@return BezierShape self
function BezierShape:poke(x, y, force)
    if not self.physics.jiggle then
        return self
    end
    
    force = force or 1
    
    -- 影响最近的非固定控制点
    for i, cp in ipairs(self.controlPoints) do
        if not cp.fixed then
            local dx = cp.x - x
            local dy = cp.y - y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist < 100 then
                local influence = 1 - dist / 100
                local vel = self.physics.velocities[i]
                if dist > 0.01 then
                    vel.x = vel.x + (dx / dist) * force * 30 * influence
                    vel.y = vel.y + (dy / dist) * force * 30 * influence
                else
                    -- 直接在控制点上戳，给一个随机方向
                    vel.x = vel.x + force * 30
                    vel.y = vel.y + force * 30
                end
            end
        end
    end
    
    return self
end

---更新
---@param dt number
---@return BezierShape self
function BezierShape:update(dt)
    -- 更新绑定参数
    for paramName, binding in pairs(self.bindings) do
        local value = binding.resource:get()
        self.params[paramName] = binding.transform(value)
    end
    
    -- 应用变形规则
    for _, rule in ipairs(self.deformRules) do
        local cp = self.controlPoints[rule.point]
        if cp and not cp.fixed then
            local paramValue = self:getParam(rule.param)
            local newValue = rule.formula(paramValue)
            
            if rule.axis == "x" then
                cp.x = newValue
            elseif rule.axis == "y" then
                cp.y = newValue
            end
        end
    end
    
    -- 更新物理
    if self.physics.jiggle then
        local stiffness = self.physics.stiffness
        local damping = self.physics.damping
        
        for i, cp in ipairs(self.controlPoints) do
            if not cp.fixed then
                local vel = self.physics.velocities[i]
                local disp = self.physics.displacements[i]
                
                -- 先更新位移
                disp.x = disp.x + vel.x * dt
                disp.y = disp.y + vel.y * dt
                
                -- 弹簧力
                local ax = -stiffness * disp.x - damping * vel.x
                local ay = -stiffness * disp.y - damping * vel.y
                
                -- 更新速度
                vel.x = vel.x + ax * dt
                vel.y = vel.y + ay * dt
                
                -- 衰减
                if math.abs(disp.x) < 0.1 and math.abs(vel.x) < 1 then
                    disp.x = 0
                    vel.x = 0
                end
                if math.abs(disp.y) < 0.1 and math.abs(vel.y) < 1 then
                    disp.y = 0
                    vel.y = 0
                end
            end
        end
    end
    
    return self
end

---获取当前控制点（含物理位移）
---@return table
function BezierShape:getControlPoints()
    local result = {}
    for i, cp in ipairs(self.controlPoints) do
        local disp = self.physics.displacements[i] or {x = 0, y = 0}
        result[i] = {
            x = cp.x + disp.x,
            y = cp.y + disp.y,
            fixed = cp.fixed,
        }
    end
    return result
end

---计算贝塞尔曲线点
---@param t number 0-1
---@param p0 table
---@param p1 table
---@param p2 table
---@param p3 table
---@return number x, number y
local function cubicBezier(t, p0, p1, p2, p3)
    local t2 = t * t
    local t3 = t2 * t
    local mt = 1 - t
    local mt2 = mt * mt
    local mt3 = mt2 * mt
    
    local x = mt3 * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t3 * p3.x
    local y = mt3 * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t3 * p3.y
    
    return x, y
end

---获取轮廓点
---@param segments number|nil
---@return table
function BezierShape:getOutlinePoints(segments)
    segments = segments or self.segments
    local points = {}
    local cps = self:getControlPoints()
    
    if #cps < 4 then
        return points
    end
    
    -- 假设控制点形成闭合曲线
    -- 每 4 个点定义一段贝塞尔曲线
    local numCurves = math.floor(#cps / 3)
    if numCurves < 1 then numCurves = 1 end
    
    local segmentsPerCurve = math.ceil(segments / numCurves)
    
    for curve = 0, numCurves - 1 do
        local i0 = (curve * 3) % #cps + 1
        local i1 = (curve * 3 + 1) % #cps + 1
        local i2 = (curve * 3 + 2) % #cps + 1
        local i3 = (curve * 3 + 3) % #cps + 1
        
        local p0 = cps[i0] or cps[1]
        local p1 = cps[i1] or cps[1]
        local p2 = cps[i2] or cps[1]
        local p3 = cps[i3] or cps[1]
        
        for j = 0, segmentsPerCurve - 1 do
            local t = j / segmentsPerCurve
            local x, y = cubicBezier(t, p0, p1, p2, p3)
            table.insert(points, {x = x, y = y})
        end
    end
    
    return points
end

---绘制
---@param cx number
---@param cy number
---@param options table|nil
function BezierShape:draw(cx, cy, options)
    if not love or not love.graphics then
        return
    end
    
    options = options or {}
    local fill = options.fill ~= false
    local outline = options.outline ~= false
    local showControlPoints = options.showControlPoints or false
    
    local points = self:getOutlinePoints()
    
    if #points < 3 then
        return
    end
    
    -- 转换为 LÖVE 格式
    local vertices = {}
    for _, p in ipairs(points) do
        table.insert(vertices, cx + p.x)
        table.insert(vertices, cy + p.y)
    end
    
    -- 填充
    if fill and #vertices >= 6 then
        love.graphics.setColor(self.fillColor)
        local ok, err = pcall(function()
            love.graphics.polygon("fill", vertices)
        end)
        if not ok then
            -- 如果多边形无效，尝试用三角形扇形
        end
    end
    
    -- 轮廓
    if outline and #vertices >= 4 then
        love.graphics.setColor(self.color)
        love.graphics.setLineWidth(self.lineWidth)
        love.graphics.polygon("line", vertices)
    end
    
    -- 显示控制点（调试用）
    if showControlPoints then
        local cps = self:getControlPoints()
        for i, cp in ipairs(cps) do
            if cp.fixed then
                love.graphics.setColor(1, 0, 0, 1)
            else
                love.graphics.setColor(0, 1, 0, 1)
            end
            love.graphics.circle("fill", cx + cp.x, cy + cp.y, 5)
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

---设置颜色
function BezierShape:setColor(r, g, b, a)
    self.color = {r, g, b, a or 1}
    return self
end

---设置填充颜色
function BezierShape:setFillColor(r, g, b, a)
    self.fillColor = {r, g, b, a or 1}
    return self
end

-- 导出
ProcShape.BezierShape = BezierShape

return ProcShape
