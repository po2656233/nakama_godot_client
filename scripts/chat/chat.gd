extends "res://scripts/chat/chat_system.gd"
@onready var mainPanle = $MarginContainer/Panel/TabContainer
@onready var addfirendPanle = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/AddFirends
@onready var addclubPanle = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/AddClub
@onready var friendListItem = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/Panel_friends/VBoxContainer/ItemList
# @onready var clubListItem = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/Panel_clubs/VBoxContainer/ItemList

@onready var clubListItem = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/Panel_clubs/VBoxContainer/GroupList

@onready var btn_upmoreChat = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/Panel_talk/btn_upmore
@onready var btn_upmoreClub = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/Panel_talk/btn_upmore
@onready var btn_upmoreWorld = $MarginContainer/Panel/TabContainer/world/Panel_talk/btn_upmore

# @onready var clubSplit = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub
# @onready var friendSplit = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends
@export var toggle_button_path: NodePath
 
enum ScrollType {
	TOP, # 接收到的消息
	MIDDLE, # 滚动到中间 
	BOTTOM # 滚动到最底部
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

var onlineColor = Color(0.605, 0.6, 0.636, 0.961)
var leaveColor = Color(0.391, 0.491, 0.585, 0.5)
var is_first = true

var button: Button
 

# 初始化 
func _ready():
	if not Network.player_data:
		PopupManager.show_message("未登录")
		return
	myUsername = Network.player_data.username
	uid = Network.player_data.id
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

	set_rotation_pivot()		# 设置旋转中心点
	# 加载本地历史消息
	load_local_history()

	# 获取好友列表
	get_friends_list()

	# 获取俱乐部
	get_club_list()

	# 连接信号
	sendTextEdit.finished.connect(_on_btn_send_pressed)
	SignalManager.FreshFriendListSIG.connect(_on_fresh_friend_list) #刷新好友列表
	SignalManager.FreshClubListSIG.connect(_on_fresh_club_list) #刷新俱乐部列表
	Network.changeChannelSIG.connect(_on_change_channel)
	 
	Network._socket.received_channel_presence.connect(_on_channel_presence)
	Network._socket.received_channel_message.connect(_on_received_message)
	Network._socket.received_status_presence.connect(_on_status_presence) #监听好友状态
	Network.chat_history_received.connect(_on_history_message)
	pass


func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE: # 或使用 KEY_RETURN
			WindowDrag.stopMove = false
			exit_fullscreen()
			get_viewport().set_input_as_handled() # 阻止事件继续传
	pass
 



######################################################
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

# 添加好友完成后刷新好友列表
func _on_fresh_friend_list():
	get_friends_list()
	pass

func _on_fresh_club_list():
	get_club_list()
	pass

# 切换频道
func _on_change_channel(channel_id):
	print("当前频道:", channel_id)
	current_channel_id = channel_id
	isToTop = false 
	changePanel(mainPanle.current_tab)	
	refresh_current_channel_display()
	pass

# 收到消息--------------------------
func _on_received_message(msg):
	if msg.message_id == "":
		return
	print("收到消息:", msg)
	if msg.code == MessageCode.JoinedGroup:
		msg.content = msg.username+"加入了群聊"
	elif msg.code == MessageCode.AddedToGroup:
		msg.content = msg.username+"已加入群聊"
	elif msg.code == MessageCode.KickedFromGroup:
		msg.content = msg.username+"已被踢出群聊"
	elif msg.code == MessageCode.LeftGroup:
		msg.content = msg.username+"已离开群聊"

