extends CanvasLayer

## 模块：RTC 全局 UI 宿主（PROMPT_REFACTOR 阶段 2 缝合）
## 职责：
##   1. 常驻监听 RtcSignaling，来电时自动弹 CallModal；
##   2. 通话中自动开启麦克风采集/回放，并把本地语音帧发给对端；
##   3. 视频通话时显示可最小化的视频悬浮窗，定时抓取摄像头帧发送。
## 说明：由 Global 在启动时懒加载（服务名 RtcUi），保证任何界面都能收到来电。

const CALL_MODAL := preload("res://shared/ui/rtc/CallModal.tscn")
const VIDEO_GRID := preload("res://shared/ui/rtc/RtcVideoGrid.tscn")

var _modal: Control = null
var _video_panel: PanelContainer = null
var _video_grid: Control = null
var _minimize_button: Button = null
var _media_started := false
var _audio_connected := false
var _video_accum := 0.0
var _video_frame_interval := 0.2
var _minimized := false

func _ready() -> void:
	layer = 90
	_modal = CALL_MODAL.instantiate()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	_build_video_panel()
	if Global.has_global("RtcSignaling"):
		Global.RtcSignaling.state_changed.connect(_on_state_changed)
		Global.RtcSignaling.call_ended.connect(_on_call_ended)
		Global.RtcSignaling.call_rejected.connect(_on_call_rejected)
		Global.RtcSignaling.video_received.connect(_on_remote_video)
	set_process(false)

func _build_video_panel() -> void:
	_video_panel = PanelContainer.new()
	_video_panel.name = "VideoPanel"
	_video_panel.visible = false
	_video_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_video_panel.position = Vector2(-500, -350)
	_video_panel.custom_minimum_size = Vector2(480, 320)
	add_child(_video_panel)

	var box := VBoxContainer.new()
	_video_panel.add_child(box)
	var bar := HBoxContainer.new()
	box.add_child(bar)
	var title := Label.new()
	title.text = "视频通话"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	_minimize_button = Button.new()
	_minimize_button.text = "最小化"
	_minimize_button.pressed.connect(_on_minimize_pressed)
	bar.add_child(_minimize_button)
	_video_grid = VIDEO_GRID.instantiate()
	_video_grid.custom_minimum_size = Vector2(464, 260)
	box.add_child(_video_grid)

func _on_state_changed(state: int) -> void:
	if state == RtcProtocol.CallState.IN_CALL:
		_start_media()
	elif state == RtcProtocol.CallState.IDLE:
		_stop_media()

func _on_call_ended(_peer: String, _reason: String) -> void:
	_stop_media()

func _on_call_rejected(_peer: String, _reason: String) -> void:
	_stop_media()

func _start_media() -> void:
	if _media_started:
		return
	_media_started = true
	if not Global.has_global("RtcMedia"):
		return
	Global.RtcMedia.start_audio_capture()
	Global.RtcMedia.start_audio_playback()
	if not _audio_connected:
		Global.RtcMedia.audio_frame.connect(_on_local_audio)
		_audio_connected = true
	if Global.has_global("RtcSignaling") and Global.RtcSignaling.is_video_call:
		_show_video()
	set_process(true)

func _stop_media() -> void:
	if not _media_started:
		return
	_media_started = false
	if Global.has_global("RtcMedia"):
		Global.RtcMedia.stop_audio()
		Global.RtcMedia.stop_camera()
		if _audio_connected:
			Global.RtcMedia.audio_frame.disconnect(_on_local_audio)
			_audio_connected = false
	_video_panel.visible = false
	_minimized = false
	set_process(false)

func _show_video() -> void:
	if not Global.has_global("RtcMedia"):
		return
	_video_panel.visible = true
	var peer: String = str(Global.RtcSignaling.peer_id) if Global.has_global("RtcSignaling") else ""
	_video_grid.clear()
	_video_grid.bind_local_camera("self")
	if not peer.is_empty():
		_video_grid.add_peer(peer)

func _on_local_audio(frames: PackedByteArray) -> void:
	if Global.has_global("RtcSignaling"):
		Global.RtcSignaling.send_audio(frames)

func _on_remote_video(peer: String, jpeg: PackedByteArray) -> void:
	if _video_panel != null and not _video_panel.visible:
		_video_panel.visible = true
	if _video_grid != null:
		_video_grid.set_peer_texture(peer, _decode_jpeg(jpeg))

func _decode_jpeg(jpeg: PackedByteArray) -> Texture2D:
	var image := Image.new()
	if image.load_jpeg_from_buffer(jpeg) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
	if not _media_started:
		return
	if not Global.has_global("RtcSignaling") or not Global.has_global("RtcMedia"):
		return
	if not Global.RtcSignaling.is_video_call:
		return
	_video_accum += delta
	if _video_accum < _video_frame_interval:
		return
	_video_accum = 0.0
	_send_video_frame()

func _send_video_frame() -> void:
	var texture: Texture2D = Global.RtcMedia.get_camera_texture()
	if texture == null:
		return
	var image: Image = texture.get_image()
	if image == null:
		return
	if image.get_width() > 320:
		image.resize(320, 240, Image.INTERPOLATE_BILINEAR)
	var jpeg := image.save_jpg_to_buffer(0.5)
	if not jpeg.is_empty():
		Global.RtcSignaling.send_video(jpeg)

func _on_minimize_pressed() -> void:
	_minimized = not _minimized
	_video_grid.visible = not _minimized
	_video_panel.custom_minimum_size = Vector2(180, 44) if _minimized else Vector2(480, 320)
	_minimize_button.text = "展开" if _minimized else "最小化"
