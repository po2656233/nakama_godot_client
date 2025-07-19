extends "res://scripts/chat/chat_system.gd"
@onready var mainPanle = $MarginContainer/Panel/TabContainer
@onready var addfirendPanle = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/AddFirends
@onready var addclubPanle = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/AddClub
@onready var friendListItem = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/Panel_friends/VBoxContainer/ItemList
# @onready var clubListItem = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/Panel_clubs/VBoxContainer/ItemList
@onready var tab_container: TabContainer = $MarginContainer/Panel/TabContainer
@onready var clubListItem = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/Panel_clubs/VBoxContainer/GroupList

@onready var btn_upmoreChat = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/Panel_talk/btn_upmore
@onready var btn_upmoreClub = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/Panel_talk/btn_upmore
@onready var btn_upmoreWorld = $MarginContainer/Panel/TabContainer/world/Panel_talk/btn_upmore
@onready var light_switch = $MarginContainer/Panel/light_switch

@onready var keyboardContainer = $MarginContainer/Panel/input_area/HBoxContainer/VBoxContainer
# @onready var clubSplit = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub
# @onready var friendSplit = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends
@export var toggle_button_path: NodePath

enum ScrollType {
	TOP, # 接收到的消息
	MIDDLE, # 滚动到中间
	BOTTOM # 滚动到最底部
}
enum NotifyStatus {
	NONE = 0,
	RECV_OFFLINE = -1, # 对方离线或不在频道的消息
	WANT_FRIEND = -2, # 用户 X 想将您添加为好友。
	ACCEPT_FRIEND = -3, # 用户 X 接受了您的好友邀请。
	ACCEPT_GROUP = -4, # 您已被 X 组接受。
	WANT_GROUP = -5, # 用户 X 想要加入您的组。
	FRIEND_JOIN = -6, # 您的朋友 X 刚刚加入游戏。
	SERVER_CLOSE = -7, # 服务器断开
	BANNED = -8, # 你被封禁了。
}


var onlineColor = Color.YELLOW
var leaveColor = Color.GRAY
var is_first = true
var is_mobile: bool = false
var last_keyboard_height = 0
var origin_height = 0
var button: Button
var isOpenLight = false
var first_friends = true
var first_clubs = true
var first_world = true


# 初始化 
func _ready():

	tab_container.set_tab_title(0,"世界")
	tab_container.set_tab_title(1,"俱乐部")
	tab_container.set_tab_title(2,"好友")
	if not OnlineLogin.player_data:
		PopupManager.show_message("未登录")
		OnlineLogin.relogin()
		return
	# 获取基础信息
	myHeadicon = OnlineLogin.get_my_headIcon()
	myUsername = OnlineLogin.get_my_name()
	uid = OnlineLogin.get_my_id()
	is_mobile = Util.isMobile()

	# 虚拟键盘高度
	origin_height = keyboardContainer.position.y
	await get_tree().process_frame
	
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
	button.visible = Util.isFullScreen()
	light_switch.visible = Util.isFullScreen()

	set_rotation_pivot() # 设置旋转中心点
	
	# 线程开启加载俱乐部成员
	# startThread()
	call_thread_safe("initData")

	# 连接信号
	sendTextEdit.finished.connect(_on_btn_send_pressed)
	SignalManager.FullWindowSIG.connect(_on_fullscreen)
	SignalManager.NormalWindowSIG.connect(_on_normalscreen)
	SignalManager.FreshFriendListSIG.connect(_on_fresh_friend_list) # 刷新好友列表
	SignalManager.FreshClubListSIG.connect(_on_fresh_club_list) # 刷新俱乐部列表
	SignalManager.AddClubSIG.connect(_on_add_club) # 添加俱乐部
	SignalManager.UpdateClubSIG.connect(_on_update_club) # 更新俱乐部
	SignalManager.RecvFinishSIG.connect(_on_recv_finish) # 收到完成消息
	OnlineChat.changeChannelSIG.connect(_on_change_channel)
	
	_on_socket_connected()
	# Online.socket_connected.connect(_on_socket_connected)
	OnlineChat.chat_history_received.connect(_on_history_message)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# 在进程中检查键盘高度变化
	if not is_mobile: return
	var current_height = DisplayServer.virtual_keyboard_get_height()
	if current_height != last_keyboard_height:
		_on_virtual_keyboard_height_changed(current_height)
		last_keyboard_height = current_height
	pass

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE: # 或使用 KEY_RETURN
			WindowDrag.stopMove = false
			exit_fullscreen()
			get_viewport().set_input_as_handled() # 阻止事件继续传
	pass

