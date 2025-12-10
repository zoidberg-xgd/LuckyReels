---@class InteractRegionConfig
---@field shape "rect"|"circle"|"polygon"|"ellipse"
---@field bounds table 边界定义
---@field interactions string[] 支持的交互类型
---@field subRegions table[]|nil 子区域

---@class InteractRegion
---@field shape string
---@field bounds table
---@field interactions table<string, boolean>
---@field subRegions table[]
---@field listeners table
---@field state table
local InteractRegion = {}
InteractRegion.__index = InteractRegion

---创建交互区域
---@param config InteractRegionConfig
---@return InteractRegion
function InteractRegion.new(config)
    local self = setmetatable({}, InteractRegion)
    
    self.shape = config.shape or "rect"
    self.bounds = config.bounds or {}
    self.points = config.points  -- 多边形点
    
    -- 支持的交互类型
    self.interactions = {}
    for _, interaction in ipairs(config.interactions or {"click"}) do
        self.interactions[interaction] = true
    end
    
    -- 子区域
    self.subRegions = {}
    for _, sub in ipairs(config.subRegions or {}) do
        table.insert(self.subRegions, {
            id = sub.id,
            shape = sub.shape or "rect",
            bounds = sub.bounds,
            points = sub.points,
        })
    end
    
    -- 事件监听器
    self.listeners = {
        click = {},
        hover = {},
        drag = {},
        hold = {},
        release = {},
        enter = {},
        leave = {},
    }
    
    -- 状态
    self.state = {
        isHovered = false,
        isPressed = false,
        isDragging = false,
        holdTime = 0,
        dragStart = nil,
        lastPosition = nil,
        currentSubRegion = nil,
    }
    
    -- 位置偏移（用于移动区域）
    self.offset = {x = 0, y = 0}
    
    -- 启用状态
    self.enabled = true
    
    return self
end

---设置偏移（移动区域位置）
---@param x number
---@param y number
---@return InteractRegion self
function InteractRegion:setOffset(x, y)
    self.offset.x = x
    self.offset.y = y
    return self
end

---启用/禁用
---@param enabled boolean
---@return InteractRegion self
function InteractRegion:setEnabled(enabled)
    self.enabled = enabled
    if not enabled then
        self:_resetState()
    end
    return self
end

---检测点是否在区域内
---@param x number
---@param y number
---@return boolean
function InteractRegion:contains(x, y)
    if not self.enabled then
        return false
    end
    
    -- 转换为本地坐标
    local lx = x - self.offset.x
    local ly = y - self.offset.y
    
    return self:_containsLocal(lx, ly, self.shape, self.bounds, self.points)
end

---获取点所在的子区域
---@param x number
---@param y number
---@return string|nil subRegionId
function InteractRegion:getSubRegion(x, y)
    if not self:contains(x, y) then
        return nil
    end
    
    local lx = x - self.offset.x
    local ly = y - self.offset.y
    
    for _, sub in ipairs(self.subRegions) do
        if self:_containsLocal(lx, ly, sub.shape, sub.bounds, sub.points) then
            return sub.id
        end
    end
    
    return nil
end

---@private
function InteractRegion:_containsLocal(x, y, shape, bounds, points)
    if shape == "rect" then
        return x >= bounds[1] and x <= bounds[1] + bounds[3] and
               y >= bounds[2] and y <= bounds[2] + bounds[4]
    elseif shape == "circle" then
        local cx, cy, r = bounds[1], bounds[2], bounds[3]
        local dx, dy = x - cx, y - cy
        return (dx * dx + dy * dy) <= (r * r)
    elseif shape == "ellipse" then
        local cx, cy, rx, ry = bounds[1], bounds[2], bounds[3], bounds[4]
        local nx = (x - cx) / rx
        local ny = (y - cy) / ry
        return (nx * nx + ny * ny) <= 1
    elseif shape == "polygon" and points then
        return self:_pointInPolygon(x, y, points)
    end
    
    return false
end

