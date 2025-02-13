extends Control

## 基础弹窗类，所有弹窗都应该继承这个类

# 信号定义
signal confirmed
signal canceled
signal closed

# 导出变量
@export var auto_close: bool = false  # 是否自动关闭
@export var close_delay: float = 1.5  # 自动关闭延迟时间(秒)
@export var show_animation: bool = true  # 是否显示动画
@export var animation_duration: float = 0.4  # 动画持续时间

# 内部变量
var _title: String = ""
var _message: String = ""
var _tween: Tween
var _panel: Panel
var isFinish: bool = true

# 初始化函数
func _ready() -> void:
	# 设置初始布局
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# 获取面板引用
	_panel = get_node_or_null("Panel")
	isFinish = true
	# 设置初始状态
	if show_animation:
		modulate.a = 0
		_show_with_animation()
	else:
		modulate.a = 1
		
	if auto_close:
		get_tree().create_timer(close_delay).timeout.connect(close)

func set_title(title: String) -> void:
	isFinish = false
	_title = title
	var title_label = get_node_or_null("Panel/Title")
	if title_label:
		title_label.text = title

func set_message(message: String) -> void:
	isFinish = false
	_message = message
	var message_label = get_node_or_null("Panel/Message")
	if message_label:
		message_label.text = message
	else:
		print("Message label not found.")
	var clossBtn = get_node_or_null("Panel/CloseButton")
	if clossBtn:
		clossBtn.visible = false if auto_close else true
	else:
		print("Close button not found.")

func close() -> void:
	isFinish = true
	if show_animation:
		_close_with_animation()
	else:
		_on_close_completed()

func _show_with_animation() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, animation_duration)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	
	if _panel:
		_panel.scale = Vector2(0.9, 0.9)
		_tween.parallel().tween_property(_panel, "scale", Vector2(1, 1), animation_duration)

func _close_with_animation() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, animation_duration)
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_CUBIC)
	
	if _panel:
		_tween.parallel().tween_property(_panel, "scale", Vector2(0.9, 0.9), animation_duration)
	
	_tween.tween_callback(_on_close_completed)

func _on_close_completed() -> void:
	closed.emit()
	queue_free()

func _on_confirm_pressed() -> void:
	print("Confirm pressed.")
	if not is_instance_valid(self):
		return
	confirmed.emit()
	close()
	pass

func _on_cancel_pressed() -> void:
	canceled.emit()
	close()

# 虚函数：子类可以重写这个函数来接收自定义参数
func set_params(_params: Dictionary) -> void:
	pass


func isVisible() -> bool:
	return isFinish
