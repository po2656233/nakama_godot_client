extends Node

signal chat_message_received(message: Dictionary)
signal chat_presence_changed(joins: Array, leaves: Array)
signal chat_history_received(messages: Array)
signal changeChannelSIG(id:String)

var _current_channel: NakamaRTAPI.Channel
var _cursor_list_channel = null
var _world_channel = null

var history_msg_count = {}
# 聊天内容结构
var DEFAULT_MESSAGE = {
	"kind": 0,#2聊天 1俱乐部 0世界
	"type": 0,
	"headicon": "",
	"path": "",
	"content": "",
	"file": "",
	"size": 0,
	"thumbnail": "",
	"duration": 0,
}


# 设置当前聊天频道
func set_current_channel(channel: NakamaRTAPI.Channel,isLoadhistory:bool=false):
	if _current_channel == channel:
		return
	_cursor_list_channel = null
	_current_channel = channel
	if channel:
		print("切换频道信号:",channel," 是否加载历史信息:",isLoadhistory)
		changeChannelSIG.emit(channel.id)
		if isLoadhistory:
			await fetch_full_chat_history(channel.id)
			# await get_chat_history(channel.id, 20, true)
	pass

func get_cursor_for_list_channel():
	return _cursor_list_channel

# Authentication
func authenticate_device(username: String="", created:bool=false) -> bool:
	var device_id = OS.get_unique_id()
	var result = await Online.nakama_client.authenticate_device_async(device_id,username,created)
	if result.is_exception():
		return false
	return true


# Authentication
func authenticate_email(username: String,password: String,email: String="",  created:bool=false) -> bool:
	if username.is_empty() and password.is_empty():
		return await self.authenticate_device(username,created)
	
	if password.is_empty():
		push_error("password is empty")
		return false
	
	if email.is_empty():
		email = username+"@game.com"
	var result = await Online.nakama_client.authenticate_email_async(email,password,username,created)
	if result.is_exception() or not result.is_valid():
		print("发送登录请求失败",result.get_exception().message)
		return false
	return true

##############################################################

# 发送消息
func send_message(content: Dictionary) -> Error:
	if _current_channel == null:
		print("Not in a chat channel")
		return FAILED
	print("发送前确认:",_current_channel.id," 内容:",content)
	var result = await Online.nakama_socket.write_chat_message_async(_current_channel.id, content)
	if result.is_exception():
		var error_message = result.get_exception().message
		print("Failed to send message: ", error_message)
		return FAILED
	print("发送反馈:",result)
	return OK



# 获取聊天历史
func get_chat_history(channelId:String = _current_channel.id, limit: int = 20, forward: bool = false,cursor = null) -> Error:
	if channelId.is_empty():
		print("Not in a chat channel or socket is wrong")
		return FAILED
 
	# 	# 先尝试加入频道
	# var join_try = await Online.nakama_client.join_chat_async(channelId)
	# if join_try.is_exception():
	# 	print("无法加入频道: ", join_try.get_exception().message)
	# 	# 处理错误，比如通知用户或创建新频道
	# 	return FAILED


	# print("获取聊天历史",channelId," -->", limit, "-->",forward)
	if cursor == null:
		cursor = _cursor_list_channel
	var result = await Online.nakama_client.list_channel_messages_async(Online.nakama_session, channelId, limit, forward, cursor)
	if result.is_exception():
		print("Failed to get chat history: ", result.get_exception().message)
		return FAILED

	print("获取当前历史大小:",result.messages.size())
	var messages = []
	for message in result.messages:
		var content = JSON.parse_string(message.content)
		if content:
			messages.append(message)
	
	chat_history_received.emit(messages)
	if result.next_cursor:
		_cursor_list_channel = result.next_cursor
		# print("获取历史记录游标",_cursor_list_channel)
	if history_msg_count.has(channelId):
		if history_msg_count[channelId] != limit and history_msg_count[channelId] == messages.size():
			return FAILED
	history_msg_count[channelId] = messages.size()
	return OK


func fetch_older_messages(channel_id: String, cursor: String, limit: int = 20):
	if not Online.nakama_client:
		return null
	var result = await Online.nakama_client.list_channel_messages_async(Online.nakama_session, channel_id, limit, true, cursor)
	if result.is_exception():
		print("Failed to get chat history: ", result.get_exception().message)
		return null

	var messages = []
	for message in result.messages:
		var content = JSON.parse_string(message.content)
		if content:
			messages.append(message)
	# print("获取当前历史大小:",messages.size()," 上一游标:", result.prev_cursor," 下一游标:", result.next_cursor)
	chat_history_received.emit(messages)
	return result.next_cursor

func fetch_full_chat_history(channel_id: String, limit: int = 20):
	var result = await Online.nakama_client.list_channel_messages_async(Online.nakama_session, channel_id, limit, true, null)
	# print("Fetched initial messages: ", result.messages.size())
	if result.is_exception():
		print("Failed to get chat history: ", result.get_exception().message)
		return
	# print("获取当前历史大小(首次):",result.messages.size()," prev_cursor:",result.prev_cursor," next_cursor:", result.next_cursor)
	var messages = []
	for message in result.messages:
		var content = JSON.parse_string(message.content)
		if content:
			messages.append(message)
	chat_history_received.emit(messages)
	var next_cursor = result.next_cursor
	while next_cursor:
		var prev_cursor = next_cursor
		next_cursor = await fetch_older_messages(channel_id, prev_cursor, limit)
	SignalMgr.RecvFinishSIG.emit()
	pass


func get_chat_history_all(channelId:String = _current_channel.id, limit: int = 20, forward: bool = false) -> Error:
	if channelId.is_empty():
		print("Not in a chat channel or socket is wrong")
		return FAILED
	while true:
		var result = await get_chat_history(channelId, limit, forward)
		if result == FAILED:
			break
	return OK

func getMsgData(message:NakamaAPI.ApiChannelMessage)->Dictionary:
	if not message or not message.content:
		return DEFAULT_MESSAGE
	var content = JSON.parse_string(message.content)
	if content:
		return {
			"kind": Util.safe_get(content, "kind", DEFAULT_MESSAGE.kind),
			"type": Util.safe_get(content, "type", DEFAULT_MESSAGE.type),
			"headicon": Util.safe_get(content, "headicon", DEFAULT_MESSAGE.headicon),
			"username": message.username,
			"content": content,
			"path": Util.safe_get(content, "path", DEFAULT_MESSAGE.path),
			"file": Util.safe_get(content,"file", DEFAULT_MESSAGE.file),
			"size":Util.safe_get(content,"size", DEFAULT_MESSAGE.size),
			"thumbnail": Util.safe_get(content,"thumbnail", DEFAULT_MESSAGE.thumbnail),
			"duration": Util.safe_get(content,"duration", DEFAULT_MESSAGE.duration),
		}
	return DEFAULT_MESSAGE


# 上传文件
func upload_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open file"}
	
	var file_data = file.get_buffer(file.get_length())
	var file_name = file_path.get_file()
	
	var result = await Online.nakama_client.write_storage_objects_async(Online.nakama_session, [{
		"collection": "chat_files",
		"key": file_name,
		"value": {"path": file_path},
		"permission_read": 2,  # Public read
		"permission_write": 1  # Owner write
	}])
	
	if result.is_exception():
		return {"error": result.get_exception().message}
	
	return {
		"path": file_path,
		"name": file_name,
		"size": file_data.size()
	}

# 下载文件
func download_file(file_info: Dictionary) -> Dictionary:
	var result = await Online.nakama_client.read_storage_objects_async(Online.nakama_session, [{
		"collection": "chat_files",
		"key": file_info.name
	}])
	
	if result.is_exception():
		return {"error": result.get_exception().message}
	
	if result.objects.is_empty():
		return {"error": "File not found"}
	
	var file_data = result.objects[0].value
	return file_data

# 处理接收到的消息
func _on_channel_message(message: NakamaAPI.ApiChannelMessage):
	chat_message_received.emit(message) 

# 处理频道状态变化
func _on_channel_presence(presence: NakamaRTAPI.ChannelPresenceEvent):
	chat_presence_changed.emit(presence.joins, presence.leaves)

# 清理
func _notification(what: int):
	if what == NOTIFICATION_PREDELETE:
		if Online.nakama_socket and Online.nakama_socket.is_connected_to_host():
			Online.nakama_socket.close()
			Online.nakama_socket = null
	pass


# Data Management

# 好友和俱乐部管理
# 通过用户名搜索用户
func search_users(username: String):
	if not Online.nakama_session:
		return null
	var result = await Online.nakama_client.get_users_async(Online.nakama_session,[], [username])
	if result.is_exception():
		print("Error search_users: ", result.get_exception().message)
		return
	print("查找用户: ", result)
	return result

func search_users_rpc(username: String):
	if not Online.nakama_session:
		return null
	var result = await Online.nakama_client.rpc_async(Online.nakama_session,  "search_username", username)
	if result.is_exception():
		print("Error search_users_rpc: ", result.get_exception().message)
		return null
	print("查找用户RPC: ", result)
	return JSON.parse_string(result.payload)

func search_groups(groupname: String):
	if not Online.nakama_session:
		return null
	var result = await Online.nakama_client.list_groups_async(Online.nakama_session, groupname)
	if result.is_exception():
		print("Error search_groups: ", result.get_exception().message)
		return null
	print("查找俱乐部: ", result)
	return result

# 获取好友列表
func get_friends_list():
	# 获取好友列表并订阅他们的状态
	var result = await Online.nakama_client.list_friends_async(Online.nakama_session)
	if result.is_exception():
		print("Error getting friends list: ", result.get_exception().message)
		return
	
	var friend_ids = []
	var friend_names = []
	for friend in result.friends:
		friend_ids.append(friend.user.id)
		friend_names.append(friend.user.username)
	
	# 订阅好友状态
	# if not friend_ids.is_empty() and friend_names.size() == friend_ids.size(): 
	# 	var status_result = await Online.nakama_socket.follow_users_async(friend_ids,friend_names)
	# 	if status_result.is_exception():
	# 		print("Error following users: ", status_result.get_exception().message)
	# print("好友列表: ", ret)
	return result


# 获取俱乐部列表
func get_group_list(uid: String):
	var result = await Online.nakama_client.list_user_groups_async(Online.nakama_session,uid)
	if result.is_exception():
		print("Error getting friends list: ", result.get_exception().message)
		return
	print("俱乐部列表: ", result)
	return result


# 获取俱乐部成员列表
func get_group_member_list_async(group_id: String):
	var result = await Online.nakama_client.list_group_users_async(Online.nakama_session,group_id)
	if result.is_exception():
		print("Error getting friends list: ", result.get_exception().message)
		return null
	print("俱乐部成员信息: ", result)
	return result

		
# 添加好友
func add_friends_async(friend_ids: Array)->bool:
	if friend_ids.size() == 0:
		return false
	var result = await Online.nakama_client.add_friends_async(Online.nakama_session, friend_ids)
	if result.is_exception():
		print("Error add_friends_async: ", result.get_exception().message)
		return false
	print("添加好友: ", result)
	return true

		
# 创建俱乐部 
func create_group_async(name1: String, description : String = "", avatar_url = null):
	var result = await Online.nakama_client.create_group_async(Online.nakama_session, name1, description, avatar_url,"zh",false)
	if result.is_exception():
		print("Error create_group_async: ", result.get_exception().message)
		return null
	print("添加俱乐部: ", result)
	return result


# 创建世界频道 一般不能使用
func create_world_async():
	var result = await Online.nakama_client.create_group_async(Online.nakama_session, "world", "世界渠道", null,"zh", true)
	if result.is_exception():
		print("Error create_world_async: ", result.get_exception().message)
		return null
	print("添加俱乐部: ", result)
	# SignalMgr.FreshClubListSIG.emit()
	return result


func get_world_channel():
	return _world_channel
	

func load_world_channel():
	if _world_channel:
		return _world_channel
	var result = await search_groups("world")
	##-----------------------
	print("查找世界频道:\n\n ")
	if not result:
		return null
	for group in result.groups:
		# var group = info.group
		print("查找世界频道: ", group)
		if group.name == "world":
			var ret1 = await Online.nakama_client.join_group_async(Online.nakama_session, group.id)
			print("加入世界频道: ", ret1)
			if ret1.is_exception():
				Global.PopupManager.show_dynamic("加入世界频道失败")
				print("加入世界频道失败",ret1.get_exception().message)
				return null
			var ret = await add_channel_async(group.id, 2)
			if not ret:
				print("加入世界渠道失败")
				Global.PopupManager.show_dynamic("加入世界渠道失败")
				return null
			print("添加世界渠道频道: ", ret)
			_world_channel = ret
			# fetch_full_chat_history(_world_channel.id)
			# get_chat_history_all(_world_channel.id)
			fetch_older_messages(_world_channel.id,"")
			return ret
	return null

# 加入聊天频道
func add_channel_async(targetId: String,tab:int = 0):
	if Online.nakama_socket:
		var chType = NakamaSocket.ChannelType.DirectMessage
		if tab == 1:
			chType = NakamaSocket.ChannelType.Room
		elif tab == 2:
			chType = NakamaSocket.ChannelType.Group
		var result = await Online.nakama_socket.join_chat_async(targetId, chType, true)
		if result.is_exception():
			print("Error add_channel_async: ",result.get_exception().message, " ID:",  targetId," 类型:", chType)
			# push_error("Error add_channel_async: ", result.get_exception().message," ID:",  targetId," 类型:", chType)
			return null
		print("添加频道: ", result)
		return result
	return null

func add_group_async(group_name: String):
	var result = await Online.nakama_client.list_groups_async(Online.nakama_session,group_name)
	if result.is_exception():
		print("Error getting friends list: ", result.get_exception().message)
		return null
	for group in result.groups:
		var ret = await Online.nakama_client.join_group_async(Online.nakama_session,group.id)
		if ret.is_exception():
			push_error("Error add_group_async: ", ret.get_exception().message)
			return null
		print("添加俱乐部: ", ret)
		return ret 
	return null


