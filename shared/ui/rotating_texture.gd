extends Control

@onready var texture_rect = $CenterContainer/TextureRect

var is_dragging = false
var drag_start_position = Vector2.ZERO
var current_rotation = 0.0
var target_rotation = 0.0
var rotation_speed = 0.0
var drag_sensitivity = 0.005  # 降低拖动灵敏度，使控制更精确
var auto_rotate_speed = 3.0   # 调整自动旋转速度
var slow_rotate_speed = 8.0   # 增加跟随速度，使拖动更丝滑
var damping = 0.98           # 添加阻尼系数

func _ready():
	texture_rect.gui_input.connect(_on_texture_rect_gui_input)
	# 设置较小的初始旋转速度
	rotation_speed = 0.5
	# 设置3D变换原点为左边缘
	texture_rect.set_pivot_offset(Vector2.ZERO)
	# 启用3D变换
	texture_rect.material = ShaderMaterial.new()
	texture_rect.material.shader = preload("res://shared/styles/shaders/rotate_around_axis.gdshader")
	texture_rect.material.set_shader_parameter("rotation", 0.0)

func _on_texture_rect_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			if is_dragging:
				drag_start_position = event.position
				rotation_speed = 0.0
			else:
				# 根据拖动速度设置旋转速度，添加平滑处理
				var drag_distance = event.position.x - drag_start_position.x
				rotation_speed = drag_distance * drag_sensitivity
				# 限制最大速度
				rotation_speed = clamp(rotation_speed, -2.0, 2.0)
				
	elif event is InputEventMouseMotion and is_dragging:
		var drag_distance = event.position.x - drag_start_position.x
		target_rotation = current_rotation + drag_distance * drag_sensitivity

func _process(delta):
	if is_dragging:
		# 使用插值实现更平滑的跟随
		current_rotation = lerp(current_rotation, target_rotation, delta * slow_rotate_speed)
	else:
		# 应用阻尼和平滑过渡
		current_rotation += rotation_speed * delta * auto_rotate_speed
		rotation_speed *= damping
		
		# 当速度很小时，平滑过渡到基础速度
		if abs(rotation_speed) < 0.1:
			rotation_speed = lerp(rotation_speed, 0.5, delta * 2.0)
	
	# 更新shader中的旋转参数，添加平滑插值
	var current_shader_rotation = texture_rect.material.get_shader_parameter("rotation")
	var target_shader_rotation = current_rotation
	var smoothed_rotation = lerp(current_shader_rotation, target_shader_rotation, delta * 10.0)
	texture_rect.material.set_shader_parameter("rotation", smoothed_rotation)
	
	# 保持旋转值在合理范围内
	if current_rotation > PI * 2:
		current_rotation -= PI * 2
	elif current_rotation < -PI * 2:
		current_rotation += PI * 2
