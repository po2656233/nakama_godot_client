extends Control
@onready var mainPanle = $MarginContainer/Panel/TabContainer
@onready var addfirendPanle = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/AddFirends
@onready var addclubPanle = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/AddClub
@onready var friendListItem = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/Panel_friends/VBoxContainer/ItemList
@onready var clubListItem = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/Panel_clubs/VBoxContainer/ItemList
@onready var findFriend = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/AddFirends
@onready var findClub = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/AddClub

@onready var btn_upmoreChat = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/Panel_talk/btn_upmore
@onready var btn_upmoreClub = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/Panel_talk/btn_upmore
@onready var btn_upmoreWorld = $MarginContainer/Panel/TabContainer/world/Panel_talk/btn_upmore

# @onready var clubSplit = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub
# @onready var friendSplit = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends

signal fullscreen_changed(is_fullscreen: bool)

@export var toggle_button_path: NodePath
@export var animate_transition: bool = true
@export var transition_duration: float = 0.3

var original_state := {
	"parent": null,
	"position": Vector2.ZERO,
	"size": Vector2.ZERO,
	"anchors": {},
	"margins": {}
}
enum ScrollType {
	TOP, # 接收到的消息
	MIDDLE, # 滚动到中间
	BOTTOM # 滚动到最底部
}

var is_fullscreen := false
var is_rotated = false
var myUsername = "我"
var uid = ""

var tween: Tween
var button: Button


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

# 使用字典存储所有channel的消息历史
var message_history: Dictionary = {} # Dictionary<String, Array>
var message_id_cache: Dictionary = {} # Dictionary<String, Dictionary> 用于快速查找消息ID
var current_channel_id: String = ""

@onready var messages_container = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/Panel_talk/ScrollContainer/talkhistory
@onready var sendTextEdit = $MarginContainer/Panel/input_area/HBoxContainer/TextEdit
@onready var send_button = $MarginContainer/Panel/input_area/HBoxContainer/SendButton

##############聊天系统(part1 end)#####################

# 初始化 
func _ready():
	if Network.player_data:
		myUsername = Network.player_data.username
		uid = Network.player_data.id
		# 加载本地历史消息
		load_local_history()

	# 创建全屏按钮
	if toggle_button_path:
		button = get_node(toggle_button_path)
		if button:
			button.pressed.connect(_on_fullscreen_toggle)
	else:
		# 如果没有指定按钮，创建一个默认的
		button = Button.new()
		button.text = "全屏切换"
		button.pressed.connect(_on_fullscreen_toggle)
		add_child(button)
	# 设置旋转中心点
	set_rotation_pivot()
	# 获取好友列表
	get_friends_list()
		
	# 连接信号
	findFriend.addFinishSIG.connect(_on_add_finish) 
	sendTextEdit.finished.connect(_on_btn_send_pressed)
	Network.changeChannelSIG.connect(_on_current_channel)
	Network._socket.received_channel_message.connect(_on_received_message)
	Network.chat_history_received.connect(_on_history_message)
	pass


func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE: # 或使用 KEY_RETURN
			WindowDrag.stopMove = false
			exit_fullscreen()
			get_viewport().set_input_as_handled() # 阻止事件继续传
	pass
 
################################################################
################	 聊天系统相关函数   ########################
################################################################
# 添加新消息
func add_message(chanId: String, msgId: String, content: Dictionary, nickname: String, is_sent: bool, timestamp: int = 0):
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

	var time_label = Label.new()
	time_label.text = time_str
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

# 确保滚动到底部并保持消息在可见区域内
func ensure_scroll_to():
	await get_tree().create_timer(0.1).timeout
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
		else:
			scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

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
		"kind": kind,
		"type": ContentType.IMAGE,
		"path": image_path
	}
	add_message(current_channel_id, msgId, content, myUsername, true)

# 发送视频消息
func send_video_message(msgId:String, video_path: String, thumbnail_path: String, duration: float):
	var content = {
		"type": ContentType.VIDEO,
		"path": video_path,
		"thumbnail": thumbnail_path,
		"duration": duration
	}
	add_message(current_channel_id, msgId, content, myUsername, true)

