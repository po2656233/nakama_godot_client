extends MarginContainer

# 消息类型枚举 - 需要与 chat_system.gd 中的枚举保持一致
enum MessageType {
	RECEIVED,  # 接收到的消息
	SENT	  # 发送的消息
}

enum ContentType {
	TEXT,	  # 文本消息
	VOICE,	 # 语音消息
	FILE,	  # 文件消息
	LONG_TEXT, # 长文本消息
	IMAGE,	 # 图片消息
	VIDEO	  # 视频消息
}

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
var max_height: float = 0  # 最大高度限制

func _ready():
	# 克隆样式以便修改
	received_style = message_panel.get_theme_stylebox("panel").duplicate()
	sent_style = received_style.duplicate()
	sent_style.bg_color = Color(0.15, 0.4, 0.15, 0.9)
	sent_style.border_color = Color(0.2, 0.5, 0.2, 0.8)
	
	# 设置大小约束
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER
	
	# 确保内容不会超出容器
	message_panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	message_panel.size_flags_vertical = SIZE_SHRINK_CENTER
	
	# 设置文本标签的自动换行
	if text_label:
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.size_flags_horizontal = SIZE_SHRINK_CENTER
		text_label.custom_minimum_size.x = 60  # 最小宽度
		
	# 监听大小变化
	resized.connect(_on_resized)

# 设置最大高度
func set_max_height(height: float):
	max_height = height
	_on_resized()

func _on_resized():
	# 获取父容器的大小
	var parent_size = get_parent().size if get_parent() else Vector2.ZERO
	if parent_size == Vector2.ZERO:
		return
	
	# 限制最大宽度为父容器的80%
	var max_width = parent_size.x * 0.8
	if size.x > max_width:
		custom_minimum_size.x = max_width
	
	# 限制最大高度
	if max_height > 0 and size.y > max_height:
		custom_minimum_size.y = max_height
		
	# 确保文本内容适应宽度和高度
	if text_label and text_label.visible:
		text_label.custom_minimum_size.x = min(text_label.size.x, max_width - 40)  # 40为边距
		if max_height > 0:
			text_label.custom_minimum_size.y = min(text_label.size.y, max_height - 40)  # 40为边距

# 设置消息内容
func set_message(content: Dictionary, nickname: String, msg_type: MessageType, show_time: bool = false, time_str: String = ""):
	# 设置昵称
	nickname_label.text = nickname
	print("设置xiaoxi:", content["type"],content["content"],"-->",content.type)
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
	var cType = content.type as ContentType
	match cType:
		ContentType.TEXT, ContentType.LONG_TEXT:
			_setup_text_message(content["content"])
		ContentType.IMAGE:
			_setup_image_message(content["path"])
		ContentType.VIDEO:
			_setup_video_message(content["path"], content["thumbnail"], content["duration"])
		ContentType.FILE:
			_setup_file_message(content["path"], content["name"], content["size"])
		ContentType.VOICE:
			_setup_voice_message(content["path"], content["duration"])
	
	# 确保大小适应内容
	_on_resized()

# 设置文本消息
func _setup_text_message(text: String):
	text_label.visible = true
	text_label.text = text
	# 确保文本适应容器宽度和高度
	_on_resized()

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
		text_label.text = "无法加载图片"

# 调整媒体预览大小
func _resize_media_preview(original_size_: Vector2):
	var parent_size = get_parent().size if get_parent() else Vector2.ZERO
	if parent_size == Vector2.ZERO:
		return
		 
	var max_width = parent_size.x * 0.6  # 最大宽度为父容器的60%
	var height_limit = min(parent_size.y * 0.4, max_height * 0.8 if max_height > 0 else INF)  # 最大高度限制
	
	var new_size = original_size_
	if original_size_.x > max_width or original_size_.y > height_limit:
		var scale_ = min(max_width / original_size_.x, height_limit / original_size_.y)
		new_size = original_size_ * scale_
	size = new_size
	_on_resized()

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
