---@class ResourceModifier
---@field id string 修改器唯一标识
---@field type "flat"|"percent"|"decay"|"regen" 修改器类型
---@field value number 修改值
---@field duration number|nil 持续时间（秒），nil表示永久
---@field elapsed number 已经过时间
---@field priority number 优先级（越高越先应用）

---@class ResourceConfig
---@field id string 资源唯一标识
---@field value number 初始值
---@field min number 最小值
---@field max number 最大值
---@field regen number 每秒自动恢复
---@field decay number 每秒自动衰减

---@class Resource
---@field id string
---@field value number
---@field min number
---@field max number
---@field baseRegen number
---@field baseDecay number
---@field modifiers table<string, ResourceModifier>
---@field thresholds table
---@field listeners table
local Resource = {}
Resource.__index = Resource

---创建新资源
---@param config ResourceConfig
---@return Resource
function Resource.new(config)
    local self = setmetatable({}, Resource)
    
    self.id = config.id or "unnamed"
    self.value = config.value or 0
    self.min = config.min or 0
    self.max = config.max or 100
    self.baseRegen = config.regen or 0
    self.baseDecay = config.decay or 0
    self.modifiers = {}
    self.thresholds = {}
    self.listeners = {
        change = {},
        min = {},
        max = {},
    }
    
    -- 确保初始值在范围内
    self.value = math.max(self.min, math.min(self.max, self.value))
    
    return self
end

---获取当前值
---@return number
function Resource:get()
    return self.value
end

---获取百分比 (0-1)
---@return number
function Resource:getPercent()
    if self.max == self.min then
        return 1
    end
    return (self.value - self.min) / (self.max - self.min)
end

---设置值
---@param newValue number
---@return Resource self
function Resource:set(newValue)
    local oldValue = self.value
    self.value = math.max(self.min, math.min(self.max, newValue))
    
    if oldValue ~= self.value then
        self:_notifyChange(oldValue, self.value)
        self:_checkThresholds(oldValue, self.value)
    end
    
    return self
end

---增加值
---@param amount number
---@return Resource self
function Resource:add(amount)
    return self:set(self.value + amount)
end

---减少值
---@param amount number
---@return Resource self
function Resource:subtract(amount)
    return self:set(self.value - amount)
end

---设置最大值
---@param newMax number
---@return Resource self
function Resource:setMax(newMax)
    self.max = newMax
    if self.value > self.max then
        self:set(self.max)
    end
    return self
end

---设置最小值
---@param newMin number
---@return Resource self
function Resource:setMin(newMin)
    self.min = newMin
    if self.value < self.min then
        self:set(self.min)
    end
    return self
end

---添加修改器
---@param modifier ResourceModifier
---@return Resource self
function Resource:addModifier(modifier)
    if not modifier.id then
        modifier.id = "mod_" .. tostring(os.time()) .. "_" .. math.random(1000)
    end
    modifier.elapsed = 0
    modifier.priority = modifier.priority or 0
    self.modifiers[modifier.id] = modifier
    return self
end

---移除修改器
---@param modifierId string
---@return Resource self
function Resource:removeModifier(modifierId)
    self.modifiers[modifierId] = nil
    return self
end

---检查是否有指定修改器
---@param modifierId string
---@return boolean
function Resource:hasModifier(modifierId)
    return self.modifiers[modifierId] ~= nil
end

---获取所有修改器
---@return table<string, ResourceModifier>
function Resource:getModifiers()
    return self.modifiers
end

---计算有效恢复率（基础 + 修改器）
---@return number
function Resource:getEffectiveRegen()
    local regen = self.baseRegen
    for _, mod in pairs(self.modifiers) do
        if mod.type == "regen" then
            regen = regen + mod.value
        end
    end
    return regen
end

---计算有效衰减率（基础 + 修改器）
---@return number
function Resource:getEffectiveDecay()
    local decay = self.baseDecay
    for _, mod in pairs(self.modifiers) do
        if mod.type == "decay" then
            decay = decay + mod.value
        end
    end
    return decay
