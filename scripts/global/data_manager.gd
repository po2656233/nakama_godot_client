extends Node

class_name DataManager

# 保存数据的文件路径
const SAVE_PATH = "user://game_data.save"
const chat_key = "chat_history_"
const uid_channel_key = "uid_channel_"
# 缓存的数据
var cached_data: Dictionary = {}

# 单例实例
static var instance: DataManager = null

func _init():
	if instance == null:
		instance = self
func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	print("data manger init")
	load_data()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Game is closing normally, saving data...")
		# save_data()
		get_tree().quit()
	elif what == NOTIFICATION_PREDELETE:
		# 节点被删除前的最后机会保存
		print("Node is being deleted, saving data...")
		# save_data()
	elif what == NOTIFICATION_CRASH:
		# 注意：这个通知在当前版本可能不存在，作为未来可能的扩展
		print("Game is crashing, attempting to save data...")
		# save_data()

# 获取单例实例
static func get_instance() -> DataManager:
	return instance

# 保存数据
func save_data() -> void:
	# 使用临时文件进行保存，以防保存过程中崩溃导致数据损坏
	var temp_path = SAVE_PATH + ".temp"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file:
		# print("保存的数据内容:", cached_data)
		var bytes = var_to_bytes(cached_data)
		file.store_buffer(bytes)
		file.close()
		
		# 如果临时文件保存成功，则替换原文件
		var dir = DirAccess.open("user://")
		if dir:
			if FileAccess.file_exists(SAVE_PATH):
				dir.remove(SAVE_PATH)  # 删除旧文件
			dir.rename(temp_path, SAVE_PATH)  # 重命名临时文件为正式文件
			# print("Data saved successfully")
	else:
		print("Failed to save data")

# 加载数据
func load_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var bytes = file.get_buffer(file.get_length())
			cached_data.clear()
			cached_data = bytes_to_var(bytes)
			file.close()

# 设置数据
func set_data(key: String, value) -> void:
	cached_data[key] = value
	# print("正在保存的数据 键:", key, " 值:", value)
	save_data()  # 每次设置数据后自动保存

# 添加渠道
func add_channel_list(uid: String, value:String) -> void:
	var key = uid_channel_key + uid
	if not cached_data.has(key):
		cached_data[key] = []
	cached_data[key].append(value)
	print("保存渠道的数据 键:", key, " 值:", value)
	save_data()  # 每次设置数据后自动保存


# 设置数据
func add_chat_history(channelId:String, msg) -> int:
	# 如果 chat_key 不存在，创建一个字典
	if not cached_data.has(chat_key):
		cached_data[chat_key] = {}
	
	# 如果 channelId 不存在，创建一个数组
	if not cached_data[chat_key].has(channelId):
		cached_data[chat_key][channelId] = []
	
	# 添加消息到数组 
	if msg.channel_id != "" and msg.channel_id != channelId:
		push_error("channelId 不匹配，无法添加消息到缓存中。")
		return -1
	msg.channel_id = ""
	cached_data[chat_key][channelId].append(msg._to_string())
	# print("保存消息的数据 键:", channelId, " 值:", msg) 
	save_data()  # 每次设置数据后 自动保存
	return cached_data[chat_key][channelId].size()

func set_chat_history(channelId:String, msgList) -> void:
	# 如果 chat_key 不存在，创建一个字典
	if not cached_data.has(chat_key):
		cached_data[chat_key] = {}
	
	# 如果 channelId 不存在，创建一个数组
	if not cached_data[chat_key].has(channelId):
		cached_data[chat_key][channelId] = []
	# 添加消息到数组 
	cached_data[chat_key][channelId] = msgList
	# print("保存消息的数据 键:", channelId, " 值:", msg) 
	save_data()  # 每次设置数据后 自动保存

# 获取数据
func get_data(key: String, default_value = null):
	return cached_data.get(key, default_value)


func get_channel_list(uid: String)-> Array:
	var key = uid_channel_key + uid
	if not cached_data.has(key):
		return []
	return cached_data[key]

# 获取聊天记录
func get_chat_history(channelId:String, default_value = null):
	if not cached_data.has(chat_key):
		return default_value
	if not cached_data[chat_key].has(channelId):
		return default_value

	var msgList = []
	for message in cached_data[chat_key][channelId]:
		var msg =message  if not (message is String) else parse_message(message)
		msgList.append(msg)
	return msgList


# 清除所有数据
func clear_data() -> void:
	cached_data.clear()
	save_data()

# 游戏退出时保存数据
func _on_tree_exiting() -> void:
	save_data()

# 检查是否存在某个键
func has_key(key: String) -> bool:
	return cached_data.has(key)



