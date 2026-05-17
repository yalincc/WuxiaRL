class_name HurtBox
extends Area2D

## 受击框脚本
##
## 当检测到敌方攻击框（enemy_hit, layer 4）进入时，根据角色当前状态分流处理：
##   - Defense  → 调用防御状态的受击处理
##   - Dodge    → 调用闪避状态的完美闪避检测
##   - DefenseCounter / HitStun → 忽略（已无敌/已受击）
##   - 其他     → 正常受伤，调用 player.take_damage(from_position, damage)

var _state_machine: StateMachine = null
var _player: CharacterBody2D = null

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player:
		_state_machine = _player.get_node("StateMachine") as StateMachine
	area_entered.connect(_on_hitbox_entered)

## 敌方攻击框进入时调用
func _on_hitbox_entered(hitbox: Area2D) -> void:
	if not _state_machine or not _player:
		return

	var attack_damage: float = _extract_damage(hitbox)
	if attack_damage <= 0.0:
		return

	var current_state_name: String = _state_machine.get_current_state_name()
	var from_position: Vector2 = hitbox.global_position

	match current_state_name:
		"defense":
			_route_to_defense(attack_damage, from_position)
		"dodge":
			_route_to_dodge(attack_damage)
		"defense_counter", "hit_stun":
			# 无敌或已受击，忽略
			pass
		_:
			# 正常受伤
			_take_normal_damage(attack_damage, from_position)

## 从攻击框提取伤害值
func _extract_damage(hitbox: Area2D) -> float:
	var parent: Node = hitbox.get_parent()
	if parent and parent.has_method("get_attack_damage"):
		return parent.get_attack_damage()
	if hitbox.has_meta("damage"):
		return hitbox.get_meta("damage")
	return 10.0  # 默认伤害

## 路由到防御状态
func _route_to_defense(damage: float, from_position: Vector2) -> void:
	var defense_state: State = _state_machine.states.get("defense")
	if defense_state and defense_state.has_method("receive_hit"):
		defense_state.receive_hit(damage, from_position)

## 路由到闪避状态
func _route_to_dodge(damage: float) -> void:
	var dodge_state: State = _state_machine.states.get("dodge")
	if dodge_state and dodge_state.has_method("check_perfect_evasion"):
		dodge_state.check_perfect_evasion(damage)

## 正常受伤处理
func _take_normal_damage(damage: float, from_position: Vector2) -> void:
	if _player and _player.has_method("take_damage"):
		_player.take_damage(from_position, damage)
