extends Node

#signal socketStateSIG(state: String)
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

# 心跳管理
var heartbeat_timer: Timer
const HEARTBEAT_INTERVAL = 10.0  # 15秒发送一次心跳

# 连接状态
var is_socket_connected = false
var last_activity_time = 0
const ACTIVITY_TIMEOUT = 30.0  # 30秒无活动视为断开
var linkCount = 0
# 广播枚举
enum EnBroadcast{
	CreateTable = 1, # 创建桌子
	RemoveTable = 2, # 删除桌子
	JoinTable = 3, # 加入桌子
	LeaveTable = 4, # 离开桌子
	TableOnline = 5, # 桌子在线人数
}  


# socket状态
var socket_state = {
	"connected":"连接成功",
	"disconnected":"连接断开",
	"reconnecting":"正在重连...",
	"restoring_session":"正在恢复会话...",
	"socket_error":"网络连接出错...",
}

###################################################################################
### 初始化
func _ready() -> void:
	nakama_client = get_nakama_client()
	pass
###################################################################################
### 设置session
func set_nakama_session(_nakama_session: NakamaSession) -> void:	
	nakama_session = _nakama_session
	if nakama_session == null:
		print("传入的session为null,关闭socket连接")
		if heartbeat_timer:heartbeat_timer.stop()
		if nakama_socket:nakama_socket.close()  
		nakama_socket = null# 如果传入的session为null，关闭socket连接
		return
	create_and_connect_socket()
	print("获取到session:\t",_nakama_session,"\n")
	pass

### 获取NakamaClient
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

### 获取NakamaSession
func get_nakama_session() -> NakamaSession:
	return nakama_session
	
### 获取nakama_socket
func get_nakama_socket():
	return nakama_socket
#################################【网络连接】############################################
### 创建并连接Socket
func create_and_connect_socket():
	if nakama_session == null:
		push_error("Session is null, cannot create socket")
		return
	if not nakama_socket:
		print("Create socket")
		nakama_socket = Nakama.create_socket_from(nakama_client)
		# 监听socket事件
		_listen_socket_events()
		# 匹配服重置socket
		OnlineMatch._set_nakama_socket(nakama_socket)
	linkCount+=1
	# 开始连接（正确使用官方API）
	print("Connecting to socket...",linkCount)
	var connect_result = await nakama_socket.connect_async(nakama_session, true,20)  # 仅session和appear_online参数
	if connect_result.is_exception():
		print("Socket connection failed: " , connect_result)
		#schedule_reconnect()
		return
	
	print("Socket connected successfully")
	is_socket_connected = true
	
	# 初始化心跳
	start_heartbeat()
	pass

### 启动心跳机制
func start_heartbeat():
	# 创建心跳计时器
	heartbeat_timer = Timer.new()
	add_child(heartbeat_timer)
	heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
	heartbeat_timer.timeout.connect(_send_heartbeat)
	heartbeat_timer.start()
	
	# 初始化最后活动时间
	last_activity_time = Time.get_unix_time_from_system()
	
	print("Heartbeat started")

### 发送心跳
func _send_heartbeat():
	if !is_connected or not nakama_socket:
		return
	# 发送心跳消息
	var result = await nakama_socket.rpc_async("ping")
	if result.is_exception():
		push_error("Heartbeat failed: " + result.exception.message)
		#_on_socket_closed()
		schedule_reconnect()
		return
	# 更新最后活动时间
	last_activity_time = Time.get_unix_time_from_system()
	if last_activity_time+20 > nakama_session.expire_time:
		push_error("Session expired")
		_reseet_session()
		return
	print("Heartbeat sent and acknowledged")

### 重置会话
func _reseet_session():
	if not nakama_session:
		push_error("No session to reset")
		return
	var result = await nakama_socket.connect_async(nakama_session, true)  # 重新连接socket
	if result.is_exception():
		push_error("Failed to reset session: " + result.exception.message)
		return
	nakama_session = result
	print("Session reset successfully")

# 检测连接活动
func check_connection_activity():
	if !is_connected:
		return
	
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_activity_time > ACTIVITY_TIMEOUT:
		push_warning("Connection inactive for too long. Assuming disconnected.")
		_on_socket_closed()
	pass

### 设置socket事件监听
func _listen_socket_events() -> void:
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
	pass

# 信号处理函数 ========================================
### socket连接事件处理
func _on_socket_connected():
	print("Socket connected event received")
	is_socket_connected = true
	last_activity_time = Time.get_unix_time_from_system()

