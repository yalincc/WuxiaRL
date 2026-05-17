class_name DefenseCounter
extends State

## 防反反击状态
##
## 完美防御后的自动反击攻击，播放防反动画
## 动画结束后回到 Idle，期间完全无敌（HurtBox 忽略此状态）

var _hitbox: Area2D = null

func enter() -> void:
	play_animation("defense_counter")
	_enable_hitbox()
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

func exit() -> void:
	_disable_hitbox()

func update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	# 无敌状态，忽略一切输入
	pass

func _enable_hitbox() -> void:
	_hitbox = character.get_node("HitBoxes/DefenseCounter") as Area2D
	if _hitbox:
		_hitbox.monitoring = true
		_hitbox.set_meta("hit_targets", [])

func _disable_hitbox() -> void:
	if _hitbox:
		_hitbox.monitoring = false

func _on_animation_finished(_anim_name: StringName) -> void:
	change_state("idle")
