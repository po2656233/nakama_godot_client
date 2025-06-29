extends Node

signal connect_state(state: String)
signal session_failed()

# For developers to set from the outside, for example:
#   Online.nakama_host = 'nakama.example.com'
#   Online.nakama_scheme = 'https'
var nakama_server_key: String = 'superman'
var nakama_host: String = 'trytry.asia'#'localhost'
var nakama_port: int = 8850
var nakama_scheme: String = 'https'

# For other scripts to access:
var nakama_client: NakamaClient: get = get_nakama_client
var nakama_session: NakamaSession: get = get_nakama_session, set = set_nakama_session
var nakama_socket: NakamaSocket = null

# 重连配置
const RECONNECT_INTERVAL := 15
const BASE_RETRY_DELAY := 3.0  # 基础重试延迟（秒）
const MAX_RETRY_DELAY := 15.0  # 最大重试延迟（秒）
const MAX_RETRY_COUNT := 5	 # 最大重试次数
const RETRY_COUNT := 5	 # 重试次数
const PING_TIMEOUT := 20.0     # 心跳超时时间
const REQUEST_RETRY_LIMIT := 3 # 单个请求最大重试次数
const SESSION_RESET_INTERVAL := 1.0  # Session重置间隔（秒）

# 状态变量
var _retry_count := 0
var _current_delay := BASE_RETRY_DELAY
var _is_connecting := false
var _is_connected := false
var _reconnect_timer: Timer
var _ping_timer: Timer
var _session_reset_timer: Timer  # Session重置定时器
var _pending_requests: Array = []  # 待重试的请求队列
var _last_ping_time := 0.0
var _request_retry_count: Dictionary = {}  # 记录每个请求的重试次数
var _is_resetting_session := false  # 是否正在重置session

var socket_state = {
	"connected":"连接成功",
	"disconnected":"连接断开",
	"reconnecting":"正在重连...",
	"restoring_session":"正在恢复会话...",
	"socket_error":"网络连接出错...",
}

enum EnBroadcast{
	CreateTable = 1,
	RemoveTable = 2,
	JoinTable = 3,
	LeaveTable = 4,
	TableOnline = 5,
}   

###################################################################################
# 获取NakamaClient
func get_nakama_client() -> NakamaClient:
	if nakama_client == null:
		nakama_client = Nakama.create_client(
			nakama_server_key,
			nakama_host,
			nakama_port,
			nakama_scheme,
			Nakama.DEFAULT_TIMEOUT,
			NakamaLogger.LOG_LEVEL.ERROR)
	return nakama_client

func get_nakama_session() -> NakamaSession:
	return nakama_session

# 设置session
func set_nakama_session(_nakama_session: NakamaSession) -> void:		
	nakama_session = _nakama_session
	if not nakama_session or nakama_session.is_exception() or nakama_session.is_expired():
		# 获取到session后连接socket
		_disconnect_socket()
		push_warning("session is invalid:", nakama_session)
		return
	print("获取到session后连接socket _connect_socket")
	await _connect_socket(_nakama_session)
	pass

###################################################################################
# 初始化
func _ready() -> void:
	# Don't stop processing messages from Nakama when the game is paused.
	Nakama.process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_timers()
	connect_state.connect(_on_connect_state)
	session_failed.connect(_on_reset_session)
	pass

# 初始化定时器
func _setup_timers() -> void:
	_last_ping_time = Time.get_unix_time_from_system()
	# 重连定时器
	_reconnect_timer = Timer.new()
	_reconnect_timer.timeout.connect(_check_connection)
	add_child(_reconnect_timer)
	_reconnect_timer.start(RECONNECT_INTERVAL)
	
	# 心跳定时器
	_ping_timer = Timer.new()
	_ping_timer.timeout.connect(sendPing)
	add_child(_ping_timer)
	_ping_timer.start(RECONNECT_INTERVAL)
	
	# Session重置定时器
	_session_reset_timer = Timer.new()
	_session_reset_timer.timeout.connect(_attempt_session_reset)
	add_child(_session_reset_timer)
	
	# 立即发送第一次心跳
	sendPing()
	pass

# 重置session
func _restore_session() -> void:
	if _is_connecting or not nakama_session:
		return
		
	print("重置session")
	connect_state.emit("restoring_session")
	_is_connecting = true
	_is_resetting_session = true
	
	var restore_result = await nakama_client.session_refresh_async(nakama_session)
	if restore_result.is_exception():
		_is_connecting = false
		_is_resetting_session = false
		print("重置session失败，将启动持续重置")
		_start_continuous_session_reset()
		return
	
	# 重置成功
	_is_resetting_session = false
	nakama_session = restore_result
	await _connect_socket(restore_result)
	pass