---@private
function InteractRegion:_pointInPolygon(x, y, points)
    local inside = false
    local j = #points
    
    for i = 1, #points do
        local xi, yi = points[i][1], points[i][2]
        local xj, yj = points[j][1], points[j][2]
        
        if ((yi > y) ~= (yj > y)) and
           (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        
        j = i
    end
    
    return inside
end

---注册事件监听器
---@param event string "click"|"hover"|"drag"|"hold"|"release"|"enter"|"leave"
---@param callback function
---@return InteractRegion self
function InteractRegion:on(event, callback)
    if self.listeners[event] then
        table.insert(self.listeners[event], callback)
    end
    return self
end

---移除事件监听器
---@param event string
---@param callback function|nil 如果为 nil，移除所有该事件的监听器
---@return InteractRegion self
function InteractRegion:off(event, callback)
    if not self.listeners[event] then
        return self
    end
    
    if callback == nil then
        self.listeners[event] = {}
    else
        for i = #self.listeners[event], 1, -1 do
            if self.listeners[event][i] == callback then
                table.remove(self.listeners[event], i)
            end
        end
    end
    
    return self
end

---@private
function InteractRegion:_emit(event, ...)
    for _, callback in ipairs(self.listeners[event] or {}) do
        callback(...)
    end
end

---处理鼠标按下
---@param x number
---@param y number
---@param button number
---@return boolean handled
function InteractRegion:mousepressed(x, y, button)
    if not self.enabled then
        return false
    end
    
    if not self:contains(x, y) then
        return false
    end
    
    self.state.isPressed = true
    self.state.holdTime = 0
    self.state.dragStart = {x = x, y = y}
    self.state.lastPosition = {x = x, y = y}
    
    return true
end

---处理鼠标释放
---@param x number
---@param y number
---@param button number
---@return boolean handled
function InteractRegion:mousereleased(x, y, button)
    if not self.enabled then
        return false
    end
    
    local wasPressed = self.state.isPressed
    local wasDragging = self.state.isDragging
    
    if wasPressed then
        local subRegion = self:getSubRegion(x, y)
        
        if wasDragging and self.interactions.drag then
            self:_emit("drag", x, y, "end", subRegion)
        elseif self:contains(x, y) and self.interactions.click then
            self:_emit("click", x, y, subRegion)
        end
        
        if self.interactions.release then
            self:_emit("release", x, y, subRegion)
        end
    end
    
    self.state.isPressed = false
    self.state.isDragging = false
    self.state.dragStart = nil
    
    return wasPressed
end

---处理鼠标移动
---@param x number
---@param y number
---@return boolean handled
function InteractRegion:mousemoved(x, y)
    if not self.enabled then
        return false
    end
    
    local wasHovered = self.state.isHovered
    local isHovered = self:contains(x, y)
    local subRegion = self:getSubRegion(x, y)
    
    -- 进入/离开检测
    if isHovered and not wasHovered then
        self.state.isHovered = true
        if self.interactions.hover then
            self:_emit("hover", x, y, true)
        end
        self:_emit("enter", x, y, subRegion)
    elseif not isHovered and wasHovered then
        self.state.isHovered = false
        if self.interactions.hover then
            self:_emit("hover", x, y, false)
        end
        self:_emit("leave", x, y, self.state.currentSubRegion)
    end
    
    -- 子区域变化
    if isHovered and subRegion ~= self.state.currentSubRegion then
        if self.state.currentSubRegion then
            self:_emit("leave", x, y, self.state.currentSubRegion)
        end
        self.state.currentSubRegion = subRegion
        if subRegion then
            self:_emit("enter", x, y, subRegion)
        end
    end
    
    -- 拖拽检测
    if self.state.isPressed and self.interactions.drag then
        local start = self.state.dragStart
        if start then
            local dx = x - start.x
            local dy = y - start.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if not self.state.isDragging and dist > 5 then
                self.state.isDragging = true
                self:_emit("drag", x, y, "start", subRegion)
            elseif self.state.isDragging then
                local last = self.state.lastPosition
                self:_emit("drag", x, y, "move", subRegion, x - last.x, y - last.y)
            end
        end
    end
    
    self.state.lastPosition = {x = x, y = y}
    
    return isHovered
end

---更新（每帧调用，用于 hold 检测）
---@param dt number
---@return InteractRegion self
function InteractRegion:update(dt)
    if not self.enabled then
        return self
    end
    
    -- Hold 检测
    if self.state.isPressed and self.interactions.hold then
        self.state.holdTime = self.state.holdTime + dt
        
        local pos = self.state.lastPosition
        if pos then
            local subRegion = self:getSubRegion(pos.x, pos.y)
            self:_emit("hold", pos.x, pos.y, self.state.holdTime, subRegion)
        end
    end
    
    return self
end

---@private
function InteractRegion:_resetState()
    self.state.isHovered = false
    self.state.isPressed = false
    self.state.isDragging = false
    self.state.holdTime = 0
    self.state.dragStart = nil
    self.state.currentSubRegion = nil
end

---绘制调试信息（LÖVE 环境）
---@param options table|nil {showBounds, showSubRegions, color}
function InteractRegion:debugDraw(options)
    if not love or not love.graphics then
        return
    end
    
    options = options or {}
    local color = options.color or {1, 0, 0, 0.3}
    local hoverColor = {0, 1, 0, 0.5}
    
    love.graphics.setColor(self.state.isHovered and hoverColor or color)
    
    local ox, oy = self.offset.x, self.offset.y
    
    if self.shape == "rect" then
        love.graphics.rectangle("fill",
            ox + self.bounds[1], oy + self.bounds[2],
            self.bounds[3], self.bounds[4])
    elseif self.shape == "circle" then
        love.graphics.circle("fill",
            ox + self.bounds[1], oy + self.bounds[2], self.bounds[3])
    elseif self.shape == "ellipse" then
        love.graphics.ellipse("fill",
            ox + self.bounds[1], oy + self.bounds[2],
            self.bounds[3], self.bounds[4])
    elseif self.shape == "polygon" and self.points then
        local vertices = {}
        for _, p in ipairs(self.points) do
            table.insert(vertices, ox + p[1])
            table.insert(vertices, oy + p[2])
        end
        if #vertices >= 6 then
            love.graphics.polygon("fill", vertices)
        end
    end
    
    -- 绘制子区域
    if options.showSubRegions then
        love.graphics.setColor(0, 0, 1, 0.2)
        for _, sub in ipairs(self.subRegions) do
            if sub.shape == "rect" then
                love.graphics.rectangle("fill",
                    ox + sub.bounds[1], oy + sub.bounds[2],
                    sub.bounds[3], sub.bounds[4])
            end
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

---绑定到 ProcShape（动态区域）
---@param procShape table ProcShape 实例
---@return InteractRegion self
function InteractRegion:bindToShape(procShape)
    self.boundShape = procShape
    return self
end

---检测点是否在绑定的形状内
---@param x number
---@param y number
---@param cx number 形状中心 x
---@param cy number 形状中心 y
---@return boolean
function InteractRegion:containsWithShape(x, y, cx, cy)
    if self.boundShape then
        return self.boundShape:contains(x, y, cx, cy)
    end
    return self:contains(x, y)
end

--------------------------------------------------------------------------------
-- InteractRegionManager: 区域管理器
--------------------------------------------------------------------------------

---@class InteractRegionManager
---@field regions table<string, InteractRegion>
---@field order string[] 渲染/检测顺序
local InteractRegionManager = {}
InteractRegionManager.__index = InteractRegionManager

---创建区域管理器
---@return InteractRegionManager
function InteractRegion.newManager()
    local self = setmetatable({}, InteractRegionManager)
    self.regions = {}
    self.order = {}
    return self
end

---注册区域
---@param id string
---@param region InteractRegion
---@return InteractRegionManager self
function InteractRegionManager:register(id, region)
    self.regions[id] = region
    table.insert(self.order, id)
    return self
end

---获取区域
---@param id string
---@return InteractRegion|nil
function InteractRegionManager:get(id)
    return self.regions[id]
end

---移除区域
---@param id string
---@return InteractRegionManager self
function InteractRegionManager:remove(id)
    self.regions[id] = nil
    for i = #self.order, 1, -1 do
        if self.order[i] == id then
            table.remove(self.order, i)
        end
    end
    return self
end

---处理鼠标按下（按顺序检测，返回第一个处理的区域）
---@param x number
---@param y number
---@param button number
---@return string|nil regionId
function InteractRegionManager:mousepressed(x, y, button)
    for i = #self.order, 1, -1 do
        local id = self.order[i]
        local region = self.regions[id]
        if region and region:mousepressed(x, y, button) then
            return id
        end
    end
    return nil
end

---处理鼠标释放
---@param x number
---@param y number
---@param button number
---@return string|nil regionId
function InteractRegionManager:mousereleased(x, y, button)
    local handled = nil
    for i = #self.order, 1, -1 do
        local id = self.order[i]
        local region = self.regions[id]
        if region and region:mousereleased(x, y, button) then
            handled = id
        end
    end
    return handled
end

---处理鼠标移动
---@param x number
---@param y number
function InteractRegionManager:mousemoved(x, y)
    for _, id in ipairs(self.order) do
        local region = self.regions[id]
        if region then
            region:mousemoved(x, y)
        end
    end
end

---更新所有区域
---@param dt number
function InteractRegionManager:update(dt)
    for _, region in pairs(self.regions) do
        region:update(dt)
    end
end

---绘制所有区域调试信息
---@param options table|nil
function InteractRegionManager:debugDraw(options)
    for _, id in ipairs(self.order) do
        local region = self.regions[id]
        if region then
            region:debugDraw(options)
        end
    end
end

-- 导出
InteractRegion.InteractRegionManager = InteractRegionManager

return InteractRegion
