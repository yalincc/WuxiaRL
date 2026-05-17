extends CharacterBody2D

## ============================================================
## 街机清版游戏 角色控制器（魂类动作系统）
##
## 移动模型：X 轴水平移动 / Y 轴纵深移动（模拟透视）
## 跳跃：视觉抛物线偏移，不改变 ground_y
## 攻击：轻按 J → 普攻 / 长按 J → 必杀(BO)
## 防御：K 防御 / 前0.15s完美防御触发反击(Parry)
## 闪避：L 翻滚，前2/3时间无敌帧
## ============================================================

# ---------- 信号 ----------
signal health_changed(new_health: float)
signal died

# ---------- 状态枚举 ----------
enum State {
	IDLE,
	WALK,
	RUN,
	JUMP,
	ATTACK,
	BO,
	AIR_ATTACK,
	FALL_ATTACK,
	DEFEND,
	PARRY,
	ROLL,
	HURT,
	DEAD,
}

# ---------- 移动参数 ----------
@export var walk_speed: float = 200.0
@export var run_speed: float = 350.0
@export var vertical_speed: float = 100.0
@export var jump_height: float = 120.0
@export var jump_duration: float = 0.5
@export var roll_speed: float = 500.0
@export var roll_duration: float = 0.3
@export var hurt_knockback: float = 150.0
@export var hurt_duration: float = 0.4

# ---------- 攻击参数 ----------
@export var attack_hold_threshold: float = 0.2
@export var attack_damage: float = 10.0
@export var bo_damage: float = 25.0
@export var air_attack_damage: float = 8.0
@export var fall_attack_damage: float = 20.0
@export var fall_attack_speed: float = 500.0

# ---------- 翻滚参数 ----------
@export var roll_iframe_end: float = 0.2

# ---------- 防御参数 ----------
@export var parry_window: float = 0.15
@export var parry_duration: float = 0.4
@export var defend_damage_reduction: float = 0.2

# ---------- 生命参数（Phase 2 完善） ----------
@export var max_health: float = 100.0

# ---------- 可行走带边界 ----------
@export var band_left: float = 0.0
@export var band_right: float = 0.0
@export var band_top: float = 0.0
@export var band_bottom: float = 0.0

# ---------- 节点 ----------
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area2D = $AttackArea
@onready var hurtbox: Area2D = $Hurtbox

# ---------- 内部状态 ----------
var current_state: State = State.IDLE
var facing_right: bool = true
var is_locked: bool = false

# 跳跃
var jump_timer: float = 0.0
var jump_start_y: float = 0.0
var jump_h_speed: float = 0.0  # 起跳时的水平速度（走/跑决定）

# 翻滚
var roll_timer: float = 0.0
var roll_dir: float = 1.0

# 受击
var hurt_timer: float = 0.0
var hurt_dir: float = -1.0

# 攻击键跟踪
var attack_hold_time: float = 0.0
var is_attack_held: bool = false
var attack_timer: float = 0.0
var attack_start_pos: Vector2 = Vector2.ZERO  # 攻击开始时锁定的位置

# 攻击持续时间（不依赖动画长度，用计时器控制）
@export var attack_duration: float = 0.4

# 防御键跟踪
var defend_hold_time: float = 0.0

# 反击
var parry_timer: float = 0.0

# 下落攻击
var fall_attack_dir_x: float = 0.0  # 下落攻击时的水平漂移

# 生命值
var current_health: float = 0.0

# 攻击命中追踪（防止同一招重复打同一目标）
var hit_targets: Array[Node2D] = []

# ---------- 动画 → 状态名映射 ----------
const ANIM_MAP := {
	State.IDLE: "idle",
	State.WALK: "walk",
	State.RUN: "run",
	State.JUMP: "jump",
	State.ATTACK: "attack",
	State.BO: "bo",
	State.AIR_ATTACK: "attack",   # 空中攻击复用攻击动画
	State.FALL_ATTACK: "attack",  # 下落攻击复用攻击动画（暂无专用动画）
	State.DEFEND: "defend",
	State.PARRY: "attack",       # 反击复用攻击动画（暂无专用动画）
	State.ROLL: "roll",
	State.HURT: "hurt",
	State.DEAD: "idle",          # 暂无死亡动画
}


func _ready() -> void:
	current_health = max_health
	# 街机清版无重力，使用浮动模式防止 CharacterBody2D 内部物理漂移
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
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


func _unhandled_input(event: InputEvent) -> void:
	# 监听攻击键松开
	if event.is_action_released("attack"):
		is_attack_held = false


