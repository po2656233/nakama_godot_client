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
var _reconnect_timer: Timer = null		# 重连定时器
var _ping_timer: Timer = null			# 心跳定时器

var _is_connecting := false				# 是否正在连接
var _is_disconnected := true 			# 是否断开

# 重连变量
var _retry_count := 0
var _current_delay := BASE_RETRY_DELAY
var _request_retry_count: Dictionary = {}  # 记录每个请求的重试次数
var _pending_requests: Array = []  # 待重试的请求队列
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
	if not nakama_session or nakama_session.is_exception() or nakama_session.is_expired():
		# 获取到session后连接socket
		_disconnect_socket()
		push_warning("session is invalid:", nakama_session)
		return
	print("获取到session:\t",_nakama_session,"\n")
	_connect_socket(_nakama_session)
	pass
###################################################################################
# 初始化
func _ready() -> void:
	reconnectSIG.connect(_on_reconnect)
	socketStateSIG.connect(_on_socket_state)
	pass
func renew_session():
	print("----完全重置session----")
	_disconnect_socket()
	# 绑定登录失败后，继续重连
	OnlineLogin.relogin()
	connect_nakama_socket()
	pass

# 事件 --重连--
func _on_reconnect() -> void:
	if _is_connecting:
		return
	if not nakama_session:
		renew_session()
		return
	# 只有session失效时才重置session
	if nakama_session.is_valid() and _retry_count < MAX_RETRY_COUNT:
		print("尝试重连", _retry_count + 1, "/", MAX_RETRY_COUNT)
		_retry_count += 1
		await reset_session()
	else:
		print("重试次数已达上限，开始重置session")
		_retry_count = 0  # 重置重试计数
		renew_session()
	pass


# 事件 --重置session--
func reset_session() -> void:
	if not nakama_session:
		return
		
	print("\n正在重置session...")
	# connect_state.emit("restoring_session")
	_is_connecting = true
	var restore_result = await nakama_client.session_refresh_async(nakama_session)
	if restore_result.is_exception():
		_is_connecting = false
		print("重置session失败，将启动持续重置\n")
		renew_session()
		return
	_is_connecting = false
	nakama_session = restore_result
	if nakama_socket:
		var result = await nakama_socket.connect_async(restore_result,false,20)
		if _check_connected():
			_on_socket_connected()
		print("重置session结果：",result)
	print("重置session...结束\n")
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
	# 重连定时器
	if _reconnect_timer == null:
		_reconnect_timer = Timer.new()
		_reconnect_timer.timeout.connect(_check_connection)
		add_child(_reconnect_timer)
	_reconnect_timer.stop()
	_reconnect_timer.start(RECONNECT_INTERVAL)
	
	# 心跳定时器
	if _ping_timer == null:
		_ping_timer = Timer.new()
		_ping_timer.timeout.connect(_check_ping)
		add_child(_ping_timer)
	_ping_timer.stop()
	_ping_timer.start(PING_INTERVAL)
	pass

func close_timers() -> void:
	if _reconnect_timer:
		_reconnect_timer.stop()
		_reconnect_timer.queue_free()
		_reconnect_timer = null
	if _ping_timer:	
		_ping_timer.stop()
		_ping_timer.queue_free()
		_ping_timer = null
	pass


# 检查连接状态
func _check_connection() -> void:
	print("检查连接状态...")
	if _is_disconnected:
		print("断线重连中...",_is_disconnected)
		if nakama_session == null:
			renew_session()
			return
		_is_connecting = false
		reconnectSIG.emit()
		return
	pass

# 检查心跳
func _check_ping() -> void:
	call_thread_safe("sendPing")

# 


#################################【网络连接】############################################
# 连接socket
func _connect_socket(session:NakamaSession) -> void:
	print("---------------------_connect_socket---------------------------------")
	_is_connecting = true
	if session == null:
		push_warning("连接Nakama Socket失败: session is null")
		_is_connecting = false
		return
		
	# 检查session是否有效
	if session.is_exception() or session.is_expired():
		reset_session()
		return
		#push_warning("连接Nakama Socket失败: session无效或已过期")
		#_is_connecting = false
		#if session.is_valid():
			#reset_session()
			#return
		#renew_session()
		#return
		
	# 创建 Nakama Socket
	if not nakama_socket:
		nakama_socket = Nakama.create_socket_from(nakama_client)
		if not nakama_socket:
			push_warning("创建Nakama Socket失败")
			_is_connecting = false
			return

	# 连接 Nakama Socket
	print("正在连接WebSocket到: %s://%s:%d" % ["wss" if  nakama_scheme == "https" else "ws", nakama_host, nakama_port])
	# print("Session token: %s" % session.token + "..." if session.token.length() > 20 else session.token)
	
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
		if exception.status_code != -1 and exception.grpc_status_code != -1:
			print("连接失败 - 可能的原因:")
			print("1. 服务器地址 %s:%d 无法访问" % [nakama_host, nakama_port])
			print("2. 网络连接问题")
			print("3. 防火墙阻止连接")
			print("4. TLS/SSL证书问题")
			_is_connecting = false
			socketStateSIG.emit("socket_error")
			# 尝试使用HTTP而不是HTTPS
			if nakama_scheme == "https":
				print("尝试切换到HTTP连接...")
				nakama_scheme = "http"
				nakama_client = null  # 重置client以使用新配置
				await _connect_socket(session)
				return
		#reconnectSIG.emit()
		#return
	print("网络nakama_socket连接 ->", nakama_socket.is_connected_to_host())
	if _check_connected():
		_on_socket_connected()
	pass

