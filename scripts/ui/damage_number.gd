extends Label

## 伤害数字弹出
##
## 受击时实例化，上浮 + 淡出后自销毁
## 直接从 damage_number.tscn 实例化或使用静态 spawn() 方法

const FLOAT_SPEED: float = 40.0
const FADE_DURATION: float = 0.6

var _lifetime: float = 0.0

func _ready() -> void:
	position.x += randf_range(-8.0, 8.0)

func _process(delta: float) -> void:
	_lifetime += delta
	position.y -= FLOAT_SPEED * delta
	var t := _lifetime / FADE_DURATION
	modulate.a = clampf(1.0 - t, 0.0, 1.0)
	scale = Vector2.ONE * (1.0 + t * 0.3)
	if _lifetime >= FADE_DURATION:
		queue_free()

## 在受击位置生成伤害数字
## [param world] 添加到世界场景
## [param pos] 全局位置
## [param damage] 伤害值
## [param is_critical] 是否暴击
static func spawn(world: Node, pos: Vector2, damage: float, is_critical: bool = false) -> void:
	var scene := preload("res://scenes/ui/damage_number.tscn")
	var instance: Label = scene.instantiate()
	instance.text = str(int(damage))
	if is_critical:
		instance.add_theme_color_override("font_color", Color.YELLOW)
		instance.text += "!"
		instance.scale = Vector2.ONE * 1.4
	else:
		instance.add_theme_color_override("font_color", Color.WHITE)

	world.add_child(instance)
	instance.global_position = pos