end

---更新资源（每帧调用）
---@param dt number delta time
---@return Resource self
function Resource:update(dt)
    -- 更新修改器计时并移除过期的
    local toRemove = {}
    for id, mod in pairs(self.modifiers) do
        if mod.duration then
            mod.elapsed = mod.elapsed + dt
            if mod.elapsed >= mod.duration then
                table.insert(toRemove, id)
            end
        end
    end
    for _, id in ipairs(toRemove) do
        self.modifiers[id] = nil
    end
    
    -- 应用恢复和衰减
    local regen = self:getEffectiveRegen()
    local decay = self:getEffectiveDecay()
    local delta = (regen - decay) * dt
    
    if delta ~= 0 then
        self:add(delta)
    end
    
    return self
end

---注册阈值事件
---@param threshold number 阈值
---@param direction "above"|"below"|"equal"|"cross" 触发方向
---@param callback function 回调函数
---@return Resource self
function Resource:onThreshold(threshold, direction, callback)
    table.insert(self.thresholds, {
        value = threshold,
        direction = direction,
        callback = callback,
        lastTriggered = false,
    })
    return self
end

---注册变化监听器
---@param callback function(oldValue, newValue)
---@return Resource self
function Resource:onChange(callback)
    table.insert(self.listeners.change, callback)
    return self
end

---注册到达最小值监听器
---@param callback function
---@return Resource self
function Resource:onMin(callback)
    table.insert(self.listeners.min, callback)
    return self
end

---注册到达最大值监听器
---@param callback function
---@return Resource self
function Resource:onMax(callback)
    table.insert(self.listeners.max, callback)
    return self
end

---@private
function Resource:_notifyChange(oldValue, newValue)
    for _, callback in ipairs(self.listeners.change) do
        callback(oldValue, newValue)
    end
    
    if newValue <= self.min then
        for _, callback in ipairs(self.listeners.min) do
            callback()
        end
    end
    
    if newValue >= self.max then
        for _, callback in ipairs(self.listeners.max) do
            callback()
        end
    end
end

---@private
function Resource:_checkThresholds(oldValue, newValue)
    for _, t in ipairs(self.thresholds) do
        local shouldTrigger = false
        
        if t.direction == "below" then
            shouldTrigger = oldValue >= t.value and newValue < t.value
        elseif t.direction == "above" then
            shouldTrigger = oldValue <= t.value and newValue > t.value
        elseif t.direction == "equal" then
            shouldTrigger = newValue == t.value and oldValue ~= t.value
        elseif t.direction == "cross" then
            shouldTrigger = (oldValue < t.value and newValue >= t.value) or
                           (oldValue > t.value and newValue <= t.value)
        end
        
        if shouldTrigger then
            t.callback(oldValue, newValue)
        end
    end
end

---重置到初始状态
---@param initialValue number|nil 可选的初始值
---@return Resource self
function Resource:reset(initialValue)
    self.modifiers = {}
    self.value = initialValue or self.max
    self.value = math.max(self.min, math.min(self.max, self.value))
    return self
end

---序列化为表（用于存档）
---@return table
function Resource:serialize()
    return {
        id = self.id,
        value = self.value,
        min = self.min,
        max = self.max,
        baseRegen = self.baseRegen,
        baseDecay = self.baseDecay,
        modifiers = self.modifiers,
    }
end

---从表反序列化
---@param data table
---@return Resource
function Resource.deserialize(data)
    local res = Resource.new({
        id = data.id,
        value = data.value,
        min = data.min,
        max = data.max,
        regen = data.baseRegen,
        decay = data.baseDecay,
    })
    res.modifiers = data.modifiers or {}
    return res
end

--------------------------------------------------------------------------------
-- DerivedResource: 派生资源（依赖其他资源计算）
--------------------------------------------------------------------------------