# 设置socket事件监听
func _setup_socket_events() -> void:

	# 断开连接时重置状态
	if not nakama_socket:
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
	

# 连接成功
func _on_socket_connected() -> void:
	print("连接Nakama Socket 成功")
	_is_connecting = false
	_is_disconnected = false
	socketStateSIG.emit("connected")
	# 监听socket事件
	_setup_socket_events()
	# 启动定时器
	start_timers()
	# 重连成功后，重试所有待处理的请求
	_retry_pending_requests()

# 网络错误
func _on_socket_error(err) -> void:
	print("网络异常——> ", err)
	_reset_reconnect_state()
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

####################重连#####################################	
func _reset_reconnect_state() -> void:
	_is_connecting = false
	_retry_count = 0
	_current_delay = BASE_RETRY_DELAY

func force_reconnect() -> void:
	_reset_reconnect_state()
	connect_nakama_socket()

# func _notification(what: int) -> void:
# 	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
# 		# 当游戏窗口重新获得焦点时检查连接
# 		if not _check_connected():
# 			connect_nakama_socket()
# 	pass
##############################################################################################
func connect_nakama_socket() -> void:
	print("连接Nakama Socket")
	await _connect_socket(nakama_session)
############################主动发送数据############################################################
func sendPing():
	if nakama_socket:
		var result = await nakama_socket.rpc_async("ping")
		if result.is_exception():
			print("发送心跳失败:", result.get_exception().message)
			reconnectSIG.emit()
		else:
			print("心跳发送成功")
	pass
# RPC 发送函数
func sendDataRPC(funcName: String, payload = null):
	print("发送RPC:", funcName, payload)
	if _is_disconnected:
		if funcName in NON_RETRY_API:
			PopupManager.show_dynamic("%s 失败: 网络断开" % funcName)
			return null
		_add_to_pending_requests(funcName, payload)
		return null
	if nakama_socket:
		var result = await nakama_socket.rpc_async(funcName, payload)
		if result.is_exception():
			if funcName in NON_RETRY_API:
				_handle_request_error(result, funcName)
				return null
			if _should_retry_request(result, funcName):
				_add_to_pending_requests(funcName, payload)
				return null
			else:
				_handle_request_error(result, funcName)
				return null
		_clear_request_retry_count(funcName)
		return result
	print("nakama_socket is null:", funcName, payload)
	return null

# 添加请求到待处理队列
func _add_to_pending_requests(funcName: String, payload = null) -> void:
	if funcName in NON_RETRY_API:
		print("接口", funcName, "配置为不自动重试，不加入重试队列")
		return
	var requests = {
		"funcName": funcName,
		"payload": payload,
		"timestamp": Time.get_unix_time_from_system()
	}
	# 检查是否已存在相同请求，避免重复
	for existing_request in _pending_requests:
		if existing_request.funcName == funcName and existing_request.payload == payload:
			print("请求已存在于队列中:", funcName)
			return
	_pending_requests.append(requests)
	print("请求已加入重试队列:", funcName, "队列长度:", _pending_requests.size())
	_check_connection()
	pass

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
	for error in Errors.NetworkErrors:
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
	
	for req in requests_to_retry:
		print("重试请求:", req.funcName)
		# 使用延迟避免请求过于密集
		await get_tree().create_timer(0.5).timeout
		sendDataRPC(req.funcName, req.payload)
	
	print("待处理请求重试完成")

# 清空待处理请求队列
func _clear_pending_requests() -> void:
	_pending_requests.clear()
	_request_retry_count.clear()
	print("已清空待处理请求队列")

# 获取待处理请求数量
func get_pending_requests_count() -> int:
	return _pending_requests.size()

# # 应用恢复焦点时检查连接
# func _notification(what: int) -> void:
# 	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
# 		# 当游戏窗口重新获得焦点时检查连接
# 		if not _check_connected():
# 			print("应用恢复焦点，检查连接状态")
# 			_check_connection()
# 	pass



# =================== 主请求入口 ===================
# 统一Nakama请求入口，自动处理断线、重试、恢复、弹窗
# 示例: Online.request("api_name", [参数...], 成功回调, 失败回调)
func Request(api: String, args: Array, success_cb: Callable, fail_cb: Callable) -> void:
	if not _check_connected():
		if api in NON_RETRY_API:
			_show_error(api, "网络断开")
			if fail_cb:
				fail_cb.call("网络断开")
			return
		_add_to_pending(api, args, success_cb, fail_cb)
		return
	var result = await _do_nakama_call(api, args)
	if result.is_exception():
		if api in NON_RETRY_API:
			_show_error(api, result.get_exception().message)
			if fail_cb:
				fail_cb.call(result.get_exception().message)
			return
		if _should_retry(result, api):
			_add_to_pending(api, args, success_cb, fail_cb)
			return
		_show_error(api, result.get_exception().message)
		if fail_cb:
			fail_cb.call(result.get_exception().message)
		return
	_clear_retry(api)
	if success_cb:
		success_cb.call(result)

