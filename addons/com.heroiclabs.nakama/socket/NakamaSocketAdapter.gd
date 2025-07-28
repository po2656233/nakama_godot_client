@tool
extends Node

class_name NakamaSocketAdapter

var _ws := WebSocketPeer.new()
var _ws_last_state := WebSocketPeer.STATE_CLOSED
var _timeout : int = 30
var _start : int = 0
var logger = NakamaLogger.new()

signal connected()
signal closed()
signal received_error(p_exception)
signal received(p_bytes) # PackedByteArray

# 自动重连参数
var _auto_reconnect := true
var _reconnect_delay := 2.0
var _max_reconnect_delay := 10.0
var _reconnect_attempts := 0
var _last_uri := ""
var _last_timeout := 30
var _reconnect_timer:Timer= null
var _token_expired_for_reconnect := false

# token刷新相关
var _refresh_session_func: Callable
func set_refresh_session_func(func_callable:Callable):
	_refresh_session_func = func_callable

func is_connected_to_host():
	return _ws.get_ready_state() == WebSocketPeer.STATE_OPEN

func is_connecting_to_host():
	return _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING

func close():
	print("websocket 已关闭")
	_ws.close()
	_auto_reconnect = false

func connect_to_host(p_uri : String, p_timeout : int):
	_last_uri = p_uri
	_last_timeout = p_timeout
	_reconnect_attempts = 0
	_reconnect_delay = 2.0
	_auto_reconnect = true
	_do_connect()

func _do_connect():
	if _ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws.close()
	_timeout = _last_timeout
	_start = Time.get_unix_time_from_system()
	print("WebSocket连接URI: %s 连接超时时间: %d秒" % [_last_uri, _timeout])
	var use_tls = _last_uri.begins_with("wss://")
	var tls_options = null
	if use_tls:
		tls_options = TLSOptions.client_unsafe()
		print("使用TLS连接 (不安全模式)")
	else:
		print("使用非TLS连接")
	var err = _ws.connect_to_url(_last_uri, tls_options)
	if err != OK:
		logger.debug("Error connecting to host %s: %d" % [_last_uri, err])
		print("WebSocket连接失败，错误代码: %d" % err)
		call_deferred("emit_signal", "received_error", err)
		return
	_ws_last_state = WebSocketPeer.STATE_CLOSED
	set_process(true)

func _on_need_reconnect(token_expired := false):
	if not _auto_reconnect:
		return
	_reconnect_attempts += 1
	_reconnect_delay = min(_reconnect_delay * 2, _max_reconnect_delay)
	_token_expired_for_reconnect = token_expired
	print("Socket断开，%d秒后自动重连（第%d次）...%s" % [_reconnect_delay, _reconnect_attempts,token_expired])
	if _reconnect_timer:
		_reconnect_timer.queue_free()
	_reconnect_timer = Timer.new()
	_reconnect_timer.one_shot = true
	_reconnect_timer.wait_time = _reconnect_delay
	add_child(_reconnect_timer)
	_reconnect_timer.timeout.connect(_on_reconnect_timer_timeout)
	_reconnect_timer.start()

func _on_reconnect_timer_timeout():
	if not is_instance_valid(self):
		return
	if _token_expired_for_reconnect and _refresh_session_func != null:
		print("检测到token过期，自动刷新session...")
		var ret = await _refresh_session_func.call()
		if ret and ret.token:
			print("重组URL")
			var token_str = "&token="
			var uris = _last_uri.split(token_str)
			if uris.size()>1:
				uris[1] = ret.token
				_last_uri = uris[0]+token_str+uris[1]
				print("重组URL",_last_uri)
	_do_connect()

func send(p_buffer : PackedByteArray, p_reliable : bool = true) -> int:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var ret = _ws.send(p_buffer, WebSocketPeer.WRITE_MODE_TEXT)
		if ret != OK:
			print('网络错误 ',ret) 
		return ret
	return FAILED

func _process(_delta):
	if _ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws.poll()
	var state = _ws.get_ready_state()
	if _ws_last_state != state:
		_ws_last_state = state
		if state == WebSocketPeer.STATE_OPEN:
			connected.emit()
			_reconnect_attempts = 0
			_reconnect_delay = 2.0
			if _reconnect_timer:
				_reconnect_timer.queue_free()
				_reconnect_timer = null
		elif state == WebSocketPeer.STATE_CLOSED:
			var reason = _ws.get_close_reason()
			var code = _ws.get_close_code()
			print("get_close_reason: %s (%d)" % [reason, code])
			closed.emit()
			set_process(false)
			# 检查token过期（401）自动刷新
			if str(reason).find("401") != -1 or code == 401 or code == -1:
				_on_need_reconnect(true)
			else:
				_on_need_reconnect()
	if state == WebSocketPeer.STATE_CONNECTING:
		if _start + _timeout < Time.get_unix_time_from_system() and _timeout != -1:
			logger.debug("Timeout when connecting to socket")
			received_error.emit(ERR_TIMEOUT)
			_ws.close()
			set_process(false)
			_on_need_reconnect()
	while _ws.get_ready_state() == WebSocketPeer.STATE_OPEN and _ws.get_available_packet_count():
		received.emit(_ws.get_packet())
