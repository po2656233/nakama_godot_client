extends Label

@export var rise_speed: float = 200.0
@export var total_distance: float = 400.0

var current_time: float = 0.0
var start_y: float = 0.0
var center_y: float = 0.0
var target_y: float = 0.0

func _ready():
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	modulate.a = 0
	# 确保锚点设置正确
	set_anchors_preset(Control.PRESET_CENTER)
	# 监听窗口大小变化
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	# 初始化位置
	_update_position()

func _update_position():
	# 获取视口大小
	var viewport_size = get_viewport_rect().size
	# 设置位置为视口中心
	position = Vector2(
		viewport_size.x / 2 - size.x / 2,
		viewport_size.y / 2 - size.y / 2
	)

func _on_viewport_size_changed():
	# 窗口大小改变时更新位置
	_update_position()

func start_animation():
	current_time = 0.0
	modulate.a = 0
	# 计算起始位置和目标位置
	var viewport_size = get_viewport_rect().size
	center_y = viewport_size.y / 2
	start_y = center_y + total_distance / 2
	target_y = center_y - total_distance / 2
	position.y = start_y
	position.x = viewport_size.x / 2 - size.x / 2  # 保持水平居中
	show()

func _process(delta):
	if not visible:
		return
		
	# 计算新位置
	position.y -= rise_speed * delta
	
	# 计算与中心的距离来控制透明度
	var distance_from_center = abs(position.y - center_y)
	var max_distance = total_distance / 2
	var opacity = 1.0 - (distance_from_center / max_distance)
	opacity = clamp(opacity, 0.0, 1.0)
	modulate.a = opacity
	
	# 当到达目标位置时隐藏
	if position.y <= target_y:
		hide()
		# 重置位置为中心
		_update_position()

func display_text(text1: String):
	self.text = text1
	# 更新大小后重新计算位置
	await get_tree().process_frame
	_update_position()
	start_animation()

func set_speed(new_speed: float):
	rise_speed = new_speed

func get_speed() -> float:
	return rise_speed
