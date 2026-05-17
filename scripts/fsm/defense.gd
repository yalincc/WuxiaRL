class_name Defense
extends State

## 防御状态
##
## 功能：
## 1. 按住防御键持续防御
## 2. 进入后 counter_window(0.15s) 为"防反窗口"：受击时触发 DefenseCounter
## 3. 超过防反窗口后受击：伤害减免 80%
## 4. 松开防御键 → Idle
## 5. 按闪避键 → Dodge（取消防御）

var _enter_time: float = 0.0

func enter() -> void:
	play_animation("defense")
	_enter_time = Time.get_ticks_msec() / 1000.0

func exit() -> void:
	pass

func update(_delta: float) -> void:
	# 松开防御键 → Idle
	if not Input.is_action_pressed("defend"):
		change_state("idle")

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("roll"):
		change_state("dodge")

## 由 HurtBox 调用：防御状态下受到攻击
## [param damage] 原始伤害值
## [param from_position] 攻击来源位置
func receive_hit(damage: float, from_position: Vector2) -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _enter_time
	var counter_window: float = character.get("counter_window")

	if elapsed <= counter_window:
		# 防反窗口内 → 触发防御反击
		change_state("defense_counter")
	else:
		# 普通防御：减伤 80%
		var reduction: float = character.get("defense_damage_reduction")
		var reduced_damage: float = damage * (1.0 - reduction)
		if character.has_method("apply_damage"):
			character.apply_damage(reduced_damage)
		# 小幅后退
		var knockback_dir: float = -1.0 if from_position.x > character.global_position.x else 1.0
		var knockback_force: float = character.get("hurt_knockback")
		var left: float = character.get("band_left")
		var right: float = character.get("band_right")
		character.global_position.x += knockback_dir * knockback_force * 0.3
		character.global_position.x = clampf(character.global_position.x, left, right)
