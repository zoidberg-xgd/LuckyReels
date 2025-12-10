---@class StateSpriteState
---@field sprite string|love.Image 精灵路径或图像
---@field priority number 优先级（越高越优先显示）
---@field offset table|nil {x, y} 偏移
---@field scale table|nil {x, y} 缩放
---@field rotation number|nil 旋转角度
---@field color table|nil {r, g, b, a} 颜色

---@class StateSpriteCondition
---@field state string 目标状态
---@field when function(ctx): boolean 条件函数
---@field priority number|nil 条件优先级

---@class StateSpriteTransition
---@field duration number 过渡时间
---@field easing string|function 缓动函数名或函数

---@class StateSpriteConfig
---@field states table<string, StateSpriteState>
---@field conditions StateSpriteCondition[]|nil
---@field transitions table<string, StateSpriteTransition>|nil
---@field defaultState string|nil

---@class StateSprite
---@field states table<string, StateSpriteState>
---@field conditions StateSpriteCondition[]
---@field transitions table<string, StateSpriteTransition>
---@field currentState string
---@field previousState string|nil
---@field context table
---@field transitionProgress number
---@field transitionDuration number
---@field temporaryState string|nil
---@field temporaryDuration number
---@field images table<string, love.Image>
local StateSprite = {}
StateSprite.__index = StateSprite

-- 缓动函数
local Easing = {
    linear = function(t) return t end,
    inQuad = function(t) return t * t end,
    outQuad = function(t) return t * (2 - t) end,
    inOutQuad = function(t)
        if t < 0.5 then return 2 * t * t end
        return -1 + (4 - 2 * t) * t
    end,
    inCubic = function(t) return t * t * t end,
    outCubic = function(t) return 1 + (t - 1) ^ 3 end,
    inOutCubic = function(t)
        if t < 0.5 then return 4 * t * t * t end
        return 1 + (t - 1) ^ 3 * 4
    end,
    inElastic = function(t)
        if t == 0 or t == 1 then return t end
        return -math.pow(2, 10 * (t - 1)) * math.sin((t - 1.1) * 5 * math.pi)
    end,
    outElastic = function(t)
        if t == 0 or t == 1 then return t end
        return math.pow(2, -10 * t) * math.sin((t - 0.1) * 5 * math.pi) + 1
    end,
    outBounce = function(t)
        if t < 1 / 2.75 then
            return 7.5625 * t * t
        elseif t < 2 / 2.75 then
            t = t - 1.5 / 2.75
            return 7.5625 * t * t + 0.75
        elseif t < 2.5 / 2.75 then
            t = t - 2.25 / 2.75
            return 7.5625 * t * t + 0.9375
        else
            t = t - 2.625 / 2.75
            return 7.5625 * t * t + 0.984375
        end
    end,
}

---获取缓动函数
---@param name string|function
---@return function
local function getEasing(name)
    if type(name) == "function" then
        return name
    end
    return Easing[name] or Easing.linear
end

---创建状态精灵
---@param config StateSpriteConfig
---@return StateSprite
function StateSprite.new(config)
    local self = setmetatable({}, StateSprite)
    
    self.states = config.states or {}
    self.conditions = config.conditions or {}
    self.transitions = config.transitions or {}
    self.defaultTransition = {duration = 0.3, easing = "outQuad"}
    
    -- 设置默认状态
    self.currentState = config.defaultState
    if not self.currentState then
        for name, _ in pairs(self.states) do
            self.currentState = name
            break
        end
    end
    
    self.previousState = nil
    self.context = {}
    self.transitionProgress = 1.0  -- 1.0 = 过渡完成
    self.transitionDuration = 0
    self.transitionEasing = Easing.linear
    
    self.temporaryState = nil
    self.temporaryDuration = 0
    
    self.images = {}
    self.listeners = {
        stateChange = {},
    }
    
    -- 排序条件（按优先级）
    table.sort(self.conditions, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)
    
    return self
end

