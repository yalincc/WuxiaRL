class_name HitStun
extends State

## 受击硬直状态
##
## 受到攻击后进入，播放受击动画并受击退
## 硬直时间结束后回到 Idle

var _stun_timer: float = 0.0
var _knockback_dir: float = 1.0

func enter() -> void:
	play_animation("hit_stun")
	_stun_timer = 0.0
	# 获取击退方向（由 take_damage 设置）
	_knockback_dir = character.get("_hit_knockback_dir")

func exit() -> void:
	pass

func update(delta: float) -> void:
	_stun_timer += delta

	# 击退
	var hurt_knockback: float = character.get("hurt_knockback")
	character.global_position.x += _knockback_dir * hurt_knockback * delta
	_clamp_x()

	# 硬直结束
	var hitstun_time: float = character.get("hitstun_time")
	if _stun_timer >= hitstun_time:
		change_state("idle")

func handle_input(_event: InputEvent) -> void:
	# 硬直中不可操作
	pass

func _clamp_x() -> void:
	var band_left: float = character.get("band_left")
	var band_right: float = character.get("band_right")
	character.global_position.x = clampf(character.global_position.x, band_left, band_right)
