class_name Idle
extends State

## 地面待机状态
## 接收输入缓冲信号，处理方向输入 → Move/Run

var _input_buffer: InputBuffer = null

func enter() -> void:
	play_animation("idle")
	_connect_input()

func exit() -> void:
	_disconnect_input()

func update(_delta: float) -> void:
	# 检测方向输入 → Move
	var dir_x := Input.get_axis("left", "right")
	var dir_y := Input.get_axis("up", "down")
	if dir_x != 0.0 or dir_y != 0.0:
		if Input.is_action_pressed("run") and dir_x != 0.0:
			change_state("run")
		else:
			change_state("move")

func handle_input(event: InputEvent) -> void:
	# 直接处理的按键（不通过输入缓冲）
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
