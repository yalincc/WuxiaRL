extends CombatEntity

## ============================================================
## 街机清版游戏 敌人控制器 V2
##
## 状态机：IDLE → CHASE → ATTACK(含Telegraph) → COOLDOWN → CHASE
##         任何状态 → HURT → 回到之前状态
##         HP归零 → DEAD
##
## P1 新增：
##   - Telegraph 攻击预警 (前摇可见 → 玩家反应窗口)
##   - 原型参数系统 (MINION/ELITE/BOSS/RANGED 一键切换)
##   - 韧性/霸体 + 冲击等级响应
## ============================================================

# ---------- 敌人原型 ----------
enum Archetype { MINION, ELITE, BOSS, RANGED }

# ---------- 状态枚举 ----------
enum State {
	IDLE,
	CHASE,
	ATTACK,     # 包含 Telegraph + Active 两阶段
	COOLDOWN,
	HURT,
	DEAD,
}

# ===================== 原型参数 =====================
## 敌人类型：杂兵/精英/Boss/远程
@export var archetype: Archetype = Archetype.MINION

# ===================== 移动参数 =====================
@export var chase_speed: float = 100.0
@export var vertical_speed: float = 60.0
@export var attack_range: float = 45.0

# ===================== 攻击参数 =====================
@export var attack_damage: float = 10.0
@export var attack_poise_damage: float = 10.0       # 削韧值
@export var attack_impact_level: int = 1             # 冲击等级 0-4

# ===================== Telegraph 参数 =====================
## 攻击预警时间（秒），敌人攻击前的可见前摇
@export var telegraph_duration: float = 0.2

# ===================== 受击参数 =====================
@export var hurt_duration: float = 0.3
@export var hurt_knockback: float = 100.0

# ===================== 冷却参数 =====================
@export var cooldown_duration: float = 0.8

# ---------- 内部状态 ----------
var current_state: int = State.IDLE
var player: CharacterBody2D = null

# 计时器
var hurt_timer: float = 0.0
var hurt_dir: float = -1.0
var cooldown_timer: float = 0.0
var _attack_timer: float = 0.0
var _attack_active: bool = false

# ---------- 节点 ----------
@onready var vision_area: Area2D = $VisionArea

# ---------- 血条 ----------
var _hp_bar: ProgressBar = null
var _hp_bar_timer: float = 0.0


# ===================== 初始化 =====================

func _entity_ready() -> void:
	anim_player.play("idle")
	_create_hp_bar()


# ===================== 主循环 =====================

func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO

	# 血条延迟隐藏
	_update_hp_bar_timer(delta)

	match current_state:
		State.IDLE:     _tick_idle()
		State.CHASE:    _tick_chase(delta)
		State.ATTACK:   _tick_attack(delta)
		State.COOLDOWN: _tick_cooldown(delta)
		State.HURT:     _tick_hurt(delta)
		State.DEAD:     pass


# ===================== idle =====================

func _tick_idle() -> void:
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

	var dir_x := signf(player.global_position.x - global_position.x)
	var dir_y := signf(player.global_position.y - global_position.y)
	global_position.x += dir_x * chase_speed * delta
	global_position.y += dir_y * vertical_speed * delta
	_clamp()

	_update_facing(dir_x)
	anim_player.play("walk")


# ===================== attack (Telegraph + Active) =====================

func _tick_attack(delta: float) -> void:
	_attack_timer += delta

	# --- Telegraph 阶段：播放预警，攻击框尚未激活 ---
	if _attack_timer < telegraph_duration:
		if anim_player.current_animation != "idle":
			anim_player.play("idle")
		_show_telegraph_warning()
		return

	# --- Active 阶段：激活攻击框 ---
	if not _attack_active:
		_attack_active = true
		anim_player.play("attack")
		_enable_attack_area()


## 攻击预警视觉效果
func _show_telegraph_warning() -> void:
	# 简单的闪烁警告：敌人身体忽明忽暗
	var t := sin(_attack_timer * 20.0) * 0.3 + 0.7  # 快速闪烁
	if sprite:
		sprite.modulate = Color(1.0, t, t, 1.0)


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
		State.ATTACK:
			_attack_timer = 0.0
			_attack_active = false
		State.CHASE:
			# 恢复精灵颜色（清除 telegraph 闪烁残留）
			if sprite:
				sprite.modulate = Color.WHITE


# ===================== 受伤系统 =====================

func take_damage(from_position: Vector2, damage_amount: float = 10.0, poise_damage: float = 10.0, impact_level: int = 1) -> void:
	if current_state == State.DEAD:
		return
	if current_state == State.HURT:
		return

	var final_damage := absf(damage_amount)
	_spawn_damage_number(final_damage)

	# 1. 韧性判定
	var staggered := _apply_poise_damage(poise_damage)
	# 2. 扣血
	_apply_damage(final_damage)
	_update_hp_bar()

	if current_health <= 0.0:
		return  # _die() 由 _apply_damage 自动调用

	# 3. 受击反应
	if staggered:
		_enter_hurt(from_position, impact_level)
	# 霸体中：不硬直，只扣血（精英/Boss 不会被打断）


## 进入受击硬直状态
func _enter_hurt(from_position: Vector2, impact_level: int) -> void:
	hurt_timer = 0.0
	hurt_dir = -1.0 if from_position.x > global_position.x else 1.0

	# 根据冲击等级调整硬直时长和击退距离
	match impact_level:
		0:  # 无反应（不应出现，staggered=true保证至少Level1）
			hurt_duration = 0.15
			hurt_knockback = 30.0
		1:  # 轻击退
			hurt_duration = 0.3
			hurt_knockback = 100.0
		2:  # 重击退
			hurt_duration = 0.45
			hurt_knockback = 200.0
		3:  # 击飞
			hurt_duration = 0.6
			hurt_knockback = 300.0
		_:  # Level 4: 击倒
			hurt_duration = 0.8
			hurt_knockback = 250.0

	_disable_attack_area()
	_attack_active = false
	current_state = State.HURT
	anim_player.play("idle")  # 暂无 hurt 动画


# ===================== 死亡 =====================

func _die() -> void:
	current_state = State.DEAD
	_disable_attack_area()
	anim_player.play("idle")
	super._die()
	# 淡出后移除
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


# ===================== 攻击属性查询 =====================

func get_attack_damage() -> float:
	return attack_damage

func get_poise_damage() -> float:
	return attack_poise_damage

func get_impact_level() -> int:
	return attack_impact_level


# ===================== 信号回调 =====================

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
		_disable_attack_area()
		_attack_active = false
		_switch(State.COOLDOWN)


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

	# Boss 血条更大
	if archetype == Archetype.BOSS:
		_hp_bar.size = Vector2(48, 6)
		_hp_bar.position = Vector2(-24, -28)


func _update_hp_bar() -> void:
	if not _hp_bar:
		return
	_hp_bar.value = current_health
	_hp_bar.show()
	_hp_bar_timer = 0.0


func _update_hp_bar_timer(delta: float) -> void:
	if _hp_bar and _hp_bar.visible:
		_hp_bar_timer += delta
		if _hp_bar_timer >= 2.0:  # Boss 血条显示更久
			_hp_bar.hide()
