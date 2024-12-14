extends Node

# Nakama _client instance
var _client: NakamaClient
var _session: NakamaSession
var _socket: NakamaSocket
var _current_channel: NakamaRTAPI.Channel
var _cursor_list_channel = null
# Game data
var player_data: NakamaAPI.ApiUser
var pets_data: Dictionary = {}
var home_data: Dictionary = {}

# Configuration
const SERVER_KEY: String = "superman"
const HOST: String = "60.205.90.152"
const PORT: int = 7350
const SCHEME: String = "http"
const SESSION_FILE_PATH = "user://nakama_session.save"
signal player_data_updated
signal connection_established
signal connection_failed
signal chat_message_received(message: Dictionary)
signal chat_presence_changed(joins: Array, leaves: Array)
signal chat_history_received(messages: Array)
signal changeChannelSIG(id:String)

# 聊天内容结构
var DEFAULT_MESSAGE = {
	"kind": 0,#2聊天 1俱乐部 0世界
	"type": 0,
	"headIcon": "",
	"path": "",
	"content": "",
	"file": "",
	"size": 0,
	"thumbnail": "",
	"duration": 0,
}



# 初始化
func _ready() -> void:
	connection_failed.connect(_on_connection_failed)
	# initialize_client()

		

func initialize_client() -> void:
	if _client:
		if _session:			# 退出登录
			_client.session_logout_async(_session)
		_client.cancel_free()
		_client = null
	_client = Nakama.create_client(SERVER_KEY, HOST, PORT, SCHEME)
	# 1. 关闭现有的 WebSocket 连接
	if _socket:
		if _socket.is_connected_to_host():
			_socket.close()
		_socket = null
	_socket = Nakama.create_socket_from(_client)
	connect_signals()
	var success = await restore_session()
	if success:
		connection_established.emit()
	# else:
	# 	await authenticate_device()

func connect_signals() -> void:
	if _socket:
		if not _socket.is_connected("connection_error",_on_connection_failed):
			_socket.connection_error.connect(_on_connection_failed)
		if not _socket.is_connected("connected",_on_connection_succeeded):
			_socket.connected.connect(_on_connection_succeeded)
		if not _socket.is_connected("received_error",_on_received_error):
			_socket.received_error.connect(_on_received_error)

func logout():
	remove_session()

# func check_network():
# 	if OS.has_feature("mobile"):
# 		# 检查网络连接状态
# 		if OS.get_network_connected_type() == -1:
# 			push_error("没有网络连接")
# 			return false
			
# 		# 输出网络类型
# 		var network_type = OS.get_network_connected_type()
# 		match network_type:
# 			0: print("未知网络类型")
# 			1: print("以太网连接")
# 			2: print("WIFI连接")
# 			3: print("移动数据连接")
# 			4: print("移动数据2G")
# 			5: print("移动数据3G")
# 			6: print("移动数据4G")
# 	return true
	

# 设置当前聊天频道
func set_current_channel(channel: NakamaRTAPI.Channel,isLoadhistory:bool=false):
	if _current_channel == channel:
		return
	_cursor_list_channel = null
	_current_channel = channel
	if channel:
		changeChannelSIG.emit(channel.id)
	if isLoadhistory:
		await get_chat_history(channel.id)

	pass

func get_cursor_for_list_channel():
	return _cursor_list_channel

# Authentication
func authenticate_device(username: String="", created:bool=false) -> bool:
	var device_id = OS.get_unique_id()
	var result = await _client.authenticate_device_async(device_id,username,created)
	
	if result.is_exception():
		connection_failed.emit()
		return false
	_session = result
	save_session()
	# Connect _socket after authentication
	if _socket.is_connected_to_host():
		return true
		
	var socket_result = await _socket.connect_async(_session)
	if socket_result.is_exception():
		push_error("Socket connection failed: " + socket_result.get_exception().message)
		connection_failed.emit()
		return false
	print("设备登录socket",socket_result)
	connection_established.emit()
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
	var result = await _client.authenticate_email_async(email,password,username,created)
	if result.is_exception() or not result.is_valid():
		print("发送登录请求失败",result.get_exception().message)
		connection_failed.emit()
		return false
	
	print("发送登录请求成功",result)
	_session = result
	save_session()
	if not _socket:
		_socket = Nakama.create_socket_from(_client)
	# Connect _socket after authentication
	if _socket.is_connected_to_host():
		return true

	var socket_result = await _socket.connect_async(_session)
	if socket_result.is_exception():
		push_error("Socket失败: " , socket_result)
		connection_failed.emit()
		return false
	print("Socket连接成功")
	connection_established.emit()
	return true

