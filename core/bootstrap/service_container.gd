class_name ServiceContainer
extends RefCounted

## 模块：全局服务容器（Global 拆解 ②）
## 职责：
##   1. 懒加载并缓存服务实例（GDScript / PackedScene / 普通 Resource）；
##   2. 把 Node 服务挂到宿主节点下，保证生命周期与 Global 一致；
##   3. 不读取配置、不依赖场景树（宿主由调用方传入）。
## 说明：Global 只持有本类，所有实例化逻辑集中于此，避免上帝对象。

var _instances: Dictionary = {}

## 是否已经实例化（不触发加载）。
func has_instance(service_name: String) -> bool:
	return _instances.has(service_name)

## 主动登记/覆盖实例（测试或运行时扩展用）。
func set_instance(service_name: String, value: Variant) -> void:
	_instances[service_name] = value

func get_instance(service_name: String) -> Variant:
	return _instances.get(service_name)

## 已实例化的服务名列表。
func instance_names() -> Array[String]:
	var names: Array[String] = []
	for name1 in _instances.keys():
		names.append(str(name1))
	names.sort()
	return names

## 取服务；不存在实例且给了路径时创建并缓存。
## host 用于挂载 Node 实例（一般传 Global 节点）。
func resolve(service_name: String, path: String, host: Node) -> Variant:
	if _instances.has(service_name):
		return _instances[service_name]
	if path.is_empty():
		return null

	var resource: Resource = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
	if resource == null:
		push_error("[ServiceContainer] 资源加载失败: %s" % path)
		return null

	var instance: Variant = null
	if resource is GDScript:
		instance = (resource as GDScript).new()
	elif resource is PackedScene:
		instance = (resource as PackedScene).instantiate()
	else:
		instance = resource

	if instance is Node and host != null:
		host.add_child(instance as Node)
	_instances[service_name] = instance
	return instance

## 清空缓存（测试用；不会主动 free 节点，由宿主释放）。
func clear() -> void:
	_instances.clear()