# 连接socket
func _connect_socket(session) -> void:
	if session == null:
		push_warning("连接Nakama Socket失败: session is null")
		_is_connecting = false
		return
	# 如果已经连接，则不再连接
	if nakama_socket and nakama_socket.is_connected_to_host():
		print("Nakama Socket已经连接")
		_is_connecting = false
		_on_socket_connected()
		return

	# 创建 Nakama Socket
	nakama_socket = Nakama.create_socket_from(nakama_client)
	if not nakama_socket:
		push_warning("创建Nakama Socket失败")
		_is_connecting = false
		return
	# 连接 Nakama Socket
	var result = await nakama_socket.connect_async(session)
	if (result is int and result == ERR_FILE_EOF ):
		print("网络连接出错 ->", result)
		_is_connecting = false
		_on_socket_disconnected("连接失败")
		return
	# if result.is_exception():
	# 	print("网络连接出错 & ", session)
	# 	_is_connecting = false
	# 	_on_socket_disconnected("连接异常")
	# 	return

	# 连接成功
	_is_connecting = false
	_is_connected = true
	connect_state.emit("connected")
	print("连接Nakama Socket 成功")
	
	# 监听socket事件
	_setup_socket_events()
	pass

# 设置socket事件监听
func _setup_socket_events() -> void:
	if not nakama_socket:
		return
		
	Util.safe_connect(nakama_socket, "connection_error", self, "_on_socket_disconnected")
	Util.safe_connect(nakama_socket, "connected", self, "_on_socket_connected")
	Util.safe_connect(nakama_socket, "received_matchmaker_matched", self, "_on_received_matchmaker_matched")
	Util.safe_connect(nakama_socket, "received_match_state", self, "_on_received_match_state")
	Util.safe_connect(nakama_socket, "received_match_presence", self, "_on_received_match_presence")
	Util.safe_connect(nakama_socket, "received_status_presence", self, "_on_received_status_presence")
	Util.safe_connect(nakama_socket, "received_notification", self, "_on_received_notification")
	Util.safe_connect(nakama_socket, "received_channel_message", self, "_on_received_message")
	
	OnlineMatch._set_nakama_socket(nakama_socket)
	pass

# 断开socket
func _disconnect_socket():
	_reset_reconnect_state()
	_stop_continuous_session_reset()  # 确保停止持续重置
	_is_connected = false
	if nakama_socket:
		nakama_socket.close()
		nakama_socket = null

#########################################################
# 事件处理
#########################################################
func _on_socket_disconnected(err) -> void:
	_reset_reconnect_state()
	_is_connected = false
	connect_state.emit("disconnected")
	print("网络异常——> ", err)
	_attempt_reconnect()

func _on_socket_connected() -> void:
	_is_connected = true
	_reset_reconnect_state()
	_stop_continuous_session_reset()  # 确保停止持续重置
	connect_state.emit("connected")
	print("网络已连接")
	
	# 重连成功后，重试所有待处理的请求
	_retry_pending_requests()
	
	# 发送心跳确认连接
	await sendPing()
	pass

func _on_reset_session():
	_disconnect_socket()
	# 绑定登录失败后，继续重连
	OnlineLogin.relogin()
	pass

func _on_connect_state(state: String):
	if socket_state.has(state) and state != "connected":
		PopupManager.show_dynamic(socket_state[state])
		return
	pass

# 收到匹配数据
func _on_received_matchmaker_matched(matchmaker_matched):
	SignalManager.MatchMakerSIG.emit(matchmaker_matched)
	pass

# 收到匹配状态
func _on_received_match_state(match_state):
	SignalManager.MatchStateEventSIG.emit(match_state)
	pass

# 收到匹配玩家数据
func _on_received_match_presence(match_presence):
	print("收到匹配的玩家数据:", match_presence)
	SignalManager.MatchPresenceEventSIG.emit(match_presence)
	pass

# 收到状态数据
func _on_received_status_presence(status_presence):	
	SignalManager.StatusPresenceEventSIG.emit(status_presence)
	pass

