extends Node

## 模块：全局服务注册表（autoload: Global）
## 职责：
##   1. 从 res://core/bootstrap/global_config.cfg 读取“服务名 -> 脚本路径”；
##   2. 首次访问 Global.Xxx 时懒加载并挂到本节点下；
##   3. 配置缺失时回退到内置 DEFAULT_SERVICES，保证仍能启动。
## 说明：服务清单只认项目内配置，不再读取 user:// 缓存，避免旧缓存覆盖新路径。

const CONFIG_PATH := "res://core/bootstrap/global_config.cfg"

const DEFAULT_SERVICES := {
	# 网络
	"Online": "res://core/network/Online.gd",
	"OnlineLogin": "res://core/network/OnlineLogin.gd",
	"OnlineChat": "res://core/network/OnlineChat.gd",
	"OnlineGame": "res://core/network/OnlineGame.gd",
	"OnlineMatch": "res://core/network/OnlineMatch.gd",
	# 管理器
	"SignalMgr": "res://core/services/signal_manager.gd",
	"SceneMgr": "res://core/scene/scene_manager.gd",
	"SettingsMgr": "res://core/services/settings_manager.gd",
	"DataMgr": "res://core/services/data_manager.gd",
	"MailMgr": "res://core/services/mail_manager.gd",
	# 窗口
	"WindowDrag": "res://core/window/drag.gd",
	"WindowPopup": "res://core/window/popup.gd",
	# 转场插件
	"Transitions": "res://addons/transitions/Transitions.gd",
	"FancyFade": "res://addons/transitions/FancyFade.gd",
	"FadeScene": "res://addons/transitions/FadeScene.gd",
	# 子游戏框架
	"SceneRouter": "res://core/navigation/scene_router.gd",
	"GameRegistry": "res://core/framework/game_registry.gd",
	"GameLauncher": "res://core/framework/game_launcher.gd",
}

## 服务名 -> 资源路径（未实例化）
var _paths: Dictionary = {}
## 服务名 -> 已实例化对象/资源
var _instances: Dictionary = {}
var _registry_loaded := false

func _ready() -> void:
	_ensure_registry()

## 检查服务是否注册（不会实例化）。
func has_global(service_name: String) -> bool:
	_ensure_registry()
	return _paths.has(service_name) or _instances.has(service_name)

## 获取服务；首次访问时实例化。
func get_global(service_name: String):
	return _get(service_name)

## 主动注册/覆盖一个服务实例（测试或运行时扩展用）。
func set_global(service_name: String, value: Variant) -> void:
	_instances[service_name] = value

func list_services() -> Array[String]:
	_ensure_registry()
	var names: Array[String] = []
	for name1 in _paths.keys():
		names.append(str(name1))
	names.sort()
	return names

######################################################################
# 注册表加载
######################################################################

func _ensure_registry() -> void:
	if not _registry_loaded:
		_load_registry()

func _load_registry() -> void:
	_registry_loaded = true
	_paths.clear()

	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		for section in config.get_sections():
			for raw_key in config.get_section_keys(section):
				# 兼容 key 后写 # 注释的旧配置
				var service_name := str(raw_key).split("#")[0].strip_edges()
				var path := str(config.get_value(section, raw_key, "")).strip_edges().replace("\\", "/")
				if service_name.is_empty() or path.is_empty():
					continue
				if not ResourceLoader.exists(path):
					push_warning("[Global] 忽略不存在的服务脚本: %s -> %s" % [service_name, path])
					continue
				_paths[service_name] = path
	else:
		push_warning("[Global] 无法读取 %s，使用内置服务表" % CONFIG_PATH)

	# 配置缺项时用内置表补齐，保证新增服务在旧配置下也能用。
	for service_name in DEFAULT_SERVICES:
		if _paths.has(service_name):
			continue
		var default_path: String = DEFAULT_SERVICES[service_name]
		if ResourceLoader.exists(default_path):
			_paths[service_name] = default_path

######################################################################
# 懒加载
######################################################################

## 通过 Global.Xxx 访问时触发。
func _get(property: StringName) -> Variant:
	var name1 := str(property)
	if _instances.has(name1):
		return _instances[name1]

	_ensure_registry()
	if not _paths.has(name1):
		push_error("[Global] 未注册的服务: %s（请检查 global_config.cfg）" % name1)
		return null

	var resource = _load_resource(str(_paths[name1]))
	if resource == null:
		return null

	if resource is GDScript:
		var instance = resource.new()
		if instance is Node:
			add_child(instance)
		_instances[name1] = instance
		return instance

	if resource is PackedScene:
		var scene_instance = resource.instantiate()
		if scene_instance is Node:
			add_child(scene_instance)
		_instances[name1] = scene_instance
		return scene_instance

	_instances[name1] = resource
	return resource

func _load_resource(path: String):
	if not ResourceLoader.exists(path):
		push_error("[Global] 资源不存在: %s" % path)
		return null
	var resource = ResourceLoader.load(path)
	if resource == null:
		push_error("[Global] 资源加载失败: %s" % path)
	return resource