func add_group_users_async(group_id: String,p_ids: PackedStringArray):
	if group_id.is_empty() or p_ids.size() <= 0:
		return false
	var result = await Online.nakama_client.add_group_users_async(Online.nakama_session,group_id,p_ids)
	if result.is_exception():
		print("Error getting friends list: ", result.get_exception().message)
		return false
	print("添加俱乐部成员: ", result)
	return true

# 降级权限
func demote_group_users_async(group_id : String, p_ids : Array):
	if group_id.is_empty() or p_ids.size() <= 0:
		return false
	var result = await Online.nakama_client.demote_group_users_async(Online.nakama_session,group_id,p_ids)
	if result.is_exception():
		print("Error getting friends list: ", result.get_exception().message)
		return false
	print("设置管理员: ", result)
	return true

# 提升权限
func promote_group_users_async(group_id : String, p_ids: Array):
	if group_id.is_empty() or p_ids.size() <= 0:
		return false
	var result = await Online.nakama_client.promote_group_users_async(Online.nakama_session,group_id,p_ids)
	if result.is_exception():
		print("Error getting friends list: ", result.get_exception().message)
		return false
	print("设置管理员: ", result)
	return true

# 订阅好友
func follow_users_async(p_ids : PackedStringArray, p_usernames : PackedStringArray):
	if Online.nakama_socket:
		await Online.nakama_socket.unfollow_users_async(p_ids)
		var result = await Online.nakama_socket.follow_users_async(p_ids, p_usernames)
		if result.is_exception():
			push_error("Error follow_users_async: ", result.get_exception().message)
			return null
		print("订阅好友: ", result)
		return result
	return null

func update_status_async(_status:String):
	if Online.nakama_socket:
		var result = await Online.nakama_socket.update_status_async(_status)
		if result.is_exception():
			push_error("Error update_status_async: ", result.get_exception().message)
			return null
		print("变更状态: ", result)
		return result
	return null



# 阻止好友
func refuse_friends_async(friend_id: String)->bool:
	var result = await Online.nakama_client.block_friends_async(Online.nakama_session, [friend_id])
	if result.is_exception():
		print("Error refuse_friends_async: ", result.get_exception().message)
		return false
	print("拒绝好友: ", result)
	return true

# 群组中禁言
func ban_group_users_async(group_id: String,user_id: String)->bool:
	var result = await Online.nakama_client.ban_group_users_async(Online.nakama_session, group_id, [user_id])
	if result.is_exception():
		print("Error ban_group_users_async: ", result.get_exception().message)
		return false
	print("群组中禁言: ", result)
	return true

# 离开群组
func leave_group(group_id: String)->bool:
	var result = await Online.nakama_client.leave_group_async(Online.nakama_session, group_id)
	if result.is_exception():
		print("Error leave_group: ", result.get_exception().message)
		return false
	print("离开俱乐部: ", result)
	return true


# 删除好友
func remove_friend(user_id: String)->bool:
	var result = await Online.nakama_client.delete_friends_async(Online.nakama_session, [user_id])
	if result.is_exception():
		print("Error removing friend: ", result.get_exception().message)
		return false
	print("删除好友成功!!!")
	return true

func remove_group(group_id: String)->bool:
	var result = await Online.nakama_client.delete_group_async(Online.nakama_session, group_id)
	if result.is_exception():
		print("Error removing group: ", result.get_exception().message)
		return false
	print("删除俱乐部!!!")
	return true

func remove_gourp_user(group_id: String,user_id: String)->bool:
	var result = await Online.nakama_client.kick_group_users_async(Online.nakama_session, group_id, [user_id])
	if result.is_exception():
		print("Error removing group: ", result.get_exception().message)
		return false
	print("删除俱乐部用户!!!",result)
	return true


func remove_channel_message(channel_id:String,message_id: String)->bool:
	if Online.nakama_socket:
		var result= await Online.nakama_socket.remove_chat_message_async(channel_id,message_id)
		if result.is_exception():
			print("Error removing group: ", result.get_exception().message)
			return false
		return true 
	return false

# 修改消息
func reback_channel_message(channel_id:String,message_id: String,data:Dictionary)->bool:
	if Online.nakama_socket:
		var result= await Online.nakama_socket.update_chat_message_async(channel_id,message_id,data)
		if result.is_exception():
			print("Error removing group: ", result.get_exception().message)
			return false
		return true
	return false


func remove_message_by_id(messages: Array, target_message_id: String):
	for i in range(messages.size() - 1, -1, -1):
		if messages[i].message_id == target_message_id:
			messages.remove_at(i)
			return true
	return false 