####################调整虚拟键盘#########################################
func _on_virtual_keyboard_height_changed(keyboard_height):
	# 如果键盘显示，确保输入框可见
	if keyboard_height > 0:
		var viewport_size = get_viewport_rect().size
		var editY = sendTextEdit.size.y
		var editGlobalY = sendTextEdit.global_position.y
		var target_position = viewport_size.y - keyboard_height - editY - 20
		
		# 如果输入框被键盘遮挡，调整VBoxContainer的位置
		if editGlobalY > target_position:
			var offset = editGlobalY - target_position
			keyboardContainer.position.y -= offset
	else:
		keyboardContainer.position.y = origin_height
	pass
####################线程开启加载数据##################################
func initData():
	# 加载世界频道


	# 加载本地历史消息
	load_local_history()
	
	# # 获取好友列表
	# get_friends_list()

	# # 加载群组列表
	# get_club_list()
	pass
######################################################
func _on_socket_connected():
	print("连接成功,监听聊天 通知等消息")
	# 使用示例 - 传入任意 socket 对象
	if Online.nakama_socket:
		Util.safe_connect(Online.nakama_socket, "received_channel_presence", self, "_on_channel_presence")
		Util.safe_connect(Online.nakama_socket, "received_channel_message", self, "_on_received_message")
		Util.safe_connect(Online.nakama_socket, "received_status_presence", self, "_on_status_presence") # 监听好友状态
		Util.safe_connect(Online.nakama_socket, "received_notification", self, "_on_received_notify")
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

# 添加好友完成后刷新好友列表
func _on_fresh_friend_list():
	get_friends_list()
	pass

func _on_fresh_club_list():
	get_club_list()
	pass

# 添加俱乐部
func _on_add_club(club):
	print("添加俱乐部的信息-->:", club)
	add_club(club)

func _on_update_club(clubName):
	print("更新俱乐部的信息-->:", clubName)
	var result = await OnlineChat.search_groups(clubName)
	if result:
		for group in result.groups:
			clubListItem._on_group_updated({
					"id": group.id,
					"name": group.name,
					"channel": null,
					"avatar": group.avatar_url,
					"description": group.description,
					"member_count": group.edge_count,
					"max_count": group.max_count,
					"notification_enabled": true,
					"owner_id": group.creator_id,
					"create_time": group.create_time,
					"update_time": group.update_time,
				})
	pass

# 切换频道
func _on_change_channel(channel_id):
	print("当前频道:", channel_id)
	current_channel_id = channel_id
	isToTop = false
	var tabNum = mainPanle.current_tab if mainPanle else 0
	changePanel(tabNum)
	refresh_current_channel_display()
	pass

# 接收完历史消息后
func _on_recv_finish():
	pass

# 收到消息--------------------------
func _on_received_message(msg):
	if msg.message_id == "":
		return
	print("收到消息:", msg)
	if add_message_to_history(msg.channel_id, msg):
		if msg.sender_id != uid:
			SignalManager.RecvMessageSIG.emit(msg)
		if current_channel_id == msg.channel_id:
			message_to_show(msg)
		ensure_scroll_to()
	pass

# 收到历史消息----------------------
func _on_history_message(msgList):
	print("收到历史消息:", msgList.size())
	# 校验是否有新消息
	var channel_id = ""
	var haveNew = false
	for msg in msgList:
		channel_id = msg.channel_id
		if add_message_to_history(msg.channel_id, msg):
			haveNew = true
		# if message_id_cache[channel_id] and message_id_cache[channel_id].finish_history:
		# 	break
		pass
	# # 判断是否已经拉完
	# if channel_id != "" and not message_id_cache[channel_id].finish_history:
	# 	var isFull = msgList.size() != MESSAGES_PER_PAGE
	# 	if isFull and message_id_cache[channel_id]:
	# 		message_id_cache[channel_id].finish_history = true
	# 		print("渠道" + channel_id + "历史消息加载完毕")
	# 		DataManager.get_instance().set_data(uid+"_msg_cache", message_id_cache) 
	# 		pass
	# 	showLoadMore(!isFull)
	# else:
	# 	showLoadMore(false)
	# 刷新当前显示的频道信息
	if haveNew:
		print("有新消息")
		refresh_current_channel_display()
	
	pass
