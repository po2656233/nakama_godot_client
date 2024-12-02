extends Node

# Nakama _client instance
var _client: NakamaClient
var _session: NakamaSession
var _socket: NakamaSocket
var _current_channel: NakamaRTAPI.Channel

# Game data
var player_data: NakamaAPI.ApiUser
var pets_data: Dictionary = {}
var home_data: Dictionary = {}

# Configuration
const SERVER_KEY: String = "superman"
const HOST: String = "60.205.90.152"
const PORT: int = 7350
const SCHEME: String = "http"

signal player_data_updated
signal connection_established
signal connection_failed
signal chat_message_received(message: Dictionary)
signal chat_presence_changed(joins: Array, leaves: Array)
signal chat_history_received(messages: Array)


const DEFAULT_MESSAGE = {
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
	# Initialize _client
	_client = Nakama.create_client(
		SERVER_KEY,
		HOST,
		PORT,
		SCHEME
	)
	
	# Initialize _socket
	_socket = Nakama.create_socket_from(_client)
	connect_signals()
	var success = await restore_session()
	if not success:
		await authenticate_device()
	else:
		connection_established.emit()
		

func initialize_client() -> void:
	if _client:
		_client.cancel_free()
		_client = null
	_client = Nakama.create_client(SERVER_KEY, HOST, PORT, SCHEME)
	connect_signals()
	var success = await restore_session()
	if not success:
		await authenticate_device()
	else:
		connection_established.emit()

func connect_signals() -> void:
	if _socket:
		_socket.connection_error.connect(_on_connection_failed)
		_socket.connected.connect(_on_connection_succeeded)
		_socket.received_error.connect(_on_received_error)


func set_current_channel(channel: NakamaRTAPI.Channel):
	_current_channel = channel


# Authentication
func authenticate_device(username: String="", created:bool=false) -> bool:
	var device_id = OS.get_unique_id()
	var result = await _client.authenticate_device_async(device_id,username,created)
	
	if result.is_exception():
		connection_failed.emit()
		return false
	print("设备登录请求成功1",result)
	_session = result
	save_session()
	print("设备登录请求成功2222")
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
	if result.is_exception():
		print("发送登录请求失败",result.get_exception().message)
		connection_failed.emit()
		return false
	
	print("发送登录请求成功",result)
	_session = result
	save_session()
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
	
	_current_channel = result
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
func get_chat_history(limit: int = 20, forward: bool = false) -> Error:
	if not _current_channel:
		print("Not in a chat channel or socket is wrong")
		return FAILED
	
	print("获取聊天历史",_current_channel.id, limit, forward)
	var result = await _client.list_channel_messages_async(_session, _current_channel.id, limit, forward)
	if result.is_exception():
		print("Failed to get chat history: ", result.get_exception().message)
		return FAILED
	  
	var messages = []
	for message in result.messages:
		var content = JSON.parse_string(message.content)
		if content:
			messages.append(message)
	
	chat_history_received.emit(messages)
	return OK

func getMsgData(message:NakamaAPI.ApiChannelMessage)->Dictionary:
	if not message or not message.content:
		return {
				"kind": DEFAULT_MESSAGE.kind,
				"type":DEFAULT_MESSAGE.type,
				"headIcon":  DEFAULT_MESSAGE.headIcon,
				"username": "",
				"content": DEFAULT_MESSAGE.content,
				"path": DEFAULT_MESSAGE.path,
				"file": DEFAULT_MESSAGE.file,
				"size":DEFAULT_MESSAGE.size,
				"thumbnail": DEFAULT_MESSAGE.thumbnail,
				"duration": DEFAULT_MESSAGE.duration,
				}
	var content = null
	content = JSON.parse_string(message.content)
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
	return {
		"message_id": "",
	}


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
		var file = FileAccess.open("user://nakama_session.save", FileAccess.WRITE)
		file.store_line(_session.token)
		file.close()
	return
		

func restore_session() -> bool:
	var session_token = load_session_token()
	print("当前的 _session: " + session_token)
	if session_token.is_empty():
		return false
		
	var result = await NakamaClient.restore_session(session_token)
	if result.is_exception():
		return false

	_session = result
	await setup_socket()
	await load_player_data()
	return true

func load_session_token() -> String:
	if not FileAccess.file_exists("user://nakama_session.save"):
		return ""
		
	var file = FileAccess.open("user://nakama_session.save", FileAccess.READ)
	var token = file.get_line()
	file.close()
	print("缓存的Session token: " + token)
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
	print("好友列表: ", result)
	return result
		
# 添加好友
func add_friends_async(friend_id: String)->bool:
	var result = await _client.add_friends_async(_session, [friend_id])
	if result.is_exception():
		print("Error add_friends_async: ", result.get_exception().message)
		return false
	print("添加好友: ", result)
	return true

func add_channel_async(user_id: String):
	if _socket:
		return await _socket.join_chat_async(user_id, NakamaSocket.ChannelType.DirectMessage,true,true)
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


# 异步加载 Texture2D
func load_texture_async(url: String) :
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
	
	image.resize(20,15)
	request.queue_free()
	return ImageTexture.create_from_image(image)

# Signal Handlers
func _on_connection_failed():
	connection_failed.emit()

func _on_connection_succeeded():
	connection_established.emit()

func _on_received_error(error: String):
	push_error("Nakama error: " + error)


##############################################
class TimestampSorter:
	static func sort_ascending(a: Dictionary, b: Dictionary) -> bool:
		return a["timestamp"] < b["timestamp"]

func sort_messages_by_timestamp(messages: Array) -> Array:
	messages.sort_custom(TimestampSorter.sort_ascending)
	return messages
# 安全转换
func safe_get(variant_content: Variant, key: String, default_value = null) -> Variant:
	if variant_content is Dictionary:
		return variant_content.get(key, default_value)
	return default_value