	if add_message_to_history(msg.channel_id, msg):
		if msg.sender_id != uid:
			SignalManager.RecvMessageSIG.emit(msg)
		message_to_show(msg)
	pass

# 收到历史消息----------------------
func _on_history_message(msgList):
	print("收到历史消息:", msgList.size())
	# 校验是否有新消息
	var channel_id = ""
	var haveNew = msgList.size() == 0
	for msg in msgList:
		channel_id = msg.channel_id
		if add_message_to_history(msg.channel_id, msg):
			haveNew = true
		if message_id_cache[channel_id] and message_id_cache[channel_id].finish_history:
			break
		pass
	# 判断是否已经拉完
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
	# 刷新当前显示的频道信息
	if haveNew:
		print("有新消息")
		refresh_current_channel_display()
	pass


## 监听好友状态
func _on_status_presence(presence):
	print("好友状态变更:", presence)
	var count = friendListItem.item_count
	for joinItem in presence.joins:
		for i in range(count):
			var friend = friendListItem.get_item_metadata(i)
			var user = friend.user
			if user.id == joinItem.user_id:
				friend.online = joinItem.status
				var username = user.username
				if user.display_name:
					username += '(' + user.display_name + ')'
						# 显示好友在线状态
				username += '[在线]'
				friendListItem.set_item_text(i,username)
				friendListItem.set_item_metadata(i, friend)
				friendListItem.set_item_custom_fg_color(i, onlineColor)
				friendListItem.move_item(i, 0)
				break
	for leaveItem in presence.leaves:
		for i in range(count):
			var friend = friendListItem.get_item_metadata(i)
			var user = friend.user
			if user.id == leaveItem.user_id:
				friend.online = leaveItem.status
				var username = user.username 
				if user.display_name:
					username += '(' + user.display_name + ')'
						# 显示好友在线状态
				username += '[离线]'
				friendListItem.set_item_text(i,username)
				friendListItem.set_item_metadata(i, friend)
				friendListItem.set_item_custom_fg_color(i, leaveColor)
				friendListItem.move_item(i, count - 1)
				break
	pass

func _on_channel_presence(presence):
	print("频道状态变更:", presence)
	pass



#################################################################
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
			SignalManager.SendMessageSIG.emit(msg)
			sendTextEdit.clear()
			isToTop = false
		else:
			PopupManager.show_message("发送失败")
		return
	PopupManager.show_message("未指定频道")
	pass # Replace with function body.

############################调整分割线的亮度############################

#################################################################
# 加载更多历史消息
func _load_more_history(forward: bool):
	if current_channel_id.is_empty():
		return

	# 发起加载请求
	await Network.get_chat_history(current_channel_id, MESSAGES_PER_PAGE, forward)

#################################################################
# 获取好友列表
func get_friends_list():
	var friendlist = await Network.get_friends_list()
	if friendlist:
		friendListItem.clear()
		var friendIds = []
		var friendNames = []
		DataManager.get_instance().remove_friend_all(uid)
		for friend in friendlist.friends:
			var ret = await Network.add_channel_async(friend.user.id)
			if ret:
				# 区分是否是互为好友
				if friend.state == 0:
					var user = friend.user
					var username = user.username
					var friend_status = "在线" if user.online else "离线"
					friendIds.append(user.id)
					friendNames.append(username)
					DataManager.get_instance().add_uid_friend(uid,user.serialize()) 
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
						pass
					print("好友列表--> ", friend.user)
					friendListItem.set_item_metadata(index, {
							"channel": ret,
							"user": friend.user,
							"state": friend.state,
							"online":friend.user.online,
						})
					if user.online:
						friendListItem.set_item_custom_fg_color(index, onlineColor)
						friendListItem.move_item(index, 0)
					else:
						friendListItem.set_item_custom_fg_color(index, leaveColor)
						friendListItem.move_item(index, friendListItem.item_count - 1)
				if friend.state == 2:#需要审批
					SignalManager.NewNotifySIG.emit(null)
					pass
			# 状态
			DataManager.get_instance().add_uid_approval(Network.player_data.id,
			{
				"type":"用户",
				"uid":friend.user.id,
				"name":friend.user.username,
				"time":friend.user.create_time,
				"update_time":friend.user.update_time,
				"status":friend.state,
			})
			pass
		await Network.update_status_async("online")
	print("获取好友列表")
	pass
####
func get_club_list():
	var result = await Network.get_group_list(uid)
	if result == null:
		return
	print("俱乐部数量:",result.user_groups.size())
	clubListItem.clear() 
	
	for info in result.user_groups:
		var group = info.group
		print("俱乐部信息:",group)
		var ret = await Network.add_channel_async(group.id,2)
		if ret:
			print("俱乐部渠道信息:",ret)
			clubListItem._on_group_joined(
				{
					"id": group.id,
					"name": group.name,
					"channel":ret,
					"avatar":group.avatar_url,
					"description": group.description,
					"member_count": group.edge_count,
					"max_count": group.max_count,
					"notification_enabled": group.open,
					"owner_id":group.creator_id,
					"create_time":group.create_time,
					"update_time":group.update_time,
				},
			)
			DataManager.get_instance().add_uid_club(uid,group.serialize()) 
	pass



#######################弹窗按钮旋转###############################
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
				print("俱乐部信息:",channel)
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


# 设置旋转中心点
func set_rotation_pivot():
	# 设置旋转中心为按钮中心
	button.pivot_offset = button.size / 2
	button.rotation_degrees = 45
	pass
###############################################################
func _on_btn_popup_pressed() -> void:
	# 来回旋转按钮
	button.rotation_degrees += 180
	
	# 如果要添加动画效果
	tween = create_tween()
	tween.tween_property(button, "rotation_degrees", 90, 0.01)
	_on_fullscreen_toggle()
	pass # Replace with function body.
