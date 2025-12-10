---@class DialogueEntry
---@field id string 对话唯一标识
---@field text string 对话文本
---@field conditions table|nil 触发条件
---@field priority number 优先级
---@field cooldown number|nil 冷却时间（秒）
---@field tags string[]|nil 标签
---@field speaker string|nil 说话者

---@class DialogueLibraryConfig
---@field entries DialogueEntry[]
---@field variables table<string, function>|nil 变量插值函数

---@class DialogueLibrary
---@field entries DialogueEntry[]
---@field variables table<string, function>
---@field cooldowns table<string, number>
---@field history table
local DialogueLibrary = {}
DialogueLibrary.__index = DialogueLibrary

local Dialogue = {}

---创建对话库
---@param config DialogueLibraryConfig
---@return DialogueLibrary
function Dialogue.newLibrary(config)
    local self = setmetatable({}, DialogueLibrary)
    
    self.entries = {}
    self.variables = config.variables or {}
    self.cooldowns = {}
    self.history = {}
    
    -- 添加条目
    for _, entry in ipairs(config.entries or {}) do
        self:addEntry(entry)
    end
    
    return self
end

---添加对话条目
---@param entry DialogueEntry
---@return DialogueLibrary self
function DialogueLibrary:addEntry(entry)
    entry.priority = entry.priority or 0
    entry.conditions = entry.conditions or {}
    table.insert(self.entries, entry)
    
    -- 按优先级排序（高优先级在前）
    table.sort(self.entries, function(a, b)
        return a.priority > b.priority
    end)
    
    return self
end

---移除对话条目
---@param id string
---@return DialogueLibrary self
function DialogueLibrary:removeEntry(id)
    for i = #self.entries, 1, -1 do
        if self.entries[i].id == id then
            table.remove(self.entries, i)
        end
    end
    return self
end

---检查条件是否满足
---@param conditions table
---@param context table
---@return boolean
function DialogueLibrary:_checkConditions(conditions, context)
    for key, expected in pairs(conditions) do
        local actual = context[key]
        
        if type(expected) == "table" then
            -- 比较操作符: {">", 100}, {"<", 50}, {">=", 10}, {"<=", 20}, {"==", "value"}, {"~=", "value"}
            local op, value = expected[1], expected[2]
            
            if op == ">" then
                if not (actual and actual > value) then return false end
            elseif op == "<" then
                if not (actual and actual < value) then return false end
            elseif op == ">=" then
                if not (actual and actual >= value) then return false end
            elseif op == "<=" then
                if not (actual and actual <= value) then return false end
            elseif op == "==" then
                if actual ~= value then return false end
            elseif op == "~=" then
                if actual == value then return false end
            elseif op == "in" then
                -- 检查值是否在列表中
                local found = false
                for _, v in ipairs(value) do
                    if actual == v then found = true; break end
                end
                if not found then return false end
            elseif op == "between" then
                -- 范围检查: {"between", {10, 50}}
                if not (actual and actual >= value[1] and actual <= value[2]) then return false end
            end
        elseif type(expected) == "function" then
            -- 自定义条件函数
            if not expected(actual, context) then return false end
        else
            -- 简单相等检查
            if actual ~= expected then return false end
        end
    end
    
    return true
end

---检查冷却
---@param id string
---@return boolean
function DialogueLibrary:_checkCooldown(id)
    local cooldownEnd = self.cooldowns[id]
    if cooldownEnd and os.time() < cooldownEnd then
        return false
    end
    return true
end

---设置冷却
---@param id string
---@param duration number
function DialogueLibrary:_setCooldown(id, duration)
    if duration and duration > 0 then
        self.cooldowns[id] = os.time() + duration
    end
end

---查询匹配的对话
---@param context table 上下文
---@param options table|nil {tags, speaker, limit}
---@return DialogueEntry|nil
function DialogueLibrary:query(context, options)
    options = options or {}
    
    for _, entry in ipairs(self.entries) do
        -- 检查标签过滤
        if options.tags then
            local hasTag = false
            for _, tag in ipairs(entry.tags or {}) do
                for _, filterTag in ipairs(options.tags) do
                    if tag == filterTag then hasTag = true; break end
                end
                if hasTag then break end
            end
            if not hasTag then goto continue end
        end
        
        -- 检查说话者过滤
        if options.speaker and entry.speaker ~= options.speaker then
            goto continue
        end
        
        -- 检查冷却
        if not self:_checkCooldown(entry.id) then
            goto continue
        end
        
        -- 检查条件
        if self:_checkConditions(entry.conditions, context) then
            return entry
        end
        
        ::continue::
    end
    
    return nil
end