func _physics_process(delta: float) -> void:
	# 清除残留速度，防止 CharacterBody2D 内部物理漂移
	velocity = Vector2.ZERO

	# ★ ATTACK/BO 期间最优先锁定位置，防止任何来源的漂移
	if current_state in [State.ATTACK, State.BO]:
		global_position.x = attack_start_pos.x

	var dir_x := Input.get_axis("left", "right")
	var dir_y := Input.get_axis("up", "down")

	# 朝向
	if dir_x != 0.0 and current_state not in [State.ATTACK, State.BO, State.PARRY, State.HURT]:
		facing_right = dir_x > 0.0
	sprite.flip_h = !facing_right

	# 攻击键按住时长累加
	if is_attack_held:
		attack_hold_time += delta

	# 防御键按住时长累加
	if Input.is_action_pressed("defend"):
		defend_hold_time += delta

	match current_state:
		State.IDLE:        _tick_idle(dir_x, dir_y)
		State.WALK:        _tick_walk(dir_x, dir_y, delta)
		State.RUN:         _tick_run(dir_x, dir_y, delta)
		State.JUMP:        _tick_jump(dir_x, delta)
		State.ATTACK:      _tick_attack(delta)
		State.BO:          _tick_bo(delta)
		State.AIR_ATTACK:  _tick_air_attack(dir_x, delta)
		State.FALL_ATTACK: _tick_fall_attack(delta)
		State.DEFEND:      _tick_defend()
		State.PARRY:       _tick_parry(delta)
		State.ROLL:        _tick_roll(delta)
		State.HURT:        _tick_hurt(delta)
		State.DEAD:        pass


# ===================== idle =====================

func _tick_idle(dir_x: float, dir_y: float) -> void:
	if _try_action(dir_x):
		return
	if dir_x != 0.0 or dir_y != 0.0:
		_switch(State.WALK)


# ===================== walk =====================

func _tick_walk(dir_x: float, dir_y: float, delta: float) -> void:
	if _try_action(dir_x):
		return
	if dir_x == 0.0 and dir_y == 0.0:
		_switch(State.IDLE)
		return
	if Input.is_action_pressed("run") and dir_x != 0.0:
		_switch(State.RUN)
		return
	global_position.x += dir_x * walk_speed * delta
	global_position.y += dir_y * vertical_speed * delta
	_clamp()


# ===================== run =====================

func _tick_run(dir_x: float, dir_y: float, delta: float) -> void:
	if _try_action(dir_x):
		return
	if dir_x == 0.0:
		_switch(State.IDLE)
		return
	if not Input.is_action_pressed("run"):
		_switch(State.WALK)
		return
	global_position.x += dir_x * run_speed * delta
	global_position.y += dir_y * vertical_speed * delta
	_clamp()


# ===================== jump =====================

func _tick_jump(dir_x: float, delta: float) -> void:
	# 空中可按攻击键
	if Input.is_action_just_pressed("attack"):
		var dir_y := Input.get_axis("up", "down")
		if dir_y > 0.0:
			_start_fall_attack(dir_x)
		else:
			_start_air_attack()
		return

	jump_timer += delta
	var t := jump_timer / jump_duration
	var offset_y := 4.0 * jump_height * t * (t - 1.0)
	global_position.y = jump_start_y + offset_y
	# X 方向用起跳时的速度 + 空中微调
	global_position.x += dir_x * jump_h_speed * delta
	global_position.x = clampf(global_position.x, band_left, band_right)

	if jump_timer >= jump_duration:
		global_position.y = jump_start_y
		_unlock_and_idle()


# ===================== attack（普攻 + 长按转BO） =====================

func _tick_attack(delta: float) -> void:
	attack_timer += delta

	# 长按检测 BO
	var is_still_holding := is_attack_held or Input.is_action_pressed("attack")
	if is_still_holding and attack_hold_time >= attack_hold_threshold:
		_start_bo_from_attack()
		return

	# 攻击持续时间结束 → 回到待机
	if attack_timer >= attack_duration:
		_unlock_and_idle()


# ===================== BO（必杀攻击） =====================

func _tick_bo(_delta: float) -> void:
	# BO 动画播完由 animation_finished 回收
	pass


# ===================== air_attack（空中普攻） =====================

func _tick_air_attack(dir_x: float, delta: float) -> void:
	# 空中攻击期间继续按跳跃抛物线下落，不锁定水平
	jump_timer += delta
	var t := jump_timer / jump_duration
	var offset_y := 4.0 * jump_height * t * (t - 1.0)
	global_position.y = jump_start_y + offset_y
	global_position.x += dir_x * jump_h_speed * delta
	global_position.x = clampf(global_position.x, band_left, band_right)
	# 如果跳跃时间已到，落地
	if jump_timer >= jump_duration:
		global_position.y = jump_start_y
		_unlock_and_idle()


