class_name PlayerFSM
extends CharacterBody2D

## ============================================================
## 2D横版动作战斗系统 - 角色主脚本
##
## 基于有限状态机（FSM）管理角色行为
## 节点结构：
##   PlayerFSM (CharacterBody2D)
##   ├── Sprite2D
##   ├── AnimationPlayer
##   ├── CollisionShape2D
##   ├── StateMachine (StateMachine)
##   │   ├── Idle
##   │   ├── Move
##   │   ├── Run
##   │   ├── Jump
##   │   ├── AttackNormal
##   │   ├── AttackSkill
##   │   ├── Defense
##   │   ├── DefenseCounter
##   │   ├── Dodge
##   │   ├── AirAttack
##   │   ├── AirDownAttack
##   │   ├── Land
##   │   └── HitStun
##   ├── InputBuffer (InputBuffer)
##   ├── HurtBox (Area2D)
##   └── HitBoxes (Node)
##       ├── AttackNormal (Area2D)
##       ├── AttackSkill (Area2D)
##       ├── AirAttack (Area2D)
##       ├── AirDownAttack (Area2D)
##       └── DefenseCounter (Area2D)
## ============================================================

# ---------- 信号 ----------
signal health_changed(new_health: float)
signal died

# ---------- 移动参数 ----------
@export var walk_speed: float = 120.0
@export var run_speed: float = 250.0
@export var vertical_speed: float = 100.0
@export var jump_velocity: float = -400.0
@export var run_jump_velocity_mult: float = 1.5
@export var run_jump_horizontal_mult: float = 1.8

# ---------- 攻击参数 ----------
@export var normal_attack_damage: float = 10.0
@export var skill_damage: float = 25.0
@export var counter_damage: float = 15.0
@export var air_attack_damage: float = 8.0
@export var air_down_attack_damage: float = 20.0

# ---------- 防御参数 ----------
@export var defense_damage_reduction: float = 0.8
@export var counter_window: float = 0.15

# ---------- 闪避参数 ----------
@export var dodge_duration: float = 0.4
@export var dodge_perfect_window: float = 0.12
@export var dodge_speed: float = 400.0

# ---------- 其他参数 ----------
@export var land_stiff_time: float = 0.2
@export var hitstun_time: float = 0.4
@export var long_press_threshold: float = 0.25

# ---------- 生命值 ----------
@export var max_health: float = 100.0

# ---------- 可行走带边界 ----------
@export var band_left: float = 0.0
@export var band_right: float = 0.0
@export var band_top: float = 0.0
@export var band_bottom: float = 0.0

# ---------- 可攻击伤害 ----------
@export var attack_damage: float = 10.0
@export var hurt_knockback: float = 150.0
@export var fall_attack_speed: float = 500.0
@export var jump_duration: float = 0.5
@export var jump_height: float = 120.0

# ---------- 节点引用 ----------
@onready var state_machine: StateMachine = $StateMachine
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hurt_box: Area2D = $HurtBox

# ---------- 内部状态 ----------
var facing_right: bool = true
var current_health: float = 0.0

# 跳跃追踪（供 AirAttack 等状态读取）
var _jump_timer: float = 0.0
var _jump_start_y: float = 0.0
var _jump_h_speed: float = 0.0
var _air_elapsed: float = 0.0

# 受击追踪
var _hit_knockback_dir: float = 1.0

# 完美闪避标记
var perfect_evasion_triggered: bool = false

# ---------- 初始化 ----------
func _ready() -> void:
	current_health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	velocity = Vector2.ZERO

	# 自动检测边界
	if band_bottom == 0.0:
		_auto_detect_bounds()

	# 配置 InputBuffer 的长按阈值
	var input_buffer: InputBuffer = $InputBuffer as InputBuffer
	if input_buffer:
		input_buffer.long_press_threshold = long_press_threshold

func _auto_detect_bounds() -> void:
	var vp := get_viewport_rect().size
	band_left = 30.0
	band_right = vp.x - 30.0
	band_top = vp.y * 0.65
	band_bottom = vp.y - 40.0
	if global_position.y < band_top or global_position.y > band_bottom:
		global_position.y = (band_top + band_bottom) / 2.0

# ---------- 伤害系统 ----------

## 受到伤害（由 HitBox 或敌人调用）
## [param from_position] - 攻击来源位置（用于计算击退方向）
## [param damage_amount] - 伤害值
func take_damage(from_position: Vector2, damage_amount: float = 10.0) -> void:
	if current_state_name() in ["defense_counter", "hit_stun"]:
		return
	if current_health <= 0.0:
		return

	current_health = maxf(current_health - damage_amount, 0.0)
	health_changed.emit(current_health)

	if current_health <= 0.0:
		_die()
		return

	# 计算击退方向
	_hit_knockback_dir = -1.0 if from_position.x > global_position.x else 1.0
	# 切换到受击状态
	state_machine.change_state("hit_stun")

## 直接扣除生命值（由 Defense 状态调用，已减伤）
func apply_damage(amount: float) -> void:
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health)
	if current_health <= 0.0:
		_die()

func _die() -> void:
	died.emit()
	set_physics_process(false)

## 根据当前状态返回攻击伤害值
func get_attack_damage() -> float:
	var state_name: String = state_machine.get_current_state_name()
	match state_name:
		"attack_normal":     return normal_attack_damage
		"attack_skill":      return skill_damage
		"air_attack":        return air_attack_damage
		"air_down_attack":   return air_down_attack_damage
		"defense_counter":   return counter_damage
	return attack_damage

func current_state_name() -> String:
	return state_machine.get_current_state_name()
