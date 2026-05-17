class_name InputBuffer
extends Node

## 输入缓冲系统（长短按判定）
##
## 监听攻击键的按下/释放时间差，区分轻攻击（短按）和技能（长按）
## 发出两个信号供状态机中的"可接收输入"状态（Idle/Move/Run）连接

signal light_attack_requested    # 轻攻击（短按释放）
signal skill_requested           # 技能（长按触发）

## 长按阈值（秒），超过此值视为长按技能
@export var long_press_threshold: float = 0.25

var _attack_pressed_time: float = 0.0
var _attack_held: bool = false
var _attack_triggered: bool = false

## 每帧检查长按状态
func _physics_process(_delta: float) -> void:
	if _attack_held and not _attack_triggered:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _attack_pressed_time >= long_press_threshold:
			_attack_triggered = true
			skill_requested.emit()

## 处理输入事件
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_attack_pressed_time = Time.get_ticks_msec() / 1000.0
		_attack_held = true
		_attack_triggered = false

	if event.is_action_released("attack"):
		if _attack_held and not _attack_triggered:
			# 短按释放 → 轻攻击
			light_attack_requested.emit()
		_attack_held = false

## 重置输入缓冲（用于状态切换时清除累积状态）
func reset() -> void:
	_attack_held = false
	_attack_triggered = false
	_attack_pressed_time = 0.0
