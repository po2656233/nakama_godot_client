extends Node

signal socketStateSIG(state: String)
signal reconnectSIG()

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

# 这些接口不会在断线重连后自动恢复
const NON_RETRY_API: Array = [
	"authenticate_email_async",
	"authenticate_device_async",
	"register_account",
	"login",
	"do_login",
	"do_device_login"
]

# 重连配置
const RECONNECT_INTERVAL := 15	# 重连间隔（秒）
const PING_INTERVAL := 10.0      # 心跳超时时间（秒）
const BASE_RETRY_DELAY := 3.0  	# 基础重试延迟（秒）
const MAX_RETRY_DELAY := 15.0  	# 最大重试延迟（秒）
const MAX_RETRY_COUNT := 5	 	# 最大重试次数
const REQUEST_RETRY_LIMIT := 3 	# 单个请求最大重试次数
enum EnBroadcast{
	CreateTable = 1,
	RemoveTable = 2,
	JoinTable = 3,
	LeaveTable = 4,
	TableOnline = 5,
}  

# 状态变量
#var _reconnect_timer: Timer = null		# 重连定时器
var _ping_timer: Timer = null			# 心跳定时器

var _is_connecting := false				# 是否正在连接
var _is_disconnected := true 			# 是否断开

# socket状态
var socket_state = {
	"connected":"连接成功",
	"disconnected":"连接断开",
	"reconnecting":"正在重连...",
	"restoring_session":"正在恢复会话...",
	"socket_error":"网络连接出错...",
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

# 获取NakamaSession
func get_nakama_session() -> NakamaSession:
	return nakama_session

# 设置session
func set_nakama_session(_nakama_session: NakamaSession) -> void:	
	nakama_session = _nakama_session
	_connect_socket(_nakama_session)
	print("获取到session:\t",_nakama_session,"\n")
	pass
###################################################################################
# 初始化
func _ready() -> void:
	# 连接Nakama Socket
	reconnectSIG.connect(_on_reset_session)
	socketStateSIG.connect(_on_socket_state)
	pass

# 重连事件处理
func renew_session():
	print("----完全重置session----")
	#_disconnect_socket()
	#OnlineLogin.relogin()# 绑定登录失败后，继续重连
	pass


# 事件 --重置session--
func _on_reset_session() -> void:
	if not nakama_session:
		renew_session()
		return
		
	print("正在重置session...")
	var restore_result = await nakama_client.session_refresh_async(nakama_session)
	if restore_result.is_exception():
		print("重置session失败，将启动持续重置")
		renew_session()
		return
	# 重置成功
	nakama_session = restore_result
	pass

# 事件 --socket状态--
func _on_socket_state(state: String):
	if socket_state.has(state) and state != "connected":
		PopupManager.show_dynamic(socket_state[state])
		return
	pass
###########################################################################################
# 初始化定时器
func start_timers() -> void:
	# 心跳定时器
	if _ping_timer == null:
		_ping_timer = Timer.new()
		_ping_timer.timeout.connect(sendPing)
		add_child(_ping_timer)
	_ping_timer.stop()
	_ping_timer.start(PING_INTERVAL)
	pass

func close_timers() -> void:
	if _ping_timer:	
		_ping_timer.stop()
		_ping_timer.queue_free()
		_ping_timer = null
	pass

func nakama_connect_socket() -> void:
	# 断开连接时关闭定时器
	_connect_socket(nakama_session)
	pass


#################################【网络连接】############################################
# 连接socket
func _connect_socket(session:NakamaSession) -> void:
	print("---------------------_connect_socket----------START-----------------------")
	_is_connecting = true
	if session == null:
		push_warning("连接Nakama Socket失败: session is null")
		_is_connecting = false
		return
		
	# 创建 Nakama Socket
	nakama_socket = Nakama.create_socket_from(nakama_client)
	if not nakama_socket:
		push_warning("创建Nakama Socket失败")
		_is_connecting = false
		return

	# 连接 Nakama Socket
	var result = await nakama_socket.connect_async(session,false,20)
	if (result is int and result == ERR_FILE_EOF ):
		pass
	elif result.is_exception():
		var exception = result.get_exception()
		print("网络连接出错 & %s" % result)
		print("错误详情 - StatusCode: %d, Message: '%s', GrpcStatusCode: %d" % [
			exception.status_code, 
			exception.message, 
			exception.grpc_status_code
		])

		
		# 根据错误类型提供具体建议
		if exception.status_code == -1 and exception.grpc_status_code == -1:
			print("连接失败 - 可能的原因:")
			print("1. 服务器地址 %s:%d 无法访问" % [nakama_host, nakama_port])
			print("2. 网络连接问题")
			print("3. 防火墙阻止连接")
			print("4. TLS/SSL证书问题")
			_is_connecting = false
			socketStateSIG.emit("socket_error")
			# 尝试使用HTTP而不是HTTPS
			#if nakama_scheme == "https":
				#print("尝试切换到HTTP连接...")
				#nakama_scheme = "http"
				#nakama_client = null  # 重置client以使用新配置
				#return
		#reconnectSIG.emit()
		# return
	print("网络nakama_socket连接 ->", nakama_socket.is_connected_to_host())
	_on_socket_connected()
	print("---------------------_connect_socket----------END-----------------------\n")
	pass

# 设置socket事件监听
func _setup_socket_events() -> void:
	# 断开连接时重置状态
	if not nakama_socket or _is_connecting:
		return
	Util.safe_connect(nakama_socket, "closed", self, "_on_socket_closed")
	Util.safe_connect(nakama_socket, "connected", self, "_on_socket_connected")
	Util.safe_connect(nakama_socket, "connection_error", self, "_on_socket_error")
	Util.safe_connect(nakama_socket, "received_matchmaker_matched", self, "_on_received_matchmaker_matched")
	Util.safe_connect(nakama_socket, "received_match_state", self, "_on_received_match_state")
	Util.safe_connect(nakama_socket, "received_match_presence", self, "_on_received_match_presence")
	Util.safe_connect(nakama_socket, "received_status_presence", self, "_on_received_status_presence")
	Util.safe_connect(nakama_socket, "received_notification", self, "_on_received_notification")
	Util.safe_connect(nakama_socket, "received_channel_message", self, "_on_received_message")
	# 匹配服重置socket
	OnlineMatch._set_nakama_socket(nakama_socket)
	pass

# 断开socket
func _disconnect_socket():
	_is_connecting = false
	_is_disconnected = true
	if nakama_socket:
		print("正在断开Nakama Socket连接...")
		nakama_socket.close()
		nakama_socket = null

#########################################################
# 事件处理
#########################################################
# 连接关闭
func _on_socket_closed() -> void:
	print("Nakama Socket 关闭")
	_is_disconnected = true
	

func _on_socket_connected() -> void:
# 连接成功
	print("连接Nakama Socket 成功")
	_is_connecting = false
	_is_disconnected = false
	socketStateSIG.emit("connected")
	# 监听socket事件
	_setup_socket_events()
	# 启动定时器
	start_timers()
	pass

# 网络错误
func _on_socket_error(err) -> void:
	print("网络异常——> ", err)
	socketStateSIG.emit("disconnected")

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

# func _notification(what: int) -> void:
# 	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
# 		# 当游戏窗口重新获得焦点时检查连接
# 		if not _check_connected():
# 			connect_nakama_socket()
# 	pass
############################主动发送数据############################################################
func sendPing():
	if nakama_socket:
		var cur_time = Time.get_unix_time_from_system()
		if cur_time > nakama_session.expire_time:
			reconnectSIG.emit()
		var result = await nakama_socket.rpc_async("ping")
		if result.is_exception():
			print("发送心跳失败:", result.get_exception().message)
		else:
			print("心跳发送成功")
	pass
	
# RPC 发送函数
func sendDataRPC(funcName: String, payload = null):
	print("发送RPC:", funcName, payload)
	var result_wrapper = { "result": null }  # 使用字典包装变量
	var sucess_cb = func(ret:NakamaAsyncResult):
		if ret and ret.id == funcName:
			result_wrapper.result = JSON.parse_string(ret.payload)
			return
		result_wrapper.result = ret  # 修改字典中的值
		pass
	var failed_cb = func(ret:NakamaAsyncResult):
		print("发送RPC:",funcName," -->结果:", ret)
		#result_wrapper.result = []  # 修改字典中的值
		return
	var result = await Util.Asyn_Call(nakama_socket, "rpc_async", [funcName, payload], sucess_cb, failed_cb)
	if not result:
		reconnectSIG.emit()  # 如果发送失败，触发重连信号
	print("发送RPC:",funcName," 结果:",result_wrapper.result)
	return result_wrapper.result  # 返回最终结果

# RPC 发送函数
func acynDataRPC(funcName: String, payload = null,success_cb: Callable = Util.EMPTY_CALLABLE, failure_cb: Callable = Util.EMPTY_CALLABLE) -> void:
	var result = await Util.Asyn_Call(nakama_socket, "rpc_async", [funcName, payload], success_cb, failure_cb)
	if not result:
		reconnectSIG.emit()  # 如果发送失败，触发重连信号
	return

# # 应用恢复焦点时检查连接
# func _notification(what: int) -> void:
# 	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
# 		# 当游戏窗口重新获得焦点时检查连接
# 		if not _check_connected():
# 			print("应用恢复焦点，检查连接状态")
# 			_check_connection()
# 	pass
