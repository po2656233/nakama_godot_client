extends Node

# 存储场景路径的字典 (场景名: 路径)
var scene_paths = {}
# 维护场景顺序的数组
var scene_order = []
# 当前场景索引
var current_scene_index = -1
var DISSOLVE_IMAGE = preload('res://addons/transitions/images/blurry-noise.png')
# 场景转换效果类型映射
const TRANSITION_TYPES = {
	# 擦除效果
	"WIPE_LEFT": {
		"key": "wipe-left",
		"description": "从右向左擦除"
	},
	"WIPE_RIGHT": {
		"key": "wipe-right",
		"description": "从左向右擦除"
	},
	"WIPE_UP": {
		"key": "wipe-up",
		"description": "从下向上擦除"
	},
	"WIPE_DOWN": {
		"key": "wipe-down",
		"description": "从上向下擦除"
	},
	"WIPE_SQUARE": {
		"key": "square",
		"description": "方形擦除效果"
	},
	"WIPE_CONICAL": {
		"key": "conical",
		"description": "锥形擦除效果"
	},
	
	# 圆形效果
	"CIRCLE_IN": {
		"key": "circle-in",
		"description": "圆形向内收缩"
	},
	"CIRCLE_OUT": {
		"key": "circle-out",
		"description": "圆形向外扩展"
	},
	
	# 噪点效果
	"NOISE": {
		"key": "noise",
		"description": "随机噪点过渡"
	},
	"NOISE_PIXELATED": {
		"key": "noise-pixelated",
		"description": "像素化噪点过渡"
	},
	"NOISE_BLURRY": {
		"key": "blurry-noise",
		"description": "模糊噪点过渡"
	},
	"NOISE_CELL": {
		"key": "cell-noise",
		"description": "蜂窝状噪点过渡"
	},
	
	# 艺术效果
	"PAINT_BRUSH_HORIZONTAL": {
		"key": "horizontal-paint-brush",
		"description": "水平画笔效果"
	},
	"PAINT_BRUSH_VERTICAL": {
		"key": "vertical-paint-brush",
		"description": "垂直画笔效果"
	},
	"SWIRL": {
		"key": "swirl",
		"description": "旋涡效果"
	},
	"TILE_REVEAL": {
		"key": "tile_reveal",
		"description": "瓦片揭示效果"
	}
}


###############################################################
func _ready():
	# 添加场景字典
	var scenes = {
		"login": "res://scenes/login.tscn",
		"register": "res://scenes/register.tscn",
		"home": "res://scenes/home.tscn",
		"game": "res://scenes/game.tscn",
		"match": "res://scenes/match.tscn",
		# "email":"res://scenes/email/mail.tscn"
		# # 如果有重复的场景名称，将被跳过并输出警告
		# "login": "res://scenes/another_login.tscn"  ,
	}

	add_scenes_from_dict(scenes)
	scan_scenes_directory("res://scenes")
	print_all_scenes()

###############################################################
# 获取转换效果的键值
static func get_transition_key(transition_type: String) -> String:
	if TRANSITION_TYPES.has(transition_type):
		return TRANSITION_TYPES[transition_type]["key"]
	return ""

# 获取转换效果的描述
static func get_transition_description(transition_type: String) -> String:
	if TRANSITION_TYPES.has(transition_type):
		return TRANSITION_TYPES[transition_type]["description"]
	return ""