#############################
func parse_message(text: String) -> Dictionary:
	var result = {}
	
	# 定义字段名
	const FIELD_CONTENT = "content: "
	const FIELD_CREATE_TIME = "create_time: "
	const FIELD_CHANNEL_ID = "channel_id: "
	const FIELD_CODE = "code: "
	const FIELD_GROUP_ID = "group_id: "
	const FIELD_MESSAGE_ID = "message_id: "
	const FIELD_PERSISTENT = "persistent: "
	const FIELD_ROOM_NAME = "room_name: "
	const FIELD_SENDER_ID = "sender_id: "
	const FIELD_UPDATE_TIME = "update_time: "
	const FIELD_USER_ID_ONE = "user_id_one: "
	const FIELD_USER_ID_TWO = "user_id_two: "
	const FIELD_USERNAME = "username: "
	
	text = text.replace("\\", "")
	# 1. 优先解析 content
	var content_start = text.find(FIELD_CONTENT) + FIELD_CONTENT.length()
	var content_end = text.find(", " + FIELD_CREATE_TIME)
	if content_start != -1 and content_end != -1:
		var content_str = text.substr(content_start, content_end - content_start)
		# 移除转义字符
		var json = JSON.new()
		var parse_result = json.parse(content_str)
		if parse_result == OK:
			result["content"] = json.get_data()
		else:
			result["content"] = {}
	# 2. 解析 create_time
	var create_time_start = text.find(FIELD_CREATE_TIME) + FIELD_CREATE_TIME.length()
	var create_time_end = text.find(", " + FIELD_GROUP_ID)
	if create_time_start != -1 and create_time_end != -1:
		result["create_time"] = text.substr(create_time_start, create_time_end - create_time_start)
	
	# 3. 解析 channel_id
	var channel_start = text.find(FIELD_CHANNEL_ID) + FIELD_CHANNEL_ID.length()
	var channel_end = text.find(", " + FIELD_CODE)
	if channel_start != -1 and channel_end != -1:
		result["channel_id"] = text.substr(channel_start, channel_end - channel_start).replace(".", "")
	
	# 4. 解析 code
	var code_start = text.find(FIELD_CODE) + FIELD_CODE.length()
	var code_end = text.find(", " + FIELD_CONTENT)
	if code_start != -1 and code_end != -1:
		result["code"] = text.substr(code_start, code_end - code_start).to_int()
	
	# 5. 解析 group_id
	var group_id_start = text.find(FIELD_GROUP_ID) + FIELD_GROUP_ID.length()
	var group_id_end = text.find(", " + FIELD_MESSAGE_ID)
	if group_id_start != -1 and group_id_end != -1:
		var group_id = text.substr(group_id_start, group_id_end - group_id_start)
		result["group_id"] = "" if group_id == "<null>" else group_id
	
	# 6. 解析 message_id
	var message_id_start = text.find(FIELD_MESSAGE_ID) + FIELD_MESSAGE_ID.length()
	var message_id_end = text.find(", " + FIELD_PERSISTENT)
	if message_id_start != -1 and message_id_end != -1:
		result["message_id"] = text.substr(message_id_start, message_id_end - message_id_start)
	
	# 7. 解析 persistent
	var persistent_start = text.find(FIELD_PERSISTENT) + FIELD_PERSISTENT.length()
	var persistent_end = text.find(", " + FIELD_ROOM_NAME)
	if persistent_start != -1 and persistent_end != -1:
		result["persistent"] = text.substr(persistent_start, persistent_end - persistent_start) == "true"
	
	# 8. 解析 room_name
	var room_name_start = text.find(FIELD_ROOM_NAME) + FIELD_ROOM_NAME.length()
	var room_name_end = text.find(", " + FIELD_SENDER_ID)
	if room_name_start != -1 and room_name_end != -1:
		var room_name = text.substr(room_name_start, room_name_end - room_name_start)
		result["room_name"] = "" if room_name == "<null>" else room_name
	
	# 9. 解析 sender_id
	var sender_id_start = text.find(FIELD_SENDER_ID) + FIELD_SENDER_ID.length()
	var sender_id_end = text.find(", " + FIELD_UPDATE_TIME)
	if sender_id_start != -1 and sender_id_end != -1:
		result["sender_id"] = text.substr(sender_id_start, sender_id_end - sender_id_start)
	
	# 10. 解析 update_time
	var update_time_start = text.find(FIELD_UPDATE_TIME) + FIELD_UPDATE_TIME.length()
	var update_time_end = text.find(", " + FIELD_USER_ID_ONE)
	if update_time_start != -1 and update_time_end != -1:
		result["update_time"] = text.substr(update_time_start, update_time_end - update_time_start)
	
	# 11. 解析 user_id_one
	var user_id_one_start = text.find(FIELD_USER_ID_ONE) + FIELD_USER_ID_ONE.length()
	var user_id_one_end = text.find(", " + FIELD_USER_ID_TWO)
	if user_id_one_start != -1 and user_id_one_end != -1:
		result["user_id_one"] = text.substr(user_id_one_start, user_id_one_end - user_id_one_start)
	
	# 12. 解析 user_id_two
	var user_id_two_start = text.find(FIELD_USER_ID_TWO) + FIELD_USER_ID_TWO.length()
	var user_id_two_end = text.find(", " + FIELD_USERNAME)
	if user_id_two_start != -1 and user_id_two_end != -1:
		result["user_id_two"] = text.substr(user_id_two_start, user_id_two_end - user_id_two_start)
	 
	# 13. 解析 username (最后一个字段)
	var username_start = text.find(FIELD_USERNAME) + FIELD_USERNAME.length()
	if username_start != -1:
		result["username"] = text.substr(username_start).strip_edges().rstrip(",")
	
	return result
