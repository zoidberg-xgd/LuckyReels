-- Anime Girl Character Template
-- 日式二次元角色模板 - 支持多种动态效果
--
-- 使用方法：
-- 1. 准备 PNG 图片文件放在此目录
-- 2. 在 mod 中加载: ModAPI.Character.loadFromFile("assets/characters/anime_girl")

return {
    -- 角色基础尺寸（参考值）
    width = 120,
    height = 200,
    
    --==========================================================================
    -- 部件定义
    -- z 值越大越靠前绘制
    -- ox, oy 是原点位置（缩放和旋转的中心）
    -- bindings 定义参数如何影响这个部件
    --==========================================================================
    parts = {
        
        -- 后发（最底层）
        back_hair = {
            image = "back_hair.png",
            x = 0, y = -80,
            ox = 60, oy = 0,
            z = 0,
            bindings = {
                -- 示例：随风摆动
                -- wind = { rotation = 0.1 },
            },
        },
        
        -- 身体
        body = {
            image = "body.png",
            x = 0, y = 0,
            ox = 60, oy = 100,
            z = 1,
            bindings = {
                -- 示例：呼吸动画由代码自动处理
                -- 可以添加自定义绑定
            },
        },
        
        -- 头部
        head = {
            image = "head.png",
            x = 0, y = -70,
            ox = 50, oy = 50,
            z = 4,
            bindings = {
                -- 示例：疲劳时头低下
                tired = { rotation = 0.1, y = 5 },
            },
        },
        
        -- 前发/刘海
        front_hair = {
            image = "front_hair.png",
            x = 0, y = -85,
            ox = 60, oy = 0,
            z = 5,
        },
        
        -- 眼睛（会根据表情切换图片）
        eyes = {
            image = "eyes_normal.png",
            x = 0, y = -75,
            ox = 30, oy = 15,
            z = 6,
        },
        
        -- 嘴巴（会根据表情切换图片）
        mouth = {
            image = "mouth_normal.png",
            x = 0, y = -60,
            ox = 10, oy = 5,
            z = 6,
        },
        
        -- 左手臂
        arm_left = {
            image = "arm_left.png",
            x = -45, y = -20,
            ox = 15, oy = 10,
            z = 0,
            bindings = {
                -- 示例：开心时手臂抬起
                happy = { rotation = -0.3, y = -10 },
            },
        },
        
        -- 右手臂
        arm_right = {
            image = "arm_right.png",
            x = 45, y = -20,
            ox = 15, oy = 10,
            z = 0,
            bindings = {
                happy = { rotation = 0.3, y = -10 },
            },
        },
        
        --[[
        -- 可选：衣服层
        clothes = {
            image = "clothes.png",
            x = 0, y = 5,
            ox = 60, oy = 80,
            z = 3,
        },
        
        -- 可选：配饰
        accessory = {
            image = "accessory.png",
            x = 0, y = -90,
            ox = 20, oy = 20,
            z = 7,
        },
        ]]
    },
    
    --==========================================================================
    -- 表情系统
    -- 根据游戏状态自动切换眼睛和嘴巴图片
    --==========================================================================
    expressions = {
        neutral = {
            eyes = "eyes_normal.png",
            mouth = "mouth_normal.png",
        },
        happy = {
            eyes = "eyes_happy.png",
            mouth = "mouth_smile.png",
        },
        worried = {
            eyes = "eyes_worried.png",
            mouth = "mouth_worried.png",
        },
        surprised = {
            eyes = "eyes_surprised.png",
            mouth = "mouth_open.png",
        },
        --[[
        -- 可以添加更多表情
        sad = {
            eyes = "eyes_sad.png",
            mouth = "mouth_sad.png",
        },
        angry = {
            eyes = "eyes_angry.png",
            mouth = "mouth_angry.png",
        },
        ]]
    },
    
    --==========================================================================
    -- 动画配置
    -- 可以启用/禁用或调整各种自动动画
    --==========================================================================
    animations = {
        -- 呼吸动画
        breathing = {
            enabled = true,
            speed = 2,        -- 呼吸速度
            amount = 2,       -- 幅度（像素）
            scale = 0.01,     -- 缩放幅度
        },
        
        -- 眨眼动画
        blinking = {
            enabled = true,
            min_interval = 3,  -- 最短间隔（秒）
            max_interval = 6,  -- 最长间隔（秒）
            speed = 8,         -- 眨眼速度
        },
        
        -- 头发飘动
        hair_sway = {
            enabled = true,
            speed = 1.5,
            amount = 0.03,    -- 旋转幅度（弧度）
        },
        
        -- 身体摇摆
        idle_sway = {
            enabled = true,
            speed = 0.8,
            amount = 0.5,     -- 位移幅度（像素）
        },
        
        -- 手臂摆动
        arm_swing = {
            enabled = true,
            speed = 1.2,
            amount = 0.05,    -- 旋转幅度（弧度）
        },
    },
    
    --==========================================================================
    -- 事件反应配置
    -- 定义角色对游戏事件的反应
    --==========================================================================
    reactions = {
        win = {
            animation = "jump",    -- jump | shake | nod | bounce | spin
            duration = 0.5,
            expression = "happy",
        },
        big_win = {
            animation = "jump",
            duration = 1.0,
            expression = "happy",
        },
        spin = {
            animation = "nod",
            duration = 0.3,
        },
        lose = {
            animation = "shake",
            duration = 0.5,
            expression = "worried",
        },
        --[[
        -- 可以添加更多事件反应
        event = {
            animation = "bounce",
            duration = 0.4,
            expression = "surprised",
        },
        ]]
    },
    
    --==========================================================================
    -- 参数映射
    -- 将游戏数据映射到角色参数
    -- source: "money" | "floor" | "rent_ratio"
    --==========================================================================
    parameter_mapping = {
        -- 疲劳程度：楼层越高越疲劳
        tired = {
            source = "floor",
            min_value = 1,
            max_value = 20,
            min_output = 0,
            max_output = 1,
        },
        
        -- 开心程度：金币充足时开心
        happy = {
            source = "rent_ratio",  -- money / rent
            min_value = 0.5,
            max_value = 2,
            min_output = 0,
            max_output = 1,
        },
        
        --[[
        -- 可以添加自定义参数
        my_param = {
            source = "money",
            min_value = 0,
            max_value = 100,
            min_output = 0,
            max_output = 1,
        },
        ]]
    },
    
    --==========================================================================
    -- 自定义脚本动画
    -- 使用 ModScripting.registerAnimation() 注册的动画
    -- 需要先在 mod 脚本中注册动画函数
    --==========================================================================
    custom_animations = {
        --[[
        -- 示例：给头发添加自定义动画
        front_hair = {
            { name = "float_rotate", intensity = 0.5 },
        },
        
        -- 示例：给身体添加心跳效果
        body = {
            { name = "heartbeat", intensity = 0.3 },
        },
        ]]
    },
}
