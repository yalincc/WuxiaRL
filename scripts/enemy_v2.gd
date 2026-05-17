extends CharacterBody2D

## ============================================================
## 街机清版游戏 敌人控制器 V2
##
## 状态机：IDLE → CHASE → ATTACK → COOLDOWN → CHASE
##         任何状态 → HURT → 回到之前状态
##         HP归零 → DEAD
## FLOATING 模式，与玩家 V2 一致
## 无巡逻系统，静止待机直到发现玩家
## ============================================================

# ---------- 信号 ----------
signal died
signal health_changed(new_health: float)

# ---------- 状态枚举 ----------
enum State {
	IDLE,
	CHASE,
	ATTACK,
	COOLDOWN,
	HURT,
	DEAD,
}

# ---------- 移动参数 ----------
@export var chase_speed: float = 100.0
@export var vertical_speed: float = 60.0
@export var attack_range: float = 45.0
@export var attack_damage: float = 10.0

# ---------- 生命参数 ----------
@export var max_health: float = 30.0

# ---------- 受击参数 ----------
@export var hurt_duration: float = 0.3
@export var hurt_knockback: float = 100.0

# ---------- 冷却参数 ----------
@export var cooldown_duration: float = 0.8

# ---------- 可行走边界 ----------
@export var band_left: float = 0.0
@export var band_right: float = 480.0
@export var band_top: float = 140.0
@export var band_bottom: float = 230.0

# ---------- 节点 ----------
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area2D = $AttackArea
@onready var hurtbox: Area2D = $Hurtbox
@onready var vision_area: Area2D = $VisionArea

# ---------- 内部状态 ----------
var current_state: int = State.IDLE
var facing_right: bool = true
var player: CharacterBody2D = null
var current_health: float = 0.0
var previous_state: int = State.IDLE   # 受击后恢复的状态

# 计时器
var hurt_timer: float = 0.0
var hurt_dir: float = -1.0
var cooldown_timer: float = 0.0

# 攻击命中追踪
var hit_targets: Array[Node2D] = []

# ---------- 血条 ----------
var _hp_bar: ProgressBar = null
var _hp_bar_timer: float = 0.0


func _ready() -> void:
	current_health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	velocity = Vector2.ZERO
	anim_player.play("idle")
	_create_hp_bar()


func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO

	match current_state:
		State.IDLE:     _tick_idle()
		State.CHASE:    _tick_chase(delta)
		State.ATTACK:   _tick_attack()
		State.COOLDOWN: _tick_cooldown(delta)
		State.HURT:     _tick_hurt(delta)
		State.DEAD:     pass


# ===================== idle =====================

func _tick_idle() -> void:
	# 看到玩家就追
	if player:
		_switch(State.CHASE)


# ===================== chase =====================

func _tick_chase(delta: float) -> void:
	if not is_instance_valid(player):
		player = null
		_switch(State.IDLE)
		return

	var dist: float = global_position.distance_to(player.global_position)
	if dist < attack_range:
		_switch(State.ATTACK)
		return

	# 追击（直接移动，不用 move_and_slide）
	var dir_x := signf(player.global_position.x - global_position.x)
	var dir_y := signf(player.global_position.y - global_position.y)
	global_position.x += dir_x * chase_speed * delta
	global_position.y += dir_y * vertical_speed * delta
	_clamp()

	# 朝向玩家
	_update_facing(dir_x)
	anim_player.play("walk")


# ===================== attack =====================

func _tick_attack() -> void:
	if anim_player.current_animation != "attack":
		anim_player.play("attack")
		hit_targets.clear()
		attack_area.monitoring = true


# ===================== cooldown =====================

func _tick_cooldown(delta: float) -> void:
	cooldown_timer += delta
	anim_player.play("idle")
	if cooldown_timer >= cooldown_duration:
		cooldown_timer = 0.0
		if player and is_instance_valid(player):
			_switch(State.CHASE)
		else:
			_switch(State.IDLE)


