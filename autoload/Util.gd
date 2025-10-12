extends Node


var EMPTY_CALLABLE = Callable(func(_ret): pass)
# 重连 可靠消息队列
var reliable_queue: ReliableMessageQueue

# 初始化
func _ready() -> void:
	# 创建可靠消息队列
	reliable_queue = ReliableMessageQueue.new()
	add_child(reliable_queue)

# 通用异步调用封装
# 参数:
#   caller: 调用对象实例
#   method_name: 异步方法名 (字符串)
#   args: 参数数组
#   on_success: 成功回调函数 (Callable)
#   on_failure: 失败回调函数 (Callable)
# 优化后的异步调用方法
func Asyn_Call(caller: Object, method_name: String, args: Array, on_success: Callable, on_failure: Callable, inqueue: bool = true) -> bool:
	print("Obj:%s:<<< FUNC:[%s] >>>|||<<<args:[%s]>>>\n" % [str(caller),method_name,str(args)])
	# 验证方法是否存在
	if not caller or not caller.has_method(method_name):
		push_error("Method not found: %s" % method_name)
		if on_failure and on_failure.is_valid(): on_failure.call("Method not found")
		return false

	# 验证回调函数是否有效
	if not on_success or not on_success.is_valid():
		push_error("Invalid on_success callback")
		return false
	if not on_failure or not on_failure.is_valid():
		push_error("Invalid on_failure callback")
		return false

	# 执行异步调用
	var task = caller.callv(method_name, args)
	if not (task is Object) or !task.has_method("is_valid") or !task.is_valid():
		if on_failure and on_failure.is_valid(): on_failure.call("Invalid async task")
		return false

	# 使用协程处理异步结果
	var result = await task.completed
	
	# 处理结果
	if result != null and result.has_method("is_exception") and result.is_exception():
		# 有异常反馈，也被认为是执行成功了
		var errMsg = result.get_exception().message
		if on_failure and on_failure.is_valid(): on_failure.call(errMsg)
		if errMsg in Errors.NetworkErrors: # 网络异常,则视为执行失败
			if inqueue:
				var msg_id = reliable_queue.EnqueueMessage(method_name,args,caller,on_success, on_failure)
				if not msg_id:
					print("添加至消息队列重试 func_name:", method_name," payload:", args, " msg_id:", msg_id)
			print("Network error occurred: %s will resend:%s" % [errMsg,inqueue])
		print("Asyn_Call Failure: %s" % errMsg)
		if errMsg in Errors.ResponeMapping:
			errMsg = Errors.ResponeMapping[errMsg]
		PopupManager.show_dynamic(errMsg)
		return false
	print("Asyn_Call Success: %s" % str(result))
	if on_success and on_success.is_valid(): on_success.call(result)
	return true

# 改进的安全连接函数
func safe_connect(obj: Object, signal_name: String, target: Object, method: String) -> void:
	# 检查socket是否有效
	if not is_instance_valid(obj):
		push_error("Attempted to connect to invalid socket instance")
		return
		
	# 检查信号是否存在
	if not obj.has_signal(signal_name):
		push_error("Signal '%s' not found on object %s" % [signal_name, obj])
		return
	
	var callable = Callable(target, method)
	
	# 安全断开：只断开已存在的连接
	if obj.is_connected(signal_name, callable):
		obj.disconnect(signal_name, callable)
	
	# 连接信号
	var error = obj.connect(signal_name, callable)
	if error != OK:
		push_error("Failed to connect signal '%s': Error %d" % [signal_name, error])
	pass
# 
func find_unique_name(parent: Node, prefix: String = '') -> String:
	var name1: String
	while true:
		name1 = random_name(prefix)
		if not parent.has_node(name1):
			break
	return name1

func random_name(prefix: String) -> String:
	return prefix + str(randi())


# 就数组进行字段排序
func sort_by_filed(arr:Array,sort_field:String=""):
	if not arr.is_empty():
		var sorted = arr.duplicate() 
		if sort_field != "":
			sorted.sort_custom(func(a, b):
				if a.has(sort_field) and b.has(sort_field):
					return a[sort_field] < b[sort_field]
				else:
					return false
			)
		return sorted
	return []