# ===================== fall_attack（下落攻击） =====================

func _tick_fall_attack(delta: float) -> void:
	# 快速向下移动
	global_position.y += fall_attack_speed * delta
	# 少量水平漂移
	global_position.x += fall_attack_dir_x * walk_speed * 0.3 * delta
	_clamp()
	# 到达地面（起跳Y位置或更低）→ 落地
	if global_position.y >= jump_start_y:
		global_position.y = jump_start_y
		_unlock_and_idle()


# ===================== defend =====================

func _tick_defend() -> void:
	# 松开防御键 → 回到待机
	if not Input.is_action_pressed("defend"):
		_unlock_and_idle()


# ===================== parry（完美防御反击） =====================

func _tick_parry(delta: float) -> void:
	parry_timer += delta
	if parry_timer >= parry_duration:
		_unlock_and_idle()


# ===================== roll =====================

func _tick_roll(delta: float) -> void:
	roll_timer += delta
	global_position.x += roll_dir * roll_speed * delta
	global_position.x = clampf(global_position.x, band_left, band_right)
	if roll_timer >= roll_duration:
		_unlock_and_idle()


# ===================== hurt =====================

func _tick_hurt(delta: float) -> void:
	hurt_timer += delta
	global_position.x += hurt_dir * hurt_knockback * delta
	global_position.x = clampf(global_position.x, band_left, band_right)
	if hurt_timer >= hurt_duration:
		_unlock_and_idle()


# ===================== 状态切换 =====================

func _switch(new_state: State) -> void:
	if is_locked and new_state != State.PARRY:
		return
	current_state = new_state
	anim_player.play(ANIM_MAP[new_state])


func _unlock_and_idle() -> void:
	is_locked = false
	attack_hold_time = 0.0
	defend_hold_time = 0.0
	_disable_hitbox()
	_switch(State.IDLE)


# ===================== 动作触发 =====================

func _try_action(dir_x: float) -> bool:
	# 优先级：跳跃 > 闪避 > 攻击 > 防御
	if Input.is_action_just_pressed("jump"):
		_start_jump()
		return true
	if Input.is_action_just_pressed("roll"):
		_start_roll(dir_x)
		return true
	if Input.is_action_just_pressed("attack"):
		_start_attack()
		return true
	if Input.is_action_pressed("defend"):
		defend_hold_time = 0.0
		_switch(State.DEFEND)
		return true
	return false


func _start_jump() -> void:
	# 记住起跳时的水平速度：跑步跳更远
	jump_h_speed = run_speed if Input.is_action_pressed("run") else walk_speed
	_switch(State.JUMP)
	is_locked = true
	jump_timer = 0.0
	jump_start_y = global_position.y


func _start_attack() -> void:
	is_attack_held = true
	attack_hold_time = 0.0
	attack_timer = 0.0
	attack_start_pos = global_position  # 锁定攻击起始位置，防止漂移
	hit_targets.clear()
	_enable_hitbox()
	_switch(State.ATTACK)
	is_locked = true


func _start_bo_from_attack() -> void:
	"""从普攻状态转入必杀（长按触发）"""
	is_attack_held = false  # BO不再跟踪按键
	hit_targets.clear()
	_enable_hitbox()
	current_state = State.BO
	anim_player.play(ANIM_MAP[State.BO])


func _start_roll(dir_x: float) -> void:
	roll_timer = 0.0
	roll_dir = 1.0 if facing_right else -1.0
	if dir_x != 0.0:
		roll_dir = dir_x
	_switch(State.ROLL)
	is_locked = true


func _start_air_attack() -> void:
	"""空中普通攻击"""
	attack_hold_time = 0.0
	is_attack_held = false
	hit_targets.clear()
	attack_start_pos = global_position  # 锁定位置，防止空中漂移
	_enable_hitbox()
	current_state = State.AIR_ATTACK
	anim_player.play(ANIM_MAP[State.AIR_ATTACK])


func _start_fall_attack(dir_x: float) -> void:
	"""下落攻击（按住下+攻击）"""
	fall_attack_dir_x = dir_x
	attack_hold_time = 0.0
	is_attack_held = false
	hit_targets.clear()
	_enable_hitbox()
	current_state = State.FALL_ATTACK
	anim_player.play(ANIM_MAP[State.FALL_ATTACK])


