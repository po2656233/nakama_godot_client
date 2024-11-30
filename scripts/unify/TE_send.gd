extends TextEdit

signal finished()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 连接 text_changed 信号
	# text_changed.connect(_on_text_changed)
	# 如果你想要在GUI中处理按键事件，设置这个属性为true
	gui_input.connect(_on_gui_input)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



# 方法1：通过 gui_input 信号处理
func _on_gui_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:  # 同时处理主键盘和小键盘的回车
			# print("按下了回车键！ 当前文本：", text)
			# 如果你想阻止回车键创建新行
			get_viewport().set_input_as_handled()
			finished.emit()
	pass


# # 方法3：如果你想在文本变化时检测是否是因为回车键
# func _on_text_changed():
# 	var last_char = text[text.length() - 1] if text.length() > 0 else ""
# 	if last_char == "\n":
# 		finished.emit()
# 		print("检测到回车！")
# 		print("当前文本：", text)