# ===================== hurt =====================

func _tick_hurt(delta: float) -> void:
	hurt_timer += delta
	global_position.x += hurt_dir * hurt_knockback * delta
	_clamp_x()
	if hurt_timer >= hurt_duration:
		hurt_timer = 0.0
		if player and is_instance_valid(player):
			_switch(State.CHASE)
		else:
			_switch(State.IDLE)


# ===================== 状态切换 =====================

func _switch(new_state: int) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			anim_player.play("idle")


# ===================== 受伤系统 =====================

func take_damage(from_position: Vector2, damage_amount: float = 10.0) -> void:
	if current_state == State.DEAD:
		return
	if current_state == State.HURT:
		return

	# 防止负数伤害
	var final_damage := absf(damage_amount)

	# 弹出伤害数字
	_spawn_damage_number(final_damage)

	current_health = maxf(current_health - final_damage, 0.0)
	health_changed.emit(current_health)
	_update_hp_bar()

	if current_health <= 0.0:
		_die()
		return

	# 受击
	hurt_timer = 0.0
	hurt_dir = -1.0 if from_position.x > global_position.x else 1.0
	attack_area.set_deferred("monitoring", false)
	current_state = State.HURT
	anim_player.play("idle")  # 暂无 hurt 动画


func _die() -> void:
	current_state = State.DEAD
	attack_area.set_deferred("monitoring", false)
	anim_player.play("idle")
	died.emit()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


# ===================== 信号回调 =====================

func _on_hurtbox_area_entered(_area: Area2D) -> void:
	"""被玩家攻击框碰到 — 伤害由玩家触发，此处不重复"""
	pass


func _on_attack_area_area_entered(area: Area2D) -> void:
	"""攻击判定碰到了玩家的 Hurtbox"""
	var target: Node2D = area.get_parent()
	# 绝不会打自己
	if target == self:
		return
	if target in hit_targets:
		return
	hit_targets.append(target)
	if target.has_method("take_damage"):
		target.take_damage(global_position, attack_damage)


func _on_vision_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("take_damage"):
		player = body
		if current_state == State.IDLE:
			_switch(State.CHASE)


func _on_vision_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		if current_state == State.CHASE:
			_switch(State.IDLE)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		attack_area.set_deferred("monitoring", false)
		hit_targets.clear()
		_switch(State.COOLDOWN)


# ===================== 工具 =====================

func _update_facing(dir_x: float) -> void:
	if dir_x != 0.0:
		facing_right = dir_x > 0.0
	sprite.flip_h = not facing_right


func get_attack_damage() -> float:
	return attack_damage


func _clamp() -> void:
	global_position.x = clampf(global_position.x, band_left, band_right)
	global_position.y = clampf(global_position.y, band_top, band_bottom)


func _clamp_x() -> void:
	global_position.x = clampf(global_position.x, band_left, band_right)


# ===================== 血条 =====================

func _create_hp_bar() -> void:
	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HPBar"
	_hp_bar.max_value = max_health
	_hp_bar.value = max_health
	_hp_bar.size = Vector2(28, 3)
	_hp_bar.position = Vector2(-14, -22)
	_hp_bar.modulate = Color(0.8, 0.2, 0.2, 1.0)
	_hp_bar.show_percentage = false
	add_child(_hp_bar)
	_hp_bar.hide()


func _update_hp_bar() -> void:
	if not _hp_bar:
		return
	_hp_bar.value = current_health
	_hp_bar.show()
	_hp_bar_timer = 0.0


func _spawn_damage_number(damage: float) -> void:
	var DamageNumberScript := preload("res://scripts/ui/damage_number.gd")
	DamageNumberScript.spawn(get_tree().current_scene, global_position, damage)


func _process(delta: float) -> void:
	# 血条延迟隐藏
	if _hp_bar and _hp_bar.visible:
		_hp_bar_timer += delta
		if _hp_bar_timer >= 1.5:
			_hp_bar.hide()