func _start_parry() -> void:
	"""触发完美防御反击"""
	parry_timer = 0.0
	is_locked = true
	attack_hold_time = 0.0
	is_attack_held = false
	hit_targets.clear()
	_enable_hitbox()
	current_state = State.PARRY
	anim_player.play(ANIM_MAP[State.PARRY])


# ===================== 受伤（外部调用） =====================

func take_damage(from_position: Vector2, damage_amount: float = 10.0) -> void:
	# 1. 翻滚无敌帧判定
	if current_state == State.ROLL:
		if roll_timer < roll_iframe_end:
			return  # 无敌帧内，不受伤害
	# 2. 反击/下落攻击状态全程无敌
	if current_state == State.PARRY or current_state == State.FALL_ATTACK:
		return
	# 3. 防御状态：完美防御 or 减伤
	if current_state == State.DEFEND:
		if defend_hold_time < parry_window:
			# 完美防御！触发反击
			_start_parry()
			return
		else:
			# 普通防御：减伤 + 小幅后退
			var reduced_damage := damage_amount * defend_damage_reduction
			_apply_damage(reduced_damage)
			# 小幅后退
			var knock_dir: float = -1.0 if from_position.x > global_position.x else 1.0
			global_position.x += knock_dir * hurt_knockback * 0.3
			global_position.x = clampf(global_position.x, band_left, band_right)
			return
	# 4. 已在受伤状态，不重复
	if current_state == State.HURT:
		return
	# 5. 死亡状态
	if current_state == State.DEAD:
		return
	# 6. 正常受伤
	_apply_damage(damage_amount)
	hurt_timer = 0.0
	hurt_dir = -1.0 if from_position.x > global_position.x else 1.0
	current_state = State.HURT
	is_locked = true
	anim_player.play(ANIM_MAP[State.HURT])


func _apply_damage(amount: float) -> void:
	"""扣除生命值，发出信号"""
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health)
	if current_health <= 0.0:
		_die()


func _die() -> void:
	"""死亡处理"""
	current_state = State.DEAD
	is_locked = true
	anim_player.play(ANIM_MAP[State.DEAD])
	died.emit()
	set_physics_process(false)


# ===================== 动画结束回调 =====================

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"attack":
			# 空中攻击动画结束 → 继续下落到地面
			if current_state == State.AIR_ATTACK:
				if jump_timer >= jump_duration:
					global_position.y = jump_start_y
					_unlock_and_idle()
				# 否则继续空中状态直到落地
			# 地面普攻由 _tick_attack 计时器控制，不在此处理
		"bo":
			if current_state == State.BO:
				_unlock_and_idle()
		"hurt":
			if current_state == State.HURT:
				_unlock_and_idle()


# ===================== Hitbox 开关 =====================

func _enable_hitbox() -> void:
	attack_area.monitoring = true


func _disable_hitbox() -> void:
	attack_area.monitoring = false
	hit_targets.clear()


# ===================== AttackArea 信号回调 =====================

func _on_attack_area_area_entered(area: Area2D) -> void:
	"""攻击判定碰到了敌人的 Hurtbox"""
	var target: Node2D = area.get_parent()
	if target in hit_targets:
		return  # 防止同一招重复打
	hit_targets.append(target)
	# 根据当前攻击类型决定伤害
	var dmg: float = get_attack_damage()
	if target.has_method("take_damage"):
		target.take_damage(global_position, dmg)


# ===================== Hurtbox 信号回调 =====================

func _on_hurtbox_area_entered(_area: Area2D) -> void:
	"""被敌人的 AttackArea 碰到 — 伤害由敌方 _on_attack_area_area_entered 统一处理，此处不重复"""
	pass


# ===================== 伤害查询（供敌人调用） =====================

func get_attack_damage() -> float:
	"""根据当前状态返回攻击伤害值"""
	match current_state:
		State.ATTACK:      return attack_damage
		State.BO:           return bo_damage
		State.AIR_ATTACK:  return air_attack_damage
		State.FALL_ATTACK: return fall_attack_damage
		State.PARRY:       return attack_damage
		_:                 return attack_damage


# ===================== 工具 =====================

func _clamp() -> void:
	global_position.x = clampf(global_position.x, band_left, band_right)
	global_position.y = clampf(global_position.y, band_top, band_bottom)


# ===================== VisionArea 信号回调（玩家不需要视野检测，空实现防止报错） =====================

func _on_vision_area_body_entered(_body: Node2D) -> void:
	pass


func _on_vision_area_body_exited(_body: Node2D) -> void:
	pass
