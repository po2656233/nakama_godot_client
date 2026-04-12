extends Node

class_name DataManager

# 保存数据的文件路径
const SAVE_PATH = "user://game_data.save"
const chat_key = "chat_history_"
const uid_channel_key = "uid_channel_"
const world_channel_id = "world_channel_id"
const uid_approval_key = "uid_approval_"
const uid_friend_key = "uid_friend_"
const uid_club_key = "uid_club_"
const ismute_key = "ismute_"
const game_list_key = "game_list_"
const current_game_key = "cur_game"
# 缓存的数据
var cached_data: Dictionary = {}

# 单例实例
static var instance: DataManager = null

func _init():
	if instance == null:
		instance = self

# 获取单例实例
static func get_instance() -> DataManager:
	return instance


# 静态函数，安全地销毁节点
static func safe_free_node(node: Node) -> void:
	if node == null:
		return
	# 如果节点已经在队列中等待释放，直接返回
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	# 停止所有正在运行的tween
	var tweens = node.get_tree().get_processed_tweens()
	for tween in tweens:
		if tween.is_valid():
			tween.kill()
	# 停止所有计时器
	for child in node.get_children():
		if child is Timer:
			child.stop()
	# 如果有动画播放器，停止动画
	var anim_player = node.get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.stop()
	# 如果节点在场景树中，从父节点移除
	if node.is_inside_tree():
		node.get_parent().remove_child(node)
	# 将节点加入释放队列
	node.queue_free()
	pass

# 准备
func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	print("data manger init")
	load_data()
	Global.SignalMgr.NewNotifySIG.connect(_on_approval_notify)
	Global.SignalMgr.GameKeepSIG.connect(_on_keep_game)

# 信号通知
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
########################################################
func _on_approval_notify(data):
	if data:
		add_uid_approval(data["uid"], data)

func _on_keep_game(mode,gid,rid,mid,gname) :
		set_current_game(mode,gid,rid,mid,gname)

###################################################
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
			if not bytes.is_empty() and bytes[0] != 0:
				cached_data.clear()
				cached_data = bytes_to_var(bytes)
			file.close()

# 设置数据
func set_data(key: String, value) -> void:
	cached_data[key] = value
	# print("正在保存的数据 键:", key, " 值:", value)
	save_data()  # 每次设置数据后自动保存

func set_current_game(mode,gid,rid,mid,gname)->void:
	set_data(current_game_key,{
		"mode":mode,
		"gid":gid,
		"rid":rid,
		"mid":mid,
		"gname":gname,
	})
	
func set_world_channel_id(id):
	set_data(world_channel_id,id)
	pass

func set_chat_history(uid:String,channelId:String, msgList) -> void:
	# 如果 chat_key 不存在，创建一个字典
	var key = chat_key+uid
	if not cached_data.has(key):
		cached_data[key] = {}
	
	# 如果 channelId 不存在，创建一个数组
	if not cached_data[key].has(channelId):
		cached_data[key][channelId] = []
	# 添加消息到数组 
	cached_data[key][channelId] = msgList
	# print("保存消息的数据 键:", channelId, " 值:", msg) 
	save_data()  # 每次设置数据后 自动保存

func set_isMute(value) -> void:
	cached_data[ismute_key] = value
	save_data()


# 添加数据 针对数组
func add_data(key, data:Dictionary) -> int:
	if not cached_data.has(key):
		cached_data[key] = []
	var count = cached_data[key].size()
	if 0 < count :
		if cached_data[key][0].has("name"):
			if cached_data[key][0].has("type"):
				for i in range(count-1,-1,-1):
					if cached_data[key][i].name == data.name and cached_data[key][i].type == data.type:
						cached_data[key][i] = data
						save_data()
						return count
			else:
				for i in range(count-1,-1,-1):
					if cached_data[key][i].name == data.name:
						cached_data[key][i] = data
						save_data()
						return count
	print("新增申请数据",key," data:",data)
	cached_data[key].append(data)
	save_data()  # 每次设置数据后 自动保存
	return cached_data[key].size()



# 添加渠道
func add_channel_list(uid: String, value:String) -> void:
	var key = uid_channel_key + uid
	if not cached_data.has(key):
		cached_data[key] = []
	cached_data[key].append(value)
	print("保存渠道的数据 键:", key, " 值:", value)
	save_data()  # 每次设置数据后自动保存