# 收到通知
func _on_received_notification(notification1):
	print("收到通知:", notification1.subject, " 内容:", notification1)
	match notification1.subject:
		"broadcast":
			do_broadcast(notification1)
		"announcement":
			pass
		"notice":
			pass
		"poster":
			pass
		"notification":
			pass
		_:
			push_warning("未知的通知类型:", notification1.category)
	pass

func _on_channel_presence(channel_presence):
	var _1 = channel_presence
	pass

func _on_received_message(channel_message):
	print("收到消息:", channel_message)
	SignalManager.RecvMessageSIG.emit(channel_message)
	pass

########################全局信号转发####################################
func do_broadcast(notification1):
	var content = JSON.parse_string(notification1.content)
	match notification1.code:
		EnBroadcast.CreateTable:
			SignalManager.CreateRoomSIG.emit(content)
		EnBroadcast.RemoveTable:
			SignalManager.RemoveRoomSIG.emit(content)
		EnBroadcast.JoinTable:
			SignalManager.JoinRoomSIG.emit(content)
		EnBroadcast.LeaveTable:
			SignalManager.LeaveRoomSIG.emit(content)
		EnBroadcast.TableOnline:
			SignalManager.OnlineCountSIG.emit(content)
		_:
			push_warning("未知的广播类型:", notification1.code)
	pass

####################重连#####################################	
func _reset_reconnect_state() -> void:
	_is_connecting = false
	_retry_count = 0
	_current_delay = BASE_RETRY_DELAY

# 检查连接状态
func _check_connection() -> void:
	if not _is_connected or not is_socket_connected():
		_attempt_reconnect()
		return
	var curtime = Time.get_unix_time_from_system()
	if curtime - _last_ping_time > PING_TIMEOUT:
		# 心跳超时，尝试重连
		print("心跳超时，尝试重连 ",curtime-_last_ping_time," last:",_last_ping_time," ping:",PING_TIMEOUT)
		_attempt_reconnect()

	
func _attempt_reconnect() -> void:
	if _is_connecting:
		return
	if not nakama_session:
		print("尝试重连-->无session")
		connect_state.emit("disconnected")
		_on_reset_session()
		return
		
	# 超过重试次数后，重置session
	if nakama_session.is_valid() and _retry_count < RETRY_COUNT:
		connect_state.emit("reconnecting")
		print("尝试重连", _retry_count + 1, "/", RETRY_COUNT)
		_retry_count += 1
		_is_connecting = true
		connect_nakama_socket()
	else:
		print("重试次数已达上限，开始重置session")
		_retry_count = 0  # 重置重试计数
		await _restore_session()
	pass


func is_socket_connected() -> bool:
	return nakama_socket != null and nakama_socket.is_connected_to_host()

func force_reconnect() -> void:
	_reset_reconnect_state()
	# _disconnect_socket()
	_attempt_reconnect()

# func _notification(what: int) -> void:
# 	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
# 		# 当游戏窗口重新获得焦点时检查连接
# 		if not is_socket_connected():
# 			_start_reconnect()
# 	pass
##############################################################################################
func connect_nakama_socket() -> void:
	print("连接Nakama Socket")
	await _connect_socket(nakama_session)
	

func is_nakama_socket_connected() -> bool:
	return nakama_socket != null && nakama_socket.is_connected_to_host()

############################主动发送数据############################################################
func sendPing():
	if nakama_socket:
		var result = await nakama_socket.rpc_async("ping")
		if result.is_exception():
			print("发送心跳失败:", result.get_exception().message)
			# _last_ping_time = 0.0  # 重置心跳时间，触发重连检查
		else:
			_last_ping_time = Time.get_unix_time_from_system()
			print("心跳发送成功:", _last_ping_time)
	pass
# RPC 发送函数
func sendDataRPC(funcName: String, payload = null):
	print("发送RPC:", funcName, payload)
	
	# 如果连接断开，将请求加入队列
	if not _is_connected or not is_socket_connected():
		_add_to_pending_requests(funcName, payload)
		return null
	
	if nakama_socket:
		var result = await nakama_socket.rpc_async(funcName, payload)
		if result.is_exception():
			# 处理网络相关错误，将请求加入重试队列
			if _should_retry_request(result, funcName):
				_add_to_pending_requests(funcName, payload)
				return null
			else:
				# 其他错误直接显示
				_handle_request_error(result, funcName)
				return null
		
		# 请求成功，清除重试计数
		_clear_request_retry_count(funcName)
		return result
	
	return null

