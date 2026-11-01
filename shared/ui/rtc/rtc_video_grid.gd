extends Control

## 模块：对局/聊天室视频网格（PROMPT_REFACTOR 阶段 3，shared/ui/rtc/）
## 职责：
##   1. 维护每个对端一个视频 Tile（TextureRect）；
##   2. 接收 RtcSignaling.video_received 的 JPEG 帧并显示；
##   3. 接收 audio_received 并送 RtcMedia 播放；
##   4. 麦克风 / 摄像头 / 挂断按钮。
## 用法：实例化后调用 add_peer(peer_id)；本端画面用 bind_local_camera()。

var _grid: GridContainer
var _mic_button: Button
var _camera_button: Button
var _hangup_button: Button
var _tiles: Dictionary = {}
var _local_texture: Texture2D = null

func _ready() -> void:
	_build_ui()
	if Global.has_global("RtcSignaling"):
		Global.RtcSignaling.video_received.connect(_on_video_received)
		Global.RtcSignaling.audio_received.connect(_on_audio_received)
		Global.RtcSignaling.call_ended.connect(_on_call_ended)

# ---------------------------------------------------------------------
# 对端 Tile
# ---------------------------------------------------------------------

## 添加（或复用）一个对端视频格；返回 TextureRect。
func add_peer(peer_id: String, texture: Texture2D = null) -> TextureRect:
	if _tiles.has(peer_id):
		if texture != null:
			(_tiles[peer_id] as TextureRect).texture = texture
		return _tiles[peer_id]
	var tile := TextureRect.new()
	tile.name = "Tile_%s" % peer_id
	tile.custom_minimum_size = Vector2(240, 160)
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.texture = texture
	_grid.add_child(tile)
	_tiles[peer_id] = tile
	return tile

func set_peer_texture(peer_id: String, texture: Texture2D) -> void:
	var tile := add_peer(peer_id)
	tile.texture = texture

func remove_peer(peer_id: String) -> void:
	if not _tiles.has(peer_id):
		return
	var tile: TextureRect = _tiles[peer_id]
	tile.queue_free()
	_tiles.erase(peer_id)

func clear() -> void:
	for peer_id in _tiles.keys():
		(_tiles[peer_id] as TextureRect).queue_free()
	_tiles.clear()

## 绑定本端摄像头画面（无设备时静默跳过）。
func bind_local_camera(peer_id: String = "self") -> void:
	if not Global.has_global("RtcMedia"):
		return
	_local_texture = Global.RtcMedia.start_camera()
	if _local_texture != null:
		set_peer_texture(peer_id, _local_texture)

func is_mic_active() -> bool:
	return Global.has_global("RtcMedia") and Global.RtcMedia.is_capturing_audio()

# ---------------------------------------------------------------------
# 信号回调
# ---------------------------------------------------------------------

func _on_video_received(peer_id: String, jpeg: PackedByteArray) -> void:
	var image := Image.new()
	if image.load_jpeg_from_buffer(jpeg) != OK:
		return
	set_peer_texture(peer_id, ImageTexture.create_from_image(image))

func _on_audio_received(_peer_id: String, frames: PackedByteArray) -> void:
	if Global.has_global("RtcMedia"):
		Global.RtcMedia.push_remote_audio(frames)

func _on_call_ended(peer_id: String, _reason: String) -> void:
	remove_peer(peer_id)

# ---------------------------------------------------------------------
# 按钮
# ---------------------------------------------------------------------

func _on_mic_pressed() -> void:
	if not Global.has_global("RtcMedia"):
		return
	if Global.RtcMedia.is_capturing_audio():
		Global.RtcMedia.stop_audio_capture()
		_mic_button.text = "开麦"
	else:
		Global.RtcMedia.start_audio_capture()
		_mic_button.text = "静音"

func _on_camera_pressed() -> void:
	if not Global.has_global("RtcMedia"):
		return
	if Global.RtcMedia.get_camera_texture() != null:
		Global.RtcMedia.stop_camera()
		remove_peer("self")
		_camera_button.text = "开摄像头"
	else:
		bind_local_camera("self")
		_camera_button.text = "关摄像头"

func _on_hangup_pressed() -> void:
	if Global.has_global("RtcSignaling"):
		Global.RtcSignaling.hang_up()

# ---------------------------------------------------------------------
# UI 构建
# ---------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = 2
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_grid)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	root.add_child(bar)

	_mic_button = _make_button("静音", bar)
	_mic_button.pressed.connect(_on_mic_pressed)
	_camera_button = _make_button("开摄像头", bar)
	_camera_button.pressed.connect(_on_camera_pressed)
	_hangup_button = _make_button("挂断", bar)
	_hangup_button.pressed.connect(_on_hangup_pressed)

func _make_button(text: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, 36)
	parent.add_child(button)
	return button
