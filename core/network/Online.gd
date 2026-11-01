extends Node

## 服务器配置
const SERVER_CONFIG = {
	"server_key": "superman",
	"host": "172.18.4.172", # 'trytry.asia'
	"port_http": 7350,
	"port_https": 8850,
	"scheme_web": "http",
	"scheme_native": "https"
}

var nakama_server_key: String = SERVER_CONFIG.server_key
var nakama_host: String = SERVER_CONFIG.host
var nakama_port: int = SERVER_CONFIG.port_https
var nakama_scheme: String = SERVER_CONFIG.scheme_native

var _client: NakamaClient = null
var _session: NakamaSession = null

## 客户端懒加载；内部用 _client 作为后端，避免 getter 自递归。
var nakama_client: NakamaClient:
	get:
		return get_nakama_client()
	set(value):
		_client = value

## 会话赋值即触发 Socket 连接/断开；内部用 _session 作为后端。
var nakama_session: NakamaSession:
	get:
		return _session
	set(value):
		_apply_session(value)

var nakama_socket: NakamaSocket = null

func _init() -> void:
	if OS.has_feature("web"):
		nakama_port = SERVER_CONFIG.port_http
		nakama_scheme = SERVER_CONFIG.scheme_web

# 心跳管理
var heartbeat_timer: Timer
var is_ping_now: bool = false
var is_socket_connected: bool = false
var is_socket_reset: bool = false
var is_socket_close: bool = false
const HEARTBEAT_INTERVAL: float = 5.0

# 广播枚举
enum EnBroadcast {
	CreateTable = 1,
	RemoveTable = 2,
	JoinTable = 3,
	LeaveTable = 4,
	TableOnline = 5,
}

enum EnAbnormal {
	OtherLogon = 115,
}

func _ready() -> void:
	get_nakama_client()

## 兼容旧调用：等价于 Online.nakama_session = value。
func set_nakama_session(value: NakamaSession) -> void:
	nakama_session = value

## 会话变化时统一处理 Socket：有会话则连接，无会话则断开。
func _apply_session(value: NakamaSession) -> void:
	_session = value
	if _session == null:
		is_socket_reset = true
		if nakama_socket:
			nakama_socket.close()
		nakama_socket = null
		return
	is_socket_reset = false
	create_and_connect_socket()
	print("Session acquired: %s" % str(_session))

func get_nakama_client() -> NakamaClient:
	if _client == null:
		_client = Nakama.create_client(
			nakama_server_key,
			nakama_host,
			nakama_port,
			nakama_scheme,
			Nakama.DEFAULT_TIMEOUT,
			NakamaLogger.LOG_LEVEL.ERROR)
	return _client

func get_nakama_session() -> NakamaSession:
	return _session

func create_and_connect_socket() -> void:
	if nakama_session == null:
		push_error("Session is null, cannot create socket")
		return

	nakama_socket = Nakama.create_socket_from(nakama_client)
	_listen_socket_events()

	if Global.has_global("OnlineMatch"):
		Global.OnlineMatch._set_nakama_socket(nakama_socket)

	var connect_result = await nakama_socket.connect_async(nakama_session, true, -1, _reset_session)
	if connect_result is int or (connect_result is NakamaAsyncResult and connect_result.is_exception()):
		print("Socket connection failed: %s" % str(connect_result))
		return

	print("Socket connected successfully")
	start_heartbeat()

func _reset_session() -> NakamaSession:
	if not nakama_session:
		push_error("No session to reset")
		return null

	var result = await nakama_client.session_refresh_async(nakama_session)
	if result == null or result.is_exception():
		push_error("Failed to reset session: %s" % str(result))
		return nakama_session

	print("Session reset successfully")
	_session = result
	return result

func start_heartbeat() -> void:
	if heartbeat_timer == null:
		heartbeat_timer = Timer.new()
		add_child(heartbeat_timer)
		heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
		heartbeat_timer.timeout.connect(_send_heartbeat)
		heartbeat_timer.start()

func _send_heartbeat() -> void:
	if is_ping_now or not is_socket_connected:
		return
	is_ping_now = true
	var result = await nakama_socket.rpc_async("ping")
	is_ping_now = false
	if result.is_exception():
		print("Heartbeat failed: %s" % str(result.exception.message))
	else:
		print("Heartbeat success")

func _listen_socket_events() -> void:
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

func _on_socket_connected() -> void:
	is_socket_connected = true
	if Global.has_global("SignalMgr"):
		Global.SignalMgr.UpdateSocketSIG.emit(nakama_socket)
	if is_socket_close:
		Global.WindowPopup.show_dynamic("Network restored")
	is_socket_close = false
	print("Socket connected")

func _on_socket_closed() -> void:
	is_socket_connected = false
	if not is_socket_reset:
		is_socket_close = true
		Global.WindowPopup.show_dynamic("Connection lost. Please check your network.")

func _on_socket_error(error) -> void:
	print("Socket error: %s" % str(error))
	Global.WindowPopup.show_dynamic("Connection error: %s" % str(error))

