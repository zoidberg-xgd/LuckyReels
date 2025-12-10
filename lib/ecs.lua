---@class Component
---@field _name string 组件名称
---@field _defaults table 默认值

---@class Entity
---@field id number 实体ID
---@field components table<string, table> 组件数据
---@field tags table<string, boolean> 标签

---@class System
---@field name string 系统名称
---@field requires string[] 需要的组件
---@field update function|nil 更新函数
---@field onAdd function|nil 实体添加时调用
---@field onRemove function|nil 实体移除时调用
---@field priority number 优先级

local ECS = {}

-- 组件注册表
local componentRegistry = {}

-- 系统注册表
local systemRegistry = {}

-- 实体存储
local entities = {}
local entityIdCounter = 0

-- 系统缓存（按组件需求缓存实体列表）
local systemEntityCache = {}
local cacheValid = {}

--------------------------------------------------------------------------------
-- Component API
--------------------------------------------------------------------------------

---定义组件
---@param name string 组件名称
---@param defaults table 默认值
---@return table component
function ECS.defineComponent(name, defaults)
    componentRegistry[name] = {
        _name = name,
        _defaults = defaults or {},
    }
    return componentRegistry[name]
end

---获取组件定义
---@param name string
---@return table|nil
function ECS.getComponent(name)
    return componentRegistry[name]
end

---检查组件是否已定义
---@param name string
---@return boolean
function ECS.hasComponent(name)
    return componentRegistry[name] ~= nil
end

--------------------------------------------------------------------------------
-- Entity API
--------------------------------------------------------------------------------

-- 共享的实体方法表
local entityMethods = {
    ---添加组件
    add = function(self, componentName, data)
        local compDef = componentRegistry[componentName]
        if not compDef then
            error("Component not defined: " .. componentName)
        end
        
        local compData = {}
        for k, v in pairs(compDef._defaults) do
            compData[k] = v
        end
        if data then
            for k, v in pairs(data) do
                compData[k] = v
            end
        end
        
        self.components[componentName] = compData
        ECS._invalidateCache()
        ECS._notifySystemsAdd(self, componentName)
        
        return self
    end,
    
    ---移除组件
    remove = function(self, componentName)
        if self.components[componentName] then
            ECS._notifySystemsRemove(self, componentName)
            self.components[componentName] = nil
            ECS._invalidateCache()
        end
        return self
    end,
    
    ---获取组件数据
    get = function(self, componentName)
        return self.components[componentName]
    end,
    
    ---检查是否有组件
    has = function(self, componentName)
        return self.components[componentName] ~= nil
    end,
    
    ---添加标签
    tag = function(self, tagName)
        self.tags[tagName] = true
        return self
    end,
    
    ---移除标签
    untag = function(self, tagName)
        self.tags[tagName] = nil
        return self
    end,
    
    ---检查是否有标签
    hasTag = function(self, tagName)
        return self.tags[tagName] == true
    end,
    
    ---销毁实体
    destroy = function(self)
        self._alive = false
        ECS._invalidateCache()
    end,
    
    ---检查实体是否存活
    isAlive = function(self)
        return self._alive
    end,
}

-- 共享的 metatable
ECS._entityMeta = {__index = entityMethods}

---创建实体
---@return Entity
function ECS.createEntity()
    entityIdCounter = entityIdCounter + 1
    
    local entity = {
        id = entityIdCounter,
        components = {},
        tags = {},
        _alive = true,
    }
    
    setmetatable(entity, ECS._entityMeta)
    
    entities[entity.id] = entity
    return entity
end

---获取实体
---@param id number
---@return Entity|nil
function ECS.getEntity(id)
    return entities[id]
end

---销毁实体
---@param entity Entity|number
function ECS.destroyEntity(entity)
    local id = type(entity) == "table" and entity.id or entity
    local e = entities[id]
    if e then
        -- 通知系统
        for compName, _ in pairs(e.components) do
            ECS._notifySystemsRemove(e, compName)
        end
        e._alive = false
        entities[id] = nil
        ECS._invalidateCache()
    end