# =================== 辅助函数 ===================
# 加入待恢复队列（避免重复）
func _add_to_pending(api, args, success_cb, fail_cb):
	for req in _pending_requests:
		if req.api == api and req.args == args:
			return
	_pending_requests.append({"api": api, "args": args, "success_cb": success_cb, "fail_cb": fail_cb})

# 判断是否可重试（网络错误且未超限）
func _should_retry(result, api):
	if not result.is_exception():
		return false
	var msg = result.get_exception().message
	var retry_count = _request_retry_count.get(api, 0)
	if retry_count >= REQUEST_RETRY_LIMIT:
		return false
	var network_errors = ["网络断开", "连接失败", "连接超时", "HTTPRequest failed!", "Invalid session.", "Session expired."]
	for error in network_errors:
		if msg.find(error) != -1:
			_request_retry_count[api] = retry_count + 1
			return true
	return false

# 弹窗显示错误
func _show_error(api, msg):
	PopupManager.show_dynamic("%s 失败: %s" % [api, msg])

# 清除接口重试计数
func _clear_retry(api):
	if _request_retry_count.has(api):
		_request_retry_count.erase(api)

# 检查socket是否已连接
func _check_connected():
	print("检查socket连接状态", nakama_socket != null)
	if nakama_socket:
		print("已连接主机:",nakama_socket.is_connected_to_host())
	return nakama_socket and nakama_socket.is_connected_to_host()

# 统一Nakama接口调用
func _do_nakama_call(api, args):
	if not nakama_client:
		return null
	if not nakama_client.has_method(api):
		return null
	return await nakama_client.callv(api, args)

# =================== 网络诊断工具 ===================
# 测试网络连接
func test_network_connection() -> void:
	print("=== 网络连接诊断 ===")
	print("服务器配置:")
	print("  Host: %s" % nakama_host)
	print("  Port: %d" % nakama_port)
	print("  Scheme: %s" % nakama_scheme)
	print("  Server Key: %s" % nakama_server_key)
	
	# 测试HTTP连接
	print("\n测试HTTP连接...")
	var http_client = HTTPRequest.new()
	add_child(http_client)
	
	var test_url = "%s://%s:%d/v2/console/config" % [nakama_scheme, nakama_host, nakama_port]
	print("测试URL: %s" % test_url)
	
	http_client.request_completed.connect(_on_http_test_completed)
	http_client.request(test_url)
	
	# 等待响应
	await http_client.request_completed
	
	# 清理
	http_client.queue_free()

# HTTP测试回调
func _on_http_test_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	print("HTTP测试结果:")
	print("  结果代码: %d" % result)
	print("  响应代码: %d" % response_code)
	
	if result == HTTPRequest.RESULT_SUCCESS:
		if response_code == 200:
			print("  ✓ HTTP连接成功")
		else:
			print("  ⚠ HTTP连接成功但响应码异常: %d" % response_code)
	else:
		print("  ✗ HTTP连接失败")
		print("  可能的原因:")
		print("    1. 服务器地址 %s:%d 无法访问" % [nakama_host, nakama_port])
		print("    2. 网络连接问题")
		print("    3. 防火墙阻止连接")
		print("    4. 服务器未运行")

# 测试WebSocket连接
func test_websocket_connection() -> void:
	print("\n=== WebSocket连接测试 ===")
	if not nakama_session:
		print("✗ 没有有效的session，无法测试WebSocket")
		return
		
	print("Session信息:")
	print("  User ID: %s" % nakama_session.user_id)
	print("  Username: %s" % nakama_session.username)
	print("  Token: %s..." % nakama_session.token.substr(0, 20))
	print("  Expired: %s" % nakama_session.is_expired())
	
	# 尝试连接WebSocket
	print("\n尝试WebSocket连接...")
	await _connect_socket(nakama_session)

# 重置连接配置
func reset_connection_config() -> void:
	print("=== 重置连接配置 ===")
	nakama_client = null
	nakama_socket = null
	_is_connecting = false
	_is_disconnected = true
	_retry_count = 0
	_current_delay = BASE_RETRY_DELAY
	_request_retry_count.clear()
	_pending_requests.clear()
	print("连接配置已重置")

# 切换连接协议
func switch_protocol(new_scheme: String) -> void:
	print("=== 切换连接协议 ===")
	print("从 %s 切换到 %s" % [nakama_scheme, new_scheme])
	nakama_scheme = new_scheme
	reset_connection_config()
	
	if nakama_session:
		print("使用新协议重新连接...")
		await _connect_socket(nakama_session)
