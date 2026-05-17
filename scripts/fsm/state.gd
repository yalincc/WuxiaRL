class_name State
extends Node

## 有限状态机基类
## 每个具体状态继承此类，实现 enter/exit/update/handle_input

var character: CharacterBody2D:
	get: return state_machine.character
var state_machine: StateMachine
var animation_player: AnimationPlayer:
	get: return character.get_node("AnimationPlayer") if character else null

## 进入状态时调用（播放动画、重置计时器、连接信号等）
func enter() -> void:
	pass

## 退出状态时调用（断开信号、清理临时数据等）
func exit() -> void:
	pass

## 每帧物理更新（delta 为 _physics_process 的 delta）
func update(_delta: float) -> void:
	pass

## 输入事件处理（_unhandled_input 传入）
func handle_input(_event: InputEvent) -> void:
	pass

## 播放动画的便捷方法
func play_animation(name: String) -> void:
	if animation_player and animation_player.has_animation(name):
		animation_player.play(name)

## 获取当前状态名称（小写，对应转换表中的目标状态名）
func get_state_name() -> String:
	return name.to_lower()

## 通过 state_machine 切换状态
func change_state(state_name: String) -> void:
	state_machine.change_state(state_name)
