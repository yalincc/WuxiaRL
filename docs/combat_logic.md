# WuxiaRL — 战斗逻辑与动画关系文档

> 供其他 AI 接手时理解架构。项目路径 `E:\WorkSpace\WuxiaRL`
> 引擎：Godot 4.6 / GDScript 2.0 静态类型

---

## 1. 架构概览

```
`_physics_process(delta)` 每帧：
  velocity = Vector2.ZERO           ← 清除物理残留
  读取 dir_x / dir_y (按键输入)
  更新朝向 flip_h
  match current_state:
    各状态下放对应的 _tick_xxx()
```

所有状态通过 `_switch(new_state)` 切换：
- 设置 `current_state`
- 调用 `anim_player.play(ANIM_MAP[new_state])` 播放对应动画

锁定机制 (`is_locked`)：攻击/跳跃/翻滚/受击/反击 期间禁止切换状态
- `is_locked` 在状态开始时置 true，`_unlock_and_idle()` 时置 false
- 唯一特例：PARRY 可以在锁定期间强行切入（用于完美防御反击）

---

## 2. 状态机与动画映射

```gdscript
# ANIM_MAP — 状态 → 动画名
IDLE        → "idle"       # 待机
WALK        → "walk"       # 走路
RUN         → "run"        # 跑步
JUMP        → "jump"       # 跳跃
ATTACK      → "attack"     # 地面普攻 (0.5s)
BO          → "bo"         # 必杀技    (1.0s)
AIR_ATTACK  → "attack"     # 空中普攻 (复用attack动画帧, 视觉帧相同)
FALL_ATTACK → "attack"     # 下落攻击 (复用attack动画帧)
DEFEND      → "defend"     # 防御
PARRY       → "attack"     # 反击     (复用attack动画帧)
ROLL        → "roll"       # 翻滚
HURT        → "hurt"       # 受击
DEAD        → "idle"       # 死亡     (暂无专用动画)
```

注意：`attack` 动画同时被 ATTACK / AIR_ATTACK / FALL_ATTACK / PARRY 四个状态共用。

---

## 3. 每帧 `_physics_process` 执行顺序

```
1. velocity = Vector2.ZERO          ← 防止 CharacterBody2D 内部物理漂移
2. 读取方向输入 → dir_x, dir_y
3. 更新朝向 (攻击/BO/Parry/Hurt 期间不更新)
4. sprite.flip_h = !facing_right
5. if is_attack_held: attack_hold_time += delta    ← 追踪长按时长
6. if 按防御:  defend_hold_time += delta           ← 追踪防御时长(完美防御窗口)
7. match current_state → _tick_xxx(delta)
```

---

## 4. 各状态详细行为

### 4.1 IDLE / WALK / RUN — 基础移动

| 状态 | 触发条件 | 行为 |
|------|---------|------|
| IDLE | 默认 | 尝试 `_try_action()` 响应按键；无按键则保持 |
| WALK | IDLE + 方向 | `dir_x * walk_speed`, `dir_y * vertical_speed` |
| RUN  | WALK + Shift | `dir_x * run_speed`, `dir_y * vertical_speed` |

`_try_action()` 优先级：跳跃 > 翻滚 > 攻击 > 防御

### 4.2 JUMP — 跳跃

- 起跳时保存 `jump_start_y` 和 `jump_h_speed`
- `jump_h_speed` = `run_speed` (按住 Shift) 或 `walk_speed`
- 抛物线公式：`offset_y = 4 * jump_height * t * (t-1)`，`t = jump_timer / jump_duration`
- 跳跃期间可按下攻击键 → 转 `_start_air_attack()`(无方向下) 或 `_start_fall_attack()`(按向下)
- `jump_duration = 0.5s`，到期回 IDLE

### 4.3 ATTACK — 地面攻击 + 长按转 BO

这是最核心的状态，**计时器驱动**（不依赖动画结束）：

