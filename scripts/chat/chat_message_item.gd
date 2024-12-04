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
# 在类的开头添加信号定义
signal message_revoked(message_item)
signal message_deleted(message_item)
# 节点引用
# @onready var message_container = $MessageContainer
@onready var content_container = $Content
@onready var header_container = $Content/Header
@onready var nickname_label = $Content/Header/Nickname
@onready var time_label = $Content/Header/Time
@onready var message_panel = $Content/MessagePanel
@onready var text_label = $Content/MessagePanel/MessageContent/Text
@onready var media_preview = $Content/MessagePanel/MessageContent/MediaPreview
@onready var file_info = $Content/MessagePanel/MessageContent/FileInfo
@onready var voice_message = $Content/MessagePanel/MessageContent/VoiceMessage


# TextEdit的最大宽度（可以根据需要调整）
const MAX_TEXTEDIT_WIDTH = 150
# TextEdit的最小宽度
const MIN_TEXTEDIT_WIDTH = 0

# 样式引用
var received_style: StyleBoxFlat
var sent_style: StyleBoxFlat
var max_height: float = 0  # 最大高度限制
var max_talk_width: float = MAX_TEXTEDIT_WIDTH

# 在类的开头添加变量
var popup_menu: PopupMenu
var current_content: Dictionary  # 保存当前消息内容以便复制
var is_self_message: bool = false  # 是否是自己发送的消息

func _ready():
	# 克隆样式以便修改
	received_style = message_panel.get_theme_stylebox("panel").duplicate()
	sent_style = received_style.duplicate()
	sent_style.bg_color = Color(0.15, 0.4, 0.15, 0.9)
	sent_style.border_color = Color(0.2, 0.5, 0.2, 0.8)
	
	# 设置大小约束
	custom_minimum_size = Vector2(0, 0)
	consistent(SIZE_EXPAND_FILL)

	 # 创建右键菜单
	popup_menu = PopupMenu.new()
	add_child(popup_menu)
	# 添加菜单项
	popup_menu.add_item("复制", 0)
	popup_menu.add_separator()
	popup_menu.add_item("撤销", 1)
	popup_menu.add_item("删除", 2)

	# 设置文本标签的自动换行
	if text_label:
		# 设置初始大小和换行
		text_label.custom_minimum_size.x = MIN_TEXTEDIT_WIDTH
		text_label.fit_content = true
		text_label.selection_enabled = true	 # 设置文本标签可选择
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# 设置垂直大小策略
		text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# 连接文本变化信号
		text_label.finished.connect(_on_text_changed)
	
	# 连接菜单信号
	popup_menu.id_pressed.connect(_on_popup_menu_item_selected)
	# 添加右键点击检测
	gui_input.connect(_on_gui_input)
	# 监听大小变化
	resized.connect(_on_resized)
	pass


#################################
# 大小约束
func consistent(flag:SizeFlags):
	size_flags_horizontal = flag 
	size_flags_vertical = flag 
	
	# # 确保内容不会超出容器
	message_panel.size_flags_horizontal = flag 
	message_panel.size_flags_vertical = flag 
	pass

# 根据消息类型设置布局
func set_message_type(msgtype: MessageType):
	if msgtype == MessageType.SENT:
		message_panel.add_theme_stylebox_override("panel", sent_style)
		header_container.alignment = BoxContainer.ALIGNMENT_END
		text_label.size_flags_horizontal = SIZE_SHRINK_END
		consistent(SIZE_SHRINK_END)
	else:
		message_panel.add_theme_stylebox_override("panel", received_style)
		header_container.alignment = BoxContainer.ALIGNMENT_BEGIN
		text_label.size_flags_horizontal = SIZE_SHRINK_BEGIN
		consistent(SIZE_SHRINK_BEGIN)
	pass

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
		text_label.custom_minimum_size.x = min(text_label.size.x, max_width - 20)  # 40为边距
		if max_height > 0:
			text_label.custom_minimum_size.y = min(text_label.size.y, max_height - 20)  # 40为边距
		custom_minimum_size.x = min(text_label.custom_minimum_size.x,max_width)
	pass
# 设置消息内容
func set_message(content: Dictionary, nickname: String, msg_type: MessageType, show_time: bool = false, time_str: String = ""):
	# 设置昵称
	nickname_label.text = nickname
	# 设置时间
	time_label.visible = show_time
	if show_time:
		time_label.text = time_str
	
	# 根据消息类型设置布局
	set_message_type(msg_type)
	
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


# 处理文本变化，调整TextEdit大小
func _on_text_changed():
	if not text_label:
		return
		
	var text = text_label.text
	if text.is_empty():
		text_label.custom_minimum_size.x = MIN_TEXTEDIT_WIDTH
		return
	
	# 计算文本宽度
	var font = text_label.get_theme_font("normal_font")
	var font_size = text_label.get_theme_font_size("normal_font_size")
	var text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	# 添加一些padding（可以根据需要调整）
	# text_width += 30
	
	# 限制宽度范围
	var proportionX = size.x/3
	if proportionX>max_talk_width:
		max_talk_width = proportionX
	var new_width = clamp(text_width, MIN_TEXTEDIT_WIDTH, max_talk_width)
	
	# 设置新的宽度
	text_label.custom_minimum_size.x =  new_width
	
	# 强制重新计算大小
	text_label.custom_minimum_size.y = 0
	text_label.size.y = 0
	
	# 通知父容器重新布局
	text_label.get_parent().queue_sort()

# 处理右键点击
func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 显示菜单前更新菜单项状态
			_update_popup_menu_items()
			# 在点击位置显示菜单
			popup_menu.position = get_global_mouse_position()
			popup_menu.popup()

# 更新菜单项状态
func _update_popup_menu_items():
	# 撤销只对自己发送的消息有效
	popup_menu.set_item_disabled(1, !is_self_message)
	# 删除只对自己发送的消息有效
	popup_menu.set_item_disabled(2, !is_self_message)

# 处理菜单项选择
func _on_popup_menu_item_selected(id: int):
	match id:
		0:  # 复制
			if current_content.has("type") and current_content["type"] == ContentType.TEXT:
				DisplayServer.clipboard_set(current_content["content"])
		1:  # 撤销
			if is_self_message:
				_revoke_message()
		2:  # 删除
			if is_self_message:
				_delete_message()

# 撤销消息
func _revoke_message():
	# 发送撤销消息到服务器
	# 这里需要根据你的具体需求实现
	emit_signal("message_revoked", self)  # 需要先定义信号

# 删除消息
func _delete_message():
	# 发送删除消息到服务器
	# 这里需要根据你的具体需求实现
	emit_signal("message_deleted", self)  # 需要先定义信号