#############################################################

## 监听好友状态
func _on_status_presence(presence):
	print("好友状态变更:", presence)
	var count = presence.joins.size()
	for joinItem in presence.joins:
		changeOnline(joinItem.user_id, true)
	if count > 1:
		SignalManager.OnlineSIG.emit()
	if count == 0:
		for leaveItem in presence.leaves:
			changeOnline(leaveItem.user_id, false)
	pass


func changeOnline(user_id: String, online: bool) -> int:
	var count = friendListItem.item_count
	for i in count:
		var friend = friendListItem.get_item_metadata(i)
		var user = friend.user
		if user.id == user_id:
			user.online = online
			var username = user.username
			print("好友变更状态--> ", username, " 在线状态:", online)
			if user.display_name:
				username += '(' + user.display_name + ')'
					# 显示好友在线状态
			username += '[在线]' if online else '[离线]'
			friendListItem.set_item_text(i, username)
			friendListItem.set_item_metadata(i, friend)
			friendListItem.set_item_custom_fg_color(i, onlineColor if online else leaveColor)
			friendListItem.move_item(i, 0 if online else count - 1)
			return i
	return -1


func _on_channel_presence(presence):
	print("频道状态变更:", presence.channel_id)
	# for p in p_presence.joins:
	#   room_users[p.user_id] = p

  	# for p in p_presence.leaves:
	#   room_users.erase(p.user_id)
	pass

func _on_received_notify(notify):
	var content = JSON.parse_string(notify.content)
	print("收到通知内容:", notify)
	var approval_data = {
				"type": "俱乐部",
				"level": 0,
				"uid": notify.sender_id,
				"name": "",
				"time": notify.create_time,
				"group_id": "-",
				"group_name": "-",
				"update_time": "-",
				"status": 2,
			}
	if content.has("username"):
		approval_data["username"] = content.username
	var status = notify.code as NotifyStatus
	match status:
		NotifyStatus.RECV_OFFLINE:
			# changeOnline(notify.sender_id, true)
			pass
		NotifyStatus.WANT_FRIEND:
			approval_data["type"] = "好友"
			approval_data["status"] = 2
			DataManager.get_instance().add_uid_approval(OnlineLogin.get_my_id(), approval_data)
			SignalManager.NewNotifySIG.emit()
		NotifyStatus.ACCEPT_FRIEND:
			approval_data["type"] = "好友"
			approval_data["status"] = 4
			DataManager.get_instance().add_uid_approval(OnlineLogin.get_my_id(), approval_data)
			# SignalManager.NewNotifySIG.emit()
			SignalManager.FreshFriendListSIG.emit()
		NotifyStatus.ACCEPT_GROUP:
			approval_data["status"] = 4
			DataManager.get_instance().add_uid_approval(OnlineLogin.get_my_id(), approval_data)
			SignalManager.NewNotifySIG.emit()
			pass
		NotifyStatus.WANT_GROUP:
			approval_data["status"] = 2
			DataManager.get_instance().add_uid_approval(OnlineLogin.get_my_id(), approval_data)
			SignalManager.NewNotifySIG.emit()
			pass
		NotifyStatus.FRIEND_JOIN:
			SignalManager.NewNotifySIG.emit()
			pass
		NotifyStatus.SERVER_CLOSE:
			pass
		NotifyStatus.BANNED:
			approval_data["status"] = 3
			DataManager.get_instance().add_uid_approval(OnlineLogin.get_my_id(), approval_data)
			SignalManager.NewNotifySIG.emit()
			pass
		_:
			pass
	pass


