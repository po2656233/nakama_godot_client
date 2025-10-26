@tool
extends Node2D
# 摇杆方向变化信号
signal analogic_change(move: Vector2)
# 摇杆按下信号
signal analogic_just_pressed
# 摇杆释放信号
signal analogic_released
# 摇杆强度变化信号
signal analogic_strength_change(strength: float)

@export_group("Joystick mapping")
## 左方向
@export var action_left := "ui_left"
## 右方向
@export var action_right := "ui_right"
## 向上方向
@export var action_up := "ui_up"
## 向下方向
@export var action_down := "ui_down"
## 确认/接受动作
@export var action_accept := "ui_accept"


@export_group("Settings")
@export var normalized: bool = true
@export var zero_at_touch: bool = false
## 是否只处理摇杆区域内的触摸事件，启用此选项可同时操作摇杆和按钮
@export var joystick_area_only: bool = true

@export_group("Sprites")
@export var border: Texture2D:
	set(value):
		border = value
		_draw()
		
@export var stick: Texture2D:
	set(value):
		stick = value
		_draw()

@export var stick_pressed: Texture2D

var joystick = Sprite2D.new()
var touch = TouchScreenButton.new()
var radius := Vector2(32, 32)
var boundary := 64
var ongoing_drag := -1
var return_accel := 20
var threshold := 0
var is_pressed = false
# 按下后若未发生方向变化则可能触发 accept（点按）
var accept_candidate := false
# 点按判定移动阈值（超过视为有方向变化，取消 accept）
var accept_move_threshold := 0.3

# 存储每个触摸点的开始时间和初始位置
var active_touches = {}  # 格式: {index: {"start_time": time, "start_position": position}}
# 当前主要触摸点的压力值
var current_pressure = 1.0
# 最大按压时间（毫秒），超过此时间压力值达到最大1.0
var max_press_duration := 2000

@onready var default_global_position = global_position


func _draw() -> void:	
	if get_child_count() == 0:
		add_child(joystick)
		
	if joystick.get_child_count() == 0:
		joystick.add_child(touch)	
		
	joystick.texture = border if is_instance_valid(border) else preload("res://addons/virtual_joystick/sprites/joystick.png")
	touch.texture_normal = stick if is_instance_valid(stick) else preload("res://addons/virtual_joystick/sprites/stick.png")


func _ready() -> void:	
	touch.position = -radius
	touch.released.connect(analogic_released.emit)

	
	
	if stick_pressed == null:
		stick_pressed = preload("res://addons/virtual_joystick/sprites/stick_pressed.png")
	analogic_change.connect(change_direction)

# 更新 更新压力显示（可根据需要修改为其他反馈方式）
func _process(delta: float) -> void:
	if ongoing_drag == -1:
		var pos_difference = (Vector2.ZERO - radius) - touch.position
		if not pos_difference.is_zero_approx():
			touch.position += pos_difference * return_accel * delta * 2
	
	if current_pressure == 0.0:
		return

	# 如果没有活动的触摸，压力为0
	if not active_touches or active_touches.is_empty()  :
		if current_pressure != 0.0:
			current_pressure = 0.0
			analogic_strength_change.emit(current_pressure)
			# _update_pressure_display(current_pressure)
		return
	
	# 计算所有活动触摸点的压力，取最大值作为当前压力
	var max_pressure = 0.0
	var current_time = Time.get_ticks_msec()
	
	for index in active_touches:
		var touch_data = active_touches[index]
		var press_duration = current_time - touch_data["start_time"]
		
		# 根据按压时间计算压力值
		var pressure = clamp(press_duration / float(max_press_duration), 0.0, 1.0)
		# var pressure = _calculate_pressure_curve(press_duration / float(max_press_duration))
		if pressure > max_pressure:
			max_pressure = pressure
		pass
	
	# 更新当前压力值
	if current_pressure != max_pressure:
		current_pressure = max_pressure * delta
		analogic_strength_change.emit(current_pressure)
		# _update_pressure_display(current_pressure)
	pass

