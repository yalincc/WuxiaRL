class_name Dodge
extends State

## 闪避（翻滚）状态
##
## 功能：
## 1. 全程无敌（HurtBox 会路由到此状态检查）
## 2. 前 0.12 秒为"完美闪避"窗口：受击时标记完美闪避
## 3. 翻滚结束后回到 Idle

var _dodge_timer: float = 0.0
var _dodge_dir: float = 1.0
var _perfect_evasion: bool = false

func enter() -> void:
	play_animation("dodge")
	_dodge_timer = 0.0
	_perfect_evasion = false

	# 闪避方向
	var dir_x := Input.get_axis("left", "right")
	if dir_x != 0.0:
		_dodge_dir = dir_x
	else:
		_dodge_dir = 1.0 if character.get("facing_right") else -1.0

func exit() -> void:
	pass

func update(delta: float) -> void:
	_dodge_timer += delta

	# 翻滚移动
	var dodge_speed: float = character.get("dodge_speed")
	character.global_position.x += _dodge_dir * dodge_speed * delta
	_clamp_x()

	# 翻滚结束
	var dodge_duration: float = character.get("dodge_duration")
	if _dodge_timer >= dodge_duration:
		change_state("idle")

func handle_input(_event: InputEvent) -> void:
	# 翻滚中忽略一切输入
	pass

## 由 HurtBox 调用：翻滚中受到攻击
## 检查是否在完美闪避窗口内
func check_perfect_evasion(_damage: float) -> void:
	var perfect_window: float = character.get("dodge_perfect_window")
	if _dodge_timer <= perfect_window and not _perfect_evasion:
		_perfect_evasion = true
		# 触发完美闪避效果（可由外部扩展）
		_on_perfect_evasion()
	# 普通无敌：直接忽略伤害

func _on_perfect_evasion() -> void:
	# 标记角色属性，供后续系统使用
	character.set("perfect_evasion_triggered", true)
	# 可在此添加特效播放

func _clamp_x() -> void:
	var band_left: float = character.get("band_left")
	var band_right: float = character.get("band_right")
	character.global_position.x = clampf(character.global_position.x, band_left, band_right)