# enum NotifyStatus {
# 	RECV_OFFLINE = -1, # 对方离线或不在频道的消息
# 	WANT_FRIEND  = -2, # 用户 X 想将您添加为好友。
# 	ACCEPT_FRIEND = -3, # 用户 X 接受了您的好友邀请。
# 	ACCEPT_GROUP = -4, # 您已被 X 组接受。
# 	WANT_GROUP  = -5, # 用户 X 想要加入您的组。
# 	FRIEND_JOIN = -6, # 您的朋友 X 刚刚加入游戏。
# 	SERVER_CLOSE = -7, # 服务器断开
# 	BANNED = -8, # 你被封禁了。


#################################################################
func _on_btn_send_pressed() -> void:
	if sendTextEdit.text.strip_edges() == "":
		ensure_scroll_to()
		return
	# 发送消息
	var channel = getCurChannelData()
	if channel:
		OnlineChat.set_current_channel(channel)
		var msg = OnlineChat.getMsgData(null)
		msg.content = sendTextEdit.text.strip_edges()
		msg.kind = mainPanle.current_tab
		msg.type = ContentType.TEXT
		msg.headicon = OnlineLogin.get_my_headIcon()
		print("发送消息:", msg)
		var ret = await OnlineChat.send_message(msg)
		if ret == OK:
			SignalManager.SendMessageSIG.emit(msg)
			sendTextEdit.clear()
			isToTop = false
		else:
			PopupManager.show_message("发送失败")
		return
	PopupManager.show_message("未指定频道")
	pass # Replace with function body.


func _on_fullscreen():
	if button:
		button.visible = true
		light_switch.visible = true
	pass

func _on_normalscreen():
	if button:
		button.visible = false
		light_switch.visible = false
	pass
############################调整分割线的亮度############################

#################################################################
# 加载更多历史消息
func _load_more_history(forward: bool):
	if current_channel_id.is_empty():
		return

	# 发起加载请求
	await OnlineChat.get_chat_history(current_channel_id, MESSAGES_PER_PAGE, forward)
	pass

#################################################################
# 获取好友列表
func get_friends_list():
	var friendlist = await OnlineChat.get_friends_list()
	if friendlist and friendlist.friends.size() > 0:
		friendListItem.clear()
		var friendIds = []
		var friendNames = []
		DataManager.get_instance().remove_friend_all(uid)
		print("好友人数:", friendlist.friends.size())
		for friend in friendlist.friends:
			# 避免重复 
			var user = friend.user
			if friendIds.find(user.id) != -1:
				continue
			# 区分是否是互为好友 
			if friend.state == 0:
				var ret = await OnlineChat.add_channel_async(friend.user.id, 0)
				if ret:
					var username = user.username
					var friend_status = "在线" if user.online else "离线"
					friendIds.append(user.id)
					friendNames.append(username)
					# 显示好友昵称
					if user.display_name:
						username += '(' + user.display_name + ')'
					# 显示好友在线状态
					username += '[' + friend_status + ']'
					var index = friendListItem.add_item(username)
					# 加载头像
					if user.avatar_url:
						var texture = await Util.load_texture_async(user.avatar_url)
						if texture:
							friendListItem.set_item_icon(index, texture)
						pass
					# 保存好友信息
					friendListItem.set_item_metadata(index, {
							"channel": ret,
							"user": friend.user,
							"state": friend.state,
							"online": friend.user.online,
						})
					DataManager.get_instance().add_uid_friend(uid, user.serialize())
					friendListItem.set_item_custom_fg_color(index, onlineColor if user.online else leaveColor)
					# 上线了则移至上方
					friendListItem.move_item(index, 0 if user.online else friendListItem.item_count - 1)
					print("好友--> ", index, "好友信息", friend.user)
					pass
			elif friend.state == 2: # 需要审批
				SignalManager.NewNotifySIG.emit(null)
				pass
			# 状态
			var approval_data = {
				"type": "用户",
				"level": 0,
				"uid": friend.user.id,
				"name": friend.user.username,
				"time": friend.user.create_time,
				"group_id": "-",
				"group_name": "-",
				"update_time": friend.user.update_time,
				"status": friend.state,
			}
			DataManager.get_instance().add_uid_approval(OnlineLogin.get_my_id(), approval_data)
			pass
		await OnlineChat.update_status_async("online")
	print("获取好友列表")
	pass
