class_name AirDownAttack
extends State

## 空中下落攻击状态
##
## 快速向下穿刺，命中敌人或到达地面后进入 Land
## 全程无敌（HurtBox 忽略此状态）

var _hitbox: Area2D = null
var _hit_something: bool = false
var _jump_start_y: float = 0.0

func enter() -> void:
	play_animation("air_down_attack")
	_hit_something = false
	_jump_start_y = character.get("_jump_start_y", character.global_position.y)
	_enable_hitbox()
	var input_buffer: InputBuffer = character.get_node("InputBuffer") as InputBuffer
	if input_buffer:
		input_buffer.reset()

func exit() -> void:
	_disable_hitbox()

func update(delta: float) -> void:
	var dir_x := Input.get_axis("left", "right")
	var fall_speed: float = character.get("fall_attack_speed")

	# 快速向下
	character.global_position.y += fall_speed * delta

	# 少量水平漂移
	if dir_x != 0.0:
		var walk_speed: float = character.get("walk_speed")
		character.global_position.x += dir_x * walk_speed * 0.3 * delta
	_clamp_x()

	# 到达起跳 Y 位置 → 落地
	if character.global_position.y >= _jump_start_y:
		character.global_position.y = _jump_start_y
		change_state("land")

func _clamp_x() -> void:
	var left: float = character.get("band_left")
	var right: float = character.get("band_right")
	character.global_position.x = clampf(character.global_position.x, left, right)

func _enable_hitbox() -> void:
	_hitbox = character.get_node("HitBoxes/AirDownAttack") as Area2D
	if _hitbox:
		_hitbox.monitoring = true
		_hitbox.set_meta("hit_targets", [])

func _disable_hitbox() -> void:
	if _hitbox:
		_hitbox.monitoring = false
