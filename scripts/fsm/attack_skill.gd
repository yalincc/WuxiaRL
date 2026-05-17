class_name AttackSkill
extends State

## 地面技能攻击状态（长按触发）
## 播放技能动画，激活技能攻击框，动画结束后回到 Idle

var _hitbox: Area2D = null

func enter() -> void:
	play_animation("attack_skill")
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
	pass

func _enable_hitbox() -> void:
	_hitbox = character.get_node("HitBoxes/AttackSkill") as Area2D
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
