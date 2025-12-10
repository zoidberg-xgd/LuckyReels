--[[
    GameLib - 通用游戏系统库
    
    一个轻量级、模块化的 Lua 游戏开发库，
    提供常用的游戏系统抽象，可用于 LÖVE2D 或其他 Lua 游戏引擎。
    
    使用方式:
    ```lua
    local GameLib = require("lib.gamelib")
    
    -- 使用单个模块
    local Resource = GameLib.Resource
    local hp = Resource.new({id = "hp", value = 100, max = 100})
    
    -- 或直接引用子模块
    local ECS = require("lib.gamelib.ecs")
    ```
    
    模块列表:
    - Resource: 资源管理系统（HP、金币、能量等）
    - StateSprite: 状态驱动精灵系统
    - ProcShape: 程序化形状变形
    - InteractRegion: 交互区域系统
    - Dialogue: 条件对话系统
    - WeightedEvent: 加权随机事件系统
    - ECS: 实体组件系统
    
    @module GameLib
    @author LuckyReels Team
    @license MIT
]]

local GameLib = {
    _VERSION = "1.0.0",
    _DESCRIPTION = "通用游戏系统库",
}

-- 延迟加载模块
local modules = {
    Resource = "lib.gamelib.resource",
    StateSprite = "lib.gamelib.state_sprite",
    ProcShape = "lib.gamelib.proc_shape",
    InteractRegion = "lib.gamelib.interact_region",
    Dialogue = "lib.gamelib.dialogue",
    WeightedEvent = "lib.gamelib.weighted_event",
    ECS = "lib.gamelib.ecs",
}

-- 使用 __index 实现延迟加载
setmetatable(GameLib, {
    __index = function(t, key)
        local modulePath = modules[key]
        if modulePath then
            local module = require(modulePath)
            rawset(t, key, module)
            return module
        end
        return nil
    end
})

---获取版本信息
---@return string
function GameLib.getVersion()
    return GameLib._VERSION
end

---获取所有可用模块名
---@return string[]
function GameLib.getModules()
    local result = {}
    for name, _ in pairs(modules) do
        table.insert(result, name)
    end
    table.sort(result)
    return result
end

---预加载所有模块
---@return GameLib
function GameLib.preloadAll()
    for name, _ in pairs(modules) do
        local _ = GameLib[name]
    end
    return GameLib
end

return GameLib
