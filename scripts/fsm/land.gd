class_name Land
extends State

## 落地硬直状态
##
## 跳跃/空中攻击落地后的短暂硬直
## 硬直时间结束后回到 Idle

var _stiff_timer: float = 0.0

func enter() -> void:
	play_animation("land")
	_stiff_timer = 0.0

func exit() -> void:
	pass

func update(delta: float) -> void:
	_stiff_timer += delta
	var land_stiff_time: float = character.get("land_stiff_time")
	if _stiff_timer >= land_stiff_time:
		change_state("idle")

func handle_input(_event: InputEvent) -> void:
	# 硬直中不可操作
	pass
