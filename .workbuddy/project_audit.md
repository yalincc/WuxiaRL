# WuxiaRL 项目审计报告

> 审核日期: 2026-05-20
> 项目路径: `E:\WorkSpace\WuxiaRL`
> 引擎: Godot 4.6 / GDScript 2.0 静态类型
> 分辨率: 480x270, 拉伸模式 canvas_items

---

## 一、完整文件树

```
E:/WorkSpace/WuxiaRL/
├── README.md                           # 简短项目说明 ("godot MVP")
├── overview.md                         # FSM 战斗系统生成说明 (方案B/辅助资料)
├── phase1_overview.md                  # Phase1 韧性/霸体 + Telegraph + 参数化
├── phase3_overview.md                  # Phase3 血条UI + 伤害数字
├── project.godot                       # 引擎配置文件
├── icon.svg                            # 项目图标
│
├── assets/
│   ├── Gemini_Generated_Image_1ysr8x1ysr8x1ysr.png  # AI 生成精灵图
│   ├── bbts.png                        # 敌人精灵图 (白骨)
│   ├── forest_bg1.png                  # 森林背景图
│   └── playersheet.png                 # 玩家精灵图 (行尸走肉风格)
│
├── docs/
│   └── combat_logic.md                 # 战斗逻辑与动画关系文档 (270行)
│
├── scripts/
│   ├── player_v2.gd                    # 玩家角色主脚本 (523行)
│   ├── enemy_v2.gd                     # 敌人AI主脚本 (332行)
│   ├── combat_entity.gd                # 战斗实体基类 (196行)
│   ├── player18.md                     # 简易玩家控制器 (156行, 旧版参考/备选)
│   └── ui/
│       ├── damage_number.gd            # 伤害数字弹出 (42行)
│       └── player_hud.gd               # 玩家HUD (47行)
│
├── scenes/
│   ├── main.tscn                       # 主场景 (Node2D)
│   ├── player_v2.tscn                  # 玩家场景 (CharacterBody2D)
│   ├── enemy_v2.tscn                   # 敌人场景 (CharacterBody2D)
│   └── ui/
│       ├── damage_number.tscn          # 伤害数字场景 (Label)
│       └── player_hud.tscn             # 玩家HUD场景 (CanvasLayer)
│
└── addons/
    └── github_copilot/
        ├── plugin.cfg                  # 插件配置 (v2.1.0)
        ├── plugin.gd                   # EditorPlugin 入口
        ├── copilot_manager.gd          # LSP 管理器 (497行)
        ├── copilot_settings.gd         # 设置持久化
        ├── copilot_panel.gd            # 底部面板
        └── copilot_overlay.gd          # 行内叠加层
```

---

## 二、脚本摘要与行数

### 2.1 核心战斗脚本

| 文件 | 路径 | 行数 | 职责 |
|------|------|------|------|
| CombatEntity | `scripts/combat_entity.gd` | 196 | 基类: HP/韧性/朝向/边界/攻击框管理/伤害管道 |
| Player | `scripts/player_v2.gd` | 523 | 玩家状态机 + 输入缓冲 + 攻击/闪避/防御/跳跃 |
| Enemy | `scripts/enemy_v2.gd` | 332 | 敌人状态机 + Telegraph + 参数化原型 + 血条 |
| DamageNumber | `scripts/ui/damage_number.gd` | 42 | 伤害数字上浮淡出组件 |
| PlayerHUD | `scripts/ui/player_hud.gd` | 47 | 玩家血条HUD (CanvasLayer) |
| player18.md | `scripts/player18.md` | 156 | 旧版简易玩家控制器 (非实际使用) |

### 2.2 文档

| 文件 | 行数 | 职责 |
|------|------|------|
| `docs/combat_logic.md` | 270 | 战斗架构文档 (状态机/动画映射/伤害管道/输入映射) |
| `overview.md` | 49 | FSM 战斗系统方案说明 |
| `phase1_overview.md` | 51 | Phase1 特性说明 (韧性/Telegraph/参数化) |
| `phase3_overview.md` | 31 | Phase3 特性说明 (HUD/伤害数字) |
| `project.godot` | 98 | 引擎配置 |

### 2.3 插件 (非项目核心功能)

| 文件 | 行数 | 职责 |
|------|------|------|
| `copilot_manager.gd` | 497 | GitHub Copilot LSP 管理器 |
| `copilot_settings.gd`, `copilot_panel.gd`, `copilot_overlay.gd` | ~150 合计 | Copilot 编辑器插件 |

---

## 三、架构总览

### 3.1 类继承体系

