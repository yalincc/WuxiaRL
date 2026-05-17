extends CanvasLayer

## 玩家 HUD
## 显示玩家生命值条和数值，放在屏幕左上角

@onready var hp_bar: ProgressBar = $HBoxContainer/Panel/VBoxContainer/HPBar
@onready var hp_label: Label = $HBoxContainer/Panel/VBoxContainer/HPLabel

var _player: CharacterBody2D = null
var _connected: bool = false

func _ready() -> void:
	# 延迟一帧等待场景完全加载
	await get_tree().process_frame
	_find_player_and_connect()

func _find_player_and_connect() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player and not _connected:
		if _player.has_signal("health_changed"):
			_player.health_changed.connect(_on_player_health_changed)
			_connected = true
			# 立即刷新显示
			var cur_hp: float = _player.get("current_health")
			_on_player_health_changed(cur_hp)
		else:
			push_warning("PlayerHUD: player has no health_changed signal")
	elif not _player:
		# 还没找到，下帧再试
		await get_tree().process_frame
		_find_player_and_connect()

func _on_player_health_changed(new_health: float) -> void:
	if not _player:
		return
	var max_hp: float = _player.get("max_health")
	hp_bar.max_value = max_hp
	hp_bar.value = new_health
	hp_label.text = "HP: %d/%d" % [new_health, max_hp]

	# 低血量变色
	if new_health <= max_hp * 0.3:
		hp_bar.modulate = Color.RED
	elif new_health <= max_hp * 0.6:
		hp_bar.modulate = Color.YELLOW
	else:
		hp_bar.modulate = Color.WHITE
