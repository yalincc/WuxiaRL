class_name Jump
extends State

## 跳跃状态（空中上升/下落）
## 使用抛物线模拟跳跃，记录起跳时的水平速度
## 来自 Run 的跳跃拥有更大水平速度
## 将计时信息存储在 character 上，供 AirAttack/AirDownAttack 读取

var _jump_timer: float = 0.0
var _jump_start_y: float = 0.0
var _jump_h_speed: float = 0.0
var _came_from_run: bool = false

func enter() -> void:
	play_animation("jump")
	_jump_timer = 0.0
	_jump_start_y = character.global_position.y

	# 记录起跳水平速度
	var walk_speed: float = character.get("walk_speed")
	var run_speed: float = character.get("run_speed")
	_came_from_run = Input.is_action_pressed("run")
	if _came_from_run:
		var mult: float = character.get("run_jump_horizontal_mult")
		var dir_x := Input.get_axis("left", "right")
		_jump_h_speed = run_speed * mult * (1.0 if dir_x != 0.0 else 0.0)
	else:
		_jump_h_speed = walk_speed

	# 写入 character，供后续状态读取
	character.set("_jump_timer", _jump_timer)
	character.set("_jump_start_y", _jump_start_y)
	character.set("_jump_h_speed", _jump_h_speed)

func _save_jump_state() -> void:
	character.set("_jump_timer", _jump_timer)
	character.set("_jump_start_y", _jump_start_y)
	character.set("_jump_h_speed", _jump_h_speed)

func update(delta: float) -> void:
	var dir_x := Input.get_axis("left", "right")

	# 空中按攻击键
	if Input.is_action_just_pressed("attack"):
		var dir_y := Input.get_axis("up", "down")
		if dir_y > 0.0:
			change_state("air_down_attack")
		else:
			_save_jump_state()
			change_state("air_attack")
		return

	# 抛物线运动
	_jump_timer += delta
	var jump_duration: float = character.get("jump_duration")
	var jump_height: float = character.get("jump_height")
	var t := _jump_timer / jump_duration
	var offset_y := 4.0 * jump_height * t * (t - 1.0)
	character.global_position.y = _jump_start_y + offset_y

	# X 轴微调
	character.global_position.x += dir_x * _jump_h_speed * delta
	_clamp_x()

	# 朝向
	if dir_x != 0.0:
		_update_facing(dir_x)

	# 跳跃结束 → 落地
	if _jump_timer >= jump_duration:
		character.global_position.y = _jump_start_y
		change_state("land")

func _clamp_x() -> void:
	var left: float = character.get("band_left")
	var right: float = character.get("band_right")
	character.global_position.x = clampf(character.global_position.x, left, right)

func _update_facing(dir_x: float) -> void:
	character.set("facing_right", dir_x > 0.0)
	var sprite_node: Sprite2D = character.get_node("Sprite2D")
	if sprite_node:
		sprite_node.flip_h = not character.get("facing_right")