---查询所有匹配的对话
---@param context table
---@param options table|nil
---@return DialogueEntry[]
function DialogueLibrary:queryAll(context, options)
    options = options or {}
    local results = {}
    local limit = options.limit or 100
    
    for _, entry in ipairs(self.entries) do
        if #results >= limit then break end
        
        -- 检查标签过滤
        if options.tags then
            local hasTag = false
            for _, tag in ipairs(entry.tags or {}) do
                for _, filterTag in ipairs(options.tags) do
                    if tag == filterTag then hasTag = true; break end
                end
                if hasTag then break end
            end
            if not hasTag then goto continue end
        end
        
        -- 检查说话者过滤
        if options.speaker and entry.speaker ~= options.speaker then
            goto continue
        end
        
        -- 检查冷却
        if not self:_checkCooldown(entry.id) then
            goto continue
        end
        
        -- 检查条件
        if self:_checkConditions(entry.conditions, context) then
            table.insert(results, entry)
        end
        
        ::continue::
    end
    
    return results
end

---获取对话并应用冷却
---@param context table
---@param options table|nil
---@return DialogueEntry|nil, string|nil formattedText
function DialogueLibrary:get(context, options)
    local entry = self:query(context, options)
    if not entry then
        return nil, nil
    end
    
    -- 应用冷却
    self:_setCooldown(entry.id, entry.cooldown)
    
    -- 记录历史
    table.insert(self.history, {
        id = entry.id,
        time = os.time(),
        context = context,
    })
    
    -- 格式化文本
    local text = self:format(entry, context)
    
    return entry, text
end

---格式化对话文本（变量插值）
---@param entry DialogueEntry
---@param context table
---@return string
function DialogueLibrary:format(entry, context)
    local text = entry.text
    
    -- 替换 {variable} 格式的变量
    text = text:gsub("{([%w_]+)}", function(varName)
        -- 先检查变量函数
        if self.variables[varName] then
            return tostring(self.variables[varName](context))
        end
        -- 再检查上下文
        if context[varName] ~= nil then
            return tostring(context[varName])
        end
        return "{" .. varName .. "}"
    end)
    
    return text
end

---添加变量插值函数
---@param name string
---@param fn function(context): any
---@return DialogueLibrary self
function DialogueLibrary:addVariable(name, fn)
    self.variables[name] = fn
    return self
end