---加载图像（LÖVE 环境）
---@param stateName string
---@param imagePath string
---@return StateSprite self
function StateSprite:loadImage(stateName, imagePath)
    if love and love.graphics then
        local success, img = pcall(love.graphics.newImage, imagePath)
        if success then
            self.images[stateName] = img
        end
    end
    return self
end

---预加载所有状态图像
---@return StateSprite self
function StateSprite:preloadImages()
    for name, state in pairs(self.states) do
        if type(state.sprite) == "string" then
            self:loadImage(name, state.sprite)
        elseif type(state.sprite) == "userdata" then
            self.images[name] = state.sprite
        end
    end
    return self
end

---更新上下文（用于条件判断）
---@param ctx table
---@return StateSprite self
function StateSprite:updateContext(ctx)
    for k, v in pairs(ctx) do
        self.context[k] = v
    end
    self:_evaluateConditions()
    return self
end

---设置上下文（替换）
---@param ctx table
---@return StateSprite self
function StateSprite:setContext(ctx)
    self.context = ctx
    self:_evaluateConditions()
    return self
end

---手动设置状态
---@param stateName string
---@param options table|nil {duration: number} 临时状态持续时间
---@return StateSprite self
function StateSprite:setState(stateName, options)
    if not self.states[stateName] then
        return self
    end
    
    options = options or {}
    
    if options.duration then
        -- 临时状态
        self.temporaryState = stateName
        self.temporaryDuration = options.duration
    else
        -- 永久切换
        self:_transitionTo(stateName)
    end
    
    return self
end

---获取当前状态名
---@return string
function StateSprite:getState()
    if self.temporaryState then
        return self.temporaryState
    end
    return self.currentState
end

---获取当前状态数据
---@return StateSpriteState|nil
function StateSprite:getStateData()
    local stateName = self:getState()
    return self.states[stateName]
end

---检查是否在过渡中
---@return boolean
function StateSprite:isTransitioning()
    return self.transitionProgress < 1.0
end

---更新（每帧调用）
---@param dt number
---@return StateSprite self
function StateSprite:update(dt)
    -- 更新临时状态
    if self.temporaryState then
        self.temporaryDuration = self.temporaryDuration - dt
        if self.temporaryDuration <= 0 then
            self.temporaryState = nil
            self.temporaryDuration = 0
        end
    end
    
    -- 更新过渡
    if self.transitionProgress < 1.0 then
        self.transitionProgress = self.transitionProgress + dt / self.transitionDuration
        if self.transitionProgress >= 1.0 then
            self.transitionProgress = 1.0
            self.previousState = nil
        end
    end
    
    return self
end

