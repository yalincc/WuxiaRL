class_name Move
extends State

## 地面行走状态（慢速）
## 持续检测方向输入，支持转为 Run / Idle / 攻击等

var _input_buffer: InputBuffer = null

func enter() -> void:
	play_animation("walk")
	_connect_input()

func exit() -> void:
	_disconnect_input()

func update(delta: float) -> void:
	var dir_x := Input.get_axis("left", "right")
	var dir_y := Input.get_axis("up", "down")

	# 无方向 → Idle
	if dir_x == 0.0 and dir_y == 0.0:
		change_state("idle")
		return

	# 奔跑键 + 水平方向 → Run
	if Input.is_action_pressed("run") and dir_x != 0.0:
		change_state("run")
		return

	# 移动
	var walk_speed: float = character.get("walk_speed")
	var vertical_speed: float = character.get("vertical_speed")
	character.global_position.x += dir_x * walk_speed * delta
	character.global_position.y += dir_y * vertical_speed * delta
	_clamp_position()

	# 朝向
	_update_facing(dir_x)

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		change_state("jump")
	elif event.is_action_pressed("roll"):
		change_state("dodge")
	elif event.is_action_pressed("defend"):
		change_state("defense")

func _connect_input() -> void:
	if not _input_buffer:
		_input_buffer = character.get_node("InputBuffer") as InputBuffer
	if _input_buffer:
		if not _input_buffer.light_attack_requested.is_connected(_on_light_attack):
			_input_buffer.light_attack_requested.connect(_on_light_attack)
		if not _input_buffer.skill_requested.is_connected(_on_skill):
			_input_buffer.skill_requested.connect(_on_skill)

func _disconnect_input() -> void:
	if _input_buffer:
		if _input_buffer.light_attack_requested.is_connected(_on_light_attack):
			_input_buffer.light_attack_requested.disconnect(_on_light_attack)
		if _input_buffer.skill_requested.is_connected(_on_skill):
			_input_buffer.skill_requested.disconnect(_on_skill)

func _on_light_attack() -> void:
	change_state("attack_normal")

func _on_skill() -> void:
	change_state("attack_skill")

func _clamp_position() -> void:
	var band_left: float = character.get("band_left")
	var band_right: float = character.get("band_right")
	var band_top: float = character.get("band_top")
	var band_bottom: float = character.get("band_bottom")
	character.global_position.x = clampf(character.global_position.x, band_left, band_right)
	character.global_position.y = clampf(character.global_position.y, band_top, band_bottom)

func _update_facing(dir_x: float) -> void:
	if dir_x != 0.0:
		character.set("facing_right", dir_x > 0.0)
		var sprite: Sprite2D = character.get_node("Sprite2D")
		if sprite:
			sprite.flip_h = not character.get("facing_right")
