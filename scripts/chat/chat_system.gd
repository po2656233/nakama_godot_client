extends "res://scripts/chat/chat_full_screen.gd"

##############聊天系统(part1)#####################
const ChatMessageItem = preload("res://scenes/chat/chat_message_item.tscn")
var MsgItemGD = load("res://scripts/chat/chat_message_item.gd")
const TIME_INTERVAL_THRESHOLD = 60 * 60 * 24 # 3分钟的秒数
const MAX_TEXT_LENGTH = 1000 # 最大文本长度
const MESSAGES_PER_PAGE = 20 # 每次加载的消息数量
var isToTop = false
var message_index = 0
var last_message_time: int = 0 # 最后一条消息的时间戳
var today_timestamp = Network.get_today_start_timestamp()
var myUsername = "我"
var myHeadicon = ""
var uid = ""
# 消息类型枚举 - 需要与 chat_message_item.gd 中的枚举保持一致
enum MessageType {
	RECEIVED, # 接收到的消息
	SENT # 发送的消息
}

enum ContentType {
	TEXT, # 文本消息
	VOICE, # 语音消息
	FILE, # 文件消息
	LONG_TEXT, # 长文本消息
	IMAGE, # 图片消息
	VIDEO # 视频消息
}

enum MessageKind {
	WORLD = 0,
	CLUB = 1,
	CHAT = 2
}
enum MessageCode {
	ChatMessage = 0,
	ChatUpdate = 1,
	ChatRemove = 2,
	JoinedGroup = 3,
	AddedToGroup = 4,#已经添加到组
	LeftGroup = 5,#已经离开组
	KickedFromGroup = 6,#被踢Group
	PromotedInGroup = 7, #在小组内晋升
	BannedInGroup = 8,# 在群组中被禁止
	DemotedInGroup = 9, #在小组内降职
}
# 使用字典存储所有channel的消息历史
var message_id_cache: Dictionary = {} # Dictionary<String, Dictionary> 用于快速查找消息ID
var current_channel_id: String = ""
var messages_container:VBoxContainer

@onready var friend_container = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/Panel_talk/ScrollContainer/talkhistory
@onready var club_container = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/Panel_talk/ScrollContainer/talkhistory
@onready var world_container = $MarginContainer/Panel/TabContainer/world/Panel_talk/ScrollContainer/talkhistory


@onready var sendTextEdit = $MarginContainer/Panel/input_area/HBoxContainer/VBoxContainer/TextEdit
@onready var send_button = $MarginContainer/Panel/input_area/HBoxContainer/SendButton

##############聊天系统(part1 end)#####################

func changePanel(tab):
	var kind = tab as MessageKind
	match kind:
		MessageKind.WORLD:
			print("切换到世界聊天")
			messages_container = world_container
		MessageKind.CHAT:
			print("切换到好友聊天")
			messages_container = friend_container
		MessageKind.CLUB:
			print("切换到俱乐部聊天")
			messages_container = club_container
	pass
	
	


################################################################
################	 聊天系统相关函数   ########################
################################################################
# 添加新消息
func add_message(chanId: String, msgId: String, content: Dictionary, nickname: String, is_sent: bool, timestamp: int = 0,code: int = 0):
	if messages_container == null:
		print("消息容器为空")
		return
	
	# 检查消息类型	
	var msgcode =  code as MessageCode
	if msgcode > MessageCode.ChatRemove:
		add_center_message(localContent(nickname,msgcode))
		return

	if timestamp == 0:
		timestamp = int(Time.get_unix_time_from_system())
	
	# 检查是否需要显示时间分割
	# var show_time = false
	var show_time = true # 显示时间
	var timeEquation = timestamp - last_message_time
	var curMsgTime = Network.convert_to_china_time(timestamp)
	var lastMsgTime = Network.convert_to_china_time(last_message_time)
	
	if last_message_time >= 0 and (timeEquation > TIME_INTERVAL_THRESHOLD or timestamp - today_timestamp > TIME_INTERVAL_THRESHOLD or curMsgTime.hour < lastMsgTime.hour):
		# 添加时间分割标签
		add_time_separator(curMsgTime)
		show_time = true
		if timestamp - today_timestamp > TIME_INTERVAL_THRESHOLD:
			today_timestamp = Network.get_today_start_timestamp()

	# 创建新的消息项
	# 获取当前消息容器中的子控件数量
	var child_count = messages_container.get_child_count()
	var message_item = null
	# 尝试复用已有控件
	if child_count > message_index:
		# 获取子节点并检查类型
		var child = messages_container.get_child(message_index)
		# 检查是否是ChatMessageItem场景实例
		if child.get_script() == MsgItemGD:
			message_item = child
			message_item.visible = true
		else:
			# 如果类型不匹配，创建新的
			message_item = ChatMessageItem.instantiate()
			# 替换旧的节点
			messages_container.remove_child(child)
			messages_container.add_child(message_item)
			# 确保新节点在正确的位置
			messages_container.move_child(message_item, message_index)
			# 连接信号
			message_item.message_revoked.connect(_on_message_revoked)
			message_item.message_deleted.connect(_on_message_deleted)
	else:
		# 如果没有可复用的控件，创建新的
		message_item = ChatMessageItem.instantiate()
		messages_container.add_child(message_item)
		# 连接信号
		message_item.message_revoked.connect(_on_message_revoked)
		message_item.message_deleted.connect(_on_message_deleted)
	
	# 设置消息类型
	var msg_type = MessageType.SENT if is_sent else MessageType.RECEIVED
	
	# 格式化时间字符串
	var time_str = ""
	if show_time:
		time_str = "%02d:%02d" % [curMsgTime["hour"], curMsgTime["minute"]]
	
	# 设置消息内容
	message_item.set_message(chanId, msgId, content, nickname, msg_type, show_time, time_str)
		
	# 更新最后消息时间
	last_message_time = timestamp
	message_index += 1

	pass

