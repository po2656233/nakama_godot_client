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
	if not nakama_session or  nakama_session.is_exception() or  nakama_session.is_expired():
		# 获取到session后连接socket
		_disconnect_socket()
		push_warning("session is invalid:",nakama_session)
		return
	print("获取到session后连接socket _connect_socket")
	await _connect_socket(_nakama_session)
	pass

###################################################################################
# 初始化
func _ready() -> void:
	# Don't stop processing messages from Nakama when the game is paused.
	Nakama.process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_reconnect_timer()
	connect_state.connect(_on_connect_state)
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

# 重置session
func _restore_session() -> void:
	if _is_connecting or not nakama_session:
		return
		
	print("重置session")
	connect_state.emit("restoring_session")
	_is_connecting = true
	var restore_result = await nakama_client.session_refresh_async(nakama_session)
	if restore_result.is_exception():
		_is_connecting = false
		print("重置session失败")
		session_failed.emit()
		return
	nakama_session = restore_result
	await _connect_socket(restore_result)
	

# 连接socket
func _connect_socket(session) -> void:
	if session == null:
		push_warning("连接Nakama Socket失败: session is null")
		return
	# 如果已经连接，则不再连接
	if nakama_socket and nakama_socket.is_connected_to_host():
		print("Nakama Socket已经连接")
		connect_state.emit("connected")
		return

	# 创建 Nakama Socket
	nakama_socket = Nakama.create_socket_from(nakama_client)
	if not nakama_socket:
		push_warning("创建Nakama Socket失败")
		return
	# 连接 Nakama Socket
	var result = await nakama_socket.connect_async(session)
	if (result is int and result == ERR_FILE_EOF ):
		# connect_state.emit("socket_error")
		print("网络连接出错 ->", result)
		_is_connecting = false
		return
	if result.is_exception():
		print("网络连接出错 & ", session)
		_is_connecting = false
		return

	# 连接成功
	_is_connecting = is_socket_connected()
	connect_state.emit("connected")
	print("连接Nakama Socket 是否成功:", _is_connecting)
	
	# 监听socket事件
	Util.safe_connect(nakama_socket, "connection_error", self, "_on_socket_disconnected")
	Util.safe_connect(nakama_socket, "connected", self, "_on_socket_connected")
	Util.safe_connect(nakama_socket, "received_matchmaker_matched", self, "_on_received_matchmaker_matched") # 监听好友状态
	Util.safe_connect(nakama_socket, "received_match_state", self, "_on_received_match_state") # 监听好友状态
	Util.safe_connect(nakama_socket, "received_match_presence", self, "_on_received_match_presence") # 监听好友状态
	Util.safe_connect(nakama_socket, "received_status_presence", self, "_on_received_status_presence") # 监听好友状态
	Util.safe_connect(nakama_socket, "received_notification", self, "_on_received_notification")
	Util.safe_connect(nakama_socket, "received_channel_message", self, "_on_received_message")
	# Util.safe_connect(nakama_socket, "received_channel_presence", self, "_on_channel_presence")
	OnlineMatch._set_nakama_socket(nakama_socket)
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
	connect_state.emit("disconnected")
	print("网络异常",err)

func _on_socket_connected() -> void:
	connect_state.emit("connected")
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

func _on_connect_state(state: String):
	if socket_state.has(state) and state != "connected":
		PopupManager.show_dynamic(socket_state[state])
		return
	#push_warning("未知的连接状态:", state)
	pass
	

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
		connect_state.emit("disconnected")
		_on_reset_session()
		return
	# 超过重试次数后，重新登录
	if nakama_session.is_valid() and _retry_count < RETRY_COUNT:
		connect_state.emit("reconnecting")
		print("尝试重连",_retry_count)
		_retry_count += 1
		connect_nakama_socket()
	else:
		print("尝试重连-->重置session")
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
			print("发送心跳...", result.get_exception().message ) 
	pass
# RPC 发送函数
func sendDataRPC(funcName: String, payload = null):
	print("发送RPC:", funcName, payload)
	if nakama_socket:
		var result = await nakama_socket.rpc_async(funcName, payload)
		if result.is_exception():
			lastSend.funcName = funcName
			lastSend.payload = payload
			# 显示中文提示信息
			if not dowithErr(result,funcName):
				await get_tree().create_timer(1.0).timeout
				return await sendDataRPC(lastSend.funcName, lastSend.payload)
			return null
		lastSend.funcName = ""
		lastSend.payload = null
		return result
	return null

func dowithErr(result,funcName="")-> bool:
	if not result.is_exception():
		return true
	var msg = result.get_exception().message
	print("RPC异常:",result)
	msg = Errors.ResponeMapping.get(msg, msg)
	PopupManager.show_dynamic("%s失败: %s" % [Errors.FuncMapping.get(funcName, funcName), msg],150.0)
	print("%s 响应异常: %s"%[funcName, msg])
	match msg:
		"网络断开":
			force_reconnect()
			print("成功连接:",_is_connecting," 重新访问接口:",lastSend.funcName)
			if not _is_connecting:
				_restore_session()
			if _is_connecting:
				return false
		_:
			print(msg)
	return true