# 发送语音消息
func send_voice_message(msgId:String, voice_path: String, duration: float):
	var content = {
		"type": ContentType.VOICE,
		"path": voice_path,
		"duration": duration
	}
	add_message(current_channel_id, msgId, content, myUsername, true)

# 发送文件消息
func send_file_message(msgId:String, file_path: String, file_name: String, file_size: int):
	var content = {
		"type": ContentType.FILE,
		"path": file_path,
		"file": file_name,
		"size": file_size
	}
	add_message(current_channel_id, msgId, content, myUsername, true)
######################################################
######################################################
func _on_fullscreen_toggle():

	if !is_fullscreen:
		WindowDrag.stopMove = true
		enter_fullscreen()
	else:
		WindowDrag.stopMove = false
		exit_fullscreen()
	# await get_tree().create_timer(1).timeout
	# Network.get_chat_history()
	pass

func _on_show_addfriend_pressed() -> void:
	if addfirendPanle.visible:
		addfirendPanle.hide()
	else:
		addfirendPanle.show()
	pass # Replace with function body.


func _on_show_addclub_pressed() -> void:
	if addclubPanle.visible:
		addclubPanle.hide()
	else:
		addclubPanle.show()
	pass # Replace with function body.


func _on_btn_popup_pressed() -> void:
	_on_fullscreen_toggle()
	# 来回旋转按钮
	button.rotation_degrees += 180
	
	# 如果要添加动画效果
	# tween = create_tween()
	# tween.tween_property(button, "rotation_degrees", 90, 0.5)
	pass # Replace with function body.

# 添加好友完成后刷新好友列表
func _on_add_finish():
	get_friends_list()
	pass


func _on_current_channel(channel_id):
	print("当前频道:", channel_id)
	current_channel_id = channel_id
	isToTop = false
	clear_messages_item()
	pass

# 收到消息
func _on_received_message(msg):
	if msg.message_id == "":
		return
	if add_message_to_history(msg.channel_id, msg):
		refresh_current_channel_display()
	pass

# 收到历史消息
func _on_history_message(msgList):
	print("收到历史消息:", msgList.size())
	# 校验是否有新消息
	var channel_id = ""
	for msg in msgList:
		channel_id = msg.channel_id
		add_message_to_history(channel_id, msg)
		if message_id_cache[channel_id] and message_id_cache[channel_id].finish_history:
			break
		pass

	if channel_id != "" and not message_id_cache[channel_id].finish_history:
		var isFull = msgList.size() != MESSAGES_PER_PAGE
		if isFull and message_id_cache[channel_id]:
			message_id_cache[channel_id].finish_history = true
			print("渠道" + channel_id + "历史消息加载完毕")
			DataManager.get_instance().set_data(uid+"_msg_cache", message_id_cache) 
			pass
		showLoadMore(!isFull)
	else:
		showLoadMore(false)
	refresh_current_channel_display()
	pass


##############################
func _on_btn_send_pressed() -> void:
	if sendTextEdit.text.strip_edges() == "":
		return
	# 发送消息
	var channel = getCurChannelData()
	if channel:
		Network.set_current_channel(channel)
		var msg = Network.getMsgData(null)
		msg.content = sendTextEdit.text.strip_edges()
		msg.kind = mainPanle.current_tab
		msg.type = ContentType.TEXT
		print("发送消息:", msg)
		var ret = await Network.send_message(msg)
		if ret == OK:
			sendTextEdit.clear()
			isToTop = false
		else:
			PopupManager.show_message("发送失败")
		return
	PopupManager.show_message("未指定频道")
	pass # Replace with function body.

############################调整分割线的亮度############################
func _on_friend_talk_focus_exited() -> void:
	# friendSplit.dragger_visibility = SplitContainer.DRAGGER_HIDDEN_COLLAPSED
	pass # Replace with function body.

func _on_friend_talk_focus_entered() -> void:
	# friendSplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	pass # Replace with function body.


func _on_club_talk_focus_exited() -> void:
	# clubSplit.dragger_visibility = SplitContainer.DRAGGER_HIDDEN_COLLAPSED
	pass # Replace with function body.

func _on_club_talk_focus_entered() -> void:
	# clubSplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	pass # Replace with function body.

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

