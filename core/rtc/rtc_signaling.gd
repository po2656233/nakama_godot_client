extends Node

## 模块：RTC 信令网关（Global.RtcSignaling，PROMPT_REFACTOR 阶段 3）
## 职责：
##   1. 维护通话状态机（IDLE/OUTGOING/INCOMING/IN_CALL）；
##   2. 通过 Nakama match state 收发 CALL_INVITE/ACCEPT/REJECT/HANGUP/OFFER/ANSWER/ICE；
##   3. 转发音频/视频帧（base64 内联，调用方控制帧率与体积）。
## 依赖：Global.OnlineGame / Global.OnlineMatch / Global.SignalMgr / Globals.OnlineLogin。
## 说明：
##   - 信令复用对局通道（op_code = RtcProtocol.op_code(Kind)），不需要额外服务端；
##   - 无 socket（单机/headless）时 `_send()` 只告警并返回 false，状态机仍可本地演练；
##   - 为不直接依赖某些服务的具体实现，统一用 has_global + has_method 守卫。

signal call_invited(peer_id: String, video: bool)
signal call_incoming(peer_id: String, video: bool)
signal call_accepted(peer_id: String)
signal call_rejected(peer_id: String, reason: String)
signal call_ended(peer_id: String, reason: String)
signal offer_received(peer_id: String, sdp: String)
signal answer_received(peer_id: String, sdp: String)
signal ice_received(peer_id: String, candidate: String)
signal audio_received(peer_id: String, frames: PackedByteArray)
signal video_received(peer_id: String, jpeg: PackedByteArray)
signal state_changed(state: int)

var call_state: int = RtcProtocol.CallState.IDLE
var peer_id: String = ""
var is_video_call := false

func _ready() -> void:
	if Global.has_global("SignalMgr"):
		Global.SignalMgr.MatchStateEventSIG.connect(_on_match_state_event)
	if Global.has_global("SignalMgr"):
		Global.SignalMgr.RecvMessageSIG.connect(_on_chat_message)

# ---------------------------------------------------------------------
# 对外 API
# ---------------------------------------------------------------------

## 主动发起通话。
func invite(peer: String, video: bool = false) -> bool:
	if call_state != RtcProtocol.CallState.IDLE:
		push_warning("[RtcSignaling] 当前已在通话状态: %d" % call_state)
		return false
	peer_id = peer
	is_video_call = video
	_set_state(RtcProtocol.CallState.OUTGOING)
	return _send(RtcProtocol.Kind.CALL_INVITE, {"from": _my_id(), "video": video})

## 兼容 PROMPT_REFACTOR 约定的入口名。
func start_call(target_user_id: String, is_video: bool = false) -> bool:
	return invite(target_user_id, is_video)
## 接听来电。
func accept() -> bool:
	if call_state != RtcProtocol.CallState.INCOMING and call_state != RtcProtocol.CallState.OUTGOING:
		return false
	_set_state(RtcProtocol.CallState.IN_CALL)
	var ok := _send(RtcProtocol.Kind.CALL_ACCEPT, {"from": _my_id()})
	call_accepted.emit(peer_id)
	return ok

## 拒接来电。
func reject(reason: String = "busy") -> bool:
	if call_state != RtcProtocol.CallState.INCOMING:
		return false
	var remote := peer_id
	var ok := _send(RtcProtocol.Kind.CALL_REJECT, {"from": _my_id(), "reason": reason})
	_reset()
	call_rejected.emit(remote, reason)
	return ok

## 挂断 / 结束通话。
func hang_up(reason: String = "hangup") -> bool:
	if call_state == RtcProtocol.CallState.IDLE:
		return false
	var remote := peer_id
	var ok := _send(RtcProtocol.Kind.CALL_HANGUP, {"from": _my_id(), "reason": reason})
	_reset()
	call_ended.emit(remote, reason)
	return ok

func send_offer(sdp: String) -> bool:
	return _send(RtcProtocol.Kind.OFFER, {"from": _my_id(), "sdp": sdp})

func send_answer(sdp: String) -> bool:
	return _send(RtcProtocol.Kind.ANSWER, {"from": _my_id(), "sdp": sdp})

func send_ice(candidate: String) -> bool:
	return _send(RtcProtocol.Kind.ICE, {"from": _my_id(), "candidate": candidate})

## 发送一帧音频（PCM 浮点字节，来自 RtcMedia.audio_frame）。
func send_audio(frames: PackedByteArray) -> bool:
	if frames.is_empty():
		return false
	return _send(RtcProtocol.Kind.AUDIO, {"from": _my_id(), "n": frames.size(), "b64": RtcProtocol.encode_bytes(frames)})

## 发送一帧视频（JPEG 字节）。
func send_video(jpeg: PackedByteArray) -> bool:
	if jpeg.is_empty():
		return false
	return _send(RtcProtocol.Kind.VIDEO, {"from": _my_id(), "b64": RtcProtocol.encode_bytes(jpeg)})

func is_active() -> bool:
	return call_state == RtcProtocol.CallState.IN_CALL

func reset() -> void:
	_reset()

