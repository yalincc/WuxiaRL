extends CharacterBody2D

## ============================================================
## 街机清版游戏 敌人控制器
##
## 状态机：IDLE → CHASE → ATTACK → COOLDOWN → CHASE
##         任何状态 → HURT → 回到之前的状态
##         HP归零 → DEAD
## 碰撞层：Hurtbox(layer=6) 接受玩家攻击
##          AttackArea(layer=4) 检测玩家受击区
## ============================================================

# ---------- 信号 ----------
signal died

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
@export var walk_speed: float = 80.0
@export var chase_speed: float = 120.0
@export var attack_range: float = 50.0
@export var attack_damage: float = 10.0

# ---------- 生命参数 ----------
@export var max_health: float = 30.0

# ---------- 受击参数 ----------
@export var hurt_duration: float = 0.3
@export var hurt_knockback: float = 100.0

# ---------- 冷却参数 ----------
@export var cooldown_duration: float = 0.8

# ---------- 巡逻参数 ----------
@export var patrol_range: float = 80.0
@export var idle_wait_time: float = 2.0

# ---------- 节点 ----------
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area2D = $AttackArea
@onready var hurtbox: Area2D = $Hurtbox
@onready var vision_area: Area2D = $VisionArea

# ---------- 内部状态 ----------
var current_state: State = State.IDLE
var facing_right: bool = true
var player: CharacterBody2D = null
var current_health: float = 0.0

# 计时器
var hurt_timer: float = 0.0
var hurt_dir: float = -1.0
var cooldown_timer: float = 0.0
var idle_timer: float = 0.0

# 巡逻
var patrol_start_pos: Vector2 = Vector2.ZERO
var patrol_direction: int = 1

# 攻击命中追踪（防止同一招重复打）
var hit_targets: Array[Node2D] = []


func _ready() -> void:
	current_health = max_health
	patrol_start_pos = global_position
	anim_player.play("idle")


func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:     _tick_idle(delta)
		State.CHASE:    _tick_chase(delta)
		State.ATTACK:   _tick_attack()
		State.COOLDOWN: _tick_cooldown(delta)
		State.HURT:     _tick_hurt(delta)
		State.DEAD:     pass


# ===================== idle =====================

func _tick_idle(delta: float) -> void:
	# 看到玩家就追
	if player:
		_switch(State.CHASE)
		return
	# 等一会儿再巡逻
	idle_timer += delta
	if idle_timer >= idle_wait_time:
		idle_timer = 0.0
		_start_patrol_walk()


func _start_patrol_walk() -> void:
	# 巡逻：走一段路
	var distance_from_start: float = global_position.x - patrol_start_pos.x
	if absf(distance_from_start) > patrol_range:
		patrol_direction *= -1
	var target_x: float = patrol_start_pos.x + patrol_direction * patrol_range * 0.5
	var dir: float = signf(target_x - global_position.x)
	if dir == 0.0:
		dir = 1.0
	velocity.x = dir * walk_speed
	move_and_slide()
	_update_facing(velocity.x)
	anim_player.play("walk")


# ===================== chase =====================

func _tick_chase(_delta: float) -> void:
	if not is_instance_valid(player):
		player = null
		_switch(State.IDLE)
		return

	var dist: float = global_position.distance_to(player.global_position)
	# 进入攻击范围
	if dist < attack_range:
		_switch(State.ATTACK)
		return

	# 追击
	var dir_x: float = signf(player.global_position.x - global_position.x)
	velocity.x = dir_x * chase_speed
	# Y 轴追击（街机清版的纵深移动）
	var dir_y: float = signf(player.global_position.y - global_position.y)
	velocity.y = dir_y * chase_speed * 0.5
	move_and_slide()
	_update_facing(velocity.x)
	anim_player.play("walk")


# ===================== attack =====================

func _tick_attack() -> void:
	# 攻击状态：播动画，Hitbox 由动画关键帧或代码开启
	if anim_player.current_animation != "attack":
		anim_player.play("attack")
		hit_targets.clear()
		# 启用攻击判定
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
	# 击退
	global_position.x += hurt_dir * hurt_knockback * delta
	if hurt_timer >= hurt_duration:
		hurt_timer = 0.0
		if player and is_instance_valid(player):
			_switch(State.CHASE)
		else:
			_switch(State.IDLE)


# ===================== 状态切换 =====================

func _switch(new_state: State) -> void:
	current_state = new_state
	# 进入新状态时重置速度
	velocity = Vector2.ZERO
	match new_state:
		State.IDLE:
			anim_player.play("idle")
			idle_timer = 0.0


# ===================== 受伤（外部调用 / Hurtbox 信号） =====================

func take_damage(from_position: Vector2, damage_amount: float = 10.0) -> void:
	if current_state == State.DEAD:
		return
	if current_state == State.HURT:
		return

	current_health = maxf(current_health - damage_amount, 0.0)
	if current_health <= 0.0:
		_die()
		return

	hurt_timer = 0.0
	hurt_dir = -1.0 if from_position.x > global_position.x else 1.0
	# 攻击中被断招
	attack_area.monitoring = false
	current_state = State.HURT
	anim_player.play("idle")  # 暂无 hurt 动画


func _die() -> void:
	current_state = State.DEAD
	attack_area.monitoring = false
	anim_player.play("idle")
	died.emit()
	# 简单的死亡效果：闪烁后移除
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


# ===================== Hurtbox 信号回调 =====================

func _on_hurtbox_area_entered(_area: Area2D) -> void:
	"""被玩家的 AttackArea 碰到 — 伤害由玩家 _on_attack_area_area_entered 统一处理，此处不重复"""
	pass


# ===================== AttackArea 信号回调 =====================

func _on_attack_area_area_entered(area: Area2D) -> void:
	"""攻击判定碰到了玩家的 Hurtbox"""
	var target: Node2D = area.get_parent()
	if target in hit_targets:
		return  # 不重复打击
	hit_targets.append(target)
	# 调用玩家的受伤方法
	if target.has_method("take_damage"):
		target.take_damage(global_position, attack_damage)


# ===================== VisionArea 信号回调 =====================

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


# ===================== 动画结束回调 =====================

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		attack_area.monitoring = false
		hit_targets.clear()
		_switch(State.COOLDOWN)


# ===================== 工具 =====================

func _update_facing(vel_x: float) -> void:
	if vel_x > 0.0:
		facing_right = true
	elif vel_x < 0.0:
		facing_right = false
	sprite.flip_h = !facing_right


func get_attack_damage() -> float:
	"""供外部查询当前攻击伤害值"""
	return attack_damage
