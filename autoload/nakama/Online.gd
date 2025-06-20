extends Node

signal connection_state_changed(state: String)
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
var nakama_session: NakamaSession: set = set_nakama_session
var nakama_socket: NakamaSocket

# Internal variable for initializing the socket.
# var _nakama_socket_connecting := false



# 重连配置
const RECONNECT_INTERVAL := 15
const BASE_RETRY_DELAY := 3.0  # 基础重试延迟（秒）
const MAX_RETRY_DELAY := 15.0  # 最大重试延迟（秒）
const MAX_RETRY_COUNT := 0	 # 0表示无限重试
const RETRY_COUNT := 1	 # 重试次数
# 状态变量
var _retry_count := 0
var _current_delay := BASE_RETRY_DELAY
var _is_connecting := false
var _reconnect_timer: Timer
var lastSend = {
	"funcName":"",
	"payload":null,
}

enum EnBroadcast{
	CreateTable = 1,
	RemoveTable = 2,
	JoinTable = 3,
	LeaveTable = 4,
	TableOnline = 5,
}   

# 初始化
func _ready() -> void:
	# Don't stop processing messages from Nakama when the game is paused.
	Nakama.process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_reconnect_timer()
	connection_state_changed.connect(_on_connection_state_changed)
	session_failed.connect(_on_reset_session)
	# OnlineLogin.session_connected.connect(set_nakama_session)
	pass

# 初始化重连定时器
func _setup_reconnect_timer() -> void:
	_reconnect_timer = Timer.new()
	# _reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(sendPing)
	# _reconnect_timer.timeout.connect(_attempt_reconnect)
	add_child(_reconnect_timer)
	_reconnect_timer.start(RECONNECT_INTERVAL)
	sendPing()
	pass

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

# 设置session
func set_nakama_session(_nakama_session: NakamaSession) -> void:
	if not _nakama_session:
		_disconnect_socket()
		return
		
	nakama_session = _nakama_session
	if nakama_session and not nakama_session.is_exception() and not nakama_session.is_expired():
		# 获取到session后连接socket
		print("获取到session后连接socket _connect_socket")
		_connect_socket()
	else:
		push_warning("session is invalid:",nakama_session)
	pass

# 重置session
func _restore_session() -> void:
	if _is_connecting or not nakama_session:
		return
		
	_is_connecting = true
	print("重置session")
	connection_state_changed.emit("restoring_session")
	
	var restore_result = await nakama_client.session_refresh_async(nakama_session)
	if restore_result.is_exception():
		_is_connecting = false
		print("重置session失败")
		session_failed.emit()
		return
	nakama_session = restore_result
	await _connect_socket()
	

# 连接socket
func _connect_socket() -> void:
	if _is_connecting:
		print("已连接")
		return
	if not nakama_session:
		_on_reset_session()
		return
	_is_connecting = true
	nakama_socket = Nakama.create_socket_from(nakama_client)
	var result = await nakama_socket.connect_async(nakama_session)
	if (result is int and result == ERR_FILE_EOF ):
		# connection_state_changed.emit("socket_error")
		print("网络连接出错 ->", result)
		_is_connecting = false
		return
	if result.is_exception():
		print("网络连接出错 & ", result.get_exception().message)
		_is_connecting = false
		return
	_is_connecting = is_socket_connected()
	connection_state_changed.emit("connected")
	
	# 监听socket事件
	nakama_socket.connection_error.connect(_on_socket_disconnected)
	nakama_socket.connected.connect(_on_socket_connected)
	nakama_socket.received_matchmaker_matched.connect(_on_received_matchmaker_matched)
	nakama_socket.received_match_state.connect(_on_received_match_state)
	nakama_socket.received_match_presence.connect(_on_received_match_presence)
	nakama_socket.received_status_presence.connect(_on_received_status_presence)
	nakama_socket.received_notification.connect(_on_received_notification)	
	# nakama_socket.received_channel_presence.connect(_on_channel_presence)
	nakama_socket.received_channel_message.connect(_on_received_message)
	OnlineMatch._set_nakama_socket(nakama_socket)
	print("成功连接 ",_is_connecting)
	pass

# 断开socket
func _disconnect_socket():
	_reset_reconnect_state()
	if nakama_socket:
		nakama_socket.close()
		nakama_socket = null
#########################################################
# 事件处理
#########################################################
func _on_socket_disconnected(err) -> void:
	_reset_reconnect_state()
	connection_state_changed.emit("disconnected")
	print("网络异常",err)

func _on_socket_connected() -> void:
	connection_state_changed.emit("connected")
	print("网络已连接")
	await sendDataRPC("ping")
	# if lastSend.funcName != "":
	# 	sendDataRPC(lastSend.funcName, lastSend.payload)
	pass

func _on_reset_session():
	_disconnect_socket()
	# 绑定登录失败后，继续重连
	OnlineLogin.relogin()
	pass