## 外部/测试入口：直接注入一条 RTC 数据包（正常由 MatchStateEventSIG 驱动）。
func handle_packet(op_value: int, data: String, from_peer: String = "") -> void:
	if not RtcProtocol.is_rtc_op(op_value):
		return
	var packet := RtcProtocol.decode(data)
	if packet.is_empty():
		return
	var payload: Dictionary = packet["p"]
	var sender := from_peer
	if sender.is_empty():
		sender = str(payload.get("from", ""))
	_handle_kind(int(packet["k"]), payload, sender)

# ---------------------------------------------------------------------
# 接收
# ---------------------------------------------------------------------

## 处理频道里的 RTC 信令（{"rtc": {to, from, k, p}}）。
func _on_chat_message(message: Variant) -> void:
	if message == null:
		return
	var raw: Variant = ""
	if message is Dictionary:
		raw = message.get("content", "")
	elif message.get("content") != null:
		raw = message.get("content")
	if not raw is String or str(raw).is_empty():
		return
	var json := JSON.new()
	if json.parse(str(raw)) != OK or not json.data is Dictionary:
		return
	var rtc: Variant = (json.data as Dictionary).get("rtc", null)
	if not rtc is Dictionary:
		return
	var packet: Dictionary = rtc
	if str(packet.get("to", "")) != _my_id():
		return
	var kind := int(packet.get("k", 0))
	var payload: Variant = packet.get("p", {})
	var sender := str(packet.get("from", ""))
	_handle_kind(kind, payload if payload is Dictionary else {}, sender)

func _on_match_state_event(event: Variant) -> void:
	if event == null:
		return
	var op_value: int = int(event.get("op_code")) if event.get("op_code") != null else 0
	if op_value == 0:
		return
	var data: String = str(event.get("data")) if event.get("data") != null else ""
	var sender := ""
	var presence = event.get("presence")
	if presence != null:
		sender = str(presence.get("user_id")) if presence.get("user_id") != null else ""
	handle_packet(op_value, data, sender)

func _handle_kind(kind: int, payload: Dictionary, sender: String) -> void:
	match kind:
		RtcProtocol.Kind.CALL_INVITE:
			if call_state != RtcProtocol.CallState.IDLE:
				_send(RtcProtocol.Kind.CALL_REJECT, {"from": _my_id(), "reason": "busy"})
				return
			peer_id = sender
			is_video_call = bool(payload.get("video", false))
			_set_state(RtcProtocol.CallState.INCOMING)
			call_invited.emit(peer_id, is_video_call)
			call_incoming.emit(peer_id, is_video_call)
		RtcProtocol.Kind.CALL_ACCEPT:
			if call_state == RtcProtocol.CallState.OUTGOING:
				_set_state(RtcProtocol.CallState.IN_CALL)
				call_accepted.emit(peer_id)
		RtcProtocol.Kind.CALL_REJECT:
			if call_state != RtcProtocol.CallState.IDLE:
				var remote := peer_id
				_reset()
				call_rejected.emit(remote, str(payload.get("reason", "")))
		RtcProtocol.Kind.CALL_HANGUP:
			if call_state != RtcProtocol.CallState.IDLE:
				var remote := peer_id
				_reset()
				call_ended.emit(remote, str(payload.get("reason", "")))
		RtcProtocol.Kind.OFFER:
			offer_received.emit(sender, str(payload.get("sdp", "")))
		RtcProtocol.Kind.ANSWER:
			answer_received.emit(sender, str(payload.get("sdp", "")))
		RtcProtocol.Kind.ICE:
			ice_received.emit(sender, str(payload.get("candidate", "")))
		RtcProtocol.Kind.AUDIO:
			audio_received.emit(sender, RtcProtocol.decode_bytes(str(payload.get("b64", ""))))
		RtcProtocol.Kind.VIDEO:
			video_received.emit(sender, RtcProtocol.decode_bytes(str(payload.get("b64", ""))))

# ---------------------------------------------------------------------
# 发送
# ---------------------------------------------------------------------

## 大厅/房间没有对局时走 Nakama Open 频道（rtc_signal），有对局时同样可用。
func _send(kind: int, payload: Dictionary) -> bool:
	if not Global.has_global("Online") or not bool(Global.Online.is_socket_connected):
		push_warning("[RtcSignaling] socket 未连接，跳过信令发送: %d" % kind)
		return false
	if Global.has_global("OnlineChat") and Global.OnlineChat.has_method("send_rtc_signal"):
		# 协程后台发送；失败只打日志，不阻塞 UI。
		Global.OnlineChat.send_rtc_signal(peer_id, kind, payload)
		return true
	if Global.has_global("OnlineGame"):
		Global.OnlineGame.sendToMatch(RtcProtocol.op_code(kind), RtcProtocol.encode(kind, payload))
		return true
	return false

func _my_id() -> String:
	if Global.has_global("OnlineLogin"):
		return str(Global.OnlineLogin.get_my_id())
	return ""

func _set_state(state: int) -> void:
	if call_state == state:
		return
	call_state = state
	state_changed.emit(state)

func _reset() -> void:
	peer_id = ""
	is_video_call = false
	_set_state(RtcProtocol.CallState.IDLE)
