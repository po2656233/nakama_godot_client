extends SceneTree

## 阶段 3 验收测试：RTC 信令协议 + 状态机 + 采集服务 + UI 组件。
##
## 覆盖：
##   1. RtcProtocol 编解码 / op_code 映射 / base64；
##   2. RtcSignaling 状态机（invite/accept/reject/hangup、offer/answer/ice、音视频帧）；
##   3. RtcMedia 无设备降级（不崩溃、返回 false/null）；
##   4. CallModal / RtcVideoGrid 场景可加载并实例化。
##
## 用法：godot --headless --path . --script res://tools/test_rtc.gd

const PROTOCOL_SCRIPT := "res://core/rtc/rtc_protocol.gd"
const CALL_MODAL := "res://shared/ui/rtc/CallModal.tscn"
const VIDEO_GRID := "res://shared/ui/rtc/RtcVideoGrid.tscn"

var _passed := 0
var _failed := 0
var _done := false
var _invited: Array = []
var _accepted: Array = []
var _rejected: Array = []
var _ended: Array = []
var _offers: Array = []
var _audio: Array = []

func _init() -> void:
	_run.call_deferred()
	_guard.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	var global := root.get_node_or_null("Global")
	_check(global != null, "Global 自动加载存在")
	if global == null:
		_finish()
		return

	# 1) 协议
	var protocol: Script = load(PROTOCOL_SCRIPT)
	_check(protocol != null, "RtcProtocol 可加载")
	if protocol != null:
		var constants: Dictionary = protocol.get_script_constant_map()
		var kinds: Dictionary = constants["Kind"]
		var states: Dictionary = constants["CallState"]
		_check(int(kinds["CALL_INVITE"]) == 1, "Kind.CALL_INVITE == 1")
		_check(int(states["IN_CALL"]) == 3, "CallState.IN_CALL == 3")
		var op_invite: int = protocol.op_code(int(kinds["CALL_INVITE"]))
		_check(protocol.is_rtc_op(op_invite), "op_code 落在 RTC 区间")
		_check(not protocol.is_rtc_op(9001), "普通自定义 RPC 不算 RTC")
		var encoded: String = protocol.encode(int(kinds["OFFER"]), {"from": "p1", "sdp": "v=0"})
		var decoded: Dictionary = protocol.decode(encoded)
		_check(int(decoded["k"]) == int(kinds["OFFER"]), "encode/decode 保留 kind")
		_check(str(decoded["p"].get("from", "")) == "p1", "encode/decode 保留 payload")
		var bytes := PackedByteArray([1, 2, 3, 250])
		var b64: String = protocol.encode_bytes(bytes)
		_check(protocol.decode_bytes(b64) == bytes, "base64 音频/视频帧往返一致")
		_check(protocol.decode("not json").is_empty(), "非法载荷返回空字典")

	# 2) 信令状态机
	_check(global.has_global("RtcSignaling"), "RtcSignaling 已注册")
	var signaling = global.RtcSignaling
	_check(signaling != null, "RtcSignaling 实例可用")
	if signaling != null and protocol != null:
		signaling.reset()
		signaling.call_invited.connect(func(peer, video): _invited = [peer, video])
		signaling.call_accepted.connect(func(peer): _accepted = [peer])
		signaling.call_rejected.connect(func(peer, reason): _rejected = [peer, reason])
		signaling.call_ended.connect(func(peer, reason): _ended = [peer, reason])
		signaling.offer_received.connect(func(peer, sdp): _offers = [peer, sdp])
		signaling.audio_received.connect(func(peer, frames): _audio = [peer, frames])

		var kinds: Dictionary = protocol.get_script_constant_map()["Kind"]
		var invite_payload: String = protocol.encode(int(kinds["CALL_INVITE"]), {"from": "peer-1", "video": true})
		signaling.handle_packet(protocol.op_code(int(kinds["CALL_INVITE"])), invite_payload, "peer-1")
		_check(signaling.call_state == 2, "收到来电 -> INCOMING")
		_check(signaling.peer_id == "peer-1", "记录来电方")
		_check(signaling.is_video_call, "记录视频通话标记")
		_check(_invited.size() == 2 and _invited[0] == "peer-1" and _invited[1] == true, "call_invited 信号参数正确")

		signaling.accept()
		_check(signaling.call_state == 3, "接听后 -> IN_CALL")
		_check(_accepted.size() == 1 and _accepted[0] == "peer-1", "call_accepted 信号触发")

		var offer_payload: String = protocol.encode(int(kinds["OFFER"]), {"from": "peer-1", "sdp": "offer-sdp"})
		signaling.handle_packet(protocol.op_code(int(kinds["OFFER"])), offer_payload, "peer-1")
		_check(_offers.size() == 2 and _offers[1] == "offer-sdp", "offer_received 信号触发")

		var frames := PackedByteArray([9, 8, 7, 6])
		var audio_payload: String = protocol.encode(int(kinds["AUDIO"]), {"from": "peer-1", "b64": protocol.encode_bytes(frames)})
		signaling.handle_packet(protocol.op_code(int(kinds["AUDIO"])), audio_payload, "peer-1")
		_check(_audio.size() == 2 and _audio[1] == frames, "audio_received 解码一致")

		signaling.hang_up()
		_check(signaling.call_state == 0, "挂断后 -> IDLE")
		_check(_ended.size() == 2 and _ended[0] == "peer-1", "call_ended 信号触发")

		# 拒接
		_invited = []
		signaling.handle_packet(protocol.op_code(int(kinds["CALL_INVITE"])), invite_payload, "peer-2")
		signaling.reject("busy")
		_check(signaling.call_state == 0, "拒接后 -> IDLE")
		_check(_rejected.size() == 2 and _rejected[0] == "peer-2", "call_rejected 信号触发")

	# 3) 媒体服务（无设备降级）
	_check(global.has_global("RtcMedia"), "RtcMedia 已注册")
	var media = global.RtcMedia
	if media != null:
		_check(media.is_audio_available(), "音频类可用（AudioStreamMicrophone/AudioEffectCapture）")
		_check(not media.is_capturing_audio(), "默认未在采集")
		_check(media.is_camera_available() == false, "headless 下无摄像头 -> false")
		_check(media.start_camera() == null, "无摄像头 start_camera 返回 null")
		media.stop_camera()
		media.push_remote_audio(PackedByteArray())  # 空帧不应崩溃

	# 4) UI 组件
	var modal_packed := ResourceLoader.load(CALL_MODAL) as PackedScene
	var grid_packed := ResourceLoader.load(VIDEO_GRID) as PackedScene
	_check(modal_packed != null, "CallModal.tscn 可加载")
	_check(grid_packed != null, "RtcVideoGrid.tscn 可加载")
	if modal_packed != null:
		var modal := modal_packed.instantiate()
		root.add_child(modal)
		await process_frame
		_check(modal.get_node_or_null("Panel") != null, "CallModal 构建了面板")
		_check(not modal.visible, "CallModal 默认隐藏")
		modal.queue_free()
	if grid_packed != null:
		var grid := grid_packed.instantiate()
		root.add_child(grid)
		await process_frame
		_check(grid.find_child("Grid", true, false) != null, "RtcVideoGrid 构建了网格")
		grid.queue_free()
	await process_frame
	await process_frame

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", label)

func _finish() -> void:
	if _done:
		return
	_done = true
	print("\n===== RTC 测试：通过 %d 项，失败 %d 项 =====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _guard() -> void:
	await create_timer(20.0).timeout
	if _done:
		return
	_done = true
	print("FAIL: RTC 测试超时（20s）")
	quit(1)