```
CombatEntity (CharacterBody2D)  <- 基类: combat_entity.gd
  +-- player_v2.gd               <- 玩家子类
  +-- enemy_v2.gd                <- 敌人子类
```

### 3.2 信号体系

```
CombatEntity:
  signal health_changed(new_health: float)  -> 连接给 HUD
  signal poise_broken                        -> 韧性击破
  signal died                                 -> 死亡

PlayerHUD:
  监听 player 组的 health_changed 信号 -> 更新血条/变色
```

### 3.3 碰撞层体系 (7层)

| Layer | 名称 | 用途 |
|-------|------|------|
| 1 | world | 地形/墙壁 |
| 2 | entity | 角色物理体 |
| 3 | player_hit | 玩家 AttackArea -> 检测 layer 6 |
| 4 | enemy_hit | 敌人 AttackArea -> 检测 layer 5 |
| 5 | player_hurt | 玩家 Hurtbox -> 被 layer 4 检测 |
| 6 | enemy_hurt | 敌人 Hurtbox -> 被 layer 3 检测 |
| 7 | vision | 敌人视野检测 -> 检测 layer 2 |

### 3.4 场景节点关系

```
main.tscn (Node2D)
  +-- 背景森林 (Sprite2D)
  +-- Camera2D
  +-- PlayerHUD (CanvasLayer)   <- 实例 player_hud.tscn
  +-- Player_v2 (CharacterBody2D) <- 实例 player_v2.tscn
  |     +-- CollisionShape2D_idle (矩形)
  |     +-- CollisionShape2D_gun (圆形, 默认禁用)
  |     +-- Sprite2D (玩家精灵)
  |     +-- AnimationPlayer (10个动画: idle/walk/run/jump/attack/bo/defend/roll/hurt/RESET)
  |     +-- AttackArea (Area2D, layer3/mask6, monitoring=false)
  |     +-- Hurtbox (Area2D, layer5/mask4)
  +-- Enemy_v2 (CharacterBody2D) <- 实例 enemy_v2.tscn
        +-- CollisionShape2D (Capsule)
        +-- Sprite2D (敌人精灵)
        +-- AnimationPlayer (3个动画: idle/walk/attack)
        +-- VisionArea (Area2D, layer7/mask2, body_entered/exited)
        +-- AttackArea (Area2D, layer4/mask5, monitoring=false)
        +-- Hurtbox (Area2D, layer6/mask3)
```

---

## 四、战斗系统详解

### 4.1 玩家状态机 (14个状态)

```
enum State {
    IDLE,              # 待机 - 响应输入
    WALK,              # 行走 (120px/s)
    RUN,               # 奔跑 (250px/s, 按住Shift)
    JUMP,              # 跳跃 (抛物线, 0.5s)
    ATTACK_NORMAL,     # 地面轻攻击 (0.4s, 伤害10, 削韧5, 冲击1)
    ATTACK_SKILL,      # 技能/必杀 (1.0s动画, 伤害25, 削韧20, 冲击2)
    DEFENSE,           # 防御 (减伤80%, 0.15s防反窗口)
    DEFENSE_COUNTER,   # 防反反击 (0.4s, 无敌, 伤害15)
    DODGE,             # 闪避翻滚 (0.4s, 前0.12s完美闪避)
    AIR_ATTACK,        # 空中普攻 (伤害8, 削韧3, 冲击1)
    AIR_DOWN_ATTACK,   # 下落攻击 (伤害20, 削韧25, 冲击3=击飞, 全程无敌)
    LAND,              # 落地硬直 (0.2s)
    HURT,              # 受击硬直 (0.4s默认可变)
    DEAD,              # 死亡
}
```

### 4.2 动作优先级

`_try_action()` 输入响应优先级 (在 IDLE/WALK/RUN 中):
1. 跳跃 (Space) -> JUMP
2. 闪避 (L) -> DODGE
3. 攻击 (J) -> 输入缓冲系统 (区分轻按/长按)
4. 防御 (K) -> DEFENSE

### 4.3 输入缓冲系统

```
攻击键按下 (J):
  1. 记录 _attack_press_time
  2. 标记 _attack_held = true
  3. 每帧检测长按超时阈值 (0.25s)
     -> 超时: _on_skill() 触发技能 ATTACK_SKILL
  4. 释放攻击键:
     -> 若未触发技能: _on_light_attack() 触发 ATTACK_NORMAL

ATTACK_NORMAL 状态中:
  -> 如果蓄力中且已触发: 从攻击转入 ATTACK_SKILL (双重检测)
```

### 4.4 伤害管道

