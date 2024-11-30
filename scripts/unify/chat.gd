extends Control
@onready var mainPanle = $MarginContainer/Panel/TabContainer
@onready var addfirendPanle = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/AddFirends
@onready var addclubPanle = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/AddClub
@onready var friendListItem = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/Panel_friends/VBoxContainer/ItemList
@onready var friendTalkItem = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/Panel_talk/ItemList
@onready var clubListItem = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/Panel_clubs/VBoxContainer/ItemList
@onready var clubTalkItem = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/Panel_talk/ItemList
@onready var findFriend = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/AddFirends
@onready var findClub = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/AddClub
@onready var sendTextEdit = $MarginContainer/Panel/HBoxContainer/PanelContainer/TE_send

##聊天消息
# @onready var chat_system = friendTalkItem#$MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/Panel_talk

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
var is_fullscreen := false
var is_rotated = false
var tween: Tween
var button: Button


# 初始化
func _ready():
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
	findFriend.addFinishSIG.connect(_on_add_finish)
	sendTextEdit.finished.connect(_on_btn_send_pressed)
	# Network.socket.received_channel_message.connect(_on_received_message)

	# 初始化聊天系统
	# chat_system.connection_status_changed.connect(_on_connection_status_changed)
	# chat_system.chat_join_status_changed.connect(_on_chat_join_status_changed)
	# chat_system.message_sent.connect(_on_message_sent)
	# chat_system.voice_record_started.connect(_on_voice_record_started)
	# chat_system.voice_record_stopped.connect(_on_voice_record_stopped)
	# chat_system.file_selected.connect(_on_file_selected)
	# chat_system.emoji_selected.connect(_on_emoji_selected)
	
	# # 创建一个定时器来检查消息已读状态
	# var read_timer = Timer.new()
	# read_timer.wait_time = 2.0  # 每2秒检查一次
	# read_timer.timeout.connect(_on_read_status_timer_timeout)
	# add_child(read_timer)
	# read_timer.start()

	# # 测试消息
	# chat_system.add_system_message("欢迎使用增强版聊天系统！")
	
	# # 测试普通消息
	# chat_system.add_message({
	# 	"type": ChatMessageItem.MessageType.NORMAL,
	# 	"content": "这是一条测试消息",
	# 	"sender": "User1",
	# 	"is_self": false,
	# 	"timestamp": Time.get_time_string_from_system()
	# })
	
	# # 测试文件消息
	# chat_system.add_file_message(
	# 	"path/to/file.pdf",
	# 	"测试文档.pdf",
	# 	1024 * 1024,  # 1MB
	# 	true
	# )
	
	# # 测试语音消息
	# chat_system.add_voice_message(
	# 	"path/to/voice.mp3",
	# 	3.5,  # 持续时间
	# 	true
	# )
	# findClub.addFinishSIG.connect(get_club_list)
	pass


# func _input(event):
# 	if event is InputEventKey:
# 		if event.pressed and event.keycode == KEY_ENTER and not PopupManager.isVisible():  # 或使用 KEY_RETURN
# 			_on_btn_send_pressed()
# 			get_viewport().set_input_as_handled()  # 阻止事件继续传
# 	pass
################################################################
################     聊天系统相关函数   ########################
################################################################

# func _on_message_sent(content: String):
# 	# 处理发送的消息
# 	print("Message sent: ", content)
	
# 	# 模拟接收到对方的回复
# 	await get_tree().create_timer(1.0).timeout
# 	chat_system.add_message({
# 		"type": ChatMessageItem.MessageType.NORMAL,
# 		"content": "收到你的消息：" + content,
# 		"sender": "Bot",
# 		"is_self": false,
# 		"timestamp": Time.get_time_string_from_system()
# 	})

# func _on_voice_record_started():
# 	# 实现录音逻辑
# 	print("开始录音...")

# func _on_voice_record_stopped(path: String):
# 	# 处理录音文件
# 	print("录音结束，文件保存在：", path)
# 	# 添加语音消息
# 	chat_system.add_voice_message(path, 2.5, true)

# func _on_file_selected(path: String):
# 	var file = FileAccess.open(path, FileAccess.READ)
# 	var file_size = file.get_length()
# 	var file_name = path.get_file()
	
# 	# 添加文件消息
# 	chat_system.add_file_message(path, file_name, file_size, true)

# func _on_emoji_selected(emoji_code: String):
# 	print("选择了表情：", emoji_code)

# func _on_read_status_timer_timeout():
# 	# 定期更新消息已读状态
# 	chat_system.mark_messages_as_read()

