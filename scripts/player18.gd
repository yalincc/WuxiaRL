extends CharacterBody2D

## ============================================================
## 街机清版游戏 角色控制器
##
## 移动模型：X 轴水平移动 / Y 轴纵深移动（模拟透视）
## 跳跃：视觉抛物线偏移，不改变 ground_y
## ============================================================

# ---------- 状态枚举 ----------
enum State {
	IDLE,
	WALK,
	RUN,
	JUMP,
	ATTACK,
	DEFEND,
	ROLL,
	HURT,
	GUN,
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

# ---------- 可行走带边界 ----------
@export var band_left: float = 0.0
@export var band_right: float = 0.0
@export var band_top: float = 0.0
@export var band_bottom: float = 0.0

# ---------- 节点 ----------
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# ---------- 内部状态 ----------
var current_state: State = State.IDLE
var facing_right: bool = true
var is_locked: bool = false
var jump_timer: float = 0.0
var jump_start_y: float = 0.0
var roll_timer: float = 0.0
var roll_dir: float = 1.0
var hurt_timer: float = 0.0
var hurt_dir: float = -1.0

# ---------- 动画 → 状态名映射 ----------
const ANIM_MAP := {
	State.IDLE: "idle",
	State.WALK: "walk",
	State.RUN: "run",
	State.JUMP: "jump",
	State.ATTACK: "attack",
	State.DEFEND: "defend",
	State.ROLL: "skill",   # 暂无 roll 动画，用 skill 占位
	State.HURT: "idle",    # 暂无 hurt 动画，用 idle 占位
	State.GUN: "gun",
}


func _ready() -> void:
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


func _physics_process(delta: float) -> void:
	var dir_x := Input.get_axis("left", "right")
	var dir_y := Input.get_axis("up", "down")

	# 朝向wdada
	if dir_x != 0.0:
		facing_right = dir_x > 0.0
	sprite.flip_h = !facing_right

	match current_state:
		State.IDLE:   _tick_idle(dir_x, dir_y)
		State.WALK:   _tick_walk(dir_x, dir_y, delta)
		State.RUN:    _tick_run(dir_x, dir_y, delta)
		State.JUMP:   _tick_jump(dir_x, delta)
		State.DEFEND: _tick_defend(dir_x, dir_y)
		State.ROLL:   _tick_roll(delta)
		State.HURT:   _tick_hurt(delta)
		State.GUN:    pass


# ===================== idle =====================

func _tick_idle(dir_x: float, dir_y: float) -> void:
	if _try_action(dir_x, dir_y):
		return
	if dir_x != 0.0 or dir_y != 0.0:
		_switch(State.WALK)


# ===================== walk =====================

func _tick_walk(dir_x: float, dir_y: float, delta: float) -> void:
	if _try_action(dir_x, dir_y):
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
	if _try_action(dir_x, dir_y):
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
	jump_timer += delta
	var t := jump_timer / jump_duration
	var offset_y := 4.0 * jump_height * t * (t - 1.0)
	global_position.y = jump_start_y + offset_y
	global_position.x += dir_x * walk_speed * delta
	global_position.x = clampf(global_position.x, band_left, band_right)

	if jump_timer >= jump_duration:
		global_position.y = jump_start_y
		_unlock_and_idle()


# ===================== attack =====================

# 由 _try_action 触发，动画播完 signal 回收


# ===================== defend =====================

func _tick_defend(_dir_x: float, _dir_y: float) -> void:
	if not Input.is_action_pressed("defend"):
		_switch(State.IDLE)


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
	if is_locked:
		return
	current_state = new_state
	anim_player.play(ANIM_MAP[new_state])


func _unlock_and_idle() -> void:
	is_locked = false
	_switch(State.IDLE)


# ===================== 动作触发 =====================

func _try_action(dir_x: float, _dir_y: float) -> bool:
	if Input.is_action_just_pressed("jump"):
		_start_jump()
		return true
	if Input.is_action_just_pressed("attack"):
		_start_attack()
		return true
	if Input.is_action_just_pressed("roll"):
		_start_roll(dir_x)
		return true
	if Input.is_action_just_pressed("gun"):
		_start_gun()
		return true
	if Input.is_action_pressed("defend"):
		_switch(State.DEFEND)
		return true
	return false


func _start_jump() -> void:
	_switch(State.JUMP)
	is_locked = true
	jump_timer = 0.0
	jump_start_y = global_position.y


func _start_attack() -> void:
	_switch(State.ATTACK)
	is_locked = true


func _start_roll(dir_x: float) -> void:
	roll_timer = 0.0
	roll_dir = 1.0 if facing_right else -1.0
	if dir_x != 0.0:
		roll_dir = dir_x
	_switch(State.ROLL)
	is_locked = true


func _start_gun() -> void:
	_switch(State.GUN)
	is_locked = true


# ===================== 受伤（外部调用） =====================

func take_damage(from_position: Vector2) -> void:
	if current_state == State.ROLL:
		return   # 翻滚无敌
	if current_state == State.HURT:
		return
	hurt_timer = 0.0
	hurt_dir = -1.0 if from_position.x > global_position.x else 1.0
	_switch(State.HURT)
	is_locked = true


# ===================== 动画结束回调 =====================

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"attack":
			if current_state == State.ATTACK:
				_unlock_and_idle()
		"gun":
			if current_state == State.GUN:
				_unlock_and_idle()


# ===================== 工具 =====================

func _clamp() -> void:
	global_position.x = clampf(global_position.x, band_left, band_right)
	global_position.y = clampf(global_position.y, band_top, band_bottom)