---获取历史记录
---@param limit number|nil
---@return table
function DialogueLibrary:getHistory(limit)
    limit = limit or 10
    local result = {}
    local start = math.max(1, #self.history - limit + 1)
    for i = start, #self.history do
        table.insert(result, self.history[i])
    end
    return result
end

---清除冷却
---@param id string|nil 如果为 nil，清除所有冷却
---@return DialogueLibrary self
function DialogueLibrary:clearCooldown(id)
    if id then
        self.cooldowns[id] = nil
    else
        self.cooldowns = {}
    end
    return self
end

---随机获取一个匹配的对话
---@param context table
---@param options table|nil
---@return DialogueEntry|nil, string|nil
function DialogueLibrary:getRandom(context, options)
    local matches = self:queryAll(context, options)
    if #matches == 0 then
        return nil, nil
    end
    
    local entry = matches[math.random(#matches)]
    
    -- 应用冷却
    self:_setCooldown(entry.id, entry.cooldown)
    
    -- 记录历史
    table.insert(self.history, {
        id = entry.id,
        time = os.time(),
        context = context,
    })
    
    return entry, self:format(entry, context)
end

--------------------------------------------------------------------------------
-- DialogueTree: 对话树
--------------------------------------------------------------------------------

---@class DialogueTreeNode
---@field id string
---@field text string
---@field speaker string|nil
---@field choices table[]|nil 选项
---@field next string|nil 下一个节点
---@field action function|nil 执行动作
---@field conditions table|nil

---@class DialogueTree
---@field nodes table<string, DialogueTreeNode>
---@field currentNode string|nil
---@field context table
---@field listeners table
local DialogueTree = {}
DialogueTree.__index = DialogueTree

---创建对话树
---@param config table
---@return DialogueTree
function Dialogue.newTree(config)
    local self = setmetatable({}, DialogueTree)
    
    self.nodes = config.nodes or {}
    self.currentNode = nil
    self.context = {}
    self.history = {}
    
    self.listeners = {
        nodeEnter = {},
        nodeExit = {},
        choiceMade = {},
        treeEnd = {},
    }
    
    return self
end

---开始对话
---@param startNode string|nil 起始节点，默认 "start"
---@param context table|nil 初始上下文
---@return DialogueTree self
function DialogueTree:start(startNode, context)
    self.currentNode = startNode or "start"
    self.context = context or {}
    self.history = {}
    
    self:_enterNode(self.currentNode)
    
    return self
end

---获取当前节点
---@return DialogueTreeNode|nil
function DialogueTree:getCurrentNode()
    if not self.currentNode then
        return nil
    end
    return self.nodes[self.currentNode]
end

---获取当前文本
---@return string|nil
function DialogueTree:getText()
    local node = self:getCurrentNode()
    return node and node.text
end

---获取当前选项
---@return table[]|nil
function DialogueTree:getChoices()
    local node = self:getCurrentNode()
    if not node or not node.choices then
        return nil
    end
    
    -- 过滤掉条件不满足的选项
    local available = {}
    for i, choice in ipairs(node.choices) do
        if not choice.conditions or self:_checkConditions(choice.conditions) then
            table.insert(available, {
                index = i,
                text = choice.text,
                disabled = choice.disabled,
            })
        end
    end
    
    return available
end

---选择选项
---@param choiceIndex number
---@return boolean success
function DialogueTree:choose(choiceIndex)
    local node = self:getCurrentNode()
    if not node or not node.choices then
        return false
    end
    
    local choice = node.choices[choiceIndex]
    if not choice then
        return false
    end
    
    -- 检查条件
    if choice.conditions and not self:_checkConditions(choice.conditions) then
        return false
    end
    
    -- 触发监听器
    self:_emit("choiceMade", choiceIndex, choice)
    
    -- 执行选项动作
    if choice.action then
        choice.action(self.context, self)
    end
    
    -- 前进到下一个节点
    local nextNode = choice.next
    if nextNode then
        self:_exitNode(self.currentNode)
        self:_enterNode(nextNode)
    else
        self:_end()
    end
    
    return true
end

---继续（无选项时）
---@return boolean success
function DialogueTree:continue()
    local node = self:getCurrentNode()
    if not node then
        return false
    end
    
    -- 如果有选项，不能直接继续
    if node.choices and #node.choices > 0 then
        return false
    end
    
    -- 执行节点动作
    if node.action then
        node.action(self.context, self)
    end
    
    -- 前进到下一个节点
    if node.next then
        self:_exitNode(self.currentNode)
        self:_enterNode(node.next)
        return true
    else
        self:_end()
        return false
    end
end

---检查对话是否结束
---@return boolean
function DialogueTree:isEnded()
    return self.currentNode == nil
end

---设置上下文
---@param key string
---@param value any
---@return DialogueTree self
function DialogueTree:setContext(key, value)
    self.context[key] = value
    return self
end

---获取上下文
---@param key string
---@return any
function DialogueTree:getContext(key)
    return self.context[key]
end

---注册事件监听器
---@param event string
---@param callback function
---@return DialogueTree self
function DialogueTree:on(event, callback)
    if self.listeners[event] then
        table.insert(self.listeners[event], callback)
    end
    return self
end

---@private
function DialogueTree:_emit(event, ...)
    for _, callback in ipairs(self.listeners[event] or {}) do
        callback(...)
    end
end

---@private
function DialogueTree:_checkConditions(conditions)
    for key, expected in pairs(conditions) do
        local actual = self.context[key]
        
        if type(expected) == "table" then
            local op, value = expected[1], expected[2]
            if op == ">" and not (actual and actual > value) then return false end
            if op == "<" and not (actual and actual < value) then return false end
            if op == ">=" and not (actual and actual >= value) then return false end
            if op == "<=" and not (actual and actual <= value) then return false end
            if op == "==" and actual ~= value then return false end
            if op == "~=" and actual == value then return false end
        else
            if actual ~= expected then return false end
        end
    end
    return true
end

---@private
function DialogueTree:_enterNode(nodeId)
    self.currentNode = nodeId
    local node = self.nodes[nodeId]
    
    if node then
        table.insert(self.history, {
            nodeId = nodeId,
            time = os.time(),
        })
        self:_emit("nodeEnter", nodeId, node)
    else
        -- 节点不存在，结束对话
        self:_end()
    end
end

---@private
function DialogueTree:_exitNode(nodeId)
    self:_emit("nodeExit", nodeId, self.nodes[nodeId])
end

---@private
function DialogueTree:_end()
    self.currentNode = nil
    self:_emit("treeEnd", self.history)
end

---跳转到指定节点
---@param nodeId string
---@return DialogueTree self
function DialogueTree:goTo(nodeId)
    if self.currentNode then
        self:_exitNode(self.currentNode)
    end
    self:_enterNode(nodeId)
    return self
end

---添加节点
---@param id string
---@param node DialogueTreeNode
---@return DialogueTree self
function DialogueTree:addNode(id, node)
    node.id = id
    self.nodes[id] = node
    return self
end

-- 导出
Dialogue.DialogueLibrary = DialogueLibrary
Dialogue.DialogueTree = DialogueTree

return Dialogue
