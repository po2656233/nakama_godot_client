extends Node


#################################################################################
# 异步加载 Texture2D
func load_texture_async(url: String,width: int = 25,height: int = 25) :
	if url.is_empty():
		return null
	var request = HTTPRequest.new()
	add_child(request)
	
	request.request(url)
	var result = await request.request_completed
	
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		print("无法加载图片: ", result[0],url)
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
	
	image.resize(width,height)
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

# 获取东八区时间
func get_chinese_time_str(timestamp: String, show_seconds: bool = true) -> String:
	return format_china_time(Time.get_unix_time_from_datetime_string(timestamp),show_seconds)

func remove_message_by_id(messages: Array, target_message_id: String):
	for i in range(messages.size() - 1, -1, -1):
		if messages[i].message_id == target_message_id:
			messages.remove_at(i)
			return true
	return false 




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

func isMobile()->bool:
	var systemName = OS.get_name()
	return systemName == "Android" or systemName == "iOS"


func isFullScreen()->bool:
	return  DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
