extends Node

## 网络管理器类
## 用于实时监控网络状态并在网络状态发生变化时通知用户

# 信号定义
signal network_status_changed(is_connected: bool)  # 网络状态改变时发出的信号
# signal wifi_strength_changed(strength: float)	  # WiFi信号强度改变时发出的信号

# 常量定义
const CHECK_INTERVAL = 1.0  # 网络检查间隔（秒）
const PING_HOST = "223.5.5.5"  # 用于检查网络连接的地址

# 变量定义

var _check_timer: Timer			  # 检查定时器
var http_client = HTTPClient.new()
var _is_connected: bool = false	  # 当前网络连接状态
# var _current_wifi_strength: float = 0.0  # 当前WiFi信号强度 (0.0 - 1.0)

func _ready() -> void:
	# _initialize()
	pass

## 初始化网络管理器
func _initialize() -> void:
	# 创建并配置定时器
	_check_timer = Timer.new()
	_check_timer.wait_time = CHECK_INTERVAL
	_check_timer.one_shot = false
	_check_timer.timeout.connect(_on_Timer_timeout)
	add_child(_check_timer)
	
	# 开始网络状态检查
	_check_timer.start()
	
	# # 立即进行第一次检查
	# _check_network_status()

	# # 连接信号
	# wifi_strength_changed.connect(func(strength):
	# 	print("WiFi 信号强弱:", strength)
	# )
	# network_status_changed.connect(func(connected):
	# 	print("网络是否连接:", connected)
	# )

## 检查网络状态
func _check_network_status() -> void:
	# 检查网络连接
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request(PING_HOST)
	var result = await http_request.request_completed
	http_request.queue_free()
	
	var new_connected = result[0] == HTTPRequest.RESULT_SUCCESS
	if new_connected != _is_connected:
		_is_connected = new_connected
		network_status_changed.emit(_is_connected)
		if not _is_connected:
			_show_network_warning()

func check_network_connection():
	# 尝试连接到一个可靠的服务器（如 Google 的 DNS）
	var error = http_client.connect_to_host(PING_HOST, 80)
	if error == OK:
		# 等待连接完成 STATUS_TLS_HANDSHAKE_ERROR 
		while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
			http_client.poll()
		
		# 检查最终状态
		if http_client.get_status() == HTTPClient.STATUS_CONNECTED:
			_is_connected = true
		else:
			_is_connected = false
	else:
		_is_connected = false
	
	# 返回连接状态
	return _is_connected
func _on_Timer_timeout():
	if check_network_connection():
		print("网络已连接")
	else:
		print("网络断开")

## 显示网络警告
func _show_network_warning() -> void:
	# 创建警告对话框
	var dialog = AcceptDialog.new()
	dialog.title = "网络连接警告"
	dialog.dialog_text = "网络连接已断开，请检查您的网络设置。"
	dialog.show()