#################################################################
# 加载更多历史消息
func _load_more_history(forward: bool):
	if current_channel_id.is_empty():
		return
	
	# 获取当前channel的消息
	var messages = message_history.get(current_channel_id, [])
	if messages.is_empty():
		return

	# 发起加载请求
	await Network.get_chat_history(current_channel_id, MESSAGES_PER_PAGE, forward)

#################################################################
# 功能函数

# 加载本地历史记录
func load_local_history():
	message_id_cache = Network.validate_dict_types(DataManager.get_instance().get_data(uid+"_msg_cache",message_id_cache))
	# print("加载本地历史记录2:",message_id_cache)
	var channelList = DataManager.get_instance().get_channel_list(uid)
	print("channelList:-->历史",channelList)
	for channel_id in channelList:
		if not message_history.has(channel_id):
			message_history[channel_id] = []
		message_history[channel_id] = DataManager.get_instance().get_chat_history(channel_id)
	# print("本地历史记录--->",message_history)
	pass
  


# 删除消息的主函数
func delete_message(channel_id: String, message_id: String):
	# 从历史记录中删除
	if channel_id in message_history:
		if message_history[channel_id].is_empty():
			message_history.erase(channel_id)
			return
		Network.remove_message_by_id(message_history[channel_id], message_id)
	
	# 从ID缓存中删除
	if channel_id in message_id_cache:
		message_id_cache[channel_id].erase(message_id)

func modify_message(channel_id: String, message_id: String,content: String):
	# 从历史记录中删除
	if channel_id in message_history:
		var messages = message_history[channel_id]
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
	pass
# 检查消息是否已存在
func has_message(channel_id: String, message_id: String) -> bool:
	if not channel_id in message_id_cache:
		return false
	return message_id in message_id_cache[channel_id]
 
# 添加消息到指定channel
func add_message_to_history(channel_id: String, msg: NakamaAPI.ApiChannelMessage) -> bool:
	# 获取消息ID 
	var message_id = msg.message_id
	if message_id.is_empty():
		push_warning("Message has no ID, skipping...")
		return false
	
	# 初始化channel的消息数组和ID缓存
	if not channel_id in message_history:
		message_history[channel_id] = []
		message_id_cache[channel_id] = {
			"message_id": false,
			"finish_history": false
		}
		print("渠道---> "+str(channel_id)+" 初始化完毕")
		DataManager.get_instance().add_channel_list(uid, msg.channel_id)
	# 检查消息是否已存在
	if has_message(channel_id, message_id):
		# print("消息 %s 已经存在于渠道 %s" % [message_id, channel_id])
		return false
	
	print("新消息-->", msg.content)

	# 添加消息到历史记录和ID缓存
	message_history[channel_id].append(msg)
	message_id_cache[channel_id][message_id] = true
	
	load_channel_history(channel_id, message_history[channel_id])
	# print("保存聊天记录",message_history[channel_id].size()) 
	
	DataManager.get_instance().add_chat_history(msg.channel_id, msg)
	DataManager.get_instance().set_data(uid+"_msg_cache", message_id_cache) 
	return true

# 获取指定channel的所有历史消息
func get_channel_messages(channel_id: String) -> Array:
	# 如果字典为空，初始化它
	if message_history == null:
		message_history = {}
	
	# 如果channel_id不存在，为其创建一个空数组
	if not message_history.has(channel_id):
		message_history[channel_id] = []
		
	# 确保返回的是数组类型
	# var messages: Array = message_history[channel_id] 
	return Network.sort_dictionary_array(message_history[channel_id], "create_time",true)

# 加载channel的历史消息
func load_channel_history(channel_id: String, messages: Array) -> void:
	# 直接设置channel的消息列表 对消息按时间戳排序
	message_history[channel_id] = Network.sort_dictionary_array(messages, "create_time",true)
	pass

# 刷新当前channel的显示
func refresh_current_channel_display() -> void:
	# 清空当前显示
	clear_messages_item()
	
	# 获取并显示当前channel的所有消息
	var messages = get_channel_messages(current_channel_id)
	for message in messages:
		var msg = message if typeof(message) != TYPE_STRING else Network.parse_message(message)
		var content = msg.content if typeof(msg.content) != TYPE_STRING else JSON.parse_string(msg.content)
		add_message(current_channel_id, msg.message_id, content, msg.username, uid == msg.sender_id, Time.get_unix_time_from_datetime_string(msg.create_time))
	# 滚动到底部
	ensure_scroll_to()
	pass
 
