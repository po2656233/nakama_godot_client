extends SceneTree

## 场景可加载性检查：逐个 ResourceLoader.load 所有 .tscn，暴露断掉的 ext_resource / 脚本。
##
## 用法：godot --headless --path . --script res://tools/validate_scenes.gd
## 退出码：0 全部可加载；1 存在失败项。

const SKIP_DIRS := [".git", ".godot", ".vscode", "addons", "gdprotobuf", "refactor"]

var _paths: Array[String] = []
var _failed: Array[String] = []
var _done := false

func _init() -> void:
	_run.call_deferred()
	_guard.call_deferred()

func _run() -> void:
	await process_frame
	_walk("res://")
	_paths.sort()
	for path in _paths:
		var res: Resource = ResourceLoader.load(path)
		if res == null or not (res is PackedScene):
			_failed.append(path)
	print("\n===== 场景校验：%d 个，失败 %d 个 =====" % [_paths.size(), _failed.size()])
	for path in _failed:
		print("FAIL: ", path)
	_done = true
	quit(1 if _failed.size() > 0 else 0)

func _walk(dir_path: String) -> void:
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
			if not SKIP_DIRS.has(entry):
				_walk(full)
		elif entry.ends_with(".tscn"):
			_paths.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

## 防止脚本异常导致进程不退出。
func _guard() -> void:
	await create_timer(60.0).timeout
	if _done:
		return
	_done = true
	print("FAIL: 场景校验超时（60s），已检查 %d / %d" % [_paths.size(), _paths.size()])
	quit(1)
