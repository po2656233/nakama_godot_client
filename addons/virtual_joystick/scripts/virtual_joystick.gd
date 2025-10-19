@tool
extends Node2D

signal analogic_change(move: Vector2)
signal analogic_just_pressed
signal analogic_released

@export_group("Joystick mapping")
## 左方向
@export var action_left := "ui_left"
## 右方向
@export var action_right := "ui_right"
## 向上方向
@export var action_up := "ui_up"
## 向下方向
@export var action_down := "ui_down"
## 选择
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

func _process(delta: float) -> void:
	if ongoing_drag == -1:
		var pos_difference = (Vector2.ZERO - radius) - touch.position
		touch.position += pos_difference * return_accel * delta * 2
		
		

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
				
				touch.texture_normal = stick_pressed
				
				if zero_at_touch:
					global_position = event.position
			
			touch.global_position = event.position - radius * global_scale
			
			if get_button_pos().length() > boundary:
				touch.position = get_button_pos().normalized() * boundary - radius

			ongoing_drag = event.get_index()
			if normalized:
				analogic_change.emit(get_value())
			else:
				analogic_change.emit(get_value() * min(get_button_pos().length() / boundary, 1))
				
			# 只有当启用了joystick_area_only且事件确实在摇杆区域内时，才标记事件为已处理
			if joystick_area_only and is_in_joystick_area:
				get_viewport().set_input_as_handled()
					
		elif event is InputEventScreenTouch and not event.is_pressed() and event.get_index() == ongoing_drag:
			ongoing_drag = -1
			analogic_change.emit(Vector2.ZERO)
			global_position = default_global_position
			is_pressed = false
			touch.texture_normal = stick if is_instance_valid(stick) else preload("res://addons/virtual_joystick/sprites/stick.png")
			
			# 释放摇杆控制的所有动作
			if _has_action(action_left) and Input.is_action_pressed(action_left):
				Input.action_release(action_left)
			if _has_action(action_right) and Input.is_action_pressed(action_right):
				Input.action_release(action_right)
			if _has_action(action_up) and Input.is_action_pressed(action_up):
				Input.action_release(action_up)
			if _has_action(action_down) and Input.is_action_pressed(action_down):
				Input.action_release(action_down)
			if _has_action(action_accept) and Input.is_action_pressed(action_accept):
				Input.action_release(action_accept)
			
			# 只有当启用了joystick_area_only时，才标记事件为已处理
			if joystick_area_only and is_in_joystick_area:
				get_viewport().set_input_as_handled()

func get_button_pos() -> Vector2:
	return touch.position + radius
	
func get_value() -> Vector2:
	if get_button_pos().length() > threshold:
		return get_button_pos().normalized()
		
	return Vector2.ZERO

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
	if _has_action(action_accept) and Input.is_action_pressed(action_accept) and dir.y <= 0.3:
		Input.action_release(action_accept)	
		
	# 根据摇杆位置触发方向输入
	if dir.x < -0.3 and _has_action(action_left):
		Input.action_press(action_left, -dir.x)
	if dir.x > 0.3 and _has_action(action_right):
		Input.action_press(action_right, dir.x)
	if dir.y < -0.3 and _has_action(action_up):
		Input.action_press(action_up, -dir.y)
	if dir.y > 0.3 and _has_action(action_down):
		Input.action_press(action_down, dir.y)

# 新增：在文件末尾或合适位置添加此辅助函数
func _has_action(name: String) -> bool:
	return name != null and name != "" and InputMap.has_action(name)
