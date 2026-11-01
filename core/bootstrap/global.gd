extends Node

## 模块：全局服务门面（autoload: Global）—— PROMPT_REFACTOR 阶段 3 拆解后
## 职责：只做门面，三件事分别委托给：
##   - ServiceCatalog：从 core/bootstrap/global_config.cfg 读取“服务名 -> 脚本路径”；
##   - ServiceContainer：懒加载 / 缓存 / 把 Node 服务挂到本节点下；
##   - 本文件：暴露 has_global/get_global/set_global/list_services 的稳定 API。
## 说明：不再在 Global 里堆配置表、资源加载与实例化逻辑（消灭上帝对象）。

const ServiceCatalogScript := preload("res://core/bootstrap/service_catalog.gd")
const ServiceContainerScript := preload("res://core/bootstrap/service_container.gd")

var _catalog = null
var _container = null
var _paths: Dictionary = {}
var _registry_loaded := false

func _ready() -> void:
	_ensure_registry()

## 检查服务是否注册（不会实例化）。
func has_global(service_name: String) -> bool:
	_ensure_registry()
	return _paths.has(service_name) or _container.has_instance(service_name)

## 获取服务；首次访问时实例化。
func get_global(service_name: String) -> Variant:
	return _get(service_name)

## 主动注册/覆盖一个服务实例（测试或运行时扩展用）。
func set_global(service_name: String, value: Variant) -> void:
	_ensure_container()
	_container.set_instance(service_name, value)

func list_services() -> Array[String]:
	_ensure_registry()
	var names: Array[String] = []
	for name1 in _paths.keys():
		names.append(str(name1))
	names.sort()
	return names

## 已实例化的服务名（调试用）。
func list_instances() -> Array[String]:
	_ensure_container()
	return _container.instance_names()

# ---------------------------------------------------------------------
# 门面转发
# ---------------------------------------------------------------------

func _ensure_catalog() -> void:
	if _catalog == null:
		_catalog = ServiceCatalogScript.new()

func _ensure_container() -> void:
	if _container == null:
		_container = ServiceContainerScript.new()

func _ensure_registry() -> void:
	if _registry_loaded:
		return
	_registry_loaded = true
	_ensure_catalog()
	_ensure_container()
	_paths = _catalog.load_paths()

## 通过 Global.Xxx 访问时触发。
func _get(property: StringName) -> Variant:
	var service_name := str(property)
	_ensure_registry()
	if not _paths.has(service_name) and not _container.has_instance(service_name):
		push_error("[Global] 未注册的服务: %s（请检查 global_config.cfg）" % service_name)
		return null
	if _container.has_instance(service_name):
		return _container.resolve(service_name, str(_paths.get(service_name, "")), self)
	return _container.resolve(service_name, str(_paths[service_name]), self)
