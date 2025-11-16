extends Node

# 存储所有全局变量的字典
var _globals: Dictionary = {}

# 加密密钥（建议在实际项目中使用更安全的密钥管理方式）
const ENCRYPTION_KEY = "your-secret-key-12345"
const CONFIG_PATH = "user://global_config.cfg"

func _ready():
	# 加载并初始化所有全局变量
	_load_globals()

# 从配置文件加载所有全局变量
func _load_globals() -> void:
	# 清空现有全局变量
	_globals.clear()
	
	# 1. 先加载默认配置
	var default_config = ConfigFile.new()
	var default_config_path = "res://autoload/global/global_config.cfg"
	if default_config.load(default_config_path) != OK:
		push_error("无法加载默认配置文件: " + default_config_path)
		return
	
	# 2. 尝试加载用户配置
	var user_config = ConfigFile.new()
	if FileAccess.file_exists(CONFIG_PATH):
		if user_config.load_encrypted_pass(CONFIG_PATH, ENCRYPTION_KEY) != OK:
			push_warning("加载用户配置失败，使用默认配置")
			user_config = default_config
	else:
		user_config = default_config
	
	# 3. 加载全局脚本
	_load_scripts(user_config)
	
	# 4. 保存用户配置（如果是第一次运行）
	if not FileAccess.file_exists(CONFIG_PATH):
		var err = user_config.save_encrypted_pass(CONFIG_PATH, ENCRYPTION_KEY)
		if err != OK:
			push_warning("保存用户配置失败: " + str(err))

# 加载脚本
func _load_scripts(config: ConfigFile) -> void:
	print("开始加载全局脚本...")
	for section in config.get_sections():
		print_rich("检查配置段: [color=red][b]", section,"[/b][/color]")
		for key in config.get_section_keys(section):
			var path = config.get_value(section, key, "").strip_edges()
			if path.is_empty():
				print("警告: 空路径在 [", section, "] ", key)
				continue
				
			# 规范化路径
			path = path.replace("\\", "/")
			
			# 提取变量名（去掉可能的中文字符）
			var var_name = key
			if "#" in key:
				var_name = key.split("#")[0].strip_edges()
			print_rich("[color=green]", var_name, "[/color] -> [color=yellow]", path,"[/color]")
			# 加载资源
			var resource = _load_resource(path)
			if resource:
				_globals[var_name] = resource
				#print("√ 已加载全局变量: ", var_name, " 类型: ", resource.get_class())
			else:
				print("× 加载失败: ", var_name, " (路径: ", path, ")")
	print("\n全局脚本加载完成\n \n")

# 加载资源
func _load_resource(path: String):
	if not ResourceLoader.exists(path):
		push_warning("资源不存在: " + path)
		return null
		
	var resource = ResourceLoader.load(path)
	if not resource:
		push_warning("无法加载资源: " + path)
		return null
		
	if resource is PackedScene:
		var instance = resource.instantiate()
		instance.name = path.get_file().get_basename()
		add_child(instance)
		return instance
		
	return resource

# 重写 _get 方法以支持直接访问全局变量
func _get(property: StringName):
	if not _globals.has(property):
		push_error("未找到全局变量: " + str(property))
		return null
		
	var value = _globals[property]
	
	# 如果是脚本资源，自动实例化
	if value is GDScript:
		var instance = value.new()
		if instance is Node:
			add_child(instance)
		_globals[property] = instance  # 缓存实例
		return instance
		
	return value

# 添加模块配置
func add_module_config(module_name: String, config_data: Dictionary) -> bool:
	if module_name.is_empty() or config_data.is_empty():
		push_error("模块名称和配置数据不能为空")
		return false
	
	# 加载或创建配置
	var config = ConfigFile.new()
	if FileAccess.file_exists(CONFIG_PATH):
		if config.load_encrypted_pass(CONFIG_PATH, ENCRYPTION_KEY) != OK:
			push_error("加载用户配置失败")
			return false
	
	# 更新配置
	for key in config_data:
		config.set_value(module_name, key, config_data[key])
	
	# 保存配置
	if config.save_encrypted_pass(CONFIG_PATH, ENCRYPTION_KEY) != OK:
		push_error("保存配置失败")
		return false
	
	# 更新内存中的全局变量
	if not _globals.has(module_name):
		_globals[module_name] = {}
	
	for key in config_data:
		_globals[module_name][key] = config_data[key]
	
	return true

# 获取全局变量
func get_global(var_name: String):
	if _globals.has(var_name):
		return _globals[var_name]
	push_error("全局变量不存在: " + var_name)
	return null

# 设置全局变量
func set_global(var_name: String, value) -> void:
	if value is Node and not value.is_inside_tree():
		add_child(value)
	_globals[var_name] = value

# 检查全局变量是否存在
func has_global(var_name: String) -> bool:
	return _globals.has(var_name)

# 移除全局变量
func remove_global(var_name: String) -> void:
	if _globals.has(var_name):
		var value = _globals[var_name]
		if value is Node and is_instance_valid(value):
			remove_child(value)
			value.queue_free()
		_globals.erase(var_name)

# 静态方法，方便在任何地方获取全局变量
static func get_global_var(var_name: String):
	var loader = _get_loader()
	if loader:
		return loader.get_global(var_name)
	return null

# 获取全局加载器实例
static func _get_loader():
	return Engine.get_main_loop().root.get_node("Global")

# 保存配置到文件
func save_config() -> bool:
	var config = ConfigFile.new()
	
	# 将当前配置保存到 ConfigFile 对象
	for section in _globals:
		config.set_value("globals", section, _globals[section])
	
	# 保存到临时文件
	var temp_path = CONFIG_PATH + ".tmp"
	var err = config.save_encrypted_pass(temp_path, ENCRYPTION_KEY)
	if err != OK:
		push_error("保存配置文件失败: " + str(err))
		return false
		
	# 确保目录存在
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("无法访问用户目录")
		return false
	
	# 重命名临时文件
	if FileAccess.file_exists(CONFIG_PATH):
		dir.remove(CONFIG_PATH)
	dir.rename(temp_path, CONFIG_PATH)
	
	return true

# 从文件加载配置
func load_config() -> bool:
	# 如果配置文件不存在，使用默认配置
	if not FileAccess.file_exists(CONFIG_PATH):
		# 从项目中的默认配置加载
		var default_config = ConfigFile.new()
		var load_err = default_config.load("res://autoload/global/global_config.cfg")
		if load_err != OK:
			push_error("无法加载默认配置文件: " + str(load_err))
			return false
		
		# 保存到用户目录
		var save_err = default_config.save_encrypted_pass(CONFIG_PATH, ENCRYPTION_KEY)
		if save_err != OK:
			push_error("无法保存默认配置文件: " + str(save_err))
			return false
	
	# 加载加密的配置文件
	var config = ConfigFile.new()
	var err = config.load_encrypted_pass(CONFIG_PATH, ENCRYPTION_KEY)
	if err != OK:
		push_error("无法加载配置文件: " + str(err))
		return false
	
	return true