```
玩家 AttackArea.area_entered(敌人 Hurtbox):
  target = area.get_parent()
  if target in _hit_targets: return       <- 防重复打击
  _hit_targets.append(target)
  target.take_damage(attacker_pos, damage, poise_damage, impact_level)

敌人 take_damage():
  1. 死亡/受击中 -> return
  2. 韧性判定 (staggered = _apply_poise_damage)
  3. 扣血 + 伤害数字
  4. HP归零 -> _die()
  5. 若韧性击破 -> _enter_hurt(冲击等级决定硬直/击退)
     若韧性未破(霸体) -> 只扣血不打断

玩家 take_damage():
  1. 死亡/受击中/防反中 -> return
  2. match current_state:
     - DEFENSE: 防反窗口? -> 触发 PARRY : 减伤80%
     - DODGE: 完美闪避窗口? -> 触发 _perfect_evasion : 无敌无视
     - 其他: 受击硬直(冲击等级决定时长)
```

### 4.5 韧性/霸体系统 (Poise)

| 属性 | 说明 |
|------|------|
| max_poise | 0=无霸体(次次硬直), >0=霸体精英 |
| current_poise | 每次受击削减, 归零触发 stagger |
| _apply_poise_damage() | 返回 true=韧性击破, false=霸体硬抗 |

### 4.6 冲击等级 (Impact Level)

| Level | 效果 | 硬直时间 | 击退距离 |
|-------|------|---------|---------|
| 0 | 无反应 | 0.15s | 30px |
| 1 | 轻击退 | 0.3s | 100px |
| 2 | 重击退 | 0.45s | 200px |
| 3 | 击飞 | 0.6s | 300px |
| 4 | 击倒 | 0.8s | 250px |

### 4.7 攻击属性汇总

| 攻击类型 | 伤害 | 削韧 | 冲击 | 无敌 | 时长 |
|---------|------|------|------|------|------|
| 普攻 (ATTACK_NORMAL) | 10 | 5 | 1 | 否 | 0.4s |
| 技能 (ATTACK_SKILL) | 25 | 20 | 2 | 否 | 1.0s (动画) |
| 防反 (DEFENSE_COUNTER) | 15 | 15 | 1 | 是 | 0.4s |
| 空中普攻 (AIR_ATTACK) | 8 | 3 | 1 | 否 | 跳跃剩余 |
| 下落攻击 (AIR_DOWN_ATTACK) | 20 | 25 | 3 | 是 | 至落地 |

### 4.8 敌人状态机 (6个状态)

```
enum State {
    IDLE,       # 待机 - 等待玩家进入视野
    CHASE,      # 追击 - 朝向玩家移动
    ATTACK,     # 攻击 - Telegraph 0.2~0.6s -> Active 攻击动画 0.6s
    COOLDOWN,   # 冷却 - 0.8s后回到 CHASE
    HURT,       # 受击 - 硬直 + 击退
    DEAD,       # 死亡 - 淡出后 queue_free
}
```

敌人类型 (Archetype):
| 类型 | HP | 韧性 | Telegraph | 备注 |
|------|----|------|-----------|------|
| MINION | 30 | 0 | 0.2s | 杂兵 |
| ELITE | 80 | 50 | 0.3s | 精英 |
| BOSS | 300 | 100 | 0.6s | 大血条 |
| RANGED | - | - | - | 预留 |

### 4.9 防御系统细节

```
按 K:
  -> DEFENSE 状态
  -> 松开 K -> 回 IDLE
  -> 按住 K 时按 L -> DODGE (防御中可闪避)

受击时:
  -> 按下 K < 0.15s -> 完美防御 -> DEFENSE_COUNTER (无敌 + 反击)
  -> 按下 K >= 0.15s -> 减伤80% + 小幅后退
```

---

## 五、动画与视觉效果

### 5.1 玩家动画 (AnimationPlayer)

| 动画名 | 时长 | 精灵区域 | 备注 |
|--------|------|---------|------|
| idle | 1帧 | (128,0,64,64) | 静态 |
| walk | 1帧 | (320,0,64,64) | 静态 |
| run | 1帧 | (384,0,64,64) | 静态 |
| jump | 1帧 | (192,0,64,64) | 跳跃碰撞盒缩放 |
| attack | 0.5s | (0,0,64,64) | 被4个状态共用 |
| bo | 0.6s | (448,0,64,64) | 必杀技 |
| defend | 0.5s | (64,0,64,64) | 防御 |
| roll | 1帧 | (256,0,64,64) | 切换碰撞盒 |
| hurt | 1帧 | (128,0,64,64) | 同idle区域 |

所有玩家动画均为单帧精灵区域切换 -- 没有逐帧动画序列。

### 5.2 敌人动画