# 获取channel的最后一条消息
func get_channel_last_message(channel_id: String) -> NakamaAPI.ApiChannelMessage:
	var messages = get_channel_messages(channel_id)
	return messages[-1] if not messages.is_empty() else {}

# 清理消息但保留控件以供复用
func clear_messages_item():
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

# 获取好友列表
func get_friends_list():
	var friendlist = await Network.get_friends_list()
	if friendlist:
		print(friendlist)
		friendListItem.clear()
		var friends = []
		var waits = []
		var refuses = []
		var approves = []
		for friend in friendlist.friends:
			var ret = await Network.add_channel_async(friend.user.id)
			if ret:
				var itemData = {
					"channel": ret,
					"user": friend.user,
					"state": friend.state,
				}
				print("渠道信息", ret, "渠道ID:", itemData.channel.id)
				# 区分是否是互为好友
				if friend.state == 0:
					friends.append(itemData)
				# 等待确认
				elif friend.state == 1:
					waits.append(itemData)
				# 请审批
				elif friend.state == 2:
					approves.append(itemData)
				# 已拒绝
				elif friend.state == 3:
					refuses.append(itemData)
				else:
					pass
				
			pass
			
		friends.sort()
		for friend in friends:
			# 处理好友数据
			var user = friend.user
			var username = user.username
			var friend_status = "在线" if user.online else "离线"
			if user.display_name:
				username += '(' + user.display_name + ')'
			# 显示好友在线状态
			username += '[' + friend_status + ']'
			var index = friendListItem.add_item(username)
			# 加载头像
			if user.avatar_url:
				var texture = await Network.load_texture_async(user.avatar_url)
				if texture:
					friendListItem.set_item_icon(index, texture)
			friendListItem.set_item_metadata(index, friend)
			pass
		var stateName = '[请审批通过]'
		approves.sort()
		for friend in approves:
			# 处理好友数据
			var user = friend.user
			var username = user.username
			# if user.display_name:
			# 	username += '('+user.display_name+')'
			# 显示好友在线状态
			username += stateName
			var index = friendListItem.add_item(username)
			# 加载头像
			if user.avatar_url:
				var texture = await Network.load_texture_async(user.avatar_url)
				if texture:
					friendListItem.set_item_icon(index, texture)
			friendListItem.set_item_metadata(index, friend)
			pass
		stateName = '[等待确认]'
		waits.sort()
		for friend in waits:
			# 处理好友数据
			var user = friend.user
			var username = user.username
			# if user.display_name:
			# 	username += '('+user.display_name+')'
			# 显示好友在线状态
			username += stateName
			var index = friendListItem.add_item(username)
			# 加载头像
			if user.avatar_url:
				var texture = await Network.load_texture_async(user.avatar_url)
				if texture:
					friendListItem.set_item_icon(index, texture)
			friendListItem.set_item_metadata(index, friend)
			pass
		refuses.sort()
		stateName = '[对方已拒绝]'
		for friend in refuses:
			# 处理好友数据
			var user = friend.user
			var username = user.username
			# if user.display_name:
			# 	username += '('+user.display_name+')'
			# 显示好友在线状态
			username += stateName
			var index = friendListItem.add_item(username)
			# 加载头像
			if user.avatar_url:
				var texture = await Network.load_texture_async(user.avatar_url)
				if texture:
					friendListItem.set_item_icon(index, texture)
			friendListItem.set_item_metadata(index, friend)
		
	print("获取好友列表")
	pass

####


#######################弹窗按钮旋转###############################
# 设置旋转中心点
func set_rotation_pivot():
	# 设置旋转中心为按钮中心
	button.pivot_offset = button.size / 2
	button.rotation_degrees = 45
	pass


#########################################################

func enter_fullscreen():
	if is_fullscreen:
		return

	# 保存当前状态
	save_current_state()
	
	# 准备全屏状态
	var viewport = get_viewport()
	if viewport:
		var target_size = viewport.get_visible_rect().size
		var target_position = Vector2.ZERO
		
		if animate_transition:
			animate_to_fullscreen(target_position, target_size)
		else:
			apply_fullscreen(target_position, target_size)

	pass

