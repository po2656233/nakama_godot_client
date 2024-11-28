extends "res://scripts/unify/base_popup.gd"

## 消息提示弹窗
## 用于显示简单的消息提示，支持自动关闭

## 消息提示弹窗
## 用于显示简单的消息提示，支持自动关闭

@export var close_button_path: NodePath = "Panel/CloseButton"  # 关闭按钮路径

func _ready() -> void:
	super._ready()
	# 默认2秒后自动关闭
	auto_close = true
	close_delay = 2.0
	
	# 连接关闭按钮信号
	var close_button = get_node_or_null(close_button_path)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	else:
		push_warning("Close button not found at path: " + str(close_button_path))

func _on_close_button_pressed() -> void:
	close()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		close()
		get_viewport().set_input_as_handled()  # 阻止事件继续传递
		# 或者使用 accept_event() 也可以
		# event.accept()
