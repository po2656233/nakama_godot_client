extends Label

@onready var popup_menu := PopupMenu.new()
var last_click_time := 0.0
var double_click_threshold := 0.3  # 双击时间阈值（秒）

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	add_child(popup_menu)
	popup_menu.add_item("复制账号")
	popup_menu.id_pressed.connect(func(_id): _copy_text())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			popup_menu.popup(Rect2(get_global_mouse_position(), Vector2.ONE))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_click_time < double_click_threshold:
				_copy_text()
			last_click_time = now
		elif event.double_click:
			_copy_text()

func _copy_text() -> void:
	DisplayServer.clipboard_set(text)
	PopupManager.show_message("已复制账号")
	print("已复制文本：", text)