| 动画名 | 时长 | 帧数 | 备注 |
|--------|------|------|------|
| idle | 0.6s | 6帧循环 | 站立/呼吸 |
| walk | 0.6s | 6帧循环 | 行走 |
| attack | 0.6s | 6帧单次 | 攻击动画 |

敌人没有 hurt 或 death 动画 (用 idle 占位)。

### 5.3 Telegraph 预警 (敌人攻击前摇)

敌人攻击分为两阶段:
1. Telegraph 阶段 (0.2~0.6s): 精灵色调闪烁, 攻击框未激活
2. Active 阶段: 播放攻击动画, 攻击框激活

---

## 六、输入映射

| 按键 | 绑定名 | 功能 |
|------|--------|------|
| A / 左箭头 | left | 左移 |
| D / 右箭头 | right | 右移 |
| W / 上箭头 | up | 上移(纵深) |
| S / 下箭头 | down | 下移(纵深) |
| Shift | run | 奔跑 |
| Space | jump | 跳跃 |
| J | attack | 攻击 (轻按普攻/长按必杀) |
| K | defend | 防御 |
| L | roll | 翻滚闪避 |
| I | bo | 必杀技 (独立按键, 但代码中未处理) |

---

## 七、项目配置

- 引擎: Godot 4.6 (Forward Plus)
- 分辨率: 480x270 (拉伸模式: canvas_items)
- 物理引擎: Jolt Physics (3D, 但项目是2D)
- 渲染器: Direct3D 12
- 贴图过滤: 默认禁用 (保持像素风)
- 移动模式: CharacterBody2D.MOTION_MODE_FLOATING (自管理位置)

---

## 八、发现的问题与待改进项

### 8.1 不完备/存在问题的系统

1. **"I" 键绑定未使用**: `bo` 按键绑定在 project.godot 中已定义, 但 player_v2.gd 中没有处理 `Input.is_action_just_pressed("bo")` 的逻辑。长按 J 才能触发 BO, 独立按键形同虚设。

2. **动画均为单帧占位**: 所有玩家动画 (除了 attack 0.5s / bo 0.6s / defend 0.5s) 都是单帧静态精灵区域切换。walk/run/jump/roll/hurt 本质上只是不同 Sprite 区域, 没有真正的逐帧动画序列。

3. **动画复用导致视觉无差异化**: 4个状态 (ATTACK_NORMAL / DEFENSE_COUNTER / AIR_ATTACK / AIR_DOWN_ATTACK) 共用同一个 "attack" 动画, 玩家完全无法从视觉上区分普攻、防反、空中攻击。

4. **敌人无受击/死亡动画**: `_enter_hurt()` 中播放 "idle" 动画, `_die()` 中播放 "idle" 后淡出。没有专门的 hurt/death 动画。

5. **攻击框管理边界问题**: `_tick_attack_normal` 没有主动关闭攻击框的逻辑。攻击框激活后, 如果动画结束回调未触发 (如空中攻击), 攻击框可能保持激活状态。

6. **完美闪避反馈为空**: `_on_perfect_evasion()` 是空方法 `pass`。完美闪避目前不存在任何视觉反馈。

### 8.2 架构复杂度评估

- 总战斗脚本量: ~1050 行 (combat_entity + player + enemy)
- 状态总数: 玩家 14 个状态, 敌人 6 个状态
- 复杂度水平: 中等偏低 -- 所有逻辑集中在 3 个文件中, 没有 FSM 模块化拆分
- 可扩展性: 状态硬编码在 switch-case 中, 新增状态需要修改多个函数

### 8.3 与 overview.md 描述的不一致

`overview.md` 描述了一套完整的 FSM 架构 (17个独立文件: state.gd, state_machine.gd, idle.gd 等), 但实际项目中这些文件不存在。当前项目使用的是简化的 v2 版本 -- 3 个主要脚本直接继承 CombatEntity, 状态机通过 `match current_state` 实现, 没有独立的 State 类/节点。

这是一份参考设计文档 (planning doc) 而非实际项目描述。类似地 `player18.md` 是另一个 (更简单的) 玩家控制器的参考设计, 非当前使用代码。

---

## 九、总结

这是一个功能完整的 2D 横版动作游戏 MVP, 具备:
- 14 状态玩家状态机 (移动/跳跃/攻击/防御/闪避/受击)
- 5 种攻击类型 (含空中/下落/防反)
- 韧性/霸体 + 冲击等级系统
- 敌人 Telegraph 预警系统
- 输入缓冲系统 (轻按 vs 长按)
- 完美防御/完美闪避机制
- HUD + 伤害数字

核心战斗系统约 1050 行 GDScript, 架构清晰但尚未模块化。动画资源均为占位级别, 需要替换为真正的逐帧动画序列。
