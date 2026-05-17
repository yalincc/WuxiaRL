class_name StateMachine
extends Node

## 有限状态机管理器
## 管理所有 State 子节点的注册与切换

var states: Dictionary = {}       # key: state_name_lower, value: State
var current_state: State = null
var character: CharacterBody2D = null
var previous_state_name: String = ""  # 记住上一个状态名，供伤害系统查询

## 初始化：收集所有 State 子节点，设定 character 引用
func _ready() -> void:
	character = get_parent() as CharacterBody2D
	if not character:
		push_error("StateMachine: parent must be a CharacterBody2D")
		return

	# 递归收集所有 State 子节点
	for child in _collect_states(self):
		var key: String = child.get_state_name()
		if states.has(key):
			push_warning("StateMachine: duplicate state name '%s' - using last found" % key)
		states[key] = child
		child.state_machine = self
		child.set_process(false)      # 状态节点自身不处理 _process
		child.set_physics_process(false)

	# 默认进入第一个注册的状态
	if states.size() > 0:
		var first_key: String = states.keys()[0]
		change_state(first_key)

## 递归收集 State 节点
func _collect_states(node: Node) -> Array[State]:
	var result: Array[State] = []
	for child in node.get_children():
		if child is State:
			result.append(child)
		elif child.get_child_count() > 0:
			result.append_array(_collect_states(child))
	return result

## 切换状态
## [param state_name] - 目标状态名（大小写不敏感，自动转小写匹配）
func change_state(state_name: String) -> void:
	var key: String = state_name.to_lower()
	if not states.has(key):
		push_error("StateMachine: unknown state '%s'" % state_name)
		return

	var new_state: State = states[key]
	if current_state == new_state:
		return

	if current_state:
		previous_state_name = current_state.get_state_name()
		current_state.exit()

	current_state = new_state
	current_state.enter()

## 物理帧更新：委托给当前状态
func _physics_process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

## 输入事件：委托给当前状态
func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

## 获取当前状态名
func get_current_state_name() -> String:
	return current_state.get_state_name() if current_state else ""

## 检查当前是否处于某个状态
func is_in_state(state_name: String) -> bool:
	return current_state and current_state.get_state_name() == state_name.to_lower()