end

---获取所有实体
---@return Entity[]
function ECS.getAllEntities()
    local result = {}
    for _, entity in pairs(entities) do
        if entity._alive then
            table.insert(result, entity)
        end
    end
    return result
end

---清除所有实体
function ECS.clearEntities()
    entities = {}
    entityIdCounter = 0
    ECS._invalidateCache()
end

--------------------------------------------------------------------------------
-- System API
--------------------------------------------------------------------------------

---定义系统
---@param name string 系统名称
---@param requires string[] 需要的组件列表
---@param updateFn function(entity, dt) 更新函数
---@return table system
function ECS.defineSystem(name, requires, updateFn)
    local system = {
        name = name,
        requires = requires or {},
        update = updateFn,
        onAdd = nil,
        onRemove = nil,
        priority = 0,
        enabled = true,
    }
    
    systemRegistry[name] = system
    cacheValid[name] = false
    
    return system
end

---获取系统
---@param name string
---@return table|nil
function ECS.getSystem(name)
    return systemRegistry[name]
end

---设置系统优先级
---@param name string
---@param priority number
function ECS.setSystemPriority(name, priority)
    local system = systemRegistry[name]
    if system then
        system.priority = priority
    end
end

---启用/禁用系统
---@param name string
---@param enabled boolean
function ECS.setSystemEnabled(name, enabled)
    local system = systemRegistry[name]
    if system then
        system.enabled = enabled
    end
end

---设置系统回调
---@param name string
---@param event "onAdd"|"onRemove"
---@param callback function
function ECS.setSystemCallback(name, event, callback)
    local system = systemRegistry[name]
    if system then
        system[event] = callback
    end
end

--------------------------------------------------------------------------------
-- Query API
--------------------------------------------------------------------------------

---查询拥有指定组件的实体
---@param componentNames string[] 组件名称列表
---@return Entity[]
function ECS.query(componentNames)
    local result = {}
    
    for _, entity in pairs(entities) do
        if entity._alive then
            local hasAll = true
            for _, compName in ipairs(componentNames) do
                if not entity.components[compName] then
                    hasAll = false
                    break
                end
            end
            if hasAll then
                table.insert(result, entity)
            end
        end
    end
    
    return result
end

---查询拥有指定标签的实体
---@param tagName string
---@return Entity[]
function ECS.queryByTag(tagName)
    local result = {}
    for _, entity in pairs(entities) do
        if entity._alive and entity.tags[tagName] then
            table.insert(result, entity)
        end
    end
    return result
end

---查询并执行操作
---@param componentNames string[]
---@param callback function(entity)
function ECS.each(componentNames, callback)
    local entities = ECS.query(componentNames)
    for _, entity in ipairs(entities) do
        callback(entity)
    end
end

---查询并归约
---@param componentNames string[]
---@param callback function(accumulator, entity): any
---@param initial any
---@return any
function ECS.reduce(componentNames, callback, initial)
    local result = initial
    local entities = ECS.query(componentNames)
    for _, entity in ipairs(entities) do
        result = callback(result, entity)
    end
    return result
end

---统计拥有指定组件的实体数量
---@param componentNames string[]
---@return number
function ECS.count(componentNames)
    return #ECS.query(componentNames)
end

--------------------------------------------------------------------------------
-- Update API
--------------------------------------------------------------------------------

---更新所有系统
---@param dt number
function ECS.update(dt)
    -- 按优先级排序系统
    local sortedSystems = {}
    for _, system in pairs(systemRegistry) do
        if system.enabled and system.update then
            table.insert(sortedSystems, system)
        end
    end
    table.sort(sortedSystems, function(a, b)
        return a.priority > b.priority
    end)
    
    -- 执行系统更新
    for _, system in ipairs(sortedSystems) do
        local entities = ECS._getSystemEntities(system)
        for _, entity in ipairs(entities) do
            if entity._alive then
                system.update(entity, dt)
            end
        end
    end
    
    -- 清理死亡实体
    ECS._cleanupDeadEntities()
