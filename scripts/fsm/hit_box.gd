class_name HitBox
extends Area2D

## 攻击框脚本
##
## 每个 HitBox 绑定一个固定的攻击类型
## 自动追踪已命中目标，防止同一招重复打击同一敌人

## 所属攻击帧的类型名称（用于查询伤害）
@export var attack_type: String = "normal"

## 当前这一帧已命中的目标列表
var hit_targets: Array[Node2D] = []

## 引用角色主脚本
var _player = null

func _ready() -> void:
	# 向上查找角色
	_player = _find_player(self)
	if _player:
		area_entered.connect(_on_enemy_hurtbox_entered)
	monitoring = false  # 默认关闭

## 向上查找 CharacterBody2D
func _find_player(node: Node) -> Node:
	if node is CharacterBody2D:
		return node
	if node.get_parent():
		return _find_player(node.get_parent())
	return null

## 当 HitBox 进入敌人的 HurtBox 时
func _on_enemy_hurtbox_entered(hurtbox: Area2D) -> void:
	if not _player:
		return

	var target: Node2D = hurtbox.get_parent()
	# 排除自身
	if target == _player:
		return
	# 防止重复打击
	if target in hit_targets:
		return
	# 确保目标是敌人（有 take_damage 方法）
	if not target.has_method("take_damage"):
		return

	hit_targets.append(target)

	# 获取当前攻击的伤害值
	var damage: float = _player.get_attack_damage()
	if damage <= 0.0:
		return

	target.take_damage(_player.global_position, damage)

## 在所属状态 enter 时调用
func activate() -> void:
	hit_targets.clear()
	monitoring = true

## 在所属状态 exit 时调用
func deactivate() -> void:
	monitoring = false
	hit_targets.clear()
