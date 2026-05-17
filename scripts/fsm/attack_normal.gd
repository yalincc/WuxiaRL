class_name AttackNormal
extends State

## 地面轻攻击状态
## 播放攻击动画，激活攻击框，动画结束后回到 Idle

var _hitbox: Area2D = null

func enter() -> void:
	play_animation("attack_normal")
	_enable_hitbox()
	# 清除输入缓冲残留
	var input_buffer: InputBuffer = character.get_node("InputBuffer") as InputBuffer
	if input_buffer:
		input_buffer.reset()
	# 连接动画结束信号
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

func exit() -> void:
	_disable_hitbox()
	_clear_hit_targets()

func update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	# 攻击中忽略其他输入
	pass

func _enable_hitbox() -> void:
	_hitbox = character.get_node("HitBoxes/AttackNormal") as Area2D
	if _hitbox:
		_hitbox.monitoring = true
		_hitbox.set_meta("hit_targets", [])

func _disable_hitbox() -> void:
	if _hitbox:
		_hitbox.monitoring = false

func _clear_hit_targets() -> void:
	if _hitbox:
		_hitbox.set_meta("hit_targets", [])

func _on_animation_finished(_anim_name: StringName) -> void:
	change_state("idle")
