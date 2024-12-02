extends Control

const ChatMessageItem = preload("res://scenes/chat/chat_message_item.tscn")
const TIME_INTERVAL_THRESHOLD = 180  # 3分钟的秒数
const MAX_TEXT_LENGTH = 1000  # 最大文本长度
const MAX_MESSAGES = 20  # 最大消息数量
const HISTORY_FETCH_COUNT = 20  # 每次获取历史消息的数量

signal request_history_messages(last_message_id: String)  # 请求历史消息的信号

# 消息类型枚举 - 需要与 chat_message_item.gd 中的枚举保持一致
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

@onready var messages_container = $talkhistory
@onready var text_edit = $input_area/TextEdit
@onready var send_button = $input_area/SendButton
var last_message_time: int = 0  # 最后一条消息的时间戳
var message_count: int = 0  # 当前消息数量
var oldest_message_id: String = ""  # 最早消息的ID
var is_loading_history: bool = false  # 是否正在加载历史消息
var scroll_container: ScrollContainer  # 滚动容器引用

func _ready():
	if send_button:
		send_button.pressed.connect(_on_send_button_pressed)
	
	# 设置消息容器的大小限制
	messages_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	messages_container.custom_minimum_size.y = 0
	
	# 获取并设置滚动容器
	scroll_container = messages_container.get_parent() as ScrollContainer
	if scroll_container:
		scroll_container.scroll_vertical_enabled = true
		scroll_container.scroll_horizontal_enabled = false
		# 连接滚动信号
		scroll_container.get_v_scroll_bar().changed.connect(_on_scroll_changed)
		# 设置滚动容器的大小策略
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# 监听大小变化
		scroll_container.resized.connect(_on_scroll_container_resized)

# 处理滚动容器大小变化
func _on_scroll_container_resized():
	if scroll_container:
		# 更新所有消息项的最大高度
		var max_height = scroll_container.size.y
		for child in messages_container.get_children():
			if child is Control:  # 确保是控制节点
				child.set_max_height(max_height * 0.8)  # 设置为滚动区域高度的80%

# 处理滚动变化
func _on_scroll_changed():
	if scroll_container and not is_loading_history:
		# 当滚动到顶部时，尝试加载更多历史消息
		if scroll_container.scroll_vertical <= 0:
			load_history_messages()

# 加载历史消息
func load_history_messages():
	if is_loading_history or oldest_message_id.is_empty():
		return
	
	is_loading_history = true
	# 发出加载历史消息的信号
	emit_signal("request_history_messages", oldest_message_id)

# 接收历史消息
func on_history_messages_received(messages: Array):
	is_loading_history = false
	if messages.is_empty():
		return
	
	# 保存当前滚动位置
	var current_scroll_pos = scroll_container.scroll_vertical if scroll_container else 0
	
	# 添加历史消息到顶部
	for message in messages:
		add_history_message(message)
	
	# 恢复滚动位置
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = current_scroll_pos + (scroll_container.get_v_scroll_bar().max_value - current_scroll_pos)

# 添加历史消息（在顶部添加）
func add_history_message(message: Dictionary):
	var message_item = ChatMessageItem.instantiate()
	messages_container.add_child(message_item)
	messages_container.move_child(message_item, 0)
	
	# 设置最大高度
	if scroll_container:
		message_item.set_max_height(scroll_container.size.y * 0.8)
	
	# 设置消息内容
	message_item.set_message(
		message.content,
		message.nickname,
		MessageType.RECEIVED if message.is_received else MessageType.SENT,
		true,
		message.time_str
	)
	
	# 更新最早消息ID
	oldest_message_id = message.id
	message_count += 1

# 管理消息数量
func manage_message_count():
	if message_count >= MAX_MESSAGES:
		# 移除最早的消息
		var oldest_message = messages_container.get_child(0)
		messages_container.remove_child(oldest_message)
		oldest_message.queue_free()
		message_count -= 1
		
		# 触发加载历史消息
		load_history_messages()

