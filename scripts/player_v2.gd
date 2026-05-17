extends CharacterBody2D

## ============================================================
## 2D横版动作战斗系统 - Player V2
##
## 基于开发文档（FSM状态表 + 输入缓冲 + 受击分流）
## 适配现有 assets：复用已有动画名 idel/walk/run/attack/bo/defend/roll/hurt
## 单文件版本，直接挂载到 player.tscn 即可运行
## ============================================================

# ---------- 信号 ----------
signal health_changed(new_health: float)
signal died

# ---------- 状态枚举（严格匹配状态转换表） ----------
enum State {
	IDLE,
	WALK,
	RUN,
	JUMP,
	ATTACK_NORMAL,    # 地面轻攻击
	ATTACK_SKILL,     # 地面长按技能
	DEFENSE,          # 防御
	DEFENSE_COUNTER,  # 防反
	DODGE,            # 闪避
	AIR_ATTACK,       # 空中普攻
	AIR_DOWN_ATTACK,  # 下落攻击
	LAND,             # 落地硬直
	HURT,             # 受击硬直
	DEAD,
}

# ===================== 移动参数 =====================
@export var walk_speed: float = 120.0
@export var run_speed: float = 250.0
@export var vertical_speed: float = 100.0
@export var jump_velocity: float = -400.0
@export var run_jump_velocity_mult: float = 1.5
@export var run_jump_horizontal_mult: float = 1.8

# ===================== 攻击参数 =====================
@export var normal_attack_damage: float = 10.0
@export var skill_damage: float = 25.0
@export var counter_damage: float = 15.0
@export var air_attack_damage: float = 8.0
@export var air_down_attack_damage: float = 20.0
@export var attack_duration: float = 0.4       # 攻击状态持续时间

# ===================== 防御参数 =====================
@export var defense_damage_reduction: float = 0.8   # 防御减伤比例
@export var counter_window: float = 0.15             # 防反窗口（秒）

# ===================== 闪避参数 =====================
@export var dodge_duration: float = 0.4
@export var dodge_perfect_window: float = 0.12
@export var dodge_speed: float = 400.0

# ===================== 其他参数 =====================
@export var land_stiff_time: float = 0.2
@export var hitstun_time: float = 0.4
@export var long_press_threshold: float = 0.25  # 输入缓冲：长按判定阈值
@export var hurt_knockback: float = 150.0
@export var fall_attack_speed: float = 500.0
@export var max_health: float = 100.0

# ===================== 可行走边界 =====================
@export var band_left: float = 0.0
@export var band_right: float = 0.0
@export var band_top: float = 0.0
@export var band_bottom: float = 0.0

# ===================== 跳跃参数 =====================
@export var jump_height: float = 120.0   # 抛物线高度
@export var jump_duration: float = 0.5   # 跳跃总时长

# ===================== 节点引用 =====================
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area2D = $AttackArea
@onready var hurtbox: Area2D = $Hurtbox

# ===================== 内部状态 =====================
var current_state: int = State.IDLE
var facing_right: bool = true
var is_locked: bool = false          # 动作锁定（攻击/跳跃/翻滚/受击中）
var current_health: float = 0.0

# --- 输入缓冲 ---
var _attack_press_time: float = 0.0
var _attack_held: bool = false
var _attack_triggered: bool = false

# --- 跳跃 ---
var _jump_timer: float = 0.0
var _jump_start_y: float = 0.0
var _jump_h_speed: float = 0.0
var _came_from_run: bool = false

# --- 攻击 ---
var _atk_start_pos_x: float = 0.0

# --- 防御 ---
var _defense_enter_time: float = 0.0

# --- 闪避 ---
var _dodge_timer: float = 0.0
var _dodge_dir: float = 1.0
var _perfect_evasion: bool = false

# --- 受击 ---
var _hurt_timer: float = 0.0
var _hurt_dir: float = 1.0

