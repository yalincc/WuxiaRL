class_name CombatEntity
extends CharacterBody2D

## ============================================================
## 战斗实体基类
##
## 玩家和敌人共享的基础设施：
##   - 生命值系统 (HP / max_health / health_changed / died)
##   - 朝向管理 (facing_right / _update_facing)
##   - 边界钳制 (_clamp / _clamp_x / 自动检测)
##   - 攻击框管理 (enable / disable / 防重复打击)
##   - 伤害数字生成
##
## 子类需要实现：
##   - take_damage()  — 具体受伤逻辑（防御/闪避判定等）
##   - get_attack_damage() — 根据当前状态返回伤害值
##   - _entity_ready() — 额外初始化（可选）
## ============================================================

# ---------- 信号 ----------
signal health_changed(new_health: float)
signal died

# ---------- 生命参数 ----------
@export var max_health: float = 100.0

# ---------- 可行走边界 ----------
@export var band_left: float = 0.0
@export var band_right: float = 0.0
@export var band_top: float = 0.0
@export var band_bottom: float = 0.0

# ---------- 节点引用 ----------
var sprite: Sprite2D
var anim_player: AnimationPlayer
var attack_area: Area2D
var hurtbox: Area2D

# ---------- 内部状态 ----------
var facing_right: bool = true
var current_health: float = 0.0

# --- 攻击命中追踪（防止同一招重复打击同一目标） ---
var _hit_targets: Array[Node2D] = []


# ===================== 初始化 =====================

func _ready() -> void:
	current_health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	velocity = Vector2.ZERO
	_setup_nodes()
	if band_bottom == 0.0:
		_auto_detect_bounds()
	_entity_ready()

## 子类重写此方法做额外初始化（如 add_to_group、创建血条等）
func _entity_ready() -> void:
	pass

func _setup_nodes() -> void:
	sprite = $Sprite2D
	anim_player = $AnimationPlayer
	attack_area = $AttackArea
	hurtbox = $Hurtbox
	# 连接碰撞信号（.tscn 中已有连接的可以被覆盖，此处做兜底）
	if attack_area and not attack_area.area_entered.is_connected(_on_attack_area_area_entered):
		attack_area.area_entered.connect(_on_attack_area_area_entered)
	if hurtbox and not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)


# ===================== 边界检测 =====================

func _auto_detect_bounds() -> void:
	var vp := get_viewport_rect().size
	band_left = 30.0
	band_right = vp.x - 30.0
	band_top = vp.y * 0.65
	band_bottom = vp.y - 40.0
	if global_position.y < band_top or global_position.y > band_bottom:
		global_position.y = (band_top + band_bottom) / 2.0

func _clamp() -> void:
	global_position.x = clampf(global_position.x, band_left, band_right)
	global_position.y = clampf(global_position.y, band_top, band_bottom)

func _clamp_x() -> void:
	global_position.x = clampf(global_position.x, band_left, band_right)


# ===================== 朝向 =====================

func _update_facing(dir_x: float) -> void:
	if dir_x != 0.0:
		facing_right = dir_x > 0.0
	if sprite:
		sprite.flip_h = not facing_right


# ===================== 攻击框管理 =====================

func _enable_attack_area() -> void:
	_hit_targets.clear()
	if attack_area:
		attack_area.monitoring = true

func _disable_attack_area() -> void:
	if attack_area:
		attack_area.set_deferred("monitoring", false)
	_hit_targets.clear()

## 攻击框碰到对方受击框时触发
func _on_attack_area_area_entered(area: Area2D) -> void:
	var target: Node2D = area.get_parent()
	# 防自伤 + 防重复打击
	if target == self or target in _hit_targets:
		return
	_hit_targets.append(target)

	var dmg: float = get_attack_damage()
	if target.has_method("take_damage"):
		target.take_damage(global_position, dmg)

## 被敌方攻击框碰到 — 伤害由攻击方统一处理，此处不重复
func _on_hurtbox_area_entered(_area: Area2D) -> void:
	pass


# ===================== 伤害系统 =====================

## 获取当前攻击伤害（子类根据状态重写）
func get_attack_damage() -> float:
	return 10.0

## 受到伤害（子类实现具体逻辑：防御判定/闪避判定等）
func take_damage(_from_position: Vector2, _damage_amount: float = 10.0) -> void:
	push_warning("CombatEntity.take_damage: should be overridden by subclass")

## 扣除生命值 + 发信号 + 死亡检测
func _apply_damage(amount: float) -> void:
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health)
	if current_health <= 0.0:
		_die()

## 死亡处理（子类可重写扩展）
func _die() -> void:
	died.emit()
	set_physics_process(false)


# ===================== 工具 =====================

## 在当前位置生成伤害数字
func _spawn_damage_number(damage: float, is_critical: bool = false) -> void:
	var DamageNumberScript := preload("res://scripts/ui/damage_number.gd")
	if is_inside_tree():
		DamageNumberScript.spawn(get_tree().current_scene, global_position, damage, is_critical)