```gdscript
func _tick_attack(delta):
    attack_timer += delta
    global_position.x = attack_start_pos.x       # ← 锁定 X 位置，彻底防漂移
    
    var holding := is_attack_held or Input.is_action_pressed("attack")
    if holding and attack_hold_time >= 0.15:     # ← BO 双重检测
        _start_bo_from_attack()
        return
    
    if attack_timer >= 0.4:                      # ← 攻击持续时间到
        _unlock_and_idle()                       #    回 IDLE
```

| 参数 | 值 | 说明 |
|------|---|------|
| `attack_duration` | 0.4s | 轻按普攻的总持续时间 |
| `attack_hold_threshold` | 0.15s | 长按多少秒后触发 BO |
| `attack_damage` | 10 | 普攻伤害 |
| `bo_damage` | 25 | 必杀伤害 |

流程：
```
按 J (轻按)
  → _start_attack()
    → is_attack_held=true, attack_hold_time=0, attack_timer=0, attack_start_pos=当前位置
    → _switch(State.ATTACK) → 播放 "attack" 动画
    → is_locked = true
  → 每帧 _tick_attack()
    ① attack_timer 累加
    ② 强制 global_position.x = attack_start_pos.x
    ③ 检长按阈值 → 到 0.15s 转 BO
    ④ 检总时长 → 到 0.4s 回 IDLE

按 J (长按) → 0.15s 后
  → _start_bo_from_attack()
    → is_attack_held=false, current_state=BO
    → anim_player.play("bo") → 播放 BO 动画 (1.0s)
    → _tick_bo() 空实现，靠 animation_finished("bo") 回收
```

### 4.4 BO — 必杀攻击

- 只有 `_tick_bo()` = `pass`，全凭动画结束回调
- `animation_finished("bo")` → `_unlock_and_idle()` 回 IDLE
- 伤害 `25`，其他攻击机制与普攻相同（Hitbox 在 `_start_bo_from_attack()` 时已启用）

### 4.5 AIR_ATTACK — 空中普攻

- 从 JUMP 状态转入，`jump_timer` 继续累加，抛物线继续
- 水平位置强制锁定：`global_position.x = attack_start_pos.x`
- 跳跃到期自动落地回 IDLE
- 伤害 `8`

### 4.6 FALL_ATTACK — 下落攻击

- JUMP 中按下方向键+攻击触发
- `global_position.y += fall_attack_speed * delta`（快速下坠）
- 少量水平漂移：`global_position.x += fall_attack_dir_x * walk_speed * 0.3 * delta`
- 落到起跳 Y 位置时落地回 IDLE
- 伤害 `20`，全程无敌（`take_damage` 中直接 return）

### 4.7 DEFEND / PARRY — 防御与完美防御

按 K 进入 DEFEND：
- 松开 K → 回 IDLE
- 受击时：
  - `defend_hold_time < 0.15s` → 完美防御！触发 PARRY（反击）
  - 否则 → 减伤（只受 20% 伤害）+ 小幅后退

PARRY 状态：
- `parry_duration = 0.4s`，到期回 IDLE
- 全程无敌
- Hitbox 启用，可打出反击伤害

### 4.8 ROLL — 翻滚

- `roll_duration = 0.3s`，水平移动 `roll_dir * roll_speed`
- 翻滚前 2/3 时间（`roll_iframe_end = 0.2s`）无敌帧
- 到期回 IDLE

### 4.9 HURT — 受击

- `hurt_duration = 0.4s`，击退 `hurt_dir * hurt_knockback`
- 击退方向：远离攻击者
- 到期回 IDLE

---

## 5. 动画结束回调

```gdscript
_on_animation_player_animation_finished(anim_name):
  "attack" → 只处理 AIR_ATTACH 落地
             地面 ATTACK 由 _tick_attack 计时器控制，不在此处理
  "bo"     → _unlock_and_idle()
  "hurt"   → _unlock_and_idle()
```