# --- 落地 ---
var _land_timer: float = 0.0

# --- 命中追踪 ---
var _hit_targets: Array[Node2D] = []

# ===================== 动画名映射 =====================
## 将文档规范动画名映射到现有 assets 中的实际动画名
const ANIM_MAP := {
	State.IDLE:            "idle",
	State.WALK:            "walk",
	State.RUN:             "run",
	State.JUMP:            "jump",
	State.ATTACK_NORMAL:   "attack",
	State.ATTACK_SKILL:    "bo",
	State.DEFENSE:         "defend",
	State.DEFENSE_COUNTER: "attack",   # 复用攻击动画
	State.DODGE:           "roll",
	State.AIR_ATTACK:      "attack",   # 复用攻击动画
	State.AIR_DOWN_ATTACK: "attack",   # 复用攻击动画
	State.LAND:            "idle",     # 复用待机动画（暂无land专属）
	State.HURT:            "hurt",
	State.DEAD:            "idle",     # 暂无死亡动画
}

# ===================== 初始化 =====================

func _ready() -> void:
	current_health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	velocity = Vector2.ZERO
	add_to_group("player")
	if band_bottom == 0.0:
		_auto_detect_bounds()
	anim_player.play("idle")

func _auto_detect_bounds() -> void:
	var vp := get_viewport_rect().size
	band_left = 30.0
	band_right = vp.x - 30.0
	band_top = vp.y * 0.65
	band_bottom = vp.y - 40.0
	if global_position.y < band_top or global_position.y > band_bottom:
		global_position.y = (band_top + band_bottom) / 2.0

# ===================== 主循环 =====================

func _unhandled_input(event: InputEvent) -> void:
	# 输入缓冲：检测攻击键松开
	if event.is_action_released("attack"):
		if _attack_held and not _attack_triggered:
			_on_light_attack()
		_attack_held = false

func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO

	# 输入缓冲：检测长按
	_tick_input_buffer(delta)

	var dir_x := Input.get_axis("left", "right")
	var dir_y := Input.get_axis("up", "down")

	# 朝向（攻击/受击中不转）
	if dir_x != 0.0 and current_state not in [State.ATTACK_NORMAL, State.ATTACK_SKILL, State.DEFENSE_COUNTER, State.HURT]:
		facing_right = dir_x > 0.0
	sprite.flip_h = not facing_right

	match current_state:
		State.IDLE:            _tick_idle(dir_x, dir_y)
		State.WALK:            _tick_walk(dir_x, dir_y, delta)
		State.RUN:             _tick_run(dir_x, dir_y, delta)
		State.JUMP:            _tick_jump(dir_x, delta)
		State.ATTACK_NORMAL:   _tick_attack_normal(delta)
		State.ATTACK_SKILL:    _tick_attack_skill(delta)
		State.DEFENSE:         _tick_defense()
		State.DEFENSE_COUNTER: _tick_defense_counter(delta)
		State.DODGE:           _tick_dodge(delta)
		State.AIR_ATTACK:      _tick_air_attack(dir_x, delta)
		State.AIR_DOWN_ATTACK: _tick_air_down_attack(dir_x, delta)
		State.LAND:            _tick_land(delta)
		State.HURT:            _tick_hurt(delta)
		State.DEAD:            pass

# ===================== 输入缓冲 =====================

func _tick_input_buffer(_delta: float) -> void:
	if _attack_held and not _attack_triggered:
		if (Time.get_ticks_msec() / 1000.0) - _attack_press_time >= long_press_threshold:
			_attack_triggered = true
			_on_skill()

# ===================== 状态逻辑 =====================

# ----- IDLE -----

func _tick_idle(dir_x: float, dir_y: float) -> void:
	if _try_action(dir_x):
		return
	if dir_x != 0.0 or dir_y != 0.0:
		_change_state(State.WALK if not (Input.is_action_pressed("run") and dir_x != 0.0) else State.RUN)