##############################################################
# 加入聊天频道
func join_chat_channel(channel_id: String, persistence: bool = true, hidden: bool = false) -> Error:
	if not _socket or not _session:
		print("Not connected to server")
		return FAILED
	 
	var result = await _socket.join_chat_async(channel_id, persistence, hidden)
	if result.is_exception():
		print("Failed to join chat channel: ", result.get_exception().message)
		return FAILED
	
	set_current_channel(result)
	return OK

# 发送消息
func send_message(content: Dictionary) -> Error:
	if not _current_channel:
		print("Not in a chat channel")
		return FAILED
	print("发送前确认",content)
	var result = await _socket.write_chat_message_async(_current_channel.id, content)
	if result.is_exception():
		print("Failed to send message: ", result.get_exception().message)
		return FAILED

	return OK



# 获取聊天历史
func get_chat_history(channelId:String = _current_channel.id, limit: int = 20, forward: bool = false,cursor = null,all:bool = false) -> Error:
	if channelId.is_empty():
		print("Not in a chat channel or socket is wrong")
		return FAILED
 
	# 	# 先尝试加入频道
	# var join_try = await _client.join_chat_async(channelId)
	# if join_try.is_exception():
	# 	print("无法加入频道: ", join_try.get_exception().message)
	# 	# 处理错误，比如通知用户或创建新频道
	# 	return FAILED


	print("获取聊天历史",channelId," -->", limit, "-->",forward)
	if cursor == null:
		cursor = _cursor_list_channel
	var result = await _client.list_channel_messages_async(_session, channelId, limit, forward, cursor)
	if result.is_exception():
		print("Failed to get chat history: ", result.get_exception().message)
		return FAILED

	var messages = []
	for message in result.messages:
		var content = JSON.parse_string(message.content)
		if content:
			messages.append(message)
	
	chat_history_received.emit(messages)
	if result.next_cursor:
		_cursor_list_channel = result.next_cursor
		# print("获取历史记录游标",_cursor_list_channel)
		if all:
			get_chat_history(channelId, limit, forward,_cursor_list_channel,all)
	return OK

func getMsgData(message:NakamaAPI.ApiChannelMessage)->Dictionary:
	if not message or not message.content:
		return DEFAULT_MESSAGE
	var content = JSON.parse_string(message.content)
	if content:
		return {
			"kind": safe_get(content, "kind", DEFAULT_MESSAGE.kind),
			"type": safe_get(content, "type", DEFAULT_MESSAGE.type),
			"headIcon": safe_get(content, "headIcon", DEFAULT_MESSAGE.headIcon),
			"username": message.username,
			"content": content,
			"path": safe_get(content, "path", DEFAULT_MESSAGE.path),
			"file": safe_get(content,"file", DEFAULT_MESSAGE.file),
			"size":safe_get(content,"size", DEFAULT_MESSAGE.size),
			"thumbnail": safe_get(content,"thumbnail", DEFAULT_MESSAGE.thumbnail),
			"duration": safe_get(content,"duration", DEFAULT_MESSAGE.duration),
		}
	return DEFAULT_MESSAGE


