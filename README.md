# LuckyReels 🎰

**幸运转轴** - 一款受《幸运房东》(Luck be a Landlord) 启发的 roguelike 老虎机游戏，使用 LÖVE2D 框架开发。

## 游戏简介

玩家通过旋转老虎机赚取金币来支付每层楼的租金。通过收集符号、升级符号、获取遗物来构建强力组合，挑战更高的楼层。

### 核心玩法
- **旋转老虎机** - 符号随机排列，计算收益
- **符号收集** - 在商店购买新符号扩充背包
- **符号升级** - 3个相同符号合成更强版本
- **符号协同** - 特定符号组合产生额外效果
- **遗物系统** - 永久增益改变游戏规则

## 快速开始

### 环境要求
- [LÖVE2D](https://love2d.org/) 11.4+
- Lua 5.1+ (用于运行测试)

### 运行游戏
```bash
# macOS/Linux
love .

# 或指定路径
love /path/to/LuckyReels
```

### 运行测试
```bash
lua tests/run_all.lua
```


## 操作说明

| 按键 | 功能 |
|------|------|
| 空格 | 旋转老虎机 |
| 鼠标左键 | 选择/购买/操作 |
| L | 切换语言 |
| R | 重新开始 |
| ESC | 返回/关闭菜单 |

## 游戏状态

```
IDLE → SPINNING → COLLECTING → [RENT_PAID/GAME_OVER]
                                    ↓
                              [EVENT] → SHOP → IDLE
```

## 开发指南

详细文档请参阅 `docs/` 目录：
- [架构设计](docs/ARCHITECTURE.md)
- [API 参考](docs/API.md)
- [Mod 开发](docs/MODDING.md)
- [数值平衡](docs/BALANCE.md)

## 许可证

MIT License
