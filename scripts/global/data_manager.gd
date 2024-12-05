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
func add_chat_history(channelId:String, msg) -> void:
	# 如果 chat_key 不存在，创建一个字典
	if not cached_data.has(chat_key):
		cached_data[chat_key] = {}
	
	# 如果 channelId 不存在，创建一个数组
	if not cached_data[chat_key].has(channelId):
		cached_data[chat_key][channelId] = []
	
	# 添加消息到数组 
	cached_data[chat_key][channelId].append(msg._to_string())
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
	return cached_data[chat_key][channelId]

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
