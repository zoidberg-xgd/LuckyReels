---@class WeightedEventItem
---@field id string 事件唯一标识
---@field weight number 基础权重
---@field type string|nil 事件类型（用于过滤）
---@field data table|nil 附加数据

---@class WeightedEventModifier
---@field condition function(ctx): boolean 条件函数
---@field filter table|nil 过滤条件 {type = "positive"}
---@field multiply number|nil 权重乘数
---@field add number|nil 权重增量

---@class WeightedEventPity
---@field threshold number 保底触发次数
---@field guarantee table|nil 保底条件 {type = "positive"}
---@field reset boolean|nil 触发后是否重置计数

---@class WeightedEventPoolConfig
---@field events WeightedEventItem[]
---@field modifiers WeightedEventModifier[]|nil
---@field pity WeightedEventPity|nil

---@class WeightedEventPool
---@field events WeightedEventItem[]
---@field modifiers WeightedEventModifier[]
---@field pity WeightedEventPity|nil
---@field history table
---@field stats table
---@field rollCount number
---@field lastTriggerRoll number
local WeightedEventPool = {}
WeightedEventPool.__index = WeightedEventPool

local WeightedEvent = {}

---创建事件池
---@param config WeightedEventPoolConfig
---@return WeightedEventPool
function WeightedEvent.newPool(config)
    local self = setmetatable({}, WeightedEventPool)
    
    self.events = {}
    for _, event in ipairs(config.events or {}) do
        table.insert(self.events, {
            id = event.id,
            weight = event.weight or 1,
            type = event.type,
            data = event.data,
        })
    end
    
    self.modifiers = config.modifiers or {}
    self.pity = config.pity
    
    self.history = {}
    self.stats = {}
    self.rollCount = 0
    self.lastTriggerRoll = 0
    
    -- 初始化统计
    for _, event in ipairs(self.events) do
        self.stats[event.id] = {
            count = 0,
            lastRoll = 0,
        }
    end
    
    return self
end

---添加事件
---@param event WeightedEventItem
---@return WeightedEventPool self
function WeightedEventPool:addEvent(event)
    table.insert(self.events, {
        id = event.id,
        weight = event.weight or 1,
        type = event.type,
        data = event.data,
    })
    self.stats[event.id] = {count = 0, lastRoll = 0}
    return self
end

---移除事件
---@param id string
---@return WeightedEventPool self
function WeightedEventPool:removeEvent(id)
    for i = #self.events, 1, -1 do
        if self.events[i].id == id then
            table.remove(self.events, i)
        end
    end
    return self
end

---获取事件
---@param id string
---@return WeightedEventItem|nil
function WeightedEventPool:getEvent(id)
    for _, event in ipairs(self.events) do
        if event.id == id then
            return event
        end
    end
    return nil
end

---添加修改器
---@param modifier WeightedEventModifier
---@return WeightedEventPool self
function WeightedEventPool:addModifier(modifier)
    table.insert(self.modifiers, modifier)
    return self
end

---计算有效权重
---@param event WeightedEventItem
---@param context table
---@return number
function WeightedEventPool:_getEffectiveWeight(event, context)
    local weight = event.weight
    
    for _, mod in ipairs(self.modifiers) do
        -- 检查条件
        if mod.condition(context) then
            -- 检查过滤器
            local matches = true
            if mod.filter then
                for key, value in pairs(mod.filter) do
                    if event[key] ~= value then
                        matches = false
                        break
                    end
                end
            end
            
            if matches then
                if mod.multiply then
                    weight = weight * mod.multiply
                end
                if mod.add then
                    weight = weight + mod.add
                end
            end
        end
    end
    
    return math.max(0, weight)
end

