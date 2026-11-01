extends Node

## 模块：RTC 音视频采集/回放（Global.RtcMedia，PROMPT_REFACTOR 阶段 3）
## 职责：
##   1. 音频：AudioStreamMicrophone -> AudioEffectCapture 取 PCM -> `audio_frame` 信号；
##      对端帧通过 `push_remote_audio()` 送入 AudioStreamGenerator 实时播放；
##   2. 视频：CameraServer / CameraFeed -> CameraTexture，供 TextureRect 直接渲染；
##   3. 无设备（headless/无麦克风/无摄像头）时优雅降级：返回 false + 告警，不崩溃。
## 依赖：仅 Godot 原生 AudioServer / CameraServer，不依赖 Nakama。

signal audio_frame(frames: PackedByteArray)
signal audio_level(level: float)
signal camera_texture_changed(texture: Texture2D)

const RTC_BUS_NAME := "RTC"
const AUDIO_MIX_RATE := 48000.0
const AUDIO_BUFFER_SECONDS := 0.2

var _capture: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _playback_player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _camera_feed: CameraFeed = null
var _camera_texture: CameraTexture = null
var _monitoring_started := false

# ---------------------------------------------------------------------
# 音频采集
# ---------------------------------------------------------------------

func is_audio_available() -> bool:
	return ClassDB.class_exists("AudioStreamMicrophone") and ClassDB.class_exists("AudioEffectCapture")

## 开始麦克风采集；每帧通过 `audio_frame` 发出 PCM 浮点字节。
func start_audio_capture() -> bool:
	if not is_audio_available():
		push_warning("[RtcMedia] 当前环境不支持麦克风采集")
		return false
	_ensure_audio_bus()
	if _capture == null:
		push_warning("[RtcMedia] 未取到 AudioEffectCapture")
		return false
	if _mic_player == null:
		_mic_player = AudioStreamPlayer.new()
		_mic_player.name = "MicCapture"
		_mic_player.bus = RTC_BUS_NAME
		add_child(_mic_player)
		_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.play()
	set_process(true)
	return true

func stop_audio_capture() -> void:
	if _mic_player != null:
		_mic_player.stop()
	set_process(false)

func is_capturing_audio() -> bool:
	return _mic_player != null and _mic_player.playing

func _ensure_audio_bus() -> void:
	var bus_index := AudioServer.get_bus_index(RTC_BUS_NAME)
	if bus_index == -1:
		bus_index = AudioServer.bus_count
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, RTC_BUS_NAME)
		AudioServer.set_bus_mute(bus_index, false)
	var existing: AudioEffect = AudioServer.get_bus_effect(bus_index, 0) if AudioServer.get_bus_effect_count(bus_index) > 0 else null
	if existing is AudioEffectCapture:
		_capture = existing as AudioEffectCapture
	else:
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.5
		AudioServer.add_bus_effect(bus_index, _capture)

## 兼容旧写法：start_audio / stop_audio。
func start_audio() -> bool:
	var captured := start_audio_capture()
	var played := start_audio_playback()
	return captured and played

func stop_audio() -> void:
	stop_audio_capture()
	stop_audio_playback()

# ---------------------------------------------------------------------
# 音频回放
# ---------------------------------------------------------------------

## 准备 AudioStreamGenerator，供 push_remote_audio() 写入对端 PCM。
func start_audio_playback() -> bool:
	if _playback_player != null and _playback_player.playing:
		return true
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = AUDIO_MIX_RATE
	generator.buffer_length = AUDIO_BUFFER_SECONDS
	if _playback_player == null:
		_playback_player = AudioStreamPlayer.new()
		_playback_player.name = "VoicePlayback"
		_playback_player.bus = "Master"
		add_child(_playback_player)
	_playback_player.stream = generator
	_playback_player.play()
	_playback = _playback_player.get_stream_playback() as AudioStreamGeneratorPlayback
	return _playback != null

func stop_audio_playback() -> void:
	_playback = null
	if _playback_player != null:
		_playback_player.stop()

## 写入对端 PCM（小端 float32 字节，成对左右声道；单声道会自动复制）。
func push_remote_audio(bytes: PackedByteArray) -> void:
	if _playback == null and not start_audio_playback():
		return
	if bytes.is_empty():
		return
	var floats := bytes.to_float32_array()
	var frames: Array[Vector2] = []
	var index := 0
	while index < floats.size():
		var left := floats[index]
		var right := left
		if index + 1 < floats.size():
			right = floats[index + 1]
			index += 2
		else:
			index += 1
		frames.append(Vector2(left, right))
	_playback.push_buffer(PackedVector2Array(frames))

## 把一段对端浮点采样打包成可发送的字节（供 CallSession/UI 使用）。
static func pack_samples(samples: PackedFloat32Array) -> PackedByteArray:
	return samples.to_byte_array()

# ---------------------------------------------------------------------
# 摄像头
# ---------------------------------------------------------------------

func is_camera_available() -> bool:
	_start_monitoring()
	return CameraServer.get_feed_count() > 0

## 打开摄像头并返回可直接给 TextureRect 使用的纹理（无设备返回 null）。
func start_camera(feed_index: int = 0) -> Texture2D:
	_start_monitoring()
	if CameraServer.get_feed_count() <= feed_index:
		push_warning("[RtcMedia] 没有可用的摄像头设备")
		return null
	_camera_feed = CameraServer.get_feed(feed_index)
	if _camera_feed == null:
		return null
	_camera_feed.feed_is_active = true
	if _camera_texture == null:
		_camera_texture = CameraTexture.new()
	_camera_texture.camera_feed_id = _camera_feed.get_id()
	_camera_texture.which_feed = CameraServer.FEED_RGBA_IMAGE
	camera_texture_changed.emit(_camera_texture)
	return _camera_texture

func stop_camera() -> void:
	if _camera_feed != null:
		_camera_feed.feed_is_active = false
	_camera_feed = null
	_camera_texture = null
	camera_texture_changed.emit(null)

func get_camera_texture() -> Texture2D:
	return _camera_texture

func _start_monitoring() -> void:
	if _monitoring_started:
		return
	_monitoring_started = true
	CameraServer.set_monitoring_feeds(true)

# ---------------------------------------------------------------------
# 每帧采集
# ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _capture == null:
		return
	var available := _capture.get_frames_available()
	if available <= 0:
		return
	var frames := _capture.get_buffer(available)
	if frames.is_empty():
		return
	var peak := 0.0
	for frame in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	audio_level.emit(clampf(peak, 0.0, 1.0))
	var samples := PackedFloat32Array()
	samples.resize(frames.size() * 2)
	for i in frames.size():
		samples[i * 2] = frames[i].x
		samples[i * 2 + 1] = frames[i].y
	audio_frame.emit(samples.to_byte_array())
