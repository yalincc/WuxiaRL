class_name AirAttack
extends State

## 空中轻攻击状态
##
## 读取 Jump 状态保存的跳跃参数继续抛物线下落
## 激活空中攻击框，落地后进入 Land

var _hitbox: Area2D = null
var _elapsed: float = 0.0
var _jump_start_y: float = 0.0
var _jump_h_speed: float = 0.0

func enter() -> void:
	play_animation("air_attack")
	_elapsed = character.get("_jump_timer")
	_jump_start_y = character.get("_jump_start_y")
	_jump_h_speed = character.get("_jump_h_speed")

	_enable_hitbox()
	var input_buffer: InputBuffer = character.get_node("InputBuffer") as InputBuffer
	if input_buffer:
		input_buffer.reset()

func exit() -> void:
	_disable_hitbox()

func update(delta: float) -> void:
	var dir_x := Input.get_axis("left", "right")
	_elapsed += delta

	var jump_duration: float = character.get("jump_duration")
	var jump_height: float = character.get("jump_height")
	var t := _elapsed / jump_duration
	var offset_y := 4.0 * jump_height * t * (t - 1.0)
	character.global_position.y = _jump_start_y + offset_y

	# X 轴微调
	character.global_position.x += dir_x * _jump_h_speed * delta
	_clamp_x()

	if dir_x != 0.0:
		character.set("facing_right", dir_x > 0.0)
		var sprite_node: Sprite2D = character.get_node("Sprite2D")
		if sprite_node:
			sprite_node.flip_h = not character.get("facing_right")

	# 落地
	if _elapsed >= jump_duration:
		character.global_position.y = _jump_start_y
		change_state("land")

func _clamp_x() -> void:
	var left: float = character.get("band_left")
	var right: float = character.get("band_right")
	character.global_position.x = clampf(character.global_position.x, left, right)

func _enable_hitbox() -> void:
	_hitbox = character.get_node("HitBoxes/AirAttack") as Area2D
	if _hitbox:
		_hitbox.monitoring = true
		_hitbox.set_meta("hit_targets", [])

func _disable_hitbox() -> void:
	if _hitbox:
		_hitbox.monitoring = false
