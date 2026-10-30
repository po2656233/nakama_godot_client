extends Node

## 模块：子游戏注册表（Global.GameRegistry）
## 职责：
##   1. 装载内置游戏清单（GameCatalog）；
##   2. 支持运行时注册下载/外部游戏；
##   3. 对外提供 key/别名 -> GameDescriptor 的唯一查询入口。
## 依赖：仅依赖 GameCatalog / GameDescriptor，不依赖场景树和网络。
## 对外：register() / register_external() / find() / has() / get_scene_path() / all() / validate()。

signal changed

const EXTERNAL_SCENE_ROOT := "res://scenes/game"

var _games: Dictionary = {}      # key -> GameDescriptor
var _aliases: Dictionary = {}    # alias -> key

func _ready() -> void:
	_load_builtin()
	discover_external_games()

## 返回所有内置游戏描述（按 order/key 排序）。
func all() -> Array[GameDescriptor]:
	var result: Array[GameDescriptor] = []
	for descriptor in _games.values():
		result.append(descriptor)
	result.sort_custom(_sort_descriptors)
	return result

## 返回所有已注册游戏的 key。
func keys() -> Array[String]:
	var result: Array[String] = []
	for key in _games.keys():
		result.append(str(key))
	result.sort()
	return result

func count() -> int:
	return _games.size()

func has(name: String) -> bool:
	return find(name) != null

## 按 key 或别名查找；找不到返回 null（调用方负责提示）。
func find(name: String) -> GameDescriptor:
	var token := str(name).strip_edges().to_lower()
	if token.is_empty():
		return null
	if _games.has(token):
		return _games[token]
	var aliased_key: String = _aliases.get(token, "")
	if not aliased_key.is_empty():
		return _games.get(aliased_key)
	return null

func get_scene_path(name: String) -> String:
	var descriptor := find(name)
	return descriptor.scene_path if descriptor != null else ""

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
	if old != null and data.get("source", "") == "":
		descriptor.source = old.source

	_games[descriptor.key] = descriptor
	for alias in descriptor.aliases:
		var owner: String = _aliases.get(alias, "")
		if not owner.is_empty() and owner != descriptor.key:
			push_warning("[GameRegistry] 别名冲突: %s 已属于 %s" % [alias, owner])
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

func unregister(name: String) -> bool:
	var descriptor := find(name)
	if descriptor == null:
		return false
	_games.erase(descriptor.key)
	for alias in _aliases.keys():
		if _aliases[alias] == descriptor.key:
			_aliases.erase(alias)
	changed.emit()
	return true

## 根据场景路径反查游戏 key（SceneMgr 用来识别当前运行的是哪个游戏）。
func get_key_by_scene(scene_path: String) -> String:
	for descriptor in _games.values():
		if descriptor.scene_path == scene_path:
			return descriptor.key
	return ""

## 校验清单：返回问题列表，空数组表示全部可用。供启动自检/测试使用。
func validate() -> Array[String]:
	var errors: Array[String] = []
	for descriptor in all():
		if not descriptor.scene_exists():
			errors.append("%s: 场景不存在 %s" % [descriptor.key, descriptor.scene_path])
		if descriptor.max_players < 1:
			errors.append("%s: max_players 必须 >= 1" % descriptor.key)
	return errors

## 扫描 res://scenes/game/<key>/<key>.tscn 形式的外部游戏并注册。
## 只认“目录名 == 场景名”的约定，避免把游戏内部子场景误注册成游戏。
func discover_external_games() -> void:
	_scan_game_dir(EXTERNAL_SCENE_ROOT)

func _load_builtin() -> void:
	for entry in GameCatalog.BUILTIN:
		register(entry, false)

func _scan_game_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_game_dir(full_path)
		elif entry.ends_with(".tscn") and entry.get_basename() == dir_path.get_file():
			# 目录名 == 场景名，例如 scenes/game/space_run/space_run.tscn
			var key := entry.get_basename()
			if not has(key):
				register_external(key, full_path, {"title": key})
		entry = dir.get_next()

	dir.list_dir_end()

func _sort_descriptors(a: GameDescriptor, b: GameDescriptor) -> bool:
	if a.order == b.order:
		return a.key < b.key
	return a.order < b.order