# 输入处理
func _input(event: InputEvent) -> void:
	# 只处理触摸和拖动事件
	if not (event is InputEventScreenDrag or event is InputEventScreenTouch ):
		return
	
	var event_dist_from_center = (event.position - global_position).length()
	var is_in_joystick_area = event_dist_from_center <= boundary * global_scale.x
	
	# 当事件在摇杆区域内或者是正在进行的摇杆拖动
	if is_in_joystick_area or event.get_index() == ongoing_drag:
		if event is InputEventScreenDrag or (event is InputEventScreenTouch and event.is_pressed()):
			if !is_pressed:
				is_pressed = true
				emit_signal("analogic_just_pressed")
				# 新：点按候选，在按下后如果不发生显著移动则视为点按
				accept_candidate = true
				touch.texture_normal = stick_pressed
				if zero_at_touch:
					global_position = event.position
			
			touch.global_position = event.position - radius * global_scale
			if get_button_pos().length() > boundary:
				touch.position = get_button_pos().normalized() * boundary - radius

			ongoing_drag = event.get_index()
			# InputEventScreenDrag 仍支持 pressure（4.5 中 ScreenTouch 已移除）
			current_pressure = 1.0  # 默认压力为最大值
			if event is InputEventScreenDrag:
				current_pressure = clamp(event.pressure, 0.0, 1.0)
				analogic_strength_change.emit(current_pressure)
			elif event is InputEventMouseMotion:
				current_pressure = clamp(event.pressure, 0.0, 1.0)
				analogic_strength_change.emit(current_pressure)
			else: 
				# 记录触摸开始的时间和位置 模拟按压强度
				active_touches[event.index] = {
					"start_time": Time.get_ticks_msec(),
					#"start_position": event.position
				}
			var emitted_value = get_value() if normalized else get_value() * current_pressure
			analogic_change.emit(emitted_value)
			
			# 只有当启用了joystick_area_only且事件确实在摇杆区域内时，才标记事件为已处理
			if joystick_area_only and is_in_joystick_area:
				get_viewport().set_input_as_handled()

		elif event is InputEventScreenTouch and not event.is_pressed() and event.get_index() == ongoing_drag:
			ongoing_drag = -1
			analogic_change.emit(Vector2.ZERO)
			analogic_strength_change.emit(0.0)
			global_position = default_global_position
			is_pressed = false
			touch.texture_normal = stick if is_instance_valid(stick) else preload("res://addons/virtual_joystick/sprites/stick.png")
			# 触摸结束，移除该触摸点的记录
			active_touches.erase(event.index)

			# 如果按下后没有发生方向变化，则视为点按，触发一次 accept（瞬时 press+release）
			if accept_candidate and _has_action(action_accept):
				# 使用最后记录的 pressure（若设备支持）或基于距离的强度作为 accept 的强度
				Input.action_press(action_accept, 1.0)
				Input.action_release(action_accept)
			accept_candidate = false
			
			# 释放摇杆控制的所有动作
			if _has_action(action_left) and Input.is_action_pressed(action_left):
				Input.action_release(action_left)
			if _has_action(action_right) and Input.is_action_pressed(action_right):
				Input.action_release(action_right)
			if _has_action(action_up) and Input.is_action_pressed(action_up):
				Input.action_release(action_up)
			if _has_action(action_down) and Input.is_action_pressed(action_down):
				Input.action_release(action_down)

			# 确保方向发生时不会保留 accept 状态
			if _has_action(action_accept) and Input.is_action_pressed(action_accept):
				Input.action_release(action_accept)

			# 只有当启用了joystick_area_only时，才标记事件为已处理
			if joystick_area_only and is_in_joystick_area:
				get_viewport().set_input_as_handled()
	# 处理拖拽事件，更新位置信息
	#if event is InputEventScreenDrag:
		#if active_touches.has(event.index):
			#active_touches[event.index]["start_position"] = event.position
	pass
	
func get_button_pos() -> Vector2:
	return touch.position + radius
	
func get_value() -> Vector2:
	if get_button_pos().length() > threshold:
		return get_button_pos().normalized()
		
	return Vector2.ZERO
	
func get_strength() -> float:
	# 返回 0.0-1.0 的按压强度（基于按钮到中心的距离 / 边界）
	return clamp(get_button_pos().length() / boundary, 0.0, 1.0)

func change_direction(dir_joystick: Vector2):
	var dir = dir_joystick
	# 释放之前的方向输入
	if _has_action(action_left) and Input.is_action_pressed(action_left) and dir.x >= -0.3:
		Input.action_release(action_left)
	if _has_action(action_right) and Input.is_action_pressed(action_right) and dir.x <= 0.3:
		Input.action_release(action_right)
	if _has_action(action_up) and Input.is_action_pressed(action_up) and dir.y >= -0.3:
		Input.action_release(action_up)
	if _has_action(action_down) and Input.is_action_pressed(action_down) and dir.y <= 0.3:
		Input.action_release(action_down)
	# if _has_action(action_accept) and Input.is_action_pressed(action_accept) and dir.y <= 0.3:
	# 	Input.action_release(action_accept)	
		
	# 任何明显的方向变化都取消点按候选（accept）
	if dir.length() > accept_move_threshold:
		accept_candidate = false
		# 如果 accept 被误按下，立即释放（互斥）
		if _has_action(action_accept) and Input.is_action_pressed(action_accept):
			Input.action_release(action_accept)
		
	# 根据摇杆位置触发方向输入
	if dir.x < -0.3 and _has_action(action_left):
		Input.action_press(action_left, -dir.x)
		# print("[VirtualJoystick] direction=",action_left)
		
	if dir.x > 0.3 and _has_action(action_right):
		Input.action_press(action_right, dir.x)
		# print("[VirtualJoystick] direction=",action_right)

	if dir.y < -0.3 and _has_action(action_up):
		Input.action_press(action_up, -dir.y)
		# print("[VirtualJoystick] direction=",action_up)

	if dir.y > 0.3 and _has_action(action_down):
		Input.action_press(action_down, dir.y)
		# print("[VirtualJoystick] direction=",action_down)

# 新增：在文件末尾或合适位置添加此辅助函数
func _has_action(name: String) -> bool:
	return name != null and name != "" and InputMap.has_action(name)