# 添加请求到待处理队列
func _add_to_pending_requests(funcName: String, payload = null) -> void:
	var request = {
		"funcName": funcName,
		"payload": payload,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# 检查是否已存在相同请求，避免重复
	for existing_request in _pending_requests:
		if existing_request.funcName == funcName and existing_request.payload == payload:
			print("请求已存在于队列中:", funcName)
			return
	
	_pending_requests.append(request)
	print("请求已加入重试队列:", funcName, "队列长度:", _pending_requests.size())

# 判断是否应该重试请求
func _should_retry_request(result, funcName: String) -> bool:
	if not result.is_exception():
		return false
	
	var msg = result.get_exception().message
	var retry_count = _request_retry_count.get(funcName, 0)
	
	# 检查重试次数限制
	if retry_count >= REQUEST_RETRY_LIMIT:
		print("请求重试次数已达上限:", funcName, "重试次数:", retry_count)
		return false
	
	# 网络相关错误才重试
	var network_errors = [
		"网络断开",
		"连接失败", 
		"连接超时",
		"HTTPRequest failed!",
		"Invalid session.",
		"Session expired."
	]
	
	for error in network_errors:
		if msg.contains(error):
			_request_retry_count[funcName] = retry_count + 1
			print("网络错误，将重试请求:", funcName, "重试次数:", retry_count + 1)
			return true
	
	return false

# 处理请求错误
func _handle_request_error(result, funcName: String) -> void:
	var msg = result.get_exception().message
	print("RPC异常:", result)
	msg = Errors.ResponeMapping.get(msg, msg)
	PopupManager.show_dynamic("%s失败: %s" % [Errors.FuncMapping.get(funcName, funcName), msg], 150.0)
	print("%s 响应异常: %s" % [funcName, msg])

# 清除请求重试计数
func _clear_request_retry_count(funcName: String) -> void:
	if _request_retry_count.has(funcName):
		_request_retry_count.erase(funcName)

# 重试所有待处理的请求
func _retry_pending_requests() -> void:
	if _pending_requests.is_empty():
		print("没有待重试的请求")
		return
	
	print("开始重试待处理请求，数量:", _pending_requests.size())
	
	# 复制队列，避免在遍历时修改
	var requests_to_retry = _pending_requests.duplicate()
	_pending_requests.clear()
	
	for request in requests_to_retry:
		print("重试请求:", request.funcName)
		# 使用延迟避免请求过于密集
		await get_tree().create_timer(0.5).timeout
		await sendDataRPC(request.funcName, request.payload)
	
	print("待处理请求重试完成")

# 清空待处理请求队列
func _clear_pending_requests() -> void:
	_pending_requests.clear()
	_request_retry_count.clear()
	print("已清空待处理请求队列")

# 获取待处理请求数量
func get_pending_requests_count() -> int:
	return _pending_requests.size()

# 获取连接状态
func get_connection_status() -> Dictionary:
	return {
		"is_connected": _is_connected,
		"is_connecting": _is_connecting,
		"pending_requests": _pending_requests.size(),
		"retry_count": _retry_count
	}

# 手动触发重连（供外部调用）
func manual_reconnect() -> void:
	print("手动触发重连")
	_disconnect_socket()
	_attempt_reconnect()

# 应用恢复焦点时检查连接
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		# 当游戏窗口重新获得焦点时检查连接
		if not is_socket_connected():
			print("应用恢复焦点，检查连接状态")
			_check_connection()
	pass

# 启动持续重置session
func _start_continuous_session_reset() -> void:
	if _is_resetting_session:
		return
		
	print("启动持续重置session，间隔:", SESSION_RESET_INTERVAL, "秒")
	_is_resetting_session = true
	_session_reset_timer.start(SESSION_RESET_INTERVAL)
	pass

# 停止持续重置session
func _stop_continuous_session_reset() -> void:
	if _session_reset_timer:
		_session_reset_timer.stop()
	_is_resetting_session = false
	print("停止持续重置session")
	pass

# 尝试重置session（持续重置用）
func _attempt_session_reset() -> void:
	if not _is_resetting_session or not nakama_session:
		_stop_continuous_session_reset()
		return
		
	print("尝试重置session...")
	var restore_result = await nakama_client.session_refresh_async(nakama_session)
	if restore_result.is_exception():
		print("重置session失败，继续尝试")
		return
	
	# 重置成功
	print("重置session成功！")
	_stop_continuous_session_reset()
	nakama_session = restore_result
	await _connect_socket(restore_result)
	pass