关键规则：**地面普攻不再依赖 `animation_finished` 回调**，改为 `attack_timer` 计时器来控制。这消除了动画时长与 BO 阈值之间的竞争条件。

---

## 6. 伤害管道

### 6.1 碰撞层体系 (project.godot / [layer_names])

| Layer# | 名称 | 用途 |
|--------|------|------|
| 1 | world | 地形/墙壁 |
| 2 | entity | 角色物理体 |
| 3 | player_hit | 玩家攻击区 (AttackArea) → 检测 layer 6 |
| 4 | enemy_hit | 敌人攻击区 (AttackArea) → 检测 layer 5 |
| 5 | player_hurt | 玩家受击区 (Hurtbox) → 被 layer 4 检测 |
| 6 | enemy_hurt | 敌人受击区 (Hurtbox) → 被 layer 3 检测 |
| 7 | vision | 视野检测 → 检测 layer 2 |

### 6.2 伤害流程

```
玩家按 J → _start_attack() → attack_area.monitoring = true
         → 播放 "attack" 动画
         → Area2D 重叠 → 信号 area_entered 触发

攻击者 AttackArea.area_entered(对方的Hurtbox):
  target = area.get_parent()          ← 获取对方的 CharacterBody2D
  if target in hit_targets: return    ← 防重复打击
  加入 hit_targets
  target.take_damage(攻击者位置, 伤害值)
```

**关键规则**：伤害只在攻击者的 `_on_attack_area_area_entered` 中处理！
受害方的 `_on_hurtbox_area_entered` 必须是 `pass`（空实现）。
因为 Area2D 重叠会同时触发双方的 `area_entered`，两边都处理会导致双倍伤害。

### 6.3 受击判定 (take_damage)

```
1. ROLL 且 roll_timer < 0.2s   → 无敌，跳过
2. PARRY / FALL_ATTACK          → 全程无敌，跳过
3. DEFEND + 0.15s内被攻击       → 完美防御 → _start_parry()
4. DEFEND + 0.15s后被攻击       → 减伤20% + 小幅后退
5. 已在 HURT / DEAD             → 跳过
6. 其他                         → 正常受伤 → HURT 状态 + 击退
```

---

## 7. 输入映射

| 按键 | 动作 | 绑定名 |
|------|------|--------|
| WASD / 方向键 | 移动 | left/right/up/down |
| Shift | 跑步 | run |
| Space | 跳跃 | jump |
| J | 攻击 | attack（轻按普攻/长按必杀） |
| K | 防御 | defend |
| L | 翻滚 | roll |

---

## 8. 已知限制与改进方向

- PARRY / FALL_ATTACK / AIR_ATTACK 共享 "attack" 动画帧，视觉无区分
- 敌人暂无 hurt/death 动画（用 idle 占位）
- 没有攻击前摇/后摇，攻击是瞬间触发
- 没有受击动画的 invincibility frames（受伤后可被连续攻击）
- 没有防御中移动

---

## 9. 核心文件清单

| 文件 | 职责 |
|------|------|
| `scripts/player.gd` | 玩家全部逻辑 — 13状态机、输入、攻击、Hitbox/Hurtbox、伤害 |
| `scripts/enemy.gd` | 敌人 AI — IDLE/CHASE/ATTACK/COOLDOWN/HURT/DEAD |
| `scenes/player.tscn` | 玩家场景 — CharacterBody2D + Sprite2D + AnimationPlayer + AttackArea + Hurtbox + VisionArea |
| `scenes/enemy.tscn` | 敌人场景 — CharacterBody2D + Sprite2D + AnimationPlayer + AttackArea + Hurtbox + VisionArea |
| `scenes/main.tscn` | 主场景 — 背景 + Camera2D + Player + Enemy |
| `project.godot` | 碰撞层定义 [layer_names] |