# 添加新消息
func add_message(content: Dictionary, nickname: String, is_sent: bool, timestamp: int = 0, message_id: String = ""):
	# 管理消息数量
	manage_message_count()
	
	if timestamp == 0:
		timestamp = Time.get_unix_time_from_system()
	
	# 检查是否需要显示时间分割
	var show_time = false
	if last_message_time > 0 and (timestamp - last_message_time) > TIME_INTERVAL_THRESHOLD:
		# 添加时间分割标签
		add_time_separator(timestamp)
		show_time = true
	
	# 创建新的消息项
	var message_item = ChatMessageItem.instantiate()
	messages_container.add_child(message_item)
	message_count += 1
	
	# 设置最大高度
	if scroll_container:
		message_item.set_max_height(scroll_container.size.y * 0.8)
	
	# 如果是第一条消息，设置为最早的消息ID
	if message_count == 1 and not message_id.is_empty():
		oldest_message_id = message_id
	
	# 设置消息类型
	var msg_type = MessageType.SENT if is_sent else MessageType.RECEIVED
	
	# 格式化时间字符串
	var time_str = ""
	if show_time:
		var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
		time_str = "%02d:%02d" % [datetime["hour"], datetime["minute"]]
	
	# 设置消息内容
	message_item.set_message(content, nickname, msg_type, show_time, time_str)
	
	# 更新最后消息时间
	last_message_time = timestamp
	
	# 滚动到底部
	await get_tree().create_timer(0.1).timeout
	ensure_scroll_to_bottom()

# 添加时间分割线
func add_time_separator(timestamp: int):
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
	var time_str = "%d-%02d-%02d %02d:%02d" % [
		datetime["year"],
		datetime["month"],
		datetime["day"],
		datetime["hour"],
		datetime["minute"]
	]
	
	var time_label = Label.new()
	time_label.text = time_str
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	messages_container.add_child(time_label)

# 确保滚动到底部
func ensure_scroll_to_bottom():
	if messages_container.get_parent() is ScrollContainer:
		var scroll = messages_container.get_parent() as ScrollContainer
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# 发送文本消息
func _on_send_button_pressed():
	if not text_edit:
		return
		
	var message = text_edit.text.strip_edges()
	if message.length() > 0:
		var content = {
			"type": ContentType.TEXT if message.length() <= 100 else ContentType.LONG_TEXT,
			"text": message
		}
		add_message(content, "我", true)
		text_edit.text = ""  # 清空输入框

# 发送图片消息
func send_image_message(image_path: String):
	var content = {
		"type": ContentType.IMAGE,
		"path": image_path
	}
	add_message(content, "我", true)

# 发送视频消息
func send_video_message(video_path: String, thumbnail_path: String, duration: float):
	var content = {
		"type": ContentType.VIDEO,
		"path": video_path,
		"thumbnail": thumbnail_path,
		"duration": duration
	}
	add_message(content, "我", true)

# 发送语音消息
func send_voice_message(voice_path: String, duration: float):
	var content = {
		"type": ContentType.VOICE,
		"path": voice_path,
		"duration": duration
	}
	add_message(content, "我", true)

# 发送文件消息
func send_file_message(file_path: String, file_name: String, file_size: int):
	var content = {
		"type": ContentType.FILE,
		"path": file_path,
		"name": file_name,
		"size": file_size
	}
	add_message(content, "我", true)

# 接收消息示例
func receive_message_example():
	# 文本消息
	add_message({
		"type": ContentType.TEXT,
		"text": "你好！"
	}, "用户A", false)
	
	# 图片消息
	add_message({
		"type": ContentType.IMAGE,
		"path": "res://images/example.png"
	}, "用户B", false)
	
	# 视频消息
	add_message({
		"type": ContentType.VIDEO,
		"path": "res://videos/example.mp4",
		"thumbnail": "res://videos/example_thumb.png",
		"duration": 65.5
	}, "用户C", false)
	
	# 语音消息
	add_message({
		"type": ContentType.VOICE,
		"path": "res://voice/example.mp3",
		"duration": 10.5
	}, "用户D", false)
	
	# 文件消息
	add_message({
		"type": ContentType.FILE,
		"path": "res://files/document.pdf",
		"name": "重要文档.pdf",
		"size": 1024 * 1024 * 2.5
	}, "用户E", false)
	
	# 长文本消息
	add_message({
		"type": ContentType.LONG_TEXT,
		"text": "这是一段很长的文本..."
	}, "用户F", false)