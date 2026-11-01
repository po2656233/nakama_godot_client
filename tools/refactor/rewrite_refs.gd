extends SceneTree

## 迁移工具（第 2 步）：按映射表重写全项目的 res:// 引用。
##
## 设计要点：
##   - 用 GDScript 读写，天然 UTF-8，不会像 PowerShell 5.1 那样按 ANSI 破坏中文；
##   - 用“解析器”逐条匹配，而不是整串替换，才能正确处理 exclude（被排除的子树不重写）；
##   - 目录项与文件项都参与，最长前缀优先；
##   - 只改文本资源（.gd/.tscn/.tres/.import/project.godot ...），跳过 addons/gdprotobuf。
##
## 用法：
##   godot --headless --path . --script res://tools/refactor/rewrite_refs.gd -- --map=res://tools/refactor/maps/p1_shared.json
##   ... --dry-run
##
## 映射表格式：
##   { "name": "...", "moves": [ { "from": "a/b", "to": "c/d", "exclude": ["x"] } ] }

const SKIP_DIRS := [".git", ".godot", ".vscode", "addons", "gdprotobuf"]
const TEXT_EXTS := [
	"gd", "tscn", "tres", "res", "cfg", "godot", "import",
	"gdshader", "shader", "md", "json", "py", "ps1", "bat", "sh",
	"txt", "csv", "yml", "yaml",
]

var _pairs: Array[Dictionary] = []
var _protected: Dictionary = {}
var _quoted_re: RegEx
var _bare_re: RegEx

var _dry_run := false
var _changed_files := 0
var _changed_refs := 0
var _scanned := 0
var _skip_self := 'res://tools/refactor/'
var _samples: Array[String] = []

func _init() -> void:
	var map_path := _arg_value("--map")
	_dry_run = OS.get_cmdline_user_args().has("--dry-run")
	if map_path.is_empty():
		push_error("[rewrite_refs] 缺少 --map=... 参数")
		quit(2)
		return

	_quoted_re = RegEx.new()
	_quoted_re.compile('"res://([^"]*)"')
	_bare_re = RegEx.new()
	_bare_re.compile("res://([^\\s\"'<>|*?\\r\\n\\t]+)")

	if not _load_map(map_path):
		quit(2)
		return

	print("[rewrite_refs] 映射 %s：%d 项（%s）" % [map_path, _pairs.size(), "dry-run" if _dry_run else "apply"])
	_walk("res://")

	print("[rewrite_refs] 扫描 %d 个文本文件，修改 %d 个文件，重写 %d 处引用" % [_scanned, _changed_files, _changed_refs])
	for sample in _samples:
		print("  ", sample)
	quit(0)

# ---------------------------------------------------------------- 参数 / 映射

func _arg_value(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix + "="):
			return arg.substr(prefix.length() + 1)
	return ""

func _load_map(map_path: String) -> bool:
	var file := FileAccess.open(map_path, FileAccess.READ)
	if file == null:
		push_error("[rewrite_refs] 无法读取映射表: %s" % map_path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		push_error("[rewrite_refs] 映射表格式错误: %s" % map_path)
		return false

	var moves: Array = parsed.get("moves", [])
	for move in moves:
		if not move is Dictionary:
			continue
		var from := str(move.get("from", "")).replace("\\", "/").trim_prefix("/").trim_suffix("/")
		var to := str(move.get("to", "")).replace("\\", "/").trim_prefix("/").trim_suffix("/")
		if from.is_empty() or to.is_empty():
			continue
		_pairs.append({"from": from, "to": to})
		if move.has("exclude") and move["exclude"] is Array:
			var excluded: Array[String] = []
			for item in move["exclude"]:
				excluded.append(str(item).trim_suffix("/"))
			_protected[from] = excluded

	# 最长前缀优先：文件项先于其父目录项命中
	_pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["from"]).length() > str(b["from"]).length())
	return _pairs.size() > 0

# ---------------------------------------------------------------- 引用解析

func _resolve_path(path: String) -> String:
	for pair in _pairs:
		var key: String = pair["from"]
		if path == key:
			return str(pair["to"])
		if path.begins_with(key + "/"):
			var sub := path.substr(key.length() + 1)
			if _protected.has(key):
				for ex in _protected[key]:
					if sub == str(ex) or sub.begins_with(str(ex) + "/"):
						return path
			return str(pair["to"]) + "/" + sub
	return path

# ---------------------------------------------------------------- 文件遍历

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
		else:
			_process_file(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _process_file(path: String) -> void:
	if path.begins_with(_skip_self):
		return
	var ext := path.get_extension().to_lower()
	if not TEXT_EXTS.has(ext):
		return
	_scanned += 1

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var original := file.get_as_text()
	file.close()

	var text := _replace_quoted(original)
	text = _replace_bare(text)
	if text == original:
		return

	_changed_files += 1
	if _samples.size() < 12:
		_samples.append(path)
	if _dry_run:
		return

	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		push_error("[rewrite_refs] 写入失败: %s" % path)
		return
	out.store_string(text)
	out.close()

# ---------------------------------------------------------------- 替换

func _replace_quoted(text: String) -> String:
	var matches := _quoted_re.search_all(text)
	if matches.is_empty():
		return text
	var parts := PackedStringArray()
	var cursor := 0
	for m in matches:
		parts.append(text.substr(cursor, m.get_start() - cursor))
		var inner := m.get_string(1)
		var resolved := _resolve_path(inner)
		if resolved != inner:
			_changed_refs += 1
		parts.append('"res://' + resolved + '"')
		cursor = m.get_end()
	parts.append(text.substr(cursor))
	return "".join(parts)

func _replace_bare(text: String) -> String:
	var matches := _bare_re.search_all(text)
	if matches.is_empty():
		return text
	var parts := PackedStringArray()
	var cursor := 0
	for m in matches:
		parts.append(text.substr(cursor, m.get_start() - cursor))
		var inner := m.get_string(1)
		var resolved := _resolve_path(inner)
		if resolved != inner:
			_changed_refs += 1
		parts.append("res://" + resolved)
		cursor = m.get_end()
	parts.append(text.substr(cursor))
	return "".join(parts)
