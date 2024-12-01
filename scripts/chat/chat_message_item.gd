extends MarginContainer

# 消息类型枚举 - 需要与 chat_system.gd 中的枚举保持一致
enum MessageType {
	RECEIVED,  # 接收到的消息
	SENT      # 发送的消息
}

enum ContentType {
	TEXT,      # 文本消息
	VOICE,     # 语音消息
	FILE,      # 文件消息
	LONG_TEXT, # 长文本消息
	IMAGE,     # 图片消息
	VIDEO      # 视频消息
}

var MAX_PREVIEW_SIZE = size#Vector2(300, 200)  # 最大预览尺寸

# 节点引用
@onready var message_container = $MessageContainer
@onready var left_spacer = $MessageContainer/LeftSpacer
@onready var right_spacer = $MessageContainer/RightSpacer
@onready var content_container = $MessageContainer/Content
@onready var nickname_label = $MessageContainer/Content/Header/Nickname
@onready var time_label = $MessageContainer/Content/Header/Time
@onready var message_panel = $MessageContainer/Content/MessagePanel
@onready var text_label = $MessageContainer/Content/MessagePanel/MessageContent/Text
@onready var media_preview = $MessageContainer/Content/MessagePanel/MessageContent/MediaPreview
@onready var file_info = $MessageContainer/Content/MessagePanel/MessageContent/FileInfo
@onready var voice_message = $MessageContainer/Content/MessagePanel/MessageContent/VoiceMessage

# 样式引用
var received_style: StyleBoxFlat
var sent_style: StyleBoxFlat

func _ready():
	# 克隆样式以便修改
	received_style = message_panel.get_theme_stylebox("panel").duplicate()
	sent_style = received_style.duplicate()
	sent_style.bg_color = Color(0.15, 0.4, 0.15, 0.9)
	sent_style.border_color = Color(0.2, 0.5, 0.2, 0.8)

# 设置消息内容
func set_message(content: Dictionary, nickname: String, msg_type: MessageType, show_time: bool = false, time_str: String = ""):
	# 设置昵称
	nickname_label.text = nickname
	
	# 设置时间
	time_label.visible = show_time
	if show_time:
		time_label.text = time_str
	
	# 根据消息类型设置布局
	if msg_type == MessageType.SENT:
		message_panel.add_theme_stylebox_override("panel", sent_style)
		left_spacer.custom_minimum_size.x = 50
		left_spacer.visible = true
		right_spacer.custom_minimum_size.x = 8
		right_spacer.visible = false
	else:
		message_panel.add_theme_stylebox_override("panel", received_style)
		left_spacer.custom_minimum_size.x = 8
		left_spacer.visible = false
		right_spacer.custom_minimum_size.x = 50
		right_spacer.visible = true
	
	# 重置所有内容组件的可见性
	text_label.visible = false
	media_preview.visible = false
	file_info.visible = false
	voice_message.visible = false
	
	# 根据内容类型设置显示
	match content["type"]:
		ContentType.TEXT, ContentType.LONG_TEXT:
			_setup_text_message(content["text"])
		ContentType.IMAGE:
			_setup_image_message(content["path"])
		ContentType.VIDEO:
			_setup_video_message(content["path"], content["thumbnail"], content["duration"])
		ContentType.FILE:
			_setup_file_message(content["path"], content["name"], content["size"])
		ContentType.VOICE:
			_setup_voice_message(content["path"], content["duration"])

# 设置文本消息
func _setup_text_message(text: String):
	text_label.visible = true
	text_label.text = text

# 设置图片消息
func _setup_image_message(path: String):
	media_preview.visible = true
	var image = Image.new()
	if image.load(path) == OK:
		var texture = ImageTexture.create_from_image(image)
		media_preview.texture = texture
		_resize_media_preview(texture.get_size())
	else:
		text_label.visible = true
		text_label.text = "[图片加载失败]"

# 设置视频消息
func _setup_video_message(_path: String, thumbnail_path: String, duration: float):
	media_preview.visible = true
	var image = Image.new()
	if image.load(thumbnail_path) == OK:
		var texture = ImageTexture.create_from_image(image)
		media_preview.texture = texture
		_resize_media_preview(texture.get_size())
		
		# 添加时长显示
		text_label.visible = true
		text_label.text = "▶ " + _format_duration(duration)
	else:
		text_label.visible = true
		text_label.text = "[视频缩略图加载失败]"

# 设置文件消息
func _setup_file_message(_path: String, file_name: String, file_size: int):
	file_info.visible = true
	var file_name_label = file_info.get_node("HBoxContainer/VBoxContainer/FileName")
	var file_size_label = file_info.get_node("HBoxContainer/VBoxContainer/FileSize")
	
	file_name_label.text = file_name
	file_size_label.text = _format_file_size(file_size)

# 设置语音消息
func _setup_voice_message(_path: String, duration: float):
	voice_message.visible = true
	var duration_label = voice_message.get_node("HBoxContainer/Duration")
	duration_label.text = _format_duration(duration)

# 调整媒体预览大小
func _resize_media_preview(original_size: Vector2):
	var new_size = original_size
	if original_size.x > MAX_PREVIEW_SIZE.x or original_size.y > MAX_PREVIEW_SIZE.y:
		var scale_ = min(MAX_PREVIEW_SIZE.x / original_size.x, MAX_PREVIEW_SIZE.y / original_size.y)
		new_size = original_size * scale_
	media_preview.custom_minimum_size = new_size

# 格式化文件大小
func _format_file_size(size_1: int) -> String:
	var units = ["B", "KB", "MB", "GB"]
	var unit_index = 0
	var size_float = float(size_1)
	
	while size_float >= 1024 and unit_index < units.size() - 1:
		size_float /= 1024
		unit_index += 1
	
	return "%.1f %s" % [size_float, units[unit_index]]

# 格式化时长
func _format_duration(seconds: float) -> String:
	var minutes = int(seconds / 60)
	var remaining_seconds = int(seconds) % 60
	return "%d:%02d" % [minutes, remaining_seconds]