# ----- WALK -----

func _tick_walk(dir_x: float, dir_y: float, delta: float) -> void:
	if _try_action(dir_x):
		return
	if dir_x == 0.0 and dir_y == 0.0:
		_change_state(State.IDLE)
		return
	if Input.is_action_pressed("run") and dir_x != 0.0:
		_change_state(State.RUN)
		return
	global_position.x += dir_x * walk_speed * delta
	global_position.y += dir_y * vertical_speed * delta
	_clamp()

# ----- RUN -----

func _tick_run(dir_x: float, dir_y: float, delta: float) -> void:
	if _try_action(dir_x):
		return
	if dir_x == 0.0:
		_change_state(State.IDLE)
		return
	if not Input.is_action_pressed("run"):
		_change_state(State.WALK)
		return
	global_position.x += dir_x * run_speed * delta
	global_position.y += dir_y * vertical_speed * delta
	_clamp()

# ----- JUMP -----

func _tick_jump(dir_x: float, delta: float) -> void:
	# 空中按攻击
	if Input.is_action_just_pressed("attack"):
		var dir_y := Input.get_axis("up", "down")
		if dir_y > 0.0:
			_start_air_down_attack(dir_x)
		else:
			_start_air_attack()
		return

	_jump_timer += delta
	var t := _jump_timer / jump_duration
	var offset_y := 4.0 * jump_height * t * (t - 1.0)
	global_position.y = _jump_start_y + offset_y
	global_position.x += dir_x * _jump_h_speed * delta
	_clamp_x()

	if _jump_timer >= jump_duration:
		global_position.y = _jump_start_y
		_change_state(State.LAND)

# ----- ATTACK_NORMAL -----

func _tick_attack_normal(_delta: float) -> void:
	# 攻击期间锁定 X 位置防止漂移
	global_position.x = _atk_start_pos_x

	# 长按检测 → 转技能（输入缓冲触发）
	if _attack_held and _attack_triggered:
		_start_attack_skill()
		return

# ----- ATTACK_SKILL -----

func _tick_attack_skill(_delta: float) -> void:
	# 技能靠 animation_finished 回收
	pass

# ----- DEFENSE -----

func _tick_defense() -> void:
	if not Input.is_action_pressed("defend"):
		_unlock_to(State.IDLE)
	# 检测防御中按闪避
	if Input.is_action_just_pressed("roll"):
		_start_dodge()

# ----- DEFENSE_COUNTER -----

func _tick_defense_counter(_delta: float) -> void:
	# 由 animation_finished 回收
	pass

# ----- DODGE -----

func _tick_dodge(delta: float) -> void:
	_dodge_timer += delta
	global_position.x += _dodge_dir * dodge_speed * delta
	_clamp_x()
	if _dodge_timer >= dodge_duration:
		_unlock_to(State.IDLE)

# ----- AIR_ATTACK -----

func _tick_air_attack(dir_x: float, delta: float) -> void:
	global_position.x = _atk_start_pos_x
	global_position.x += dir_x * _jump_h_speed * delta

	# 继续下坠
	_jump_timer += delta
	var t := _jump_timer / jump_duration
	var offset_y := 4.0 * jump_height * t * (t - 1.0)
	global_position.y = _jump_start_y + offset_y
	_clamp_x()

	# 落地检测
	if _jump_timer >= jump_duration:
		global_position.y = _jump_start_y
		_change_state(State.LAND)

# ----- AIR_DOWN_ATTACK -----

func _tick_air_down_attack(dir_x: float, delta: float) -> void:
	global_position.y += fall_attack_speed * delta
	global_position.x += dir_x * walk_speed * 0.3 * delta
	_clamp()

	if global_position.y >= _jump_start_y:
		global_position.y = _jump_start_y
		_change_state(State.LAND)

# ----- LAND -----

func _tick_land(delta: float) -> void:
	_land_timer += delta
	if _land_timer >= land_stiff_time:
		_unlock_to(State.IDLE)

