extends Node

# 存储所有全局变量的字典
var _globals: Dictionary = {}

func _ready():
	# 加载并初始化所有全局变量
	_load_globals()

# 从配置文件加载所有全局变量
func _load_globals() -> void:
	# 加载配置文件
	var config_file = FileAccess.open("res://autoload/global/global_config.json", FileAccess.READ)
	if not config_file:
		push_error("无法加载全局变量配置文件!")
		return
	
	# 解析JSON
	var json = JSON.new()
	var error = json.parse(config_file.get_as_text())
	if error != OK:
		push_error("解析全局变量配置失败: " + json.get_error_message())
		return
		
	var config = json.get_data()
	if typeof(config) != TYPE_DICTIONARY:
		push_error("全局变量配置格式错误!")
		return
	
	# 加载并实例化全局变量
	for key in config:
		var path = config[key]
		var resource = load(path)
		if resource:
			if resource is PackedScene:
				var instance = resource.instantiate()
				instance.name = key
				add_child(instance)
				_globals[key] = instance
				print("已加载全局场景: ", key, " 路径: ", path)
			elif path.ends_with(".gd"):
				# 加载脚本
				_globals[key] = resource.new()
				if _globals[key] is Node and not _globals[key].is_inside_tree():
					add_child(_globals[key])
				print("已加载全局脚本: ", key, " 路径: ", path)
		else:
			push_error("无法加载资源: " + path)

# 重写 _get 方法以支持直接访问全局变量
func _get(property: StringName):
	if _globals.has(property):
		return _globals[property]
	push_error("未找到全局变量: " + str(property))
	return null

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