func exit_fullscreen():
	if !is_fullscreen:
		return
	
	if animate_transition:
		animate_to_normal()
	else:
		restore_original_state()
	pass

func save_current_state():
	var parent = get_parent()
	if parent:
		original_state.parent = parent
		original_state.position = position
		original_state.size = size
		original_state.anchors = {
			"left": anchor_left,
			"right": anchor_right,
			"top": anchor_top,
			"bottom": anchor_bottom
		}
		original_state.margins = {
			"left": offset_left,
			"right": offset_right,
			"top": offset_top,
			"bottom": offset_bottom
		}
	pass

func apply_fullscreen(target_position: Vector2, target_size: Vector2):
	var viewport = get_viewport()
	if !viewport:
		return
		
	# 保存当前父节点引用
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
		
		# 设置全屏属性
		viewport.add_child(self)
		position = target_position
		size = target_size
		anchors_preset = Control.PRESET_FULL_RECT
		
		# 确保显示在最上层
		top_level = true
		
		# 更新状态
		is_fullscreen = true
		emit_signal("fullscreen_changed", true)

func animate_to_fullscreen(target_position: Vector2, target_size: Vector2):
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 先设置top_level确保在最上层
	top_level = true
	
	# 动画过渡到全屏
	tween.tween_property(self, "position", target_position, transition_duration)
	tween.parallel().tween_property(self, "size", target_size, transition_duration)
	
	tween.tween_callback(func():
		var viewport=get_viewport()
		if viewport and original_state.parent:
			if get_parent() != viewport:
				original_state.parent.remove_child(self)
				viewport.add_child(self)
			anchors_preset=Control.PRESET_FULL_RECT
			is_fullscreen=true
			emit_signal("fullscreen_changed", true)
	)
	pass

func animate_to_normal():
	if !original_state.parent:
		return
	WindowDrag.unregister_drag_zone(original_state.parent)
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 动画过渡到原始状态
	tween.tween_property(self, "position", original_state.position, transition_duration)
	tween.parallel().tween_property(self, "size", original_state.size, transition_duration)
	
	tween.tween_callback(func():
		restore_original_state()
	)
	pass

func restore_original_state():
	if !original_state.parent:
		return
		
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	
	# 恢复到原始父节点
	original_state.parent.add_child(self)
	WindowDrag.unregister_drag_zone(original_state.parent)
	
	# 恢复原始属性
	position = original_state.position
	size = original_state.size
	anchor_left = original_state.anchors.left
	anchor_right = original_state.anchors.right
	anchor_top = original_state.anchors.top
	anchor_bottom = original_state.anchors.bottom
	offset_left = original_state.margins.left
	offset_right = original_state.margins.right
	offset_top = original_state.margins.top
	offset_bottom = original_state.margins.bottom
	
	
	# 重置顶层显示
	top_level = false
	
	is_fullscreen = false
	emit_signal("fullscreen_changed", false)
	pass

func showLoadMore(isVisible: bool):
	print("显示加载更多按钮", isVisible)
	var kind = mainPanle.current_tab as MessageKind
	match kind:
		MessageKind.WORLD:
			btn_upmoreWorld.visible = isVisible
		MessageKind.CHAT:
			btn_upmoreChat.visible = isVisible
		MessageKind.CLUB:
			btn_upmoreClub.visible = isVisible
	pass

func getCurChannelData():
	var channel = null
	var kind = mainPanle.current_tab as MessageKind
	match kind:
		MessageKind.WORLD:
			# 世界
			channel = null
			pass
		MessageKind.CHAT:
			# 好友
			var info = friendListItem.GetCurrentItemData()
			if info:
				channel = info.channel
			pass
		MessageKind.CLUB:
			# 俱乐部
			var info = clubListItem.GetCurrentItemData()
			if info:
				channel = info.channel
			pass
		_:
			print("无效的选项")
	return channel
# 处理滚动结束事件
func _on_msg_scroll_ended() -> void:
	print("滚动结束")
	pass # Replace with function body.


func _on_btn_upmore_pressed() -> void:
	isToTop = true
	_load_more_history(false)
	pass # Replace with function body.
