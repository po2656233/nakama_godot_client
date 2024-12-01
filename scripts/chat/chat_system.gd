extends Control

const ChatMessageItem = preload("res://scenes/chat/chat_message_item.tscn")
const TIME_INTERVAL_THRESHOLD = 180  # 3分钟的秒数
const MAX_TEXT_LENGTH = 1000  # 最大文本长度

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

func _ready():
	if send_button:
		send_button.pressed.connect(_on_send_button_pressed)

# 添加新消息
func add_message(content: Dictionary, nickname: String, is_sent: bool, timestamp: int = 0):
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