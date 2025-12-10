-- mods/script_example.lua
-- 示例：如何用脚本创建自定义动画和行为
-- Example: How to create custom animations and behaviors with scripts

return function(ModAPI)
    local ModScripting = require("src.core.mod_scripting")
    
    ----------------------------------------------------------------------------
    -- 注册自定义动画
    -- Register custom animations
    ----------------------------------------------------------------------------
    
    -- 心跳动画 - 模拟心跳效果
    -- Heartbeat animation
    ModScripting.registerAnimation("heartbeat", function(part, time, intensity)
        intensity = intensity or 1
        local beat = math.abs(math.sin(time * 3))
        beat = beat * beat * beat  -- 更尖锐的脉冲
        part.scaleX = (part.scaleX or 1) + beat * 0.15 * intensity
        part.scaleY = (part.scaleY or 1) + beat * 0.15 * intensity
    end)
    
    -- 果冻效果 - 弹性变形
    -- Jelly effect - elastic deformation
    ModScripting.registerAnimation("jelly", function(part, time, intensity)
        intensity = intensity or 1
        local jelly = math.sin(time * 5)
        part.scaleX = (part.scaleX or 1) + jelly * 0.08 * intensity
        part.scaleY = (part.scaleY or 1) - jelly * 0.08 * intensity
    end)
    
    -- 漂浮旋转 - 缓慢旋转漂浮
    -- Float and rotate
    ModScripting.registerAnimation("float_rotate", function(part, time, intensity)
        intensity = intensity or 1
        part.y = (part.y or 0) + math.sin(time * 1.5) * 8 * intensity
        part.rotation = (part.rotation or 0) + math.sin(time * 0.8) * 0.1 * intensity
    end)
    
    ----------------------------------------------------------------------------
    -- 注册自定义参数
    -- Register custom parameters
    ----------------------------------------------------------------------------
    
    -- 兴奋度 - 基于金币和楼层计算
    -- Excitement - calculated from money and floor
    ModScripting.registerParameter("excitement", function(gameState)
        if not gameState then return 0 end
        local moneyFactor = (gameState.money or 0) / 50
        local floorFactor = (gameState.floor or 1) / 10
        return math.min(1, moneyFactor * floorFactor)
    end)
    
    -- 危险度 - 金币低于租金时增加
    -- Danger level - increases when money is below rent
    ModScripting.registerParameter("danger", function(gameState)
        if not gameState then return 0 end
        local money = gameState.money or 0
        local rent = gameState.rent or 15
        if money >= rent then return 0 end
        return 1 - (money / rent)
    end)
    
    ----------------------------------------------------------------------------
    -- 注册事件反应
    -- Register event reactions
    ----------------------------------------------------------------------------
    
    -- 大奖时的特殊反应
    -- Special reaction for big wins
    ModScripting.registerReaction("big_win", function(character, data)
        -- 播放特殊动画
        if character.triggerReaction then
            character:triggerReaction("spin", 1.5)
        end
        print("[Script] Big win reaction triggered!")
    end)
    
    ----------------------------------------------------------------------------
    -- 注册每帧更新
    -- Register per-frame updates
    ----------------------------------------------------------------------------
    
    -- 根据危险度改变角色颜色（示例）
    -- Change character based on danger level (example)
    ModScripting.registerUpdate("danger_effect", function(character, dt, gameState)
        if not gameState or not character.parts then return end
        
        local danger = ModScripting.calculateParameter("danger", gameState)
        
        -- 危险时增加抖动
        if danger > 0.5 and character.parts.body then
            local shake = math.sin(character.time * 15) * danger * 2
            character.parts.body.x = (character.parts.body.x or 0) + shake
        end
    end)
    
    print("[Script] Example script mod loaded!")
    print("[Script] Custom animations: heartbeat, jelly, float_rotate")
    print("[Script] Custom parameters: excitement, danger")
end