---绘制（LÖVE 环境）
---@param x number
---@param y number
---@param options table|nil {scale, rotation, color}
function StateSprite:draw(x, y, options)
    if not love or not love.graphics then
        return
    end
    
    options = options or {}
    local stateName = self:getState()
    local state = self.states[stateName]
    
    if not state then return end
    
    local img = self.images[stateName]
    if not img then return end
    
    -- 计算属性
    local ox = (state.offset and state.offset.x) or 0
    local oy = (state.offset and state.offset.y) or 0
    local sx = (state.scale and state.scale.x) or 1
    local sy = (state.scale and state.scale.y) or 1
    local r = state.rotation or 0
    
    -- 应用选项覆盖
    if options.scale then
        sx = sx * (options.scale.x or options.scale)
        sy = sy * (options.scale.y or options.scale)
    end
    if options.rotation then
        r = r + options.rotation
    end
    
    -- 颜色
    local color = state.color or {1, 1, 1, 1}
    if options.color then
        color = options.color
    end
    
    -- 过渡混合
    if self:isTransitioning() and self.previousState then
        local prevImg = self.images[self.previousState]
        if prevImg then
            local t = self.transitionEasing(self.transitionProgress)
            local prevAlpha = 1 - t
            local currAlpha = t
            
            -- 绘制前一状态
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * prevAlpha)
            love.graphics.draw(prevImg, x + ox, y + oy, r, sx, sy,
                prevImg:getWidth() / 2, prevImg:getHeight() / 2)
            
            -- 绘制当前状态
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * currAlpha)
            love.graphics.draw(img, x + ox, y + oy, r, sx, sy,
                img:getWidth() / 2, img:getHeight() / 2)
            
            love.graphics.setColor(1, 1, 1, 1)
            return
        end
    end
    
    -- 正常绘制
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.draw(img, x + ox, y + oy, r, sx, sy,
        img:getWidth() / 2, img:getHeight() / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

---注册状态变化监听器
---@param callback function(oldState, newState)
---@return StateSprite self
function StateSprite:onStateChange(callback)
    table.insert(self.listeners.stateChange, callback)
    return self
end

---@private
function StateSprite:_transitionTo(newState)
    if newState == self.currentState then
        return
    end
    
    local oldState = self.currentState
    self.previousState = oldState
    self.currentState = newState
    
    -- 获取过渡配置
    local transKey = oldState .. "->" .. newState
    local trans = self.transitions[transKey] or self.transitions.default or self.defaultTransition
    
    self.transitionDuration = trans.duration or 0.3
    self.transitionEasing = getEasing(trans.easing or "outQuad")
    self.transitionProgress = 0
    
    if self.transitionDuration <= 0 then
        self.transitionProgress = 1.0
        self.previousState = nil
    end
    
    -- 触发监听器
    for _, callback in ipairs(self.listeners.stateChange) do
        callback(oldState, newState)
    end
end

---@private
function StateSprite:_evaluateConditions()
    -- 按优先级检查条件
    for _, cond in ipairs(self.conditions) do
        if cond.when(self.context) then
            if self.states[cond.state] then
                -- 检查状态优先级
                local currentPriority = self.states[self.currentState] and
                    self.states[self.currentState].priority or 0
                local newPriority = self.states[cond.state].priority or 0
                
                if cond.state ~= self.currentState then
                    self:_transitionTo(cond.state)
                end
            end
            return
        end
    end
end

---添加状态
---@param name string
---@param state StateSpriteState
---@return StateSprite self
function StateSprite:addState(name, state)
    self.states[name] = state
    return self
end

---添加条件
---@param condition StateSpriteCondition
---@return StateSprite self
function StateSprite:addCondition(condition)
    table.insert(self.conditions, condition)
    table.sort(self.conditions, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)
    return self
end

---设置过渡
---@param key string 如 "neutral->happy" 或 "default"
---@param transition StateSpriteTransition
---@return StateSprite self
function StateSprite:setTransition(key, transition)
    self.transitions[key] = transition
    return self
end

--------------------------------------------------------------------------------
-- LayeredStateSprite: 分层状态精灵
--------------------------------------------------------------------------------

---@class LayeredStateSpriteLayer
---@field name string
---@field z number 层级
---@field states table<string, string|love.Image>
---@field currentState string
---@field visible boolean
---@field offset table|nil
---@field scale table|nil
---@field color table|nil

---@class LayeredStateSprite
---@field layers LayeredStateSpriteLayer[]
---@field layersByName table<string, LayeredStateSpriteLayer>
---@field images table<string, table<string, love.Image>>
local LayeredStateSprite = {}
LayeredStateSprite.__index = LayeredStateSprite

---创建分层状态精灵
---@param config table
---@return LayeredStateSprite
function StateSprite.newLayered(config)
    local self = setmetatable({}, LayeredStateSprite)
    
    self.layers = {}
    self.layersByName = {}
    self.images = {}
    self.context = {}
    self.conditions = {}
    
    -- 初始化层
    for _, layerConfig in ipairs(config.layers or {}) do
        local layer = {
            name = layerConfig.name,
            z = layerConfig.z or 0,
            states = {},
            currentState = nil,
            visible = true,
            offset = layerConfig.offset,
            scale = layerConfig.scale,
            color = layerConfig.color,
        }
        table.insert(self.layers, layer)
        self.layersByName[layer.name] = layer
        self.images[layer.name] = {}
    end
    
    -- 按 z 排序
    table.sort(self.layers, function(a, b)
        return a.z < b.z
    end)
    
    -- 设置层状态
    if config.layerStates then
        for layerName, states in pairs(config.layerStates) do
            local layer = self.layersByName[layerName]
            if layer then
                layer.states = states
                -- 设置默认状态
                for stateName, _ in pairs(states) do
                    layer.currentState = stateName
                    break
                end
            end
        end
    end
    
    return self
end

---设置层状态
---@param layerName string
---@param stateName string
---@return LayeredStateSprite self
function LayeredStateSprite:setLayerState(layerName, stateName)
    local layer = self.layersByName[layerName]
    if layer and layer.states[stateName] then
        layer.currentState = stateName
    end
    return self
end

---获取层状态
---@param layerName string
---@return string|nil
function LayeredStateSprite:getLayerState(layerName)
    local layer = self.layersByName[layerName]
    return layer and layer.currentState
end

---设置层可见性
---@param layerName string
---@param visible boolean
---@return LayeredStateSprite self
function LayeredStateSprite:setLayerVisible(layerName, visible)
    local layer = self.layersByName[layerName]
    if layer then
        layer.visible = visible
    end
    return self
end

---加载层图像
---@param layerName string
---@param stateName string
---@param imagePath string
---@return LayeredStateSprite self
function LayeredStateSprite:loadImage(layerName, stateName, imagePath)
    if love and love.graphics then
        local success, img = pcall(love.graphics.newImage, imagePath)
        if success then
            if not self.images[layerName] then
                self.images[layerName] = {}
            end
            self.images[layerName][stateName] = img
        end
    end
    return self
end

---预加载所有层图像
---@return LayeredStateSprite self
function LayeredStateSprite:preloadImages()
    for _, layer in ipairs(self.layers) do
        for stateName, sprite in pairs(layer.states) do
            if type(sprite) == "string" then
                self:loadImage(layer.name, stateName, sprite)
            elseif type(sprite) == "userdata" then
                self.images[layer.name][stateName] = sprite
            end
        end
    end
    return self
end

---更新
---@param dt number
---@return LayeredStateSprite self
function LayeredStateSprite:update(dt)
    -- 可扩展：层动画等
    return self
end

---绘制
---@param x number
---@param y number
---@param options table|nil
function LayeredStateSprite:draw(x, y, options)
    if not love or not love.graphics then
        return
    end
    
    options = options or {}
    
    for _, layer in ipairs(self.layers) do
        if layer.visible and layer.currentState then
            local img = self.images[layer.name] and self.images[layer.name][layer.currentState]
            if img then
                local ox = (layer.offset and layer.offset.x) or 0
                local oy = (layer.offset and layer.offset.y) or 0
                local sx = (layer.scale and layer.scale.x) or 1
                local sy = (layer.scale and layer.scale.y) or 1
                local color = layer.color or {1, 1, 1, 1}
                
                if options.scale then
                    sx = sx * (options.scale.x or options.scale)
                    sy = sy * (options.scale.y or options.scale)
                end
                
                love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
                love.graphics.draw(img, x + ox, y + oy, 0, sx, sy,
                    img:getWidth() / 2, img:getHeight() / 2)
            end
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

---添加层条件
---@param layerName string
---@param condition table {state: string, when: function}
---@return LayeredStateSprite self
function LayeredStateSprite:addCondition(layerName, condition)
    table.insert(self.conditions, {
        layer = layerName,
        state = condition.state,
        when = condition.when,
        priority = condition.priority or 0,
    })
    return self
end

---更新上下文并评估条件
---@param ctx table
---@return LayeredStateSprite self
function LayeredStateSprite:updateContext(ctx)
    for k, v in pairs(ctx) do
        self.context[k] = v
    end
    
    -- 评估条件
    for _, cond in ipairs(self.conditions) do
        if cond.when(self.context) then
            self:setLayerState(cond.layer, cond.state)
        end
    end
    
    return self
end

-- 导出
StateSprite.Easing = Easing
StateSprite.LayeredStateSprite = LayeredStateSprite

return StateSprite