func _on_received_matchmaker_matched(matchmaker_matched) -> void:
	Global.SignalMgr.MatchMakerSIG.emit(matchmaker_matched)

func _on_received_match_state(match_state) -> void:
	Global.SignalMgr.MatchStateEventSIG.emit(match_state)

func _on_received_match_presence(match_presence) -> void:
	if match_presence.match_id:
		Global.OnlineMatch.set_match_id(match_presence.match_id)
	Global.SignalMgr.MatchPresenceEventSIG.emit(match_presence)

func _on_received_status_presence(status_presence) -> void:
	Global.SignalMgr.StatusPresenceEventSIG.emit(status_presence)

func _on_received_notification(notification1) -> void:
	match notification1.subject:
		"broadcast":
			do_broadcast(notification1)
		_:
			do_abnormal(notification1)

func _on_received_message(channel_message) -> void:
	Global.SignalMgr.RecvMessageSIG.emit(channel_message)

func do_broadcast(notification1) -> void:
	var content = JSON.parse_string(notification1.content)
	match notification1.code:
		EnBroadcast.CreateTable:
			Global.SignalMgr.CreateRoomSIG.emit(content)
		EnBroadcast.RemoveTable:
			Global.SignalMgr.RemoveRoomSIG.emit(content)
		EnBroadcast.JoinTable:
			Global.SignalMgr.JoinRoomSIG.emit(content)
		EnBroadcast.LeaveTable:
			Global.SignalMgr.LeaveRoomSIG.emit(content)
		EnBroadcast.TableOnline:
			Global.SignalMgr.OnlineCountSIG.emit(content)
		_:
			push_warning("Unknown broadcast code: %s" % str(notification1.code))

func do_abnormal(notification1) -> void:
	var content = JSON.parse_string(notification1.content)
	match notification1.code:
		EnAbnormal.OtherLogon:
			Global.OnlineLogin.logout(false)
			Global.WindowPopup.show_message(content.get("message", "Other logon detected"), "Warning", false)
			Global.SceneMgr.switch_to_scene("login", Global.SceneMgr.get_transition_key("WIPE_LEFT"), 0.5)

## 业务 RPC：发送并解析服务端返回的 JSON。
## obj/work_cb/error_cb 保留旧约定：有回调对象时直接调用其方法。
func sendDataRPC(
	func_name: String,
	payload = null,
	obj: Object = null,
	work_cb: String = "_on_work",
	error_cb: String = "_on_err"
) -> Variant:
	if nakama_socket == null:
		var offline_message := "网络未连接"
		push_error("[Online] sendDataRPC 失败：socket 未连接")
		_notify_rpc_error(obj, error_cb, offline_message)
		return null

	var result = await nakama_socket.rpc_async(func_name, payload)
	if result == null or (result is NakamaAsyncResult and result.is_exception()):
		var error_text := "RPC 调用失败"
		if result is NakamaAsyncResult:
			error_text = Errors.humanize(result.get_exception().message)
		push_warning("[Online] RPC %s 失败: %s" % [func_name, error_text])
		_notify_rpc_error(obj, error_cb, error_text)
		return null

	var parsed = JSON.parse_string(result.payload)
	if obj != null and obj.has_method(work_cb):
		obj.call(work_cb, parsed)
	return parsed

func _notify_rpc_error(obj: Object, error_cb: String, message: String) -> void:
	if obj != null and obj.has_method(error_cb):
		obj.call(error_cb, message)

## 兼容旧调用：只关心成功/失败回调的 RPC。
func asyncDataRPC(
	func_name: String,
	payload = null,
	success_cb: Callable = Util.EMPTY_CALLABLE,
	failure_cb: Callable = Util.EMPTY_CALLABLE
) -> void:
	if nakama_socket == null:
		if failure_cb.is_valid():
			failure_cb.call("网络未连接")
		return
	var result = await nakama_socket.rpc_async(func_name, payload)
	if result == null or result.is_exception():
		if failure_cb.is_valid():
			failure_cb.call(Errors.humanize(result.get_exception().message) if result != null else "RPC 调用失败")
		return
	if success_cb.is_valid():
		success_cb.call(JSON.parse_string(result.payload))

## 现代化的 RPC 调用封装
## 直接使用 await 调用此函数即可获取结果
func call_rpc(func_name: String, payload = null) -> Variant:
	if not nakama_socket:
		push_error("Socket not connected")
		return null

	print("Sending RPC: %s, payload: %s" % [func_name, str(payload)])
	var result = await nakama_socket.rpc_async(func_name, payload)

	if result.is_exception():
		print("RPC %s failed: %s" % [func_name, str(result.exception.message)])
		return null

	var parsed = JSON.parse_string(result.payload)
	print("RPC %s success" % func_name)
	return parsed

func send_match_state(p_match_id: String, p_op_code: int, p_data: String, p_presences = null):
	return nakama_socket.send_match_state_async(p_match_id, p_op_code, p_data, p_presences)