---@class DerivedResourceConfig
---@field id string
---@field dependencies table<string, Resource> 依赖的资源
---@field formula function(deps: table<string, number>): number 计算公式
---@field min number|nil
---@field max number|nil

---@class DerivedResource
---@field id string
---@field dependencies table<string, Resource>
---@field formula function
---@field min number
---@field max number
---@field cachedValue number
local DerivedResource = {}
DerivedResource.__index = DerivedResource

---创建派生资源
---@param config DerivedResourceConfig
---@return DerivedResource
function Resource.newDerived(config)
    local self = setmetatable({}, DerivedResource)
    
    self.id = config.id or "derived"
    self.dependencies = config.dependencies or {}
    self.formula = config.formula
    self.min = config.min or -math.huge
    self.max = config.max or math.huge
    self.cachedValue = 0
    self.listeners = {
        change = {},
    }
    
    return self
end

---获取当前值（重新计算）
---@return number
function DerivedResource:get()
    local deps = {}
    for name, resource in pairs(self.dependencies) do
        if type(resource) == "table" and resource.get then
            deps[name] = resource:get()
        else
            deps[name] = resource
        end
    end
    
    local newValue = self.formula(deps)
    newValue = math.max(self.min, math.min(self.max, newValue))
    
    if newValue ~= self.cachedValue then
        local oldValue = self.cachedValue
        self.cachedValue = newValue
        for _, callback in ipairs(self.listeners.change) do
            callback(oldValue, newValue)
        end
    end
    
    return self.cachedValue
end

---获取百分比
---@return number
function DerivedResource:getPercent()
    if self.max == self.min then
        return 1
    end
    local value = self:get()
    return (value - self.min) / (self.max - self.min)
end

---更新依赖
---@param name string
---@param resource Resource|number
---@return DerivedResource self
function DerivedResource:setDependency(name, resource)
    self.dependencies[name] = resource
    return self
end

---注册变化监听器
---@param callback function(oldValue, newValue)
---@return DerivedResource self
function DerivedResource:onChange(callback)
    table.insert(self.listeners.change, callback)
    return self
end

--------------------------------------------------------------------------------
-- ResourceManager: 资源管理器
--------------------------------------------------------------------------------

---@class ResourceManager
---@field resources table<string, Resource|DerivedResource>
local ResourceManager = {}
ResourceManager.__index = ResourceManager

---创建资源管理器
---@return ResourceManager
function Resource.newManager()
    local self = setmetatable({}, ResourceManager)
    self.resources = {}
    return self
end

---注册资源
---@param resource Resource|DerivedResource
---@return ResourceManager self
function ResourceManager:register(resource)
    self.resources[resource.id] = resource
    return self
end

---获取资源
---@param id string
---@return Resource|DerivedResource|nil
function ResourceManager:get(id)
    return self.resources[id]
end

---更新所有资源
---@param dt number
---@return ResourceManager self
function ResourceManager:update(dt)
    for _, resource in pairs(self.resources) do
        if resource.update then
            resource:update(dt)
        end
    end
    return self
end

---序列化所有资源
---@return table
function ResourceManager:serialize()
    local data = {}
    for id, resource in pairs(self.resources) do
        if resource.serialize then
            data[id] = resource:serialize()
        end
    end
    return data
end

---反序列化资源
---@param data table
---@return ResourceManager self
function ResourceManager:deserialize(data)
    for id, resData in pairs(data) do
        if self.resources[id] and self.resources[id].value then
            -- 更新现有资源
            local res = self.resources[id]
            res.value = resData.value
            res.min = resData.min
            res.max = resData.max
            res.baseRegen = resData.baseRegen
            res.baseDecay = resData.baseDecay
            res.modifiers = resData.modifiers or {}
        end
    end
    return self
end

-- 导出
Resource.DerivedResource = DerivedResource
Resource.ResourceManager = ResourceManager

return Resource
