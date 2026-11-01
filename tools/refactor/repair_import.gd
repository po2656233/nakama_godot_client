extends SceneTree

## 一次性修复工具：修补被旧 PowerShell 迁移脚本污染的 .import 文件。
##
## 污染形态：脚本在“引用解析”时把 `res://` 前缀插到了每个 token 前面，
## 例如 `[remap]` -> `res://[remap]`、`importer="texture"` -> `res://importer="res://res://texture"`。
##
## 修复规则：
##   1. 折叠重复的 `res://res://` -> `res://`；
##   2. 只保留后面紧跟 `.godot/`、`assets/`、`shared/`、`games/` 的 `res://`，其余前缀删除。
##
## 用法：godot --headless --path . --script res://tools/refactor/repair_import.gd [-- --dry-run]

const KEEP_PREFIXES := [".godot/", "assets/", "shared/", "games/", "core/", "lobby/"]

var _dry := false
var _repaired := 0
var _scanned := 0

func _init() -> void:
	_dry = OS.get_cmdline_user_args().has("--dry-run")
	_walk("res://")
	print("[repair_import] 扫描 %d 个 .import，修复 %d 个%s" % [_scanned, _repaired, "（dry-run）" if _dry else ""])
	quit(0)

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
			if entry != "addons" and entry != "gdprotobuf":
				_walk(full)
		elif entry.ends_with(".import"):
			_repair(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _repair(path: String) -> void:
	_scanned += 1
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var original := file.get_as_text()
	file.close()
	if not original.begins_with("res://") and not original.contains("res://res://"):
		return

	var text := original
	while text.contains("res://res://"):
		text = text.replace("res://res://", "res://")

	var out := ""
	var i := 0
	while i < text.length():
		if text.substr(i, 6) == "res://":
			var rest := text.substr(i + 6)
			var keep := false
			for prefix in KEEP_PREFIXES:
				if rest.begins_with(prefix):
					keep = true
					break
			if keep:
				out += "res://"
			i += 6
		else:
			out += text[i]
			i += 1

	if out == original:
		return
	_repaired += 1
	print("  FIX ", path)
	if _dry:
		return
	var writer := FileAccess.open(path, FileAccess.WRITE)
	if writer == null:
		push_error("[repair_import] 无法写入: %s" % path)
		return
	writer.store_string(out)
	writer.close()
