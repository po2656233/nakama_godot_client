extends Node

# 单例配置
var dragging := false
var drag_offset := Vector2i()
var drag_zones: Array[Control] = []
var drag_zones_but: Array[Control] = []
var stopMove := false

func _ready():
	# 确保窗口全屏并禁止缩放
	setup_fullscreen_window()
	drag_zones_but.clear()

func setup_fullscreen_window():
	# 设置窗口为全屏模式
	get_window().mode = Window.MODE_FULLSCREEN
	
	# 设置窗口为无边框模式
	get_window().borderless = true
	
	# 设置窗口为独占模式（在某些系统上可以防止其他窗口覆盖）
	get_window().exclusive = true
	
	# 监听窗口大小变化事件
	get_window().size_changed.connect(_on_window_size_changed)
	
	# 监听窗口焦点变化事件
	get_window().focus_entered.connect(_on_window_focus_entered)

func _on_window_size_changed():
	# 如果窗口大小发生变化，重新设置为全屏
	if get_window().mode != Window.MODE_FULLSCREEN:
		get_window().mode = Window.MODE_FULLSCREEN

func _on_window_focus_entered():
	# 当窗口获得焦点时，确保保持全屏状态
	if get_window().mode != Window.MODE_FULLSCREEN:
		get_window().mode = Window.MODE_FULLSCREEN

func _input(event: InputEvent) -> void:
	# 检测操作系统
	var os_name = OS.get_name()
	var is_windows = os_name == "Windows"
	var is_mac = os_name == "macOS"
	
	# 在Windows和Mac环境下允许双击全屏，其他环境禁止
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			if is_windows or is_mac:
				# Windows和Mac环境下允许双击全屏
				toggle_fullscreen()
			else:
				# 其他环境下阻止双击事件
				get_viewport().set_input_as_handled()
			return
	
	# 禁止Alt+Enter切换全屏（在所有环境下）
	if event is InputEventKey:
		if event.keycode == KEY_ENTER and event.alt_pressed:
			# 阻止Alt+Enter事件
			get_viewport().set_input_as_handled()
			return
	
	# 禁止F11切换全屏（在所有环境下）
	if event is InputEventKey:
		if event.keycode == KEY_F11:
			# 阻止F11事件
			get_viewport().set_input_as_handled()
			return
	
	# 禁止ESC键退出全屏（在所有环境下）
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		# 阻止ESC键事件
		get_viewport().set_input_as_handled()
		return
	
	# 获取鼠标位置
	var mouse_pos = get_viewport().get_mouse_position()
	if stopMove:
		drag_offset = Vector2i()
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				for zone in drag_zones_but:
					if zone.get_global_rect() && zone.get_global_rect().has_point(mouse_pos):
						return
					pass
				# 检查是否在拖动区域内
				for zone in drag_zones:
					if zone.get_global_rect() && zone.get_global_rect().has_point(mouse_pos):
						# 在全屏模式下不处理拖动
						if get_window().mode == Window.MODE_FULLSCREEN:
							return
						# 单击：开始拖动
						var global_mouse_pos = Vector2i(DisplayServer.mouse_get_position())
						var window_pos = DisplayServer.window_get_position()
						drag_offset = global_mouse_pos - window_pos
						dragging = true
						break
			else:
				# 停止拖动
				dragging = false
	
	elif event is InputEventMouseMotion and dragging:
		# 如果窗口全屏，不处理拖动
		if get_window().mode == Window.MODE_FULLSCREEN:
			return
		# 实时更新窗口位置
		var new_position = Vector2i(DisplayServer.mouse_get_position()) - drag_offset
		DisplayServer.window_set_position(new_position)

# 注册一个控件作为拖动区域
func register_drag_zone(control: Control) -> void:
	if not drag_zones.has(control):
		drag_zones.append(control)
		# 监听控件的销毁信号，以便自动移除
		control.tree_exiting.connect(func(): drag_zones.erase(control))

# 取消注册拖动区域
func unregister_drag_zone(control: Control) -> void:
	drag_zones_but.append(control)
	control.tree_exiting.connect(func(): drag_zones_but.erase(control))

# 切换全屏状态
func toggle_fullscreen() -> void:
	if get_window().mode == Window.MODE_FULLSCREEN:
		# 退出全屏
		get_window().mode = Window.MODE_WINDOWED
	else:
		# 进入全屏
		get_window().mode = Window.MODE_FULLSCREEN