# 添加时间分割线
func add_time_separator(datetime: Dictionary):
	var time_str = "%d-%02d-%02d" % [
		datetime["year"],
		datetime["month"],
		datetime["day"]
	]
	add_center_message(time_str)
	pass

# 添加中间消息
func add_center_message(msg: String):
	if msg.is_empty():
		return
	var time_label = Label.new()
	time_label.text = msg
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	# 获取当前消息容器中的子控件数量
	var child_count = messages_container.get_child_count()
	# 尝试复用已有控件
	if child_count > message_index:
		var child = messages_container.get_child(message_index)
		messages_container.remove_child(child)
		messages_container.add_child(time_label)
		# 确保新节点在正确的位置
		messages_container.move_child(time_label, message_index)
	else:
		messages_container.add_child(time_label)
	message_index += 1
	pass
# 清理超出可见区域的消息
func cleanup_overflow_messages(scroll: ScrollContainer):
	var visible_height = scroll.size.y
	var scroll_bar = scroll.get_v_scroll_bar()
	var current_scroll = scroll_bar.value
	
	# 获取所有消息
	var children = messages_container.get_children()
	var total_height = 0
	
	# 从底部开始计算，移除超出可见区域的消息
	for child in children:
		if not child is Control:
			continue
			
		var child_pos = child.position.y
		var child_height = child.size.y
		
		# 检查消息是否在可见区域内
		var is_in_view_area = child_pos + child_height >= current_scroll and child_pos <= current_scroll + visible_height
		
		if not is_in_view_area:
			child.visible = false # 隐藏不可见的消息
		else:
			child.visible = true # 显示可见的消息
			
		total_height += child_height
		
		# 如果总高度超过可见区域的2倍，移除最早的消息
		if total_height > visible_height * 2:
			child.queue_free()
 

# 处理消息撤销
func _on_message_revoked(message_item):
	if message_item.current_content.content:
		message_item.current_content.content = "[已撤回]"
	var ret = await Network.reback_channel_message(message_item.channel_id, message_item.message_id,message_item.current_content)
	# 如果成功，可以更新消息显示
	if ret:
		message_item.text_label.text = "[已撤回]"
		message_item.text_label.modulate = Color(0.5, 0.5, 0.5)
		modify_message(message_item.channel_id, message_item.message_id, "[已撤回]")
	pass 

# 处理消息删除
func _on_message_deleted(message_item):
	await Network.remove_channel_message(message_item.channel_id, message_item.message_id)
	 # 创建渐隐动画
	message_item.visible = false
	delete_message(message_item.channel_id, message_item.message_id)



# 删除消息的主函数
func delete_message(channel_id: String, message_id: String):
	# 从历史记录中删除
	# 获取当前channel的消息
	var messages = DataManager.get_instance().get_chat_history(uid,channel_id)
	if messages.is_empty():
		return
	Network.remove_message_by_id(messages, message_id)
	DataManager.get_instance().set_chat_history(uid,channel_id, messages)
	# 从ID缓存中删除
	if channel_id in message_id_cache:
		message_id_cache[channel_id].erase(message_id)