func _on_connection_state_changed(state: String):
	if state == "connected":
		# 连接成功
		#PopupManager.show_dynamic("连接成功")
		pass
	elif state == "disconnected":
		# 连接断开
		PopupManager.show_dynamic("连接断开")
	elif state == "reconnecting":
		# 正在重连
		PopupManager.show_dynamic("正在重连")
	# elif state == "waiting_to_reconnect":
		# 等待重连
		# PopupManager.show_dynamic("等待重连")
	elif state == "restoring_session":
		PopupManager.show_dynamic("正在恢复会话")
	elif state == "socket_error":
		PopupManager.show_dynamic("网络连接出错")

# 收到匹配数据
func _on_received_matchmaker_matched(matchmaker_matched):
	#print("收到匹配的数据:", matchmaker_matched)
	SignalManager.MatchMakerSIG.emit(matchmaker_matched)
	pass

# 收到匹配状态
func _on_received_match_state(match_state):
	#print("收到匹配状态:", match_state)
	SignalManager.MatchStateEventSIG.emit(match_state)
	pass

# 收到匹配玩家数据
func _on_received_match_presence(match_presence):
	print("收到匹配的玩家数据:", match_presence)
	SignalManager.MatchPresenceEventSIG.emit(match_presence)
	pass

# 收到状态数据
func _on_received_status_presence(status_presence):	
	#print("收到状态的玩家数据:", status_presence)
	SignalManager.StatusPresenceEventSIG.emit(status_presence)
	pass

# 收到通知
func _on_received_notification(notification1):
	print("收到通知:",notification1.subject," 内容:", notification1)
	# SignalManager.NewNotifySIG.emit(notification1)
	match notification1.subject:
		"broadcast":
			do_broadcast(notification1)
			pass
		"announcement":
			pass
		"notice":
			pass
		"poster":
			pass
		"notification":
			pass
		_:
			push_warning("未知的通知类型:",notification1.category)
			pass
	pass

func _on_channel_presence(channel_presence):
	var _1 = channel_presence
	# print("收到频道数据:", channel_presence,OnlineLogin.get_my_name())
	pass

func _on_received_message(channel_message):
	print("收到消息0000:", channel_message)
	SignalManager.RecvMessageSIG.emit(channel_message)
	pass

# func _on_received_error(error):
# 	print("收到错误:", error)
# 	pass

########################全局信号转发####################################
func do_broadcast(notification1):
	var content = JSON.parse_string(notification1.content)
	match notification1.code:
		EnBroadcast.CreateTable:
			SignalManager.CreateRoomSIG.emit(content)
			pass
		EnBroadcast.RemoveTable:
			SignalManager.RemoveRoomSIG.emit(content)
			pass
		EnBroadcast.JoinTable:
			SignalManager.JoinRoomSIG.emit(content)
			pass
		EnBroadcast.LeaveTable:
			SignalManager.LeaveRoomSIG.emit(content)
			pass
		EnBroadcast.TableOnline:
			SignalManager.OnlineCountSIG.emit(content)
			pass
		_:
			push_warning("未知的广播类型:",notification1.code)
			pass
	pass


####################重连#####################################	
func _reset_reconnect_state() -> void:
	_is_connecting = false
	_retry_count = 0
	_current_delay = BASE_RETRY_DELAY
	
func _attempt_reconnect() -> void:
	if _is_connecting:
		return
	if not nakama_session:
		print("尝试重连-->无session")
		connection_state_changed.emit("disconnected")
		_on_reset_session()
		return
	# 超过重试次数后，重新登录
	if nakama_session.is_valid() and _retry_count < RETRY_COUNT:
		connection_state_changed.emit("reconnecting")
		print("尝试重连",_retry_count)
		_retry_count += 1
		await _connect_socket()
	else:
		print("尝试重连-->重置session")
		await _restore_session()
	pass


func is_socket_connected() -> bool:
	return nakama_socket != null and nakama_socket.is_connected_to_host()

func force_reconnect() -> void:
	_reset_reconnect_state()
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
	_connect_socket()
	

func is_nakama_socket_connected() -> bool:
	#print("conncted")
	return nakama_socket != null && nakama_socket.is_connected_to_host()


############################主动发送数据############################################################
func sendPing():
	if nakama_socket:
		var result = await nakama_socket.rpc_async("ping")
		if result.is_exception():
			print("发送心跳...", result.get_exception().message ) 
	pass
# RPC 发送函数
func sendDataRPC(funcName: String, payload = null):
	print("发送RPC:", funcName, payload)
	if nakama_socket:
		var result = await nakama_socket.rpc_async(funcName, payload)
		if result.is_exception():
			# 显示中文提示信息
			dowithErr(result,funcName)
			lastSend.funcName = funcName
			lastSend.payload = payload
			return null
		lastSend.funcName = ""
		lastSend.payload = null
		return result
	return null

func dowithErr(result,funcName=""):
	if not result.is_exception():
		return
	var msg = result.get_exception().message
	print("RPC异常:",result)
	msg = Errors.ResponeMapping.get(msg, msg)
	PopupManager.show_dynamic("%s失败: %s" % [Errors.FuncMapping.get(funcName, funcName), msg],150.0)
	print("%s 响应异常: %s"%[funcName, msg])
	match msg:
		"网络断开":
			force_reconnect()
		_:
			print(msg)
	return
