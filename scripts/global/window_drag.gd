extends Node

# 单例配置
var dragging := false
var drag_offset := Vector2i()
var drag_zones: Array[Control] = []

# 双击检测
var last_click_time := 0.0
const DOUBLE_CLICK_TIME := 0.3  # 双击时间阈值（秒）

func _ready():
	# 确保窗口是无边框的
	if not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

func _input(event: InputEvent) -> void:
	# 获取鼠标位置
	var mouse_pos = get_viewport().get_mouse_position()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 检查是否在拖动区域内
				for zone in drag_zones:
					if zone.get_global_rect() && zone.get_global_rect().has_point(mouse_pos):
						# 检查是否是双击
						var current_time = Time.get_ticks_msec() / 1000.0
						if current_time - last_click_time < DOUBLE_CLICK_TIME:
							# 双击：切换最大化状态
							toggle_maximize()
							last_click_time = 0.0  # 重置点击时间
						else:
							# 单击：开始拖动
							var global_mouse_pos = Vector2i(DisplayServer.mouse_get_position())
							var window_pos = DisplayServer.window_get_position()
							drag_offset = global_mouse_pos - window_pos
							dragging = true
							last_click_time = current_time
						break
			else:
				# 停止拖动
				dragging = false
	
	elif event is InputEventMouseMotion and dragging:
		# 如果窗口最大化，不处理拖动
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			return
		# 实时更新窗口位置
		var new_position = Vector2i(DisplayServer.mouse_get_position()) - drag_offset
		DisplayServer.window_set_position(new_position)

# 切换最大化状态
func toggle_maximize() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		# 还原窗口
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		# 最大化窗口
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# 注册一个控件作为拖动区域
func register_drag_zone(control: Control) -> void:
	if not drag_zones.has(control):
		drag_zones.append(control)
		# 监听控件的销毁信号，以便自动移除
		control.tree_exiting.connect(func(): unregister_drag_zone(control))

# 取消注册拖动区域
func unregister_drag_zone(control: Control) -> void:
	drag_zones.erase(control)