func modify_message(channel_id: String, message_id: String,content: String):
	# 从历史记录中删除
	var messages = DataManager.get_instance().get_chat_history(uid,channel_id)
	 # 使用从后向前遍历的方法（最安全）
	for i in range(messages.size() - 1, -1, -1):
		if messages[i].message_id == message_id:
			var old_msg = messages[i]
			# 创建新的消息对象 
			var new_msg = {
				"message_id": old_msg.message_id,
				"channel_id": old_msg.channel_id,
				"sender_id": old_msg.sender_id,
				"username": old_msg.username,
				"create_time": old_msg.create_time,
				"update_time": Time.get_unix_time_from_system(),
				"content": JSON.stringify({
					"type": "TEXT",
					"content": content
				})
			}
			# 替换消息
			messages[i] = new_msg
			print("更新后的消息: ", messages[i])
	DataManager.get_instance().set_chat_history(uid,channel_id, messages)
	pass

 
# 检查消息是否已存在
func has_message(channel_id: String, message_id: String) -> bool:
	var messages = DataManager.get_instance().get_chat_history(uid,channel_id)
	if messages == null:
		return false
	for item in messages:
		if item.message_id == message_id:
			return true
	if not channel_id in message_id_cache: 
		return false
	return message_id in message_id_cache[channel_id]
 

func localContent(username:String,code:MessageCode):
	match code:
		MessageCode.JoinedGroup:
			return username+"加入了群聊"
		MessageCode.AddedToGroup:
			return username+"已加入群聊"
		MessageCode.KickedFromGroup:
			return username+"已被踢出群聊"
		MessageCode.LeftGroup:
			return username+"已离开群聊"
	return ""

func localMsg(msg):
	var code = msg.code as MessageCode
	match code:
		MessageCode.JoinedGroup:
			msg._content = JSON.stringify({
				"type":ContentType.TEXT,
				"content":msg.username+"加入了群聊"
				})
		MessageCode.AddedToGroup:
			msg._content = JSON.stringify({
					"type":ContentType.TEXT,
					"content":msg.username+"已加入群聊"
				})
		MessageCode.KickedFromGroup:
			msg._content = JSON.stringify({
				"type":ContentType.TEXT,
				"content":msg.username+"已被踢出群聊"
				})
		MessageCode.LeftGroup:
			msg._content = JSON.stringify({
				"type":ContentType.TEXT,
				"content":msg.username+"已离开群聊"
				})
		_:
			pass
	return msg

# 添加消息到指定channel
func add_message_to_history(channel_id: String, msg: NakamaAPI.ApiChannelMessage) -> bool:
	msg = localMsg(msg)
	# 获取消息ID 
	var message_id = msg.message_id
	if message_id.is_empty():
		push_warning("Message has no ID, skipping...")
		return false
	
	# 初始化channel的消息数组和ID缓存
	if not channel_id in message_id_cache:
		message_id_cache[channel_id] = {
			"message_id": false,
			"finish_history": false
		}
		DataManager.get_instance().add_channel_list(uid, channel_id)
		print("渠道---> "+str(channel_id)+" 初始化完毕")

	# 检查消息是否已存在
	if has_message(channel_id, message_id):
		# print("消息 %s 已经存在于渠道 %s" % [message_id, channel_id])
		return false

	# 添加消息到历史记录和ID缓存
	message_id_cache[channel_id].message_id = true

	var msgCount = DataManager.get_instance().add_chat_history(uid, channel_id, msg)
	print("当前消息数量",msgCount) 
	DataManager.get_instance().set_data(uid+"_msg_cache", message_id_cache) 
	return true

# 加载本地历史记录
func load_local_history():
	message_id_cache = Network.validate_dict_types(DataManager.get_instance().get_data(uid+"_msg_cache",message_id_cache))
	print("加载本地历史记录:",message_id_cache)
	# var channelList = DataManager.get_instance().get_channel_list(uid)
	# print("加载本地玩家渠道:",channelList)
	ensure_scroll_to()
	pass

# 获取指定channel的所有历史消息
func get_channel_messages(channel_id: String) -> Array:
	# 排序
	var messages = DataManager.get_instance().get_chat_history(uid,channel_id)
	if messages == null:
		return []
	return Network.sort_dictionary_array(messages, "create_time",true)


# 刷新当前channel的显示
func refresh_current_channel_display() -> void:
	# 清空当前显示
	clear_messages_item()
	
	# 获取并显示当前channel的所有消息
	var messages = get_channel_messages(current_channel_id)
	for message in messages:
		var msg = message if typeof(message) != TYPE_STRING else DataManager.get_instance().parse_message(message) 
		var content = msg.content if typeof(msg.content) != TYPE_STRING else JSON.parse_string(msg.content)
		var code = msg.code if msg.has("code") else 0
		add_message(current_channel_id, msg.message_id, content, msg.username, uid == msg.sender_id, Time.get_unix_time_from_datetime_string(msg.create_time),code)
	# 滚动到底部
	ensure_scroll_to()
	pass

