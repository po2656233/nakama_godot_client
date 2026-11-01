extends SceneTree

## 开发辅助：批量加载业务脚本，暴露解析/编译错误。
## 用法：godot --headless --path . --script res://tools/validate_scripts.gd
##
## 扫描整个 res://，跳过第三方/生成代码（addons / gdprotobuf）与资源目录。

const SKIP_DIRS := [".git", ".godot", ".vscode", "addons", "gdprotobuf", "assets", "docs", "certs", "android", "sprites"]

var _failed: Array[String] = []
var _total := 0

func _init() -> void:
	_validate.call_deferred()

func _validate() -> void:
	# 等待自动加载（Global/Util/Errors）就绪，脚本里的全局标识符才能解析。
	await process_frame
	await process_frame
	_scan_dirs("res://")
	print("\n===== 脚本校验完成：%d 个，失败 %d 个 =====" % [_total, _failed.size()])
	for path in _failed:
		print("FAIL: ", path)
	quit(1 if _failed.size() > 0 else 0)

func _scan_dirs(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not SKIP_DIRS.has(name):
				_scan_dirs(full)
		elif name.ends_with(".gd"):
			_total += 1
			var script := load(full)
			# 解析失败的脚本会返回 null 并打印 SCRIPT ERROR。
			if script == null:
				_failed.append(full)
		name = dir.get_next()
	dir.list_dir_end()