---检查保底
---@param context table
---@return WeightedEventItem|nil
function WeightedEventPool:_checkPity(context)
    if not self.pity then
        return nil
    end
    
    local rollsSinceLastTrigger = self.rollCount - self.lastTriggerRoll
    
    if rollsSinceLastTrigger >= self.pity.threshold then
        -- 找到符合保底条件的事件
        local candidates = {}
        for _, event in ipairs(self.events) do
            local matches = true
            if self.pity.guarantee then
                for key, value in pairs(self.pity.guarantee) do
                    if event[key] ~= value then
                        matches = false
                        break
                    end
                end
            end
            if matches then
                table.insert(candidates, event)
            end
        end
        
        if #candidates > 0 then
            return candidates[math.random(#candidates)]
        end
    end
    
    return nil
end

---执行一次抽取
---@param options table|nil {baseChance, context, filter}
---@return boolean triggered, WeightedEventItem|nil event
function WeightedEventPool:roll(options)
    options = options or {}
    local baseChance = options.baseChance or 1.0
    local context = options.context or {}
    local filter = options.filter
    
    self.rollCount = self.rollCount + 1
    
    -- 检查基础概率
    if baseChance < 1.0 and math.random() > baseChance then
        return false, nil
    end
    
    -- 检查保底
    local pityEvent = self:_checkPity(context)
    if pityEvent then
        self:_recordTrigger(pityEvent)
        return true, pityEvent
    end
    
    -- 收集候选事件和权重
    local candidates = {}
    local totalWeight = 0
    
    for _, event in ipairs(self.events) do
        -- 应用过滤器
        local matches = true
        if filter then
            for key, value in pairs(filter) do
                if event[key] ~= value then
                    matches = false
                    break
                end
            end
        end
        
        if matches then
            local weight = self:_getEffectiveWeight(event, context)
            if weight > 0 then
                table.insert(candidates, {event = event, weight = weight})
                totalWeight = totalWeight + weight
            end
        end
    end
    
    if #candidates == 0 or totalWeight <= 0 then
        return false, nil
    end
    
    -- 加权随机选择
    local roll = math.random() * totalWeight
    local cumulative = 0
    
    for _, candidate in ipairs(candidates) do
        cumulative = cumulative + candidate.weight
        if roll <= cumulative then
            self:_recordTrigger(candidate.event)
            return true, candidate.event
        end
    end
    
    -- 兜底（理论上不会到这里）
    local lastEvent = candidates[#candidates].event
    self:_recordTrigger(lastEvent)
    return true, lastEvent
end

---@private
function WeightedEventPool:_recordTrigger(event)
    self.lastTriggerRoll = self.rollCount
    
    -- 更新统计
    if self.stats[event.id] then
        self.stats[event.id].count = self.stats[event.id].count + 1
        self.stats[event.id].lastRoll = self.rollCount
    end
    
    -- 记录历史
    table.insert(self.history, {
        id = event.id,
        roll = self.rollCount,
        time = os.time(),
    })
    
    -- 限制历史长度
    while #self.history > 1000 do
        table.remove(self.history, 1)
    end
end

---获取历史记录
---@param limit number|nil
---@return table
function WeightedEventPool:getHistory(limit)
    limit = limit or 10
    local result = {}
    local start = math.max(1, #self.history - limit + 1)
    for i = start, #self.history do
        table.insert(result, self.history[i])
    end
    return result
end

---获取统计信息
---@return table
function WeightedEventPool:getStats()
    local result = {
        totalRolls = self.rollCount,
        totalTriggers = #self.history,
        events = {},
    }
    
    for id, stat in pairs(self.stats) do
        result.events[id] = {
            count = stat.count,
            rate = self.rollCount > 0 and (stat.count / self.rollCount) or 0,
            lastRoll = stat.lastRoll,
        }
    end
    
    return result
end

---重置统计
---@return WeightedEventPool self
function WeightedEventPool:resetStats()
    self.history = {}
    self.rollCount = 0
    self.lastTriggerRoll = 0
    for id, _ in pairs(self.stats) do
        self.stats[id] = {count = 0, lastRoll = 0}
    end
    return self
end

---获取所有事件的当前权重
---@param context table|nil
---@return table<string, number>
function WeightedEventPool:getWeights(context)
    context = context or {}
    local result = {}
    for _, event in ipairs(self.events) do
        result[event.id] = self:_getEffectiveWeight(event, context)
    end
    return result
end

---获取事件概率
---@param context table|nil
---@param filter table|nil
---@return table<string, number>
function WeightedEventPool:getProbabilities(context, filter)
    context = context or {}
    local weights = {}
    local totalWeight = 0
    
    for _, event in ipairs(self.events) do
        local matches = true
        if filter then
            for key, value in pairs(filter) do
                if event[key] ~= value then
                    matches = false
                    break
                end
            end
        end
        
        if matches then
            local weight = self:_getEffectiveWeight(event, context)
            weights[event.id] = weight
            totalWeight = totalWeight + weight
        end
    end
    
    local result = {}
    for id, weight in pairs(weights) do
        result[id] = totalWeight > 0 and (weight / totalWeight) or 0
    end
    
    return result
end

---模拟多次抽取
---@param count number
---@param options table|nil
---@return table results {[eventId] = count}
function WeightedEventPool:simulate(count, options)
    local results = {}
    local originalRollCount = self.rollCount
    local originalLastTrigger = self.lastTriggerRoll
    local originalHistory = #self.history
    
    for _ = 1, count do
        local triggered, event = self:roll(options)
        if triggered and event then
            results[event.id] = (results[event.id] or 0) + 1
        end
    end
    
    -- 恢复状态（模拟不影响真实统计）
    self.rollCount = originalRollCount
    self.lastTriggerRoll = originalLastTrigger
    while #self.history > originalHistory do
        table.remove(self.history)
    end
    
    return results
end

---序列化
---@return table
function WeightedEventPool:serialize()
    return {
        rollCount = self.rollCount,
        lastTriggerRoll = self.lastTriggerRoll,
        stats = self.stats,
        history = self.history,
    }
end

---反序列化
---@param data table
---@return WeightedEventPool self
function WeightedEventPool:deserialize(data)
    self.rollCount = data.rollCount or 0
    self.lastTriggerRoll = data.lastTriggerRoll or 0
    self.stats = data.stats or {}
    self.history = data.history or {}
    return self
end

-- 导出
WeightedEvent.WeightedEventPool = WeightedEventPool

return WeightedEvent