# ----- HURT -----

func _tick_hurt(delta: float) -> void:
	_hurt_timer += delta
	global_position.x += _hurt_dir * hurt_knockback * delta
	_clamp_x()
	if _hurt_timer >= hitstun_time:
		_unlock_to(State.IDLE)

# ===================== 动作触发 =====================

func _try_action(dir_x: float) -> bool:
	# 优先级：跳跃 > 闪避 > 攻击(输入缓冲触发) > 防御
	if Input.is_action_just_pressed("jump"):
		_start_jump()
		return true
	if Input.is_action_just_pressed("roll"):
		_start_dodge(dir_x)
		return true
	if Input.is_action_just_pressed("attack"):
		# 按下攻击键 → 启动输入缓冲
		_attack_press_time = Time.get_ticks_msec() / 1000.0
		_attack_held = true
		_attack_triggered = false
		return true
	if Input.is_action_pressed("defend"):
		_start_defense()
		return true
	return false

func _start_jump() -> void:
	_jump_timer = 0.0
	_jump_start_y = global_position.y
	_came_from_run = Input.is_action_pressed("run")
	if _came_from_run:
		var dir_x := Input.get_axis("left", "right")
		_jump_h_speed = run_speed * run_jump_horizontal_mult * (1.0 if dir_x != 0.0 else 0.0)
	else:
		_jump_h_speed = walk_speed
	_change_state(State.JUMP)
	is_locked = true

func _start_attack_normal() -> void:
	_atk_start_pos_x = global_position.x
	_hit_targets.clear()
	_enable_attack_area()
	_change_state(State.ATTACK_NORMAL)
	is_locked = true

func _start_attack_skill() -> void:
	# 技能攻击
	_hit_targets.clear()
	_enable_attack_area()
	_change_state(State.ATTACK_SKILL)
	is_locked = true

# 输入缓冲回调：轻攻击
func _on_light_attack() -> void:
	if current_state in [State.IDLE, State.WALK, State.RUN]:
		_start_attack_normal()

# 输入缓冲回调：技能（长按触发）
func _on_skill() -> void:
	if current_state in [State.IDLE, State.WALK, State.RUN]:
		_start_attack_skill()

func _start_defense() -> void:
	_defense_enter_time = Time.get_ticks_msec() / 1000.0
	_change_state(State.DEFENSE)
	is_locked = true

func _start_dodge(dir_x: float = 0.0) -> void:
	_dodge_timer = 0.0
	_perfect_evasion = false
	if dir_x != 0.0:
		_dodge_dir = dir_x
	else:
		_dodge_dir = 1.0 if facing_right else -1.0
	_change_state(State.DODGE)
	is_locked = true

func _start_air_attack() -> void:
	_atk_start_pos_x = global_position.x
	_hit_targets.clear()
	_enable_attack_area()
	_change_state(State.AIR_ATTACK)

func _start_air_down_attack(_dir_x: float) -> void:
	_hit_targets.clear()
	_enable_attack_area()
	_change_state(State.AIR_DOWN_ATTACK)

func _start_defense_counter() -> void:
	"""触发防反"""
	_hit_targets.clear()
	_enable_attack_area()
	_change_state(State.DEFENSE_COUNTER)
	is_locked = true

# ===================== 状态切换 =====================

func _change_state(new_state: int) -> void:
	current_state = new_state
	anim_player.play(ANIM_MAP[new_state])

func _unlock_to(state: int) -> void:
	is_locked = false
	_attack_held = false
	_attack_triggered = false
	_disable_attack_area()
	_hit_targets.clear()
	_change_state(state)

# ===================== 受伤系统 =====================

