extends SceneTree

## 子游戏插件契约校验（P4/P5 门禁）。
##
## 检查项：
##   1. 结构：games/<key>/ 必须含 game_meta.tres + entry.tscn；
##   2. 元数据：key == 目录名、entry_scene 指向本目录 entry.tscn 且存在、key 不重复；
##   3. 冒烟：entry.tscn 可加载并实例化；
##   4. 沙盒：games/**/*.gd 不得直接访问 Global.Online* / DataMgr / SceneMgr / WindowPopup / Shared，
##            不得引用其它子游戏目录（--strict-sandbox 时违规导致退出码 1）。
##
## 用法：
##   godot --headless --path . --script res://tools/validate_plugins.gd
##   godot --headless --path . --script res://tools/validate_plugins.gd -- --strict-sandbox
## 退出码：0 通过；1 结构/冒烟失败，或 strict 模式下存在沙盒违规。

const GAMES_ROOT := "res://games"
const META_FILE := "game_meta.tres"
const ENTRY_FILE := "entry.tscn"
const IGNORED_DIRS := ["template"]

## 子游戏不得直接访问任何 Global.* 服务（唯一入口是 GameBridge）。
const FORBIDDEN_TOKENS := [
	"Global.",
]

var _strict := false
var _errors: Array[String] = []
var _sandbox: Array[String] = []
var _checked := 0
var _keys: Dictionary = {}

func _init() -> void:
	_strict = OS.get_cmdline_user_args().has("--strict-sandbox")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var dir := DirAccess.open(GAMES_ROOT)
	if dir == null:
		push_error("[validate_plugins] 缺少 %s" % GAMES_ROOT)
		quit(1)
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with(".") and dir.current_is_dir() and not IGNORED_DIRS.has(entry):
			_check_plugin(entry)
		entry = dir.get_next()
	dir.list_dir_end()

	print("\n===== 插件校验：检查 %d 个，结构/冒烟失败 %d，沙盒违规 %d =====" %
		[_checked, _errors.size(), _sandbox.size()])
	for error in _errors:
		print("FAIL: ", error)
	for violation in _sandbox:
		print("SANDBOX: ", violation)

	var failed := _errors.size() > 0 or (_strict and _sandbox.size() > 0)
	quit(1 if failed else 0)

func _check_plugin(dir_name: String) -> void:
	_checked += 1
	var plugin_dir := GAMES_ROOT.path_join(dir_name)
	var meta_path := plugin_dir.path_join(META_FILE)
	var entry_path := plugin_dir.path_join(ENTRY_FILE)

	if not FileAccess.file_exists(meta_path):
		_errors.append("%s: 缺少 %s" % [dir_name, META_FILE])
		return
	if not FileAccess.file_exists(entry_path):
		_errors.append("%s: 缺少 %s" % [dir_name, ENTRY_FILE])
		return

	var meta: Resource = ResourceLoader.load(meta_path)
	if meta == null or not meta.has_method("is_valid"):
		_errors.append("%s: %s 不是 GameMeta" % [dir_name, META_FILE])
		return
	if not meta.call("is_valid"):
		_errors.append("%s: game_meta 无效（key/entry_scene 为空）" % dir_name)
		return

	var key := str(meta.get("key"))
	var entry_scene := str(meta.get("entry_scene"))
	if key != dir_name:
		_errors.append("%s: key(%s) 与目录名不一致" % [dir_name, key])
	if entry_scene != entry_path:
		_errors.append("%s: entry_scene(%s) 应为 %s" % [dir_name, entry_scene, entry_path])
	if not ResourceLoader.exists(entry_scene):
		_errors.append("%s: entry_scene 不存在: %s" % [dir_name, entry_scene])
	if _keys.has(key):
		_errors.append("%s: key 重复（已由 %s 使用）" % [dir_name, _keys[key]])
	_keys[key] = dir_name

	var packed: Resource = ResourceLoader.load(entry_path)
	if packed == null or not (packed is PackedScene):
		_errors.append("%s: entry.tscn 无法加载" % dir_name)
	else:
		var instance: Node = (packed as PackedScene).instantiate()
		if instance == null:
			_errors.append("%s: entry.tscn 实例化失败" % dir_name)
		else:
			instance.free()

	_lint_dir(plugin_dir, dir_name)

## 静态沙盒扫描：禁止子游戏直接触达框架网络/场景/窗口服务，或引用别的子游戏。
func _lint_dir(dir_path: String, owner_key: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if entry != "assets" and entry != "scenes":
				_lint_dir(full, owner_key)
		elif entry.ends_with(".gd"):
			_lint_file(full, owner_key)
		entry = dir.get_next()
	dir.list_dir_end()

func _lint_file(path: String, owner_key: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var line_no := 0
	for raw_line in text.split("\n"):
		line_no += 1
		var line := raw_line.strip_edges()
		if line.begins_with("#"):
			continue
		for token in FORBIDDEN_TOKENS:
			if line.contains(token):
				_sandbox.append("%s:%d 使用 %s" % [path, line_no, token])
		for other_dir in _list_other_plugins(owner_key):
			if line.contains("res://games/%s/" % other_dir):
				_sandbox.append("%s:%d 引用其它子游戏 %s" % [path, line_no, other_dir])

func _list_other_plugins(owner_key: String) -> Array[String]:
	var others: Array[String] = []
	var dir := DirAccess.open(GAMES_ROOT)
	if dir == null:
		return others
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with(".") and dir.current_is_dir() and entry != owner_key and not IGNORED_DIRS.has(entry):
			others.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return others