####
func add_club(group):
	if group.name == "world":
		return
	print("俱乐部信息:", group)
	var ret = await OnlineChat.add_channel_async(group.id, 2)
	if ret:
		var group_data = {
				"id": group.id,
				"name": group.name,
				"channel": ret,
				"avatar": group.avatar_url,
				"description": group.description,
				"member_count": group.edge_count,
				"max_count": group.max_count,
				"notification_enabled": true,
				"owner_id": group.creator_id,
				"create_time": group.create_time,
				"update_time": group.update_time,
			}
		clubListItem._on_group_joined(group_data)
		# 更新成员
		await update_club(group.serialize())
	pass

#######################获取俱乐部###############################
func update_club(group):
	# 获取成员列表
	var retsult = await OnlineChat.get_group_member_list_async(group.id)
	if not retsult:
		return
	var dataList = []
	var isAdmin = false
	for info1 in retsult.group_users:
		if info1.user.id == OnlineLogin.get_my_id() and (info1.state == 0 or info1.state == 1):
			isAdmin = true
			continue
		if info1.state == 3: # 申请加入群组
			dataList.append({
			"type": "俱乐部",
			"level": info1.state, # 0超管 1 管理员 2成员
			"uid": info1.user.id,
			"name": info1.user.username,
			"time": info1.user.create_time,
			"group_id": group["id"],
			"group_name": group["name"],
			"update_time": info1.user.update_time,
			"status": 2,
		})

	# 是管理员
	if isAdmin and dataList.size() > 0:
		for data in dataList:
			DataManager.get_instance().add_uid_approval(OnlineLogin.get_my_id(), data)
	DataManager.get_instance().add_uid_club(OnlineLogin.get_my_id(), group)
	pass


#######################获取俱乐部列表###############################
func get_club_list():
	var result = await OnlineChat.get_group_list(uid)
	if result == null:
		return
	print("俱乐部数量:", result.user_groups.size())
	clubListItem.clear()
	 
	for info in result.user_groups:
		await add_club(info.group)
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
			channel = OnlineChat.get_world_channel()
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
				print("俱乐部信息:", channel)
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
	if not button:
		return
	button.rotation_degrees += 180
	
	# 如果要添加动画效果
	tween = create_tween()
	tween.tween_property(button, "rotation_degrees", 90, 0.01)
	_on_fullscreen_toggle()
	pass # Replace with function body.

##############################################################
func _on_text_edit_focus_entered() -> void:
	# 获取目标编辑控件的全局位置和大小
	if is_mobile:
		DisplayServer.virtual_keyboard_show("中文输入法")
	pass # Replace with function body.
 
func _on_text_edit_focus_exited() -> void:
	if is_mobile:
		DisplayServer.virtual_keyboard_hide()
	pass # Replace with function body.

func _on_text_edit_finished() -> void:
	if is_mobile:
		DisplayServer.virtual_keyboard_hide()
	pass # Replace with function body.


func _on_light_button_pressed() -> void:
	var normal = light_switch.texture_normal
	var pressed = light_switch.texture_pressed
	light_switch.texture_normal = pressed
	light_switch.texture_pressed = normal
	if !isOpenLight:
		SignalManager.OpenLightSIG.emit()
	else:
		SignalManager.CloseLightSIG.emit()
	isOpenLight = !isOpenLight
	pass # Replace with function body.


func _on_tab_container_tab_selected(tab: int) -> void:
	if tab == 0 and first_world:
		first_world = false
		var world = OnlineChat.get_world_channel()
		if not world:
			world = await OnlineChat.load_world_channel()
		if world:
			DataManager.get_instance().set_world_channel_id(world.id)
			_on_change_channel(world.id)
		print("加载世界频道")
			# await OnlineChat.get_chat_history(world.id)
	elif tab == 1 and first_clubs:
		first_clubs = false
		# get_club_list()
		call_thread_safe("get_club_list")
	elif tab == 2 and first_friends:
		first_friends = false
		# get_friends_list()  
		call_thread_safe("get_friends_list")
	print("切换选项卡:", tab)
	pass # Replace with function body.
