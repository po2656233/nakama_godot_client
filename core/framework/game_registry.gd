extends Node

## 模块：子游戏注册表（Global.GameRegistry）
## 职责：
##   1. 扫描 res://games/<key>/game_meta.tres（内置插件）与 user://games/<key>/game_meta.tres（下载插件）；
##   2. 为每个插件建立 key/别名索引；
##   3. 对外提供 key/别名 -> GameDescriptor 的唯一查询入口。
## 说明：新增/删除子游戏只需要增删 games/<key>/ 目录，不再需要改框架代码。
## 依赖：GameMeta / GameDescriptor，不依赖场景树与网络。
## 对外：discover_builtin() / discover_external() / register() / register_external() /
##       find() / has() / get_scene_path() / all() / validate()。

signal changed

const BUILTIN_ROOT := "res://games"
const EXTERNAL_ROOT := "user://games"
const META_FILE := "game_meta.tres"
const ENTRY_FILE := "entry.tscn"
## 模板目录不是插件，扫描时跳过（复制出去改名后才会被注册）
const IGNORED_DIRS := ["template"]

var _games: Dictionary = {}      # key -> GameDescriptor
var _aliases: Dictionary = {}    # alias -> key

func _ready() -> void:
	discover_builtin()
	discover_external()

# ---------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------

## 返回所有已注册游戏（按 order/key 排序）。
func all() -> Array[GameDescriptor]:
	var result: Array[GameDescriptor] = []
	for descriptor in _games.values():
		result.append(descriptor)
	result.sort_custom(_sort_descriptors)
	return result

func keys() -> Array[String]:
	var result: Array[String] = []
	for key in _games.keys():
		result.append(str(key))
	result.sort()
	return result

func count() -> int:
	return _games.size()

func has(name1: String) -> bool:
	return find(name1) != null

## 按 key 或别名查找；找不到返回 null（调用方负责提示）。
func find(name1: String) -> GameDescriptor:
	var token := str(name1).strip_edges().to_lower()
	if token.is_empty():
		return null
	if _games.has(token):
		return _games[token]
	var aliased_key: String = _aliases.get(token, "")
	if not aliased_key.is_empty():
		return _games.get(aliased_key)
	return null

func get_scene_path(name1: String) -> String:
	var descriptor := find(name1)
	return descriptor.scene_path if descriptor != null else ""

## 根据场景路径反查游戏 key（SceneMgr 用来识别当前运行的是哪个游戏）。
func get_key_by_scene(scene_path: String) -> String:
	for descriptor in _games.values():
		if descriptor.scene_path == scene_path:
			return descriptor.key
	return ""

# ---------------------------------------------------------------------
# 注册
# ---------------------------------------------------------------------

## 注册/更新一个游戏。overwrite=false 时已存在则原样返回。
func register(data: Dictionary, overwrite: bool = true) -> GameDescriptor:
	var descriptor := GameDescriptor.new(data)
	if not descriptor.is_valid():
		push_error("[GameRegistry] 无效的游戏描述: %s" % str(data))
		return null

	if _games.has(descriptor.key) and not overwrite:
		return _games[descriptor.key]

	# 保留已有别名，避免下载更新时把内置别名冲掉
	var old: GameDescriptor = _games.get(descriptor.key)
	if old != null and descriptor.aliases.is_empty():
		descriptor.aliases = old.aliases
	if old != null and str(data.get("source", "")) == "":
		descriptor.source = old.source

	_games[descriptor.key] = descriptor
	for alias in descriptor.aliases:
		var owner1: String = _aliases.get(alias, "")
		if not owner1.is_empty() and owner1 != descriptor.key:
			push_warning("[GameRegistry] 别名冲突: %s 已属于 %s" % [alias, owner1])
			continue
		_aliases[alias] = descriptor.key

	changed.emit()
	return descriptor

## 注册/覆盖一个外部（下载）游戏；key 必须与服务端 en_name 一致。
func register_external(key: String, scene_path: String, meta: Dictionary = {}) -> GameDescriptor:
	var data := meta.duplicate(true)
	data["key"] = key
	data["scene"] = scene_path
	data["source"] = "external"
	if not data.has("title"):
		data["title"] = key
	return register(data, true)

## 用 GameMeta 注册一个插件。
func register_meta(meta: Resource, source: String = "builtin", overwrite: bool = true) -> GameDescriptor:
	if meta == null or not meta.has_method("is_valid") or not meta.call("is_valid"):
		push_warning("[GameRegistry] 跳过无效 game_meta: %s" % str(meta))
		return null
	if not meta.has_method("to_descriptor_dict"):
		push_error("[GameRegistry] game_meta 缺少 to_descriptor_dict(): %s" % str(meta))
		return null
	return register(meta.call("to_descriptor_dict", source), overwrite)

func unregister(name1: String) -> bool:
	var descriptor := find(name1)
	if descriptor == null:
		return false
	_games.erase(descriptor.key)
	for alias in _aliases.keys():
		if _aliases[alias] == descriptor.key:
			_aliases.erase(alias)
	changed.emit()
	return true

# ---------------------------------------------------------------------
# 插件发现
# ---------------------------------------------------------------------

## 扫描内置插件目录：res://games/<key>/game_meta.tres。
func discover_builtin() -> void:
	_scan_plugin_root(BUILTIN_ROOT, "builtin")

## 扫描下载/热更新插件目录：user://games/<key>/game_meta.tres（无 meta 时退回 entry.tscn）。
func discover_external() -> void:
	_scan_plugin_root(EXTERNAL_ROOT, "external")

## 兼容旧调用名。
func discover_external_games() -> void:
	discover_external()

## 校验清单：返回问题列表，空数组表示全部可用。供启动自检/测试使用。
func validate() -> Array[String]:
	var errors: Array[String] = []
	for descriptor in all():
		if not descriptor.scene_exists():
			errors.append("%s: 场景不存在 %s" % [descriptor.key, descriptor.scene_path])
		if descriptor.max_players < 1:
			errors.append("%s: max_players 必须 >= 1" % descriptor.key)
	return errors

# ---------------------------------------------------------------------
# 内部
# ---------------------------------------------------------------------

func _scan_plugin_root(root: String, source: String) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		if dir.current_is_dir():
			if not IGNORED_DIRS.has(entry):
				_try_register_plugin(root.path_join(entry), source)
		entry = dir.get_next()
	dir.list_dir_end()

func _try_register_plugin(plugin_dir: String, source: String) -> void:
	var meta_path := plugin_dir.path_join(META_FILE)
	if FileAccess.file_exists(meta_path):
		var meta: Resource = ResourceLoader.load(meta_path)
		if meta != null:
			register_meta(meta, source, source == "external")
			return
		push_error("[GameRegistry] game_meta 加载失败: %s" % meta_path)

	# 没有 meta 的旧插件：目录名 == key，入口固定 entry.tscn
	var entry_path := plugin_dir.path_join(ENTRY_FILE)
	if FileAccess.file_exists(entry_path):
		var key := plugin_dir.get_file()
		if not has(key):
			push_warning("[GameRegistry] %s 缺少 game_meta.tres，按目录名注册" % plugin_dir)
			register_external(key, entry_path, {"title": key})
	else:
		push_warning("[GameRegistry] %s 不是有效插件目录（缺少 %s）" % [plugin_dir, META_FILE])

func _sort_descriptors(a: GameDescriptor, b: GameDescriptor) -> bool:
	if a.order == b.order:
		return a.key < b.key
	return a.order < b.order
