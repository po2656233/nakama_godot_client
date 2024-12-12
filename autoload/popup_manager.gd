extends Node

## 弹窗管理器单例
## 使用方法:
## 1. 普通提示: PopupManager.show_message("提示内容")
## 2. 确认框: PopupManager.show_confirm("确认内容", callback)
## 3. 自定义弹窗: PopupManager.show_custom(popup_scene_path, params)

# 信号定义
signal popup_confirmed(popup_id: String)
signal popup_canceled(popup_id: String)
signal popup_closed(popup_id: String)

# 预加载场景
var message_scene = preload("res://scenes/element/popup/message_popup.tscn")
var confirm_scene = preload("res://scenes/element/popup/confirm_popup.tscn")
var dynamic_scene = preload("res://scenes/element/popup/dynamic_text.tscn")


# 当前活动的弹窗
var active_popups: Dictionary = {}
var canvas_layer: CanvasLayer
var dynamic_text:Label
var is_visible: bool = false
## 初始化
func _ready() -> void:
	# 设置为始终处理（即使游戏暂停）
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	# 创建一个顶层CanvasLayer来显示弹窗
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # 设置一个较高的层级
	add_child(canvas_layer)
	dynamic_text = dynamic_scene.instantiate()
	canvas_layer.add_child(dynamic_text)


## 显示普通消息弹窗
func show_dynamic(message: String,speed:float=200.0) -> void:
	dynamic_text.display_text(message)  # 文本会自动居中显示
	dynamic_text.set_speed(speed)
	is_visible = true
	pass


## 显示普通消息弹窗
func show_message(message: String, title: String = "提示", auto_close:bool=true) -> void:
	var popup = message_scene.instantiate()
	_setup_popup(popup, title, message,auto_close)
	
## 显示确认框
## callback为确认后的回调函数
func show_confirm(message: String, callback: Callable, title: String = "确认") -> void:
	var popup = confirm_scene.instantiate()
	print("提示")
	_setup_popup(popup, title, message)
	if callback:
		# 使用lambda连接信号，这样可以在确认后调用回调
		print("确认框")
		popup_confirmed.connect(
			func(popup_id: String): 
				print('ok')
				if popup_id == str(popup.get_instance_id()):
					print("确认了")
					callback.call(),
			CONNECT_ONE_SHOT
		)

## 显示自定义弹窗
## popup_scene_path: 自定义弹窗场景路径
## params: 传递给弹窗的参数
func show_custom(popup_scene_path: String, params: Dictionary = {}) -> void:
	var scene = load(popup_scene_path)
	if not scene:
		push_error("Failed to load popup scene: " + popup_scene_path)
		return
		
	var popup = scene.instantiate()
	if popup.has_method("set_params"):
		popup.set_params(params)
	_setup_popup(popup)

## 关闭指定ID的弹窗
func close_popup(popup_id: String) -> void:
	is_visible = false
	if active_popups.has(popup_id):
		var popup = active_popups[popup_id]
		popup.queue_free()
		active_popups.erase(popup_id)
		popup_closed.emit(popup_id)

## 关闭所有弹窗
func close_all() -> void:
	is_visible = false
	for popup_id in active_popups.keys():
		close_popup(popup_id)

# 内部方法：设置弹窗基本属性
func _setup_popup(popup: Node, title: String = "", message: String = "",auto_close:bool = false) -> void:
	is_visible = true
	var popup_id = str(popup.get_instance_id())
	popup.auto_close = auto_close
	# 设置基本属性
	if title and popup.has_method("set_title"):
		popup.set_title(title)
	if message and popup.has_method("set_message"):
		popup.set_message(message)
	   
	# 连接信号
	if popup.has_signal("confirmed"):
		popup.confirmed.connect(func(): popup_confirmed.emit(popup_id))
	if popup.has_signal("canceled"):
		popup.canceled.connect(func(): popup_canceled.emit(popup_id))
	if popup.has_signal("closed"):
		popup.closed.connect(func(): close_popup(popup_id))
	
	# 添加到顶层CanvasLayer
	canvas_layer.add_child(popup)
	active_popups[popup_id] = popup

func isVisible() -> bool:
	return  is_visible