# 设置数据
func add_chat_history(uid:String, channelId:String, msg) -> int:
	# 如果 chat_key 不存在，创建一个字典
	var key = chat_key+uid
	if not cached_data.has(key):
		cached_data[key] = {}
	
	# 如果 channelId 不存在，创建一个数组
	if not cached_data[key].has(channelId):
		cached_data[key][channelId] = []
	
	# 添加消息到数组 
	if msg.channel_id != "" and msg.channel_id != channelId:
		push_error("channelId 不匹配，无法添加消息到缓存中。")
		return -1
	msg.channel_id = ""
	cached_data[key][channelId].append(msg._to_string())
	# print("保存消息的数据 键:", channelId, " 值:", msg) 
	save_data()  # 每次设置数据后 自动保存
	return cached_data[key][channelId].size()



# 添加申请数据  
func add_uid_approval(uid:String, approvalData:Dictionary) -> int:
	var key = uid_approval_key + uid
	return add_data(key,approvalData)

# 添加好友 
func add_uid_friend(uid:String, friend:Dictionary) -> int:
	var key = uid_friend_key + uid
	return add_data(key,friend)

# 添加俱乐部
func add_uid_club(uid:String, club:Dictionary) -> int:
	var key = uid_club_key + uid
	return add_data(key,club)


# 获取数据
func get_data(key: String, default_value = null):
	return cached_data.get(key, default_value)


func get_data_array(key:String) -> Array:
	if not cached_data.has(key):
		return []
	return cached_data[key]

func get_data_array_item(key:String,field:String,value) -> Dictionary:
	if not cached_data.has(key):
		return {}
	for item in cached_data[key]:
		if item.has(field) and item[field] == value:
			return item
	return {}

# 获取是否静音
func get_isMute() -> bool:
	if cached_data.has(ismute_key):
		return cached_data[ismute_key]
	return false

#获取申请数据 
func get_uid_approval(uid:String) -> Array:
	return get_data_array(uid_approval_key + uid)

# 获取好友列表
func get_uid_friends(uid:String) -> Array:
	return get_data_array(uid_friend_key + uid)

# 获取好友信息
func get_uid_friendInfo(uid:String, friendId:String) -> Dictionary:
	return get_data_array_item(uid_friend_key + uid,"id",friendId)

# 获取俱乐部列表
func get_uid_clubs(uid:String) -> Array:
	return get_data_array(uid_club_key + uid)

# 获取俱乐部信息
func get_uid_clubInfo(uid:String, clubId:String) -> Dictionary:
	return get_data_array_item(uid_club_key + uid,"id",clubId)

func get_channel_list(uid: String)-> Array:
	var key = uid_channel_key + uid
	if not cached_data.has(key):
		return []
	return cached_data[key]

# 获取聊天记录
func get_chat_history(uid:String, channelId:String, default_value = null):
	var key = chat_key+uid
	if not cached_data.has(key):
		return default_value
	if not cached_data[key].has(channelId):
		return default_value

	var msgList = []
	for message in cached_data[key][channelId]:
		var msg =message  if not (message is String) else parse_message(message)
		msgList.append(msg)
	return msgList

func get_world_channel_id():
	return get_data(world_channel_id)

func get_current_game():
	return get_data(current_game_key)



# 删除数据
func remove_data(key:String, filed:String, value):
	if not cached_data.has(key):
		return 
	if not cached_data[key].has(filed):
		return 
	cached_data[key].filed.erase(value)
	pass

# 删除数组数据
func remove_data_array(key:String, field:String, value):
	if not cached_data.has(key):
		return 
	var itemList = []
	if field == "":
		cached_data[key] = itemList
		return
	for item in cached_data[key]:
		if item.has(field) and item[field] == value:
			continue
		itemList.append(item)
	cached_data[key] = itemList
	pass

# 删除聊天记录
func remove_chat_history(uid:String, channelId:String, messageId:String=""):
	var key = chat_key+uid
	if not cached_data.has(key):
		return 
	if not cached_data[key].has(channelId):
		return 

	var msgList = []
	if messageId != "":
		for message in cached_data[key][channelId]:
			var msg =message  if not (message is String) else parse_message(message)
			if msg.message_id != messageId:
				msgList.append(msg)
	cached_data[key][channelId] = msgList
	save_data()  # 每次设置数据后 自动保存
	return msgList


# 更新聊天记录
func update_chat_history(uid:String, channelId:String, msg):
	var key = chat_key+uid
	if not cached_data.has(key):
		return 
	if not cached_data[key].has(channelId):
		return 

	var messageId = msg.message_id
	if messageId != "":
		for message in cached_data[key][channelId]:
			var msgObj =message  if not (message is String) else parse_message(message)
			if msgObj.message_id == messageId:
				message = msg._to_string()
				save_data()  # 每次设置数据后 自动保存
				return
	return


func remove_friend(uid:String, friendId:String):
	remove_data_array(uid_friend_key + uid,"id",friendId)
	save_data()  # 每次设置数据后 自动保存
	pass

func remove_friend_all(uid:String):
	remove_data_array(uid_friend_key + uid,"","")
	pass

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



##########################################################################
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
