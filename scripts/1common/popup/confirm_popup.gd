extends "res://scripts/1common/popup/base_popup.gd"

## 确认框弹窗
## 用于需要用户确认的操作，比如删除、退出等

@export var confirm_text: String = "确认"  # 确认按钮文本
@export var cancel_text: String = "取消"   # 取消按钮文本

func _ready() -> void:
	super._ready()
	
	# 设置按钮文本和连接信号
	var confirm_button = get_node_or_null("Panel/ButtonContainer/ConfirmButton")  # 修改路径以匹配实际节点路径
	if confirm_button:
		confirm_button.text = confirm_text
		confirm_button.pressed.connect(_on_confirm_pressed)
		
	var cancel_button = get_node_or_null("Panel/ButtonContainer/CancelButton")   # 修改路径以匹配实际节点路径
	if cancel_button:
		cancel_button.text = cancel_text
		cancel_button.pressed.connect(_on_cancel_pressed)

# 重写参数设置方法
func set_params(params: Dictionary) -> void:
	if params.has("confirm_text"):
		confirm_text = params.confirm_text
		var confirm_button = get_node_or_null("Panel/ConfirmButton")
		if confirm_button:
			confirm_button.text = confirm_text
			
	if params.has("cancel_text"):
		cancel_text = params.cancel_text
		var cancel_button = get_node_or_null("Panel/CancelButton")
		if cancel_button:
			cancel_button.text = cancel_text

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER:
			var confirm_button = get_node_or_null("Panel/ButtonContainer/ConfirmButton")  # 修改路径以匹配实际节点路径
			if confirm_button:
				confirm_button.pressed.emit()
				# get_viewport().set_input_as_handled()  # 阻止事件继续传递
		elif event.keycode == KEY_ESCAPE:
			var cancel_button = get_node_or_null("Panel/ButtonContainer/CancelButton")   # 修改路径以匹配实际节点路径
			if cancel_button:
				cancel_button.pressed.emit()
				# get_viewport().set_input_as_handled()  # 阻止事件继续传递
        # 或者使用 accept_event() 也可以
        # event.accept()