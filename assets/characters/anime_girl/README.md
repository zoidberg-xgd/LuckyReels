# 日式二次元角色模板

这是一个通用的 PNG 部件角色模板，支持多种动态效果。

## 快速开始

1. 准备 PNG 图片文件
2. 放到此目录
3. 在 mod 中加载

## 需要的图片文件

### 基础部件（必需）
| 文件名 | 说明 | 建议尺寸 |
|--------|------|----------|
| `body.png` | 身体 | 120x150 |
| `head.png` | 头部 | 100x100 |
| `front_hair.png` | 前发/刘海 | 120x60 |
| `back_hair.png` | 后发 | 120x150 |

### 表情部件
| 文件名 | 说明 |
|--------|------|
| `eyes_normal.png` | 正常眼睛 |
| `eyes_happy.png` | 开心眼睛 |
| `eyes_worried.png` | 担心眼睛 |
| `eyes_surprised.png` | 惊讶眼睛 |
| `mouth_normal.png` | 正常嘴巴 |
| `mouth_smile.png` | 微笑 |
| `mouth_worried.png` | 担心 |
| `mouth_open.png` | 张嘴 |

### 可选部件
| 文件名 | 说明 |
|--------|------|
| `arm_left.png` | 左手臂 |
| `arm_right.png` | 右手臂 |
| `clothes.png` | 衣服 |
| `accessory.png` | 配饰 |

## 动态效果

虽然使用静态 PNG 图片，但系统会自动添加以下动画：

### 自动动画（可在 parts.lua 中配置）

在 `animations` 中配置：

```lua
animations = {
    breathing = {
        enabled = true,    -- 是否启用
        speed = 2,         -- 速度
        amount = 2,        -- 幅度（像素）
    },
    blinking = {
        enabled = true,
        min_interval = 3,  -- 最短眨眼间隔
        max_interval = 6,  -- 最长眨眼间隔
    },
    hair_sway = {
        enabled = true,
        speed = 1.5,
        amount = 0.03,     -- 旋转幅度
    },
    idle_sway = {
        enabled = true,
        speed = 0.8,
        amount = 0.5,
    },
    arm_swing = {
        enabled = true,
        speed = 1.2,
        amount = 0.05,
    },
},
```

### 事件反应（可在 parts.lua 中配置）

在 `reactions` 中配置：

```lua
reactions = {
    win = {
        animation = "jump",     -- jump | shake | nod | bounce | spin
        duration = 0.5,         -- 持续时间
        expression = "happy",   -- 切换表情
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
},
```

### 可用的反应动画
| 动画 | 效果 |
|------|------|
| `jump` | 跳跃 |
| `shake` | 左右摇晃 |
| `nod` | 点头 |
| `bounce` | 弹跳 |
| `spin` | 旋转 |

### 参数绑定
| 参数 | 来源 | 效果 |
|------|------|------|
| `tired` | 楼层数 | 头低下、疲劳姿态 |
| `happy` | 金币/租金比 | 手臂抬起、开心动作 |

### 自定义参数绑定

在 `parts.lua` 中修改 `bindings`：

```lua
head = {
    image = "head.png",
    bindings = {
        -- 参数名 = { 属性 = 变化量 }
        tired = {
            rotation = 0.1,  -- 疲劳时头微微倾斜
            y = 5,           -- 头低下
        },
    },
},
```

### 可用的绑定属性
| 属性 | 说明 |
|------|------|
| `scaleX` | 横向缩放 |
| `scaleY` | 纵向缩放 |
| `rotation` | 旋转（弧度） |
| `x` | 横向位移 |
| `y` | 纵向位移 |

## 参数映射

在 `parts.lua` 中配置游戏数据到参数的映射：

```lua
parameter_mapping = {
    wealth = {
        source = "money",      -- 数据来源: money | floor | rent_ratio
        min_value = 0,         -- 输入最小值
        max_value = 50,        -- 输入最大值
        min_output = 0,        -- 输出最小值
        max_output = 1,        -- 输出最大值
    },
},
```

## 使用方法

### 在 mod 中加载

```lua
return function(ModAPI)
    local char = ModAPI.Character.loadFromFile("assets/characters/anime_girl")
    if char then
        ModAPI.Character.setActive(char)
    end
end
```

### 直接在游戏中使用

修改 `src/game.lua`：
```lua
local CharacterLoader = require("src.character_loader")
self.character = CharacterLoader.load("assets/characters/anime_girl")
```

## 自定义示例

### 添加新部件

```lua
-- 在 parts 中添加
accessory = {
    image = "accessory.png",
    x = 0, y = -90,
    ox = 20, oy = 20,
    z = 7,
    bindings = {
        happy = { rotation = 0.1 },  -- 开心时轻微旋转
    },
},
```

### 添加新参数

```lua
-- 在 parameter_mapping 中添加
my_param = {
    source = "money",       -- 或 "floor" 或 "rent_ratio"
    min_value = 0,
    max_value = 100,
    min_output = 0,
    max_output = 1,
},
```

## 脚本扩展

用户可以通过 Lua 脚本创建更复杂的效果。

### 创建脚本 mod

在 `mods/` 目录创建 `.lua` 文件：

```lua
-- mods/my_animations.lua
return function(ModAPI)
    local ModScripting = require("src.core.mod_scripting")
    
    -- 注册自定义动画
    ModScripting.registerAnimation("my_anim", function(part, time, intensity)
        part.rotation = math.sin(time * 5) * 0.2 * intensity
        part.scaleX = 1 + math.sin(time * 3) * 0.1 * intensity
    end)
    
    -- 注册自定义参数
    ModScripting.registerParameter("my_param", function(gameState)
        return gameState.money / 100
    end)
    
    -- 注册事件反应
    ModScripting.registerReaction("win", function(character, data)
        character:triggerReaction("bounce", 0.5)
    end)
    
    -- 注册每帧更新
    ModScripting.registerUpdate("my_update", function(character, dt, gameState)
        -- 每帧执行的逻辑
    end)
end
```

### 在 parts.lua 中使用脚本动画

```lua
custom_animations = {
    body = {
        { name = "my_anim", intensity = 0.5 },
    },
},
```

### 内置脚本动画

| 名称 | 效果 |
|------|------|
| `wobble` | 摇摆变形 |
| `float` | 上下漂浮 |
| `pulse` | 脉冲缩放 |
| `shake_anim` | 左右抖动 |
| `squash` | 挤压拉伸 |

### Mod 目录位置

游戏发布后，用户可以在以下位置添加 mod：

- **Windows**: `%APPDATA%/LOVE/LuckyReels/mods/`
- **macOS**: `~/Library/Application Support/LOVE/LuckyReels/mods/`
- **Linux**: `~/.local/share/love/LuckyReels/mods/`
