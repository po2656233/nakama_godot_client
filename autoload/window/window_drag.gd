extends Node

# 单例配置
var dragging := false
var drag_offset := Vector2i()
var drag_zones: Array[Control] = []
var drag_zones_but: Array[Control] = []
var stopMove := false

func _ready():
	var os_name = OS.get_name()
	var is_windows = os_name == "Windows"
	if is_windows:
		# Windows下默认窗口模式
		get_window().mode = Window.MODE_WINDOWED
	else:
		# 其他平台始终全屏
		get_window().mode = Window.MODE_FULLSCREEN
	setup_fullscreen_window()
	drag_zones_but.clear()

func setup_fullscreen_window():
	# 设置窗口为无边框模式
	get_window().borderless = true
	# 设置窗口为独占模式
	get_window().exclusive = true

func _on_normal_screen():
	get_window().mode = Window.MODE_WINDOWED
	SignalMgr.NormalWindowSIG.emit()

func _on_full_screen():
	get_window().mode = Window.MODE_FULLSCREEN
	SignalMgr.FullWindowSIG.emit()

func _input(event: InputEvent) -> void:
	var os_name = OS.get_name()
	var is_windows = os_name == "Windows"
	if not is_windows:
		# 非Windows平台不开放拖拽和切换，始终全屏
		return

	# Windows下允许拖拽和全屏/窗口切换
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
				for zone in drag_zones:
					if zone.get_global_rect() && zone.get_global_rect().has_point(mouse_pos):
						if event.double_click:
							toggle_fullscreen()
							get_viewport().set_input_as_handled()
							return
						if get_window().mode == Window.MODE_WINDOWED:
							var global_mouse_pos = Vector2i(DisplayServer.mouse_get_position())
							var window_pos = DisplayServer.window_get_position()
							drag_offset = global_mouse_pos - window_pos
							dragging = true
						break
			else:
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		if get_window().mode != Window.MODE_WINDOWED:
			return
		var new_position = Vector2i(DisplayServer.mouse_get_position()) - drag_offset
		DisplayServer.window_set_position(new_position)
	# Windows下允许F11/ESC切换全屏
	if event is InputEventKey:
		if event.keycode == KEY_ENTER and event.alt_pressed:
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F11:
			_on_full_screen()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			_on_normal_screen()
			get_viewport().set_input_as_handled()

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
		_on_normal_screen()
	else:
		# 进入全屏
		_on_full_screen()
