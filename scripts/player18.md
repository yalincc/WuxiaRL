extends CharacterBody2D

## ============================================================
## 街机清版游戏（恐龙快打/三国战纪风格）角色控制器
##
## 移动模型说明：
##   - X 轴：左右自由移动（水平走动）
##   - Y 轴：上下只在可行走带内移动（模拟纵深透视）
##   - 跳跃：纯视觉偏移，不改变 ground_y（落地回到起跳位置）
##   - 攻击：播放动画期间锁定移动
## ============================================================

# ---------- 移动参数 ----------
@export var move_speed: float = 200.0         # 水平移动速度
@export var vertical_speed: float = 100.0     # 上下纵深移动速度（比水平慢，模拟透视）
@export var jump_height: float = 120.0        # 跳跃最大高度（像素）
@export var jump_duration: float = 0.5        # 跳跃总时长（秒）
@export var walk_band_top: float = 0.0        # 可行走带 上边界 Y（场景坐标）
@export var walk_band_bottom: float = 0.0     # 可行走带 下边界 Y（场景坐标）
@export var walk_band_left: float = 0.0       # 可行走带 左边界 X
@export var walk_band_right: float = 0.0      # 可行走带 右边界 X

@onready var anim = $AnimatedSprite2D

# ---------- 状态 ----------
var is_attacking: bool = false
var is_jumping: bool = false
var jump_timer: float = 0.0          # 跳跃计时器
var jump_start_y: float = 0.0        # 起跳时的 ground_y
var facing_right: bool = true        # 朝向

# ---------- 节点引用 ----------
# 可选：通过节点引用获取边界，比手动设 @export 更方便
# 如果场景中有 Area2D 作为可行走区域，可以在这里引用


func _ready() -> void:
	# 如果 @export 边界都是 0，尝试自动计算
	if walk_band_bottom == 0.0:
		_auto_detect_bounds()


func _auto_detect_bounds() -> void:
	"""尝试从场景自动检测可行走区域边界"""
	var vp := get_viewport_rect().size
	# 默认：可行走带占屏幕下半部分约 40%
	walk_band_left = 30.0
	walk_band_right = vp.x - 30.0
	walk_band_top = vp.y * 0.65
	walk_band_bottom = vp.y - 40.0

	# 如果初始位置在边界外，修正初始位置
	if global_position.y < walk_band_top or global_position.y > walk_band_bottom:
		global_position.y = (walk_band_top + walk_band_bottom) / 2.0


func _physics_process(delta: float) -> void:
	# 攻击期间锁定移动
	if is_attacking:
		return

	var dir_x := Input.get_axis("left", "right")
	var dir_y := Input.get_axis("up", "down")

	# ---------- 地面移动 ----------
	if not is_jumping:
		# 水平移动
		global_position.x += dir_x * move_speed * delta
		# 纵深移动（速度比水平慢，模拟透视效果）
		global_position.y += dir_y * vertical_speed * delta

		# 边界约束
		global_position.x = clampf(global_position.x, walk_band_left, walk_band_right)
		global_position.y = clampf(global_position.y, walk_band_top, walk_band_bottom)

		# 跳跃输入
		if Input.is_action_just_pressed("jump"):
			_start_jump()

	# ---------- 跳跃逻辑 ----------
	if is_jumping:
		_update_jump(delta, dir_x)

	# ---------- 攻击 ----------
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_jumping:
		_start_attack()

	# ---------- 朝向 ----------
	if dir_x > 0:
		facing_right = true
	elif dir_x < 0:
		facing_right = false
	anim.flip_h = facing_right

	# ---------- 动画 ----------
	_update_animation(dir_x, dir_y)


# ===================== 跳跃系统 =====================

func _start_jump() -> void:
	"""开始跳跃"""
	is_jumping = true
	jump_timer = 0.0
	jump_start_y = global_position.y   # 记录起跳的地面 Y


func _update_jump(delta: float, dir_x: float) -> void:
	"""
	更新跳跃状态
	使用抛物线公式：offset_y = -4 * jump_height * (t/T) * (t/T - 1)
	这样 t=0 和 t=T 时 offset_y=0，t=T/2 时 offset_y=-jump_height（最高点）
	"""
	jump_timer += delta
	var t := jump_timer / jump_duration   # 归一化时间 0~1

	# 抛物线偏移（负值 = 向上跳）
	var offset_y := 4.0 * jump_height * t * (t - 1.0)
	global_position.y = jump_start_y + offset_y

	# 空中可以左右微调
	global_position.x += dir_x * move_speed * delta

	# X 边界仍然生效
	global_position.x = clampf(global_position.x, walk_band_left, walk_band_right)

	# 落地
	if jump_timer >= jump_duration:
		global_position.y = jump_start_y
		is_jumping = false
		jump_timer = 0.0


# ===================== 攻击系统 =====================

func _start_attack() -> void:
	"""开始攻击"""
	is_attacking = true
	anim.play("attack")
	await anim.animation_finished
	is_attacking = false


# ===================== 动画 =====================

func _update_animation(dir_x: float, dir_y: float) -> void:
	"""更新动画状态"""
	if is_attacking:
		return   # 攻击动画由 _start_attack 控制

	if is_jumping:
		anim.play("jump")
	elif dir_x != 0.0 or dir_y != 0.0:
		anim.play("run")
	else:
		anim.play("idle")