################################################################
# 扫描目录下的所有.tscn场景文件
func scan_scenes_directory(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir() and file_name != "." and file_name != "..":
				# 递归扫描子目录
				scan_scenes_directory(path.path_join(file_name))
			elif file_name.ends_with(".tscn"):
				# 将场景添加到路径字典中
				var scene_name = file_name.get_basename()  # 移除.tscn扩展名
				var full_path = path.path_join(file_name)
				add_scene(scene_name, full_path)
				
			file_name = dir.get_next()
			
		dir.list_dir_end()

# 添加单个场景，如果场景名已存在则跳过
# @param scene_name: 场景名称
# @param scene_path: 场景路径
# @return: 是否成功添加场景（true：添加成功，false：场景已存在）
func add_scene(scene_name: String, scene_path: String) -> bool:
	# 如果场景名已存在，则跳过
	if scene_paths.has(scene_name):
		push_warning("场景名称 '%s' 已存在，跳过添加。" % scene_name)
		return false
		
	# 添加新场景
	scene_paths[scene_name] = scene_path
	scene_order.append(scene_name)
	return true

# 添加场景字典，保持字典中的顺序，跳过重复场景
# @param scenes_dict: 包含场景名称和路径的字典
func add_scenes_from_dict(scenes_dict: Dictionary) -> void:
	# 清空现有的场景数据
	scene_paths.clear()
	scene_order.clear()
	
	# 用于检查重复场景名的临时集合
	var added_scenes = {}
	
	# 遍历字典并按顺序添加场景，跳过重复的
	for scene_name in scenes_dict:
		# 如果场景名未被添加过
		if not added_scenes.has(scene_name):
			add_scene(scene_name, scenes_dict[scene_name])
			added_scenes[scene_name] = true
		else:
			push_warning("场景名称 '%s' 重复，跳过添加。" % scene_name)

# 设置场景的自定义顺序
# @param scene_names: 场景名称数组，按照期望的顺序排列
func set_scene_order(scene_names: Array) -> void:
	var new_order = []
	var added_scenes = {}  # 用于检查重复场景名
	
	for scene_name in scene_names:
		# 确保场景存在且未被添加过
		if scene_paths.has(scene_name) and not added_scenes.has(scene_name):
			new_order.append(scene_name)
			added_scenes[scene_name] = true
	
	scene_order = new_order

# 获取当前场景名称
func get_current_scene_name() -> String:
	if current_scene_index >= 0 and current_scene_index < scene_order.size():
		return scene_order[current_scene_index]
	return ""

func get_previous_scene_name() -> String:
	if current_scene_index > 0:
		# 获取上一个场景的名称
		var previous_name = scene_order[current_scene_index - 1]
		# 返回上一个场景的完整路径
		return previous_name
	# 如果是第一个场景或未找到当前场景，返回空字符串
	return ""

# 根据当前场景名称获取上一个场景的路径
# @param current_scene_name: 当前场景名称（不带.tscn后缀）
# @return: 上一个场景的完整路径，如果没有上一个场景则返回空字符串
func get_previous_scene_path(current_scene_name: String) -> String:
	# 如果当前场景名称为空，返回空字符串
	if current_scene_name.is_empty():
		return ""
		
	# 在顺序数组中查找当前场景的索引
	var current_idx = scene_order.find(current_scene_name)
	
	# 如果找到当前场景且不是第一个场景
	if current_idx > 0:
		# 获取上一个场景的名称
		var previous_name = scene_order[current_idx - 1]
		# 返回上一个场景的完整路径
		return scene_paths[previous_name]
	
	# 如果是第一个场景或未找到当前场景，返回空字符串
	return ""

# 设置当前场景
func set_current_scene(scene_name: String) -> void:
	current_scene_index = scene_order.find(scene_name)

# 通过场景名称获取场景路径
func get_scene_path(scene_name: String) -> String:
	return scene_paths.get(scene_name, "")

# 获取按顺序排列的所有场景名称
func get_ordered_scene_names() -> Array:
	return scene_order

# 获取所有可用的场景路径
func get_all_scenes() -> Dictionary:
	return scene_paths

# 获取当前场景的完整路径
# @return: 当前场景的完整路径，如果未设置当前场景则返回空字符串
func get_current_scene_path() -> String:
	var current_name = get_current_scene_name()
	return get_scene_path(current_name)

# 从场景路径中获取场景名称（不含.tscn后缀）
# @param scene_path: 场景的完整路径
# @return: 场景名称
func get_scene_name_from_path(scene_path: String) -> String:
	# 获取文件名（带后缀）
	var file_name = scene_path.get_file()
	# 移除后缀返回场景名
	return file_name.get_basename()

# 获取当前运行场景的完整路径
# @return: 当前运行场景的完整路径
func get_running_scene_path() -> String:
	return get_tree().current_scene.scene_file_path

# 获取当前运行场景的名称（不含.tscn后缀）
# @return: 当前运行场景的名称
func get_running_scene_name() -> String:
	return get_scene_name_from_path(get_running_scene_path())

# 返回上一个场景
func go_back() -> void:
	var nodeName = get_running_scene_name()
	var path = SceneManager.get_previous_scene_path(nodeName)
	_transition_scene(path)
	pass

# 切换场景
func switch_to_scene(scene_name: String, transition_way:String = "conical", dissolve_time: float = 1.0, dissolve_image: CompressedTexture2D = DISSOLVE_IMAGE) -> void:
	if scene_name == "":
		return 
	var scene_path = get_scene_path(scene_name)
	_transition_scene(scene_path,transition_way,dissolve_time, dissolve_image)
	pass

func _transition_scene(scene_path: String,  transition_way:String = "conical",dissolve_time: float = 1.0, dissolve_image: CompressedTexture2D = DISSOLVE_IMAGE) -> void:
	if scene_path == "":
		push_error("场景路径为空")
		return
	var sceneObj = load(scene_path).instantiate()
	if not  sceneObj:
		return
	if transition_way == "custom":
		FancyFade.custom_fade(sceneObj, dissolve_time, dissolve_image)
	elif transition_way == "cross":
		FancyFade.cross_fade(sceneObj, dissolve_time)
	else:
		FancyFade._fade(transition_way,sceneObj,dissolve_time)


# 隐藏指定场景
func hide_scene(scene_name: String) -> bool:
	var scene_path = get_scene_path(scene_name)
	var current_scene = get_tree().current_scene
	if current_scene == null:
		push_warning("当前没有活动场景")
		return false
		
	# 遍历当前场景的所有子节点
	if _is_scene_displayed(scene_path):
		for child in current_scene.get_children():
			# 检查是否是我们添加的容器
			if child is Control:
				# 检查容器中的场景
				for container_child in child.get_children():
					print("节点路径:",container_child.scene_file_path)
					if container_child.scene_file_path == scene_path:
						# 找到了指定场景，隐藏其容器
						child.visible = false
						print("隐藏--->",scene_name)
						return true
		push_warning("未找到要隐藏的场景：" + scene_path)
		return false

	var scene = load(scene_path)
	if not scene:
		push_error("无法加载场景：" + scene_path)
		return false
		
	var scene_instance = scene.instantiate()
	if not scene_instance:
		push_error("无法实例化场景：" + scene_path)
		return false
 
	scene_instance.hide()
	current_scene.add_child(scene_instance)
	return false

# 显示指定场景（如果已经被隐藏）
func show_scene(scene_name: String) -> bool:
	var scene_path = get_scene_path(scene_name)
	var current_scene = get_tree().current_scene
	if current_scene == null:
		push_warning("当前没有活动场景")
		return false

	if _is_scene_displayed(scene_path):
		# 遍历当前场景的所有子节点 
		for child in current_scene.get_children():
			# 检查是否是我们添加的容器
			if child is Control:
				# 检查容器中的场景
				for container_child in child.get_children():
					if container_child.scene_file_path == scene_path:
						# 找到了指定场景，显示其容器
						child.visible = true
						print("展示--->",scene_name)
						return true
		push_warning("未找到要显示的场景：" + scene_path)
		return false

	var scene = load(scene_path)
	if not scene:
		push_error("无法加载场景：" + scene_path)
		return false
		
	var scene_instance = scene.instantiate()
	if not scene_instance:
		push_error("无法实例化场景：" + scene_path)
		return false

	scene_instance.visible = true
	current_scene.add_child(scene_instance)
	return true


# 检查场景是否已经在显示中
func _is_scene_displayed(scene_path: String) -> bool:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return false
		
	# 遍历当前场景的所有子节点
	for child in current_scene.get_children():
		# 检查是否是我们添加的容器
		if child is Control:
			# 检查容器中的场景
			for container_child in child.get_children():
				if container_child.scene_file_path == scene_path:
					return true
	return false

# 在当前场景的中间按比例显示场景
# @param scene_path: 要显示的场景路径
# @param scale_ratio: 缩放比例 (0.0 到 1.0 之间，1.0 表示原始大小)
# @return: 返回实例化的场景节点
func show_scene_in_center(scene_name: String, scale_ratio: float = 0.8) -> Node:
	var scene_path = get_scene_path(scene_name)
	# 检查场景是否已经显示
	if _is_scene_displayed(scene_path):
		push_warning("场景已经在显示中：" + scene_path)
		return null
	# 确保比例在有效范围内
	scale_ratio = clampf(scale_ratio, 0.1, 1.0)
	
	# 加载并实例化场景
	var scene = load(scene_path)
	if not scene:
		push_error("无法加载场景：" + scene_path)
		return null
		
	var scene_instance = scene.instantiate()
	if not scene_instance:
		push_error("无法实例化场景：" + scene_path)
		return null
	
	# 获取当前场景
	var current_scene = get_tree().current_scene
	
	# 创建一个Control节点作为容器
	var container = Control.new()
	
	# 计算边距比例（用于居中）
	var margin_ratio = (1.0 - scale_ratio) / 2.0
	
	# 设置锚点到全屏
	container.anchor_left = margin_ratio
	container.anchor_right = 1.0 - margin_ratio
	container.anchor_top = margin_ratio
	container.anchor_bottom = 1.0 - margin_ratio
	
	# 设置边距为0，确保完全贴合锚点
	container.offset_left = 0
	container.offset_right = 0
	container.offset_top = 0
	container.offset_bottom = 0
	
	# 将场景实例添加到容器中
	scene_instance.visible = true
	container.add_child(scene_instance)
	
	# 将容器添加到当前场景
	current_scene.add_child(container)
	
	return scene_instance

# 在当前场景的右半边显示指定的场景
# @param scene_path: 要显示的场景路径
# @param custom_size: 自定义大小 (可选)
# @return: 返回实例化的场景节点
func show_scene_on_right(scene_name: String, custom_size: Vector2 = Vector2.ZERO) -> Node:
	var scene_path = get_scene_path(scene_name)

	# 检查场景是否已经显示
	if _is_scene_displayed(scene_path):
		push_warning("场景已经在显示中：" + scene_path)
		return null

	# 加载并实例化场景
	var scene = load(scene_path)
	if not scene:
		push_error("无法加载场景：" + scene_path)
		return null
		
	var scene_instance = scene.instantiate()
	if not scene_instance:
		push_error("无法实例化场景：" + scene_path)
		return null
	
	# 获取当前场景
	var current_scene = get_tree().current_scene
	
	# 创建一个Control节点作为容器
	var container = Control.new()
	
	# 设置锚点到右半边
	container.anchor_left = 0.5  # 从中间开始
	container.anchor_right = 1.0  # 到右边
	container.anchor_top = 0.0	# 从顶部开始
	container.anchor_bottom = 1.0  # 到底部
	
	# 设置边距为0，确保完全贴合锚点
	container.offset_left = 0
	container.offset_right = 0
	container.offset_top = 0
	container.offset_bottom = 0
	
	# 如果提供了自定义大小，则设置大小
	if custom_size != Vector2.ZERO:
		container.custom_minimum_size = custom_size
	
	# 将场景实例添加到容器中
	scene_instance.visible = true
	container.add_child(scene_instance)
	
	# 将容器添加到当前场景
	current_scene.add_child(container)
	
	return scene_instance

# 移除显示的场景
# @param scene_instance: 要移除的场景实例
func remove_scene(scene_instance: Node) -> void:
	if scene_instance and is_instance_valid(scene_instance):
		var parent = scene_instance.get_parent()
		if parent:
			parent.queue_free()  # 这将同时移除容器和场景实例




# 打印所有场景信息
# 打印所有场景信息
func print_all_scenes() -> void:
	var _scenes =scene_paths
	print("\n=== 场景列表 ===")
	print("总数: ", _scenes.size(), " 个场景\n")
	
	# 获取最长的场景名称长度用于对齐
	var max_name_length = 0
	for scene_name in _scenes.keys():
		max_name_length = max(max_name_length, scene_name.length())
	
	# 计算索引列宽
	var index_width = len(str(_scenes.size()))
	
	# 打印分隔线
	var separator = "+" + "-".repeat(index_width + 2) + "+" + "-".repeat(max_name_length + 2) + "+" + "-".repeat(50) + "+"
	print(separator)
	
	# 打印表头
	print("| %-*s | %-*s | %48s |" % [index_width, "序号", max_name_length, "场景名称", "场景路径"])
	print(separator)
	
	# 按场景名称排序并打印
	var sorted_scenes = _scenes.keys()
	# sorted_scenes.sort()
	 
	# 遍历打印场景信息
	for i in range(sorted_scenes.size()):
		var scene_name = sorted_scenes[i]
		var scene_index = scene_order.find(scene_name)  # 获取原始添加顺序的索引
		print("| %-*d | %-*s | %48s |" % [index_width, scene_index, max_name_length, scene_name, _scenes[scene_name]])
	
	# 打印底部分隔线
	print(separator)
	print("\n")
	pass