end

---更新指定系统
---@param name string
---@param dt number
function ECS.updateSystem(name, dt)
    local system = systemRegistry[name]
    if not system or not system.enabled or not system.update then
        return
    end
    
    local entities = ECS._getSystemEntities(system)
    for _, entity in ipairs(entities) do
        if entity._alive then
            system.update(entity, dt)
        end
    end
end

--------------------------------------------------------------------------------
-- Internal Functions
--------------------------------------------------------------------------------

---@private
function ECS._invalidateCache()
    for name, _ in pairs(cacheValid) do
        cacheValid[name] = false
    end
end

---@private
function ECS._getSystemEntities(system)
    if cacheValid[system.name] and systemEntityCache[system.name] then
        return systemEntityCache[system.name]
    end
    
    local result = ECS.query(system.requires)
    systemEntityCache[system.name] = result
    cacheValid[system.name] = true
    
    return result
end

---@private
function ECS._notifySystemsAdd(entity, componentName)
    for _, system in pairs(systemRegistry) do
        if system.onAdd then
            -- 检查实体是否现在满足系统要求
            local hasAll = true
            for _, req in ipairs(system.requires) do
                if not entity.components[req] then
                    hasAll = false
                    break
                end
            end
            if hasAll then
                -- 检查是否刚刚满足（之前缺少这个组件）
                local wasJustAdded = false
                for _, req in ipairs(system.requires) do
                    if req == componentName then
                        wasJustAdded = true
                        break
                    end
                end
                if wasJustAdded then
                    system.onAdd(entity)
                end
            end
        end
    end
end

---@private
function ECS._notifySystemsRemove(entity, componentName)
    for _, system in pairs(systemRegistry) do
        if system.onRemove then
            -- 检查实体是否之前满足系统要求
            local hadAll = true
            for _, req in ipairs(system.requires) do
                if not entity.components[req] then
                    hadAll = false
                    break
                end
            end
            if hadAll then
                -- 检查是否因为移除这个组件而不再满足
                local willLose = false
                for _, req in ipairs(system.requires) do
                    if req == componentName then
                        willLose = true
                        break
                    end
                end
                if willLose then
                    system.onRemove(entity)
                end
            end
        end
    end
end

---@private
function ECS._cleanupDeadEntities()
    local toRemove = {}
    for id, entity in pairs(entities) do
        if not entity._alive then
            table.insert(toRemove, id)
        end
    end
    for _, id in ipairs(toRemove) do
        entities[id] = nil
    end
end

--------------------------------------------------------------------------------
-- Serialization
--------------------------------------------------------------------------------

---序列化所有实体
---@return table
function ECS.serialize()
    local data = {
        entities = {},
        nextId = entityIdCounter,
    }
    
    for id, entity in pairs(entities) do
        if entity._alive then
            data.entities[id] = {
                id = entity.id,
                components = entity.components,
                tags = entity.tags,
            }
        end
    end
    
    return data
end

---反序列化实体
---@param data table
function ECS.deserialize(data)
    ECS.clearEntities()
    
    entityIdCounter = data.nextId or 0
    
    for _, entityData in pairs(data.entities or {}) do
        local entity = {
            id = entityData.id,
            components = entityData.components or {},
            tags = entityData.tags or {},
            _alive = true,
        }
        
        -- 添加方法（使用 ECS._entityMeta）
        setmetatable(entity, ECS._entityMeta)
        entities[entity.id] = entity
    end
    
    ECS._invalidateCache()
end

--------------------------------------------------------------------------------
-- Reset
--------------------------------------------------------------------------------

---重置 ECS（清除所有实体、组件定义和系统）
function ECS.reset()
    entities = {}
    entityIdCounter = 0
    componentRegistry = {}
    systemRegistry = {}
    systemEntityCache = {}
    cacheValid = {}
end

---仅清除运行时数据（保留定义）
function ECS.clearRuntime()
    entities = {}
    entityIdCounter = 0
    systemEntityCache = {}
    cacheValid = {}
end

return ECS