### socket关闭事件处理
func _on_socket_closed():
	print("Socket closed event received")
	is_socket_connected = false
	if heartbeat_timer:
		heartbeat_timer.stop()
	schedule_reconnect()

### 处理socket错误
func _on_socket_error(error):
	push_error("Socket error: " + str(error))
	if error == ERR_TIMEOUT:
		PopupManager.show_dynamic("连接超时,请稍后重试")
	is_socket_connected = false
	if heartbeat_timer:
		heartbeat_timer.stop()

# 收到匹配数据
func _on_received_matchmaker_matched(matchmaker_matched):
	last_activity_time = Time.get_unix_time_from_system()# 更新最后活动时间
	SignalManager.MatchMakerSIG.emit(matchmaker_matched)
	pass

# 收到匹配状态
func _on_received_match_state(match_state):
	last_activity_time = Time.get_unix_time_from_system()# 更新最后活动时间
	SignalManager.MatchStateEventSIG.emit(match_state)
	pass

# 收到匹配玩家数据
func _on_received_match_presence(match_presence):
	last_activity_time = Time.get_unix_time_from_system()# 更新最后活动时间
	print("收到匹配的玩家数据:", match_presence)
	SignalManager.MatchPresenceEventSIG.emit(match_presence)
	pass

# 收到状态数据
func _on_received_status_presence(status_presence):	
	last_activity_time = Time.get_unix_time_from_system()# 更新最后活动时间
	SignalManager.StatusPresenceEventSIG.emit(status_presence)
	pass

# 收到通知
func _on_received_notification(notification1):
	last_activity_time = Time.get_unix_time_from_system()# 更新最后活动时间
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

# 收到频道消息
func _on_channel_presence(channel_presence):
	var _1 = channel_presence
	pass

# 接收消息
func _on_received_message(channel_message):
	last_activity_time = Time.get_unix_time_from_system()# 更新最后活动时间
	print("收到消息:", channel_message)
	SignalManager.RecvMessageSIG.emit(channel_message)
	pass

# 全局信号转发
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

# 重连逻辑 ==========================================
func schedule_reconnect():
	# 指数退避重连策略
	var delay = 1.0 + randf() * 2.0  # 1-3秒随机延迟防止重连风暴
	
	print("Scheduling reconnect in ", delay, " seconds")
	
	# 创建定时器执行重连
	var timer = Timer.new()
	add_child(timer)
	timer.one_shot = true
	timer.wait_time = delay
	timer.timeout.connect(_perform_reconnect)
	timer.start()

func _perform_reconnect():
	print("Attempting reconnect...")
	create_and_connect_socket()

# 游戏生命周期管理 ==================================

func _notification(what):
	# 失去焦点时暂停心跳
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		print("App lost focus. Pausing heartbeat.")
		if heartbeat_timer:
			heartbeat_timer.paused = true
	
	# 获得焦点时恢复心跳
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		print("App gained focus. Resuming heartbeat.")
		if heartbeat_timer:
			heartbeat_timer.paused = false
			# 立即发送心跳检测连接状态
			_send_heartbeat()

############################主动发送数据############################################################
# RPC 发送函数
func sendDataRPC(funcName: String, payload = null,obj:Object=null,work_cb:String="_on_work"):
	print("发送RPC:", funcName, payload)
	var result_wrapper = { "result":null}  # 使用字典包装变量
	var sucess_cb = func(ret:NakamaAsyncResult):
		if ret and ret.id == funcName:
			result_wrapper.result = JSON.parse_string(ret.payload)
			# 外部有处理函数,再发送信号
			if obj != null:
				# 动态创建信号，并且根据外部obj和work_cb名称进行处理
				var sigName = funcName+"SIG"
				if not has_signal(sigName):
					add_user_signal(sigName, result_wrapper.result)
				#disconnect(sigName,Callable(obj,work_cb))
				if is_connected(sigName,Callable(obj,work_cb)):
					disconnect(sigName,Callable(obj,work_cb))
				connect(sigName,Callable(obj,work_cb))
				emit_signal(sigName,result_wrapper.result) 
			print("接收RPC成功,发送信号:",funcName+"SIG") 
			return
		result_wrapper.result = ret  # 修改字典中的值
		pass
	var failed_cb = func(ret):
		print("发送RPC失败:",funcName," -->结果:", ret)
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