func message_to_show(msg:NakamaAPI.ApiChannelMessage):
	var content = msg.content if typeof(msg.content) != TYPE_STRING else JSON.parse_string(msg.content)
	add_message(current_channel_id, msg.message_id, content, msg.username, uid == msg.sender_id, Time.get_unix_time_from_datetime_string(msg.create_time),msg.code)
	ensure_scroll_to()

# 获取channel的最后一条消息
func get_channel_last_message(channel_id: String) -> NakamaAPI.ApiChannelMessage:
	var messages = get_channel_messages(channel_id)
	return messages[-1] if not messages.is_empty() else {}

# 清理消息但保留控件以供复用
func clear_messages_item():
	if not messages_container:
		return
	message_index = 0 # 重置消息索引
	
 	# 获取所有子控件
	var children = messages_container.get_children()
	# 隐藏所有正确类型的控件
	for child in children:
		# 检查是否是ChatMessageItem场景实例
		child.visible = false
	# 重置最后消息时间
	last_message_time = 0
	pass

# 确保滚动到底部并保持消息在可见区域内
func ensure_scroll_to():
	if not messages_container:
		return
	# await get_tree().create_timer(0.1).timeout
	if messages_container.get_parent() is ScrollContainer:
		var scroll = messages_container.get_parent() as ScrollContainer
		
		# 获取可见区域的大小和实际内容大小
		var visible_height = messages_container.size.y # scroll.size.y
		var content_height = scroll.size.y # messages_container.size.y
		var scroll_bar = scroll.get_v_scroll_bar()
		var current_scroll = scroll_bar.value
		
		# 设置ScrollContainer的clip_contents属性为true，确保超出部分被裁剪
		scroll.clip_contents = true
		messages_container.clip_contents = true
		
		# 如果内容超出可见区域，调整显示
		if content_height > visible_height:
			# 确保滚动位置不会导致内容超出底部
			var max_scroll = scroll_bar.max_value
			var min_scroll = max(0, max_scroll - visible_height)
			
			# 限制滚动范围
			current_scroll = clamp(current_scroll, min_scroll, max_scroll)
			scroll_bar.value = current_scroll
			print("滑到底部")
			# 检查并清理超出可见区域的消息(未完善暂不采用)
			# cleanup_overflow_messages(scroll)
		#等待一帧以确保UI已更新
		await get_tree().process_frame

		# 直接滚动到最底部
		if isToTop:
			scroll.scroll_vertical = 0
			print("滑到顶部")
		else:
			scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
			print("滑到底部")

	pass


##########################################
# # 发送文本消息
# func _on_send_button_pressed():
# 	if not sendTextEdit:
# 		return
		
# 	var message = sendTextEdit.text.strip_edges()
# 	if message.length() > 0:
# 		var content = {
# 			"type": ContentType.TEXT if message.length() <= 100 else ContentType.LONG_TEXT,
# 			"content": message
# 		}
# 		add_message(content, myUsername, true)
# 		sendTextEdit.text = ""  # 清空输入框

# 发送图片消息
func send_image_message(msgId:String, image_path: String, kind: int = 0):
	var content = {
		"headicon":myHeadicon,
		"kind": kind,
		"type": ContentType.IMAGE,
		"path": image_path,
	}
	add_message(current_channel_id, msgId, content, myUsername, true)

# 发送视频消息
func send_video_message(msgId:String, video_path: String, thumbnail_path: String, duration: float):
	var content = {
		"headicon":myHeadicon,
		"type": ContentType.VIDEO,
		"path": video_path,
		"thumbnail": thumbnail_path,
		"duration": duration,
	}
	add_message(current_channel_id, msgId, content, myUsername, true)

# 发送语音消息
func send_voice_message(msgId:String, voice_path: String, duration: float):
	var content = {
		"headicon":myHeadicon,
		"type": ContentType.VOICE,
		"path": voice_path,
		"duration": duration,
	}
	add_message(current_channel_id, msgId, content, myUsername, true)

# 发送文件消息
func send_file_message(msgId:String, file_path: String, file_name: String, file_size: int):
	var content = {
		"headicon":myHeadicon,
		"type": ContentType.FILE,
		"path": file_path,
		"file": file_name,
		"size": file_size,
	}
	add_message(current_channel_id, msgId, content, myUsername, true)
######################################################