# func _on_connection_status_changed(status: String):
# 	print("连接状态: " + status)

# func _on_chat_join_status_changed(status: String):
# 	print("频道状态: " + status)

######################################################
######################################################
func _on_fullscreen_toggle():
	if !is_fullscreen:
		enter_fullscreen()
	else:
		exit_fullscreen()
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
	button.rotation_degrees += 45
	
	# 如果要添加动画效果
	# tween = create_tween()
	# tween.tween_property(button, "rotation_degrees", 90, 0.5)
	pass # Replace with function body.

func _on_add_finish():
	get_friends_list()
	pass

func _on_received_message(msg):
	print("收到消息:",msg)
	if msg.content == "":
		return
	
	var message = JSON.parse_string(msg.content)
	if message.type == 0:
		print("收到世界消息:",message)
	elif message.type == 1:
		print("收到俱乐部消息:",message)
	elif message.type == 2:
		print("收到聊天消息:",message)
		friendTalkItem.add_message(message.content)
	else:
		print("无效的消息类型")
	pass
	# print("收到消息:",msg)


func _on_btn_send_pressed() -> void:
	if sendTextEdit.text.strip_edges() == "":
		print("全是空字符")
		return
	# 发送消息
	var msg = {
		# "type": mainPanle.current_tab,
		"type": ChatMessageItem.MessageType.NORMAL,
		# "content": "收到你的消息：" + content,
		"content": sendTextEdit.text,
		"sender": "Bot",
		"is_self": false,
		"timestamp": Time.get_time_string_from_system()
	}
	var channel = null
	if mainPanle.current_tab == 0:
		# 世界
		#Network.send_message(msg)
		pass
	elif mainPanle.current_tab == 1:
		# 俱乐部
		var info = clubListItem.GetCurrentItemData()
		if info:
			channel = info.channel
		pass
	elif mainPanle.current_tab == 2:
		# 好友
		var info = friendListItem.GetCurrentItemData()
		if info:
			channel = info.channel
		pass
	else:
		print("无效的选项")
		return
	
	# 发送消息
	if channel:
		Network.set_current_channel(channel)
		print("发送给好友 内容:",msg)
		var ret = await Network.send_message(msg)
		if ret == OK:
			friendTalkItem.add_message(msg.content)
			# chat_system.add_message(msg)
			sendTextEdit.clear()
		else:
			PopupManager.show_message("发送失败")
	pass # Replace with function body.

#################################################################
# 以下是按钮事件处理函数
func get_friends_list():
	var friendlist = await Network.get_friends_list()
	if friendlist:
		print(friendlist)
		friendListItem.clear()
		var friends = []
		var waits = []
		var refuses= []
		var approves = []
		for friend in friendlist.friends:
			var ret = await Network.add_channel_async(friend.user.id)
			if not ret.is_exception():
				var itemData ={
					"channel":ret,
					"user":friend.user,
					"state":friend.state,
				}
				print("渠道信息",ret,"渠道ID:",itemData.channel)
				# 区分是否是互为好友
				if friend.state == 0:
					friends.append(itemData)
				# 等待确认
				elif friend.state ==1:
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
				username += '('+user.display_name+')'
			# 显示好友在线状态
			username += '['+friend_status+']'
			var index = friendListItem.add_item(username)
			# 加载头像
			if user.avatar_url:
				var texture = await Network.load_texture_async(user.avatar_url)
				if texture:
					friendListItem.set_item_icon(index,texture)
			friendListItem.set_item_metadata(index,friend)
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
					friendListItem.set_item_icon(index,texture)
			friendListItem.set_item_metadata(index,friend)
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
					friendListItem.set_item_icon(index,texture)
			friendListItem.set_item_metadata(index,friend)
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
					friendListItem.set_item_icon(index,texture)
			friendListItem.set_item_metadata(index,friend)
		
	print("获取好友列表")
	pass

####


#######################弹窗按钮旋转###############################
# 设置旋转中心点
func set_rotation_pivot():
	# 设置旋转中心为按钮中心
	button.pivot_offset = button.size / 2
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
		var viewport = get_viewport()
		if viewport and original_state.parent:
			if get_parent() != viewport:
				original_state.parent.remove_child(self)
				viewport.add_child(self)
			anchors_preset = Control.PRESET_FULL_RECT
			is_fullscreen = true
			emit_signal("fullscreen_changed", true)
	)
	pass

func animate_to_normal():
	if !original_state.parent:
		return
		
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