## 受到伤害（与现有 enemy.gd 兼容：from_position, damage）
func take_damage(from_position: Vector2, damage_amount: float = 10.0) -> void:
	if current_state in [State.DEAD, State.HURT]:
		return
	# DEFENSE_COUNTER 全程无敌
	if current_state == State.DEFENSE_COUNTER:
		return

	match current_state:
		State.DEFENSE:
			_handle_defense_hit(damage_amount, from_position)
		State.DODGE:
			_handle_dodge_hit(damage_amount)
		_:
			_take_normal_hit(damage_amount, from_position)

func _handle_defense_hit(damage: float, from_position: Vector2) -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _defense_enter_time
	if elapsed <= counter_window:
		# 防反窗口内 → 触发反击
		_start_defense_counter()
	else:
		# 普通防御：减伤 80%
		var reduced: float = damage * (1.0 - defense_damage_reduction)
		_apply_damage(reduced)
		# 小幅后退
		var knock_dir: float = -1.0 if from_position.x > global_position.x else 1.0
		global_position.x += knock_dir * hurt_knockback * 0.3
		_clamp_x()

func _handle_dodge_hit(_damage: float) -> void:
	# 简化检测：用 _dodge_timer 判断完美闪避窗口
	if _dodge_timer <= dodge_perfect_window:
		_perfect_evasion = true
		# 触发完美闪避（可扩展添加特效）
		_on_perfect_evasion()
	# 普通无敌：直接忽略伤害

func _take_normal_hit(damage: float, from_position: Vector2) -> void:
	_apply_damage(damage)
	_hurt_timer = 0.0
	_hurt_dir = -1.0 if from_position.x > global_position.x else 1.0
	_disable_attack_area()
	_hit_targets.clear()
	_change_state(State.HURT)
	is_locked = true

func _apply_damage(amount: float) -> void:
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health)
	if current_health <= 0.0:
		_die()

func _on_perfect_evasion() -> void:
	# 可扩展：播放完美闪避特效、增加资源等
	pass

func _die() -> void:
	current_state = State.DEAD
	is_locked = true
	anim_player.play(ANIM_MAP[State.DEAD])
	died.emit()
	set_physics_process(false)

# ===================== 攻击伤害查询 =====================

func get_attack_damage() -> float:
	match current_state:
		State.ATTACK_NORMAL:   return normal_attack_damage
		State.ATTACK_SKILL:    return skill_damage
		State.AIR_ATTACK:      return air_attack_damage
		State.AIR_DOWN_ATTACK: return air_down_attack_damage
		State.DEFENSE_COUNTER: return counter_damage
	return normal_attack_damage

# ===================== 攻击框管理 =====================

func _enable_attack_area() -> void:
	attack_area.monitoring = true

func _disable_attack_area() -> void:
	attack_area.monitoring = false
	_hit_targets.clear()

func _on_attack_area_area_entered(area: Area2D) -> void:
	"""攻击框碰到敌人的 HurtBox"""
	var target: Node2D = area.get_parent()
	if target in _hit_targets or target == self:
		return
	_hit_targets.append(target)
	var dmg: float = get_attack_damage()
	if target.has_method("take_damage"):
		target.take_damage(global_position, dmg)

func _on_hurtbox_area_entered(_area: Area2D) -> void:
	"""被敌方攻击框碰到 — 伤害由敌方攻击框触发，此处不重复处理"""
	pass

# ===================== 动画结束回调 =====================

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"attack":
			if current_state == State.ATTACK_NORMAL or current_state == State.DEFENSE_COUNTER:
				_unlock_to(State.IDLE)
			# AIR_ATTACK/AIR_DOWN_ATTACK 由落地检测回收
		"bo":
			if current_state == State.ATTACK_SKILL:
				_unlock_to(State.IDLE)

# ===================== 工具 =====================

func _clamp() -> void:
	global_position.x = clampf(global_position.x, band_left, band_right)
	global_position.y = clampf(global_position.y, band_top, band_bottom)

func _clamp_x() -> void:
	global_position.x = clampf(global_position.x, band_left, band_right)