# 上传文件
func upload_file(file_path: String) -> Dictionary:
	if not _session:
		return {"error": "Not connected to server"}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open file"}
	
	var file_data = file.get_buffer(file.get_length())
	var file_name = file_path.get_file()
	
	var result = await _client.write_storage_objects_async(_session, [{
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
	if not _session:
		return {"error": "Not connected to server"}
	
	var result = await _client.read_storage_objects_async(_session, [{
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
		if _socket and _socket.is_connected_to_host():
			_socket.close()
			_socket = null





#################################################################
# Session Management
func save_session() -> void:
	if _session:
		var file = FileAccess.open(SESSION_FILE_PATH, FileAccess.WRITE)
		file.store_line(_session.token)
		file.close()
	return

func remove_session() -> void:
	if _session:
		# 清除当前 session
		_session = null
		var dir = DirAccess.open("user://")
		if dir and dir.file_exists("nakama_session.save"):
			dir.remove("nakama_session.save")
		print("Logged out successfully")	

func restore_session() -> bool:
	var session_token = load_session_token()
	print("当前的 _session: " + session_token)
	if session_token.is_empty() or not _client:
		return false
		
	var result = await NakamaClient.restore_session(session_token)
	if result.is_exception():
		return false

	_session = result
	await setup_socket()
	await load_player_data()
	return true

func load_session_token() -> String:
	if not FileAccess.file_exists(SESSION_FILE_PATH):
		return ""
		
	var file = FileAccess.open(SESSION_FILE_PATH, FileAccess.READ)
	var token = file.get_line()
	file.close()
	# print("缓存的Session token: " + token)
	return token

# Socket Setup
func setup_socket() -> void:
	if _session:
		if _socket:
			_socket.close()
		_socket = Nakama.create_socket_from(_client)
		await _socket.connect_async(_session)
		connect_signals()

# Data Management
func load_player_data() -> void:
	if !_session:
		return
	var result = await _client.read_storage_objects_async(_session, [{
		"collection": "player_data",
		"key": "profile",
		"user_id": _session.user_id
	}])
	print("读取玩家数据: ", result)
	if not result.is_exception():
		if result.objects.size() > 0:
			player_data = JSON.parse_string(result.objects[0].value)
		else:
			var ret = await _client.get_account_async(_session)
			if ret.is_exception():
				push_error("获取用户信息失败: " + ret.get_exception().message)
				return
			player_data = ret.user
			print('用户信息1',player_data)	
			await save_player_data()
		print("已读取玩家数据: ", player_data)
	player_data_updated.emit()

func save_player_data() -> void:
	if !_session:
		return
		
	var objects = [{
		"collection": "player_data",
		"key": "profile",
		"value": JSON.stringify(player_data),
		"permission_read": 1,
		"permission_write": 1
	}]
	
	await _client.write_storage_objects_async(_session, objects)





# 好友和群组管理
# 通过用户名搜索用户
func search_users(username: String):
	var result = await _client.get_users_async(_session,[], [username])
	if result.is_exception():
		print("Error searching users: ", result.get_exception().message)
		return
	print("查找用户: ", result)
	return result

func search_users_rpc(username: String):
	var result = await _client.rpc_async(_session,  "search_username", username)
	if result.is_exception():
		print("Error searching users: ", result.get_exception().message)
		return
	print("查找用户RPC: ", result)
	return JSON.parse_string(result.payload)

func search_groups(groupname: String):
	var result = await _client.list_groups_async(_session, groupname)
	if result.is_exception():
		print("Error searching users: ", result.get_exception().message)
		return
	print("查找群组: ", result)
	return result

# 获取好友列表
func get_friends_list():
	var result = await _client.list_friends_async(_session)
	if result.is_exception():
		print("Error getting friends list: ", result.get_exception().message)
		return
	var friend_ids = [] 
	var friend_names = []
	for friend in result.friends:
		var f = friend as NakamaAPI.ApiFriend
		if not f or not f.user.online:
			continue
		friend_ids.append(f.user.id)
		friend_names.append(f.user.username)
	var ret : NakamaAsyncResult = await _socket.follow_users_async(friend_ids,friend_names)
	for presence in ret.presences:
		print("%s is online with status: %s" % [presence.user_id, presence.status])
	print("好友列表: ", ret)
	return result


# 获取群组列表
func get_group_list():
	var result = await _client.list_groups_async(_session)
	if result.is_exception():
		print("Error getting friends list: ", result.get_exception().message)
		return
	print("群组列表: ", result)
	return result

		
# 添加好友
func add_friends_async(friend_ids: Array)->bool:
	if friend_ids.size() == 0:
		return false
	var result = await _client.add_friends_async(_session, friend_ids)
	if result.is_exception():
		print("Error add_friends_async: ", result.get_exception().message)
		return false
	print("添加好友: ", result)
	SignalManager.FreshFriendListSIG.emit()
	return true

		
# 添加好友 
func create_group_async(name1: String, description : String = "", avatar_url = null)->bool:
	var result = await _client.create_group_async(_session, name1, description, avatar_url)
	if result.is_exception():
		print("Error add_friends_async: ", result.get_exception().message)
		return false
	print("添加好友: ", result)
	SignalManager.FreshClubListSIG.emit()
	return true

func add_channel_async(targetId: String,chanType:int = 0):
	if _socket:
		var chType = null
		if chanType == 1:
			chType = NakamaSocket.ChannelType.Room
		elif chanType == 2:
			chType = NakamaSocket.ChannelType.Group
		else:
			chType = NakamaSocket.ChannelType.DirectMessage
		var result = await _socket.join_chat_async(targetId,chType,true,true)
		if result.is_exception():
			push_error("Error add_channel_async: ", result.get_exception().message)
			return null
		print("添加频道: ", result)
		return result
	return null

func add_group_async(group_id: String):
	var result = await _client.join_group_async(_session,group_id)
	if result.is_exception():
		push_error("Error add_group_async: ", result.get_exception().message)
		return null
	print("添加群组: ", result)
	return result



# 订阅好友
func follow_users_async(p_ids : PackedStringArray, p_usernames : PackedStringArray):
	if _socket:
		await _socket.unfollow_users_async(p_ids)
		var result = await _socket.follow_users_async(p_ids, p_usernames)
		if result.is_exception():
			push_error("Error follow_users_async: ", result.get_exception().message)
			return null
		print("订阅好友: ", result)
		return result
	return null

func update_status_async(_status:String):
	if _socket:
		var result = await _socket.update_status_async(_status)
		if result.is_exception():
			push_error("Error update_status_async: ", result.get_exception().message)
			return null
		print("变更状态: ", result)
		return result
	return null



# 阻止好友
func refuse_friends_async(friend_id: String)->bool:
	var result = await _client.block_friends_async(_session, [friend_id])
	if result.is_exception():
		print("Error refuse_friends_async: ", result.get_exception().message)
		return false
	print("拒绝好友: ", result)
	return true



# 删除好友
func remove_friend(user_id: String)->bool:
	var result = await _client.delete_friends_async(_session, [user_id])
	if result.is_exception():
		print("Error removing friend: ", result.get_exception().message)
		return false
	print("删除好友成功!!!")
	return true

func remove_group(group_id: String)->bool:
	var result = await _client.delete_group_async(_session, group_id)
	if result.is_exception():
		print("Error removing group: ", result.get_exception().message)
		return false
	print("删除群组!!!")
	return true

func remove_channel_message(channel_id:String,message_id: String)->bool:
	if _socket:
		var result= await _socket.remove_chat_message_async(channel_id,message_id)
		if result.is_exception():
			print("Error removing group: ", result.get_exception().message)
			return false
		return true 
	return false

func reback_channel_message(channel_id:String,message_id: String,data:Dictionary)->bool:
	if _socket:
		var result= await _socket.update_chat_message_async(channel_id,message_id,data)
		if result.is_exception():
			print("Error removing group: ", result.get_exception().message)
			return false
		return true
	return false


# 异步加载 Texture2D
func load_texture_async(url: String) :
	if url.is_empty():
		return null
	var request = HTTPRequest.new()
	add_child(request)
	
	request.request(url)
	var result = await request.request_completed
	
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		request.queue_free()
		return null
	
	var image = Image.new()

	var error = image.load_png_from_buffer(result[3])
	if error != OK:
		request.queue_free()
		return null
	
	image.resize(25,25)
	request.queue_free()
	return ImageTexture.create_from_image(image)

# Signal Handlers
func _on_connection_failed():
	PopupManager.show_dynamic("网络连接失败")

func _on_connection_succeeded():
	PopupManager.show_dynamic("网络连接成功")
	# connection_established.emit()

func _on_received_error(error: String):
	push_error("Nakama error: " + error)


############################################################################################
############################################################################################
# 安全地获取对象的字段值
func _get_field_value(item, field: String):
	if item == null:
		return null

	# 如果是字典
	if item is Dictionary:
		return item.get(field)
	
	if item is String:
		var obj = DataManager.get_instance().parse_message(item)
		return obj.get(field)

	# 如果是对象，尝试多种方式获取值
	if item is Object:
		# 1. 尝试使用get方法
		if item.has_method("get"):
			return item.get(field)
		
		# 2. 尝试直接访问属性
		if field in item: 
			return item.get(field)
			
		# 3. 尝试使用get_xxx方法
		var getter_name = "get_" + field
		if item.has_method(getter_name):
			return item.call(getter_name)
	
	# 其他情况返回null
	return null

# 对字典数组按指定字段排序
func sort_dictionary_array(array: Array, sort_field: String, ascending: bool = true) -> Array:
	if array.is_empty():
		return array
		
	# 验证第一个元素
	var first_element = array[0]
	if first_element == null:
		push_warning("First element is null")
		return array
	
	# 尝试获取字段值
	var field_value = _get_field_value(first_element, sort_field)
	if field_value == null:
		push_warning("First element is not have: " + str(sort_field))
		return array
	
	array.sort_custom(func(a, b): 
		var field_value_a = _get_field_value(a,sort_field)
		var field_value_b = _get_field_value(b,sort_field)
		# print('时间比较:',field_value_a, field_value_b)
		if not field_value_a or not field_value_b:
			push_error("比较异常",field_value_a, field_value_b)
			return false
		if ascending:
			return field_value_a < field_value_b
		else:
			return field_value_a > field_value_b
		)
	return array


#####################
func validate_dict_types(data: Dictionary) -> Dictionary:
	if not (data is Dictionary):
		push_warning("data is not Dictionary")
		return {}
	return data
####################################################################


# 安全转换
func safe_get(variant_content: Variant, key: String, default_value = null) -> Variant:
	if variant_content is Dictionary:
		return variant_content.get(key, default_value)
	return default_value

# 将时间戳转换为东八区（UTC+8）时间
func convert_to_china_time(timestamp: int) -> Dictionary:
	# 东八区偏移量（8小时）
	const CHINA_TIMEZONE_OFFSET = 8 * 60 * 60
	
	# 加上时区偏移
	var adjusted_timestamp = timestamp + CHINA_TIMEZONE_OFFSET
	
	# 转换为时间字典
	return Time.get_datetime_dict_from_unix_time(adjusted_timestamp)

# 格式化东八区时间显示
func format_china_time(timestamp: int, show_seconds: bool = false) -> String:
	var time_dict = convert_to_china_time(timestamp)
	
	# 获取今天凌晨的时间戳
	var today_start = get_today_start_timestamp()
	var yesterday_start = today_start - 24 * 60 * 60
	
	# 根据时间判断显示格式
	if timestamp >= today_start:
		# 今天的消息只显示时间
		if show_seconds:
			return "今天 %02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second]
		return "今天 %02d:%02d" % [time_dict.hour, time_dict.minute]
	elif timestamp >= yesterday_start:
		# 昨天的消息
		if show_seconds:
			return "昨天 %02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second]
		return "昨天 %02d:%02d" % [time_dict.hour, time_dict.minute]
	else:
		# 更早的消息显示完整日期
		if show_seconds:
			return "%d-%02d-%02d %02d:%02d:%02d" % [
				time_dict.year,
				time_dict.month,
				time_dict.day,
				time_dict.hour,
				time_dict.minute,
				time_dict.second
			]
		return "%d-%02d-%02d %02d:%02d" % [
			time_dict.year,
			time_dict.month,
			time_dict.day,
			time_dict.hour,
			time_dict.minute
		]

# 获取今天凌晨0点的东八区时间戳
func get_today_start_timestamp() -> int:
	var current_time = Time.get_datetime_dict_from_system()
	
	# 将时分秒都设置为0
	current_time["hour"] = 0
	current_time["minute"] = 0
	current_time["second"] = 0
	
	# 转换为时间戳并减去东八区偏移
	# 因为我们要得到的是东八区的凌晨0点
	const CHINA_TIMEZONE_OFFSET = 8 * 60 * 60
	return Time.get_unix_time_from_datetime_dict(current_time) - CHINA_TIMEZONE_OFFSET

func remove_message_by_id(messages: Array, target_message_id: String):
	for i in range(messages.size() - 1, -1, -1):
		if messages[i].message_id == target_message_id:
			messages.remove_at(i)
			return true
	return false 