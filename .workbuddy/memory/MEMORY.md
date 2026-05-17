# WuxiaRL 项目记忆

## 项目概况
- **类型**：街机清版动作游戏（类街机三国/恐龙快打风格）
- **引擎**：Godot 4.6，Forward Plus 渲染
- **分辨率**：480×270 低分辨率视口，canvas_items 拉伸
- **路径**：E:\WorkSpace\WuxiaRL\
- **代码风格**：GDScript 2.0 静态类型，snake_case 信号，组合优于继承

## 碰撞层体系
- Layer 1: world — 地形/墙壁
- Layer 2: entity — 角色物理体
- Layer 3: player_hit — 玩家攻击区（检测 enemy_hurt）
- Layer 4: enemy_hit — 敌人攻击区（检测 player_hurt）
- Layer 5: player_hurt — 玩家受击区（被 enemy_hit 检测）
- Layer 6: enemy_hurt — 敌人受击区（被 player_hit 检测）
- Layer 7: vision — 视野检测

## 核心文件结构
- `scripts/player.gd` — 主力玩家脚本，魂类动作系统 + Hitbox/Hurtbox
- `scripts/player18.gd` — 简化版玩家脚本（独立维护，不改动）
- `scripts/enemy.gd` — 敌人AI：IDLE/CHASE/ATTACK/COOLDOWN/HURT/DEAD
- `scenes/player.tscn` — 玩家场景：CharacterBody2D + AttackArea + Hurtbox + VisionArea
- `scenes/enemy.tscn` — 敌人场景：CharacterBody2D + AttackArea + Hurtbox + VisionArea
- `scenes/main.tscn` — 主场景：背景 + Camera2D + Player + Enemy

## 输入映射
- WASD / 方向键：移动
- Shift：跑步
- Space：跳跃
- J：攻击（轻按普攻/长按必杀）
- K：防御
- L：翻滚/闪避
- I：bo（已废弃，攻击统一用J键长按触发）

## 动画资源
- 玩家(playersheet.png)：10个动画 RESET/attack/bo/defend/hurt/idle/jump/roll/run/walk
- 敌人(bbts.png)：4个动画 RESET/attack/idle/walk
- 玩家18(Gemini_Generated_Image)：5个动画 attack/idle/jump/run/walk

## 已知问题
- 敌人暂无 hurt 动画（用 idle 占位），无 death 动画
- 玩家 PARRY/FALL_ATTACK 复用 attack 动画（暂无专用动画）

## 关键设计决策
- **攻击系统改为计时器驱动**：`_tick_attack` 用 `attack_timer + attack_duration` 控制攻击持续时间，不再依赖 `animation_finished` 回调。避免动画时长与 BO 阈值(0.15s)竞争
- **CharacterBody2D 设为 FLOATING 模式**：`motion_mode = MOTION_MODE_FLOATING`，街机清版无重力
- **每帧清零 velocity**：`_physics_process` 开头 `velocity = Vector2.ZERO`，防止物理引擎残留速度漂移
- **攻击时强制锁定 X 位置**：`_start_attack()` 和 `_start_air_attack()` 保存 `attack_start_pos`，`_tick_attack()` 和 `_tick_air_attack()` 每帧强制执行 `global_position.x = attack_start_pos.x`，彻底杜绝任何水平漂移
- **BO 双重检测**：`_tick_attack()` 同时检查 `is_attack_held`（脚本变量）和 `Input.is_action_pressed("attack")`（原始输入），防止按键事件丢失导致 BO 不触发

## 开发阶段
- Phase 1（已完成）：player.gd 魂类动作系统 — 轻按/长按攻击、翻滚无敌帧、防御/完美防御反击、跳跃速度关联起跑状态、空中普攻/下落攻击
- Phase 2（已完成）：碰撞层体系 + Hitbox/Hurtbox + 敌人AI重写 + 伤害管道
- Phase 3（待做）：血条UI、伤害数字弹出、敌人群体行为、关卡/波次系统
