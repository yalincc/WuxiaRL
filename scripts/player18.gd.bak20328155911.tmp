extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var anim = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# 施加重力
	if not is_on_floor():
		velocity += get_gravity() * delta
		anim.animation = "jump"     # 空中 -> 跳跃动画
	elif velocity.x != 0:
		anim.animation = "run"      # 地上移动 -> 跑步动画
	else:
		anim.animation = "idle"     # 地上静止 -> 待机动画
	
	if velocity.x != 0:
		anim.flip_h = velocity.x > 0
		
	# 处理跳跃
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 获取输入方向并处理移动/减速
	# 良好实践：你应该将 UI 动作替换为自定义游戏动作。
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