#################################################################################
# 异步加载 Texture2D
func load_texture_async(url: String, width: int = 25, height: int = 25):
	if url.is_empty():
		return null
	var request = HTTPRequest.new()
	add_child(request)
	
	request.request(url)
	var result = await request.request_completed
	
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		print("无法加载图片: ", result[0], url)
		request.queue_free()
		return null
	# var response_code = result[1]
	var headers = result[2]
	var image = Image.new()
	# 检查Content-Type
	var error = OK
	for header in headers:
		if header.to_lower().begins_with("content-type:"):
			var content_type = header.split(":")[1].strip_edges().to_lower()
			# 根据content-type返回对应的扩展名
			match content_type:
				"image/jpeg", "image/jpg":
					error = image.load_jpg_from_buffer(result[3])
				"image/png":
					error = image.load_png_from_buffer(result[3])
				"image/gif":
					return "gif"
				"image/webp":
					error = image.load_webp_from_buffer(result[3])
				"image/bmp":
					error = image.load_bmp_from_buffer(result[3])
				"image/svg":
					error = image.load_svg_from_buffer(result[3])
				"image/tga":
					error = image.load_tga_from_buffer(result[3])
	if error != OK:
		print("加载图片失败: ", url)
		request.queue_free()
		return null
	
	image.resize(width, height)
	request.queue_free()
	return ImageTexture.create_from_image(image)
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
		var field_value_a = _get_field_value(a, sort_field)
		var field_value_b = _get_field_value(b, sort_field)
		# print('时间比较:',field_value_a, field_value_b)
		if not field_value_a or not field_value_b:
			push_error("比较异常", field_value_a, field_value_b)
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

# 获取东八区时间
func get_chinese_time_str(timestamp: String, show_seconds: bool = true) -> String:
	return format_china_time(Time.get_unix_time_from_datetime_string(timestamp), show_seconds)


# 获取当前时间戳
func get_current_timestamp() -> String:
	var time_dict = Time.get_time_dict_from_system()
	var date_dict = Time.get_date_dict_from_system()
	
	# 格式化时间为 HH:MM:SS
	var time_str = "%02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second]
	 
	# 格式化日期为 YYYY-MM-DD
	var date_str = "%04d-%02d-%02d" % [date_dict.year, date_dict.month, date_dict.day]
	return "%s %s" % [date_str, time_str] # 输出示例：2024-03-15 14:30:45

# func check_network():
# 	if OS.has_feature("mobile"):
# 		# 检查网络连接状态
# 		if OS.get_network_connected_type() == -1:
# 			push_error("没有网络连接")
# 			return false
			
# 		# 输出网络类型
# 		var network_type = OS.get_network_type()
# 		match network_type:
# 			0: print("未知网络类型")
# 			1: print("以太网连接")
# 			2: print("WIFI连接")
# 			3: print("移动数据连接")
# 			4: print("移动数据2G")
# 			5: print("移动数据3G")
# 			6: print("移动数据4G")
# 	return true

func isMobile() -> bool:
	var systemName = OS.get_name()
	return systemName == "Android" or systemName == "iOS"


func isFullScreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func norepeat(arr: Array) -> Array:
	arr = arr.duplicate(true) # 使用副本而不是对原数组进行操作
	var dict: Dictionary = {}
	for item in arr:
		dict[item] = item
	return dict.keys() # dict.values()也可以



# # 1. 初始化（无场景树）
# func _init():
# 	print("场景初始化")

# # 2. 加入场景树
# func _enter_tree():
# 	print("进入场景树")

# # 3. 准备就绪（所有子节点就绪）
# func _ready():
# 	print("场景准备就绪")
# 	set_process(true)
	
# # 4. 每帧更新 虚拟 靠算力补充帧
# func _process(delta):
# 	pass
	
# # 5. 每物理帧更新
# func _physics_process(delta):
# 	pass

# # 6. 输入处理
# func _input(event):
# 	if event is InputEventKey:
# 		print("按键输入:", event.as_text())

# # 7. 离开场景树
# func _exit_tree():
# 	print("离开场景树")

# # 8. 删除前（最后清理）
# func _notification(what):
# 	if what == NOTIFICATION_PREDELETE:
# 		print("场景即将销毁")
