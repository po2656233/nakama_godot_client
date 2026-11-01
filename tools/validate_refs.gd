extends SceneTree

## 引用完整性检查：扫描全仓库文本里的 res:// 字面量，报告悬空引用。
##
## 用法：
##   godot --headless --path . --script res://tools/validate_refs.gd
##   godot --headless --path . --script res://tools/validate_refs.gd -- --update-baseline
##
## 退出码：0 没有“新增”悬空；1 存在新增悬空。
## 基线机制：refs_baseline.json 记录重构前就存在、暂不处理的历史悬空，只对新增悬空报警。

const BASELINE_PATH := "res://tools/refs_baseline.json"
const SKIP_DIRS := [".git", ".godot", ".vscode"]
const TEXT_EXTS := [
	"gd", "tscn", "tres", "res", "cfg", "godot", "import",
	"gdshader", "shader", "json", "py", "bat", "sh", "txt", "csv", "yml", "yaml",
]

var _update := false
var _scanned := 0
var _missing: Dictionary = {}      # path -> Array[String] sources
var _known: Dictionary = {}        # path -> true
var _quoted_re: RegEx
var _bare_re: RegEx

func _init() -> void:
	_update = OS.get_cmdline_user_args().has("--update-baseline")

	_quoted_re = RegEx.new()
	_quoted_re.compile('"res://[^"\r\n]*"')
	_bare_re = RegEx.new()
	_bare_re.compile("res://([^\\s\"'<>|*?\\r\\n\\t]+)")

	_known = _load_baseline()
	_walk("res://")

	var new_missing: Array[String] = []
	for path in _missing.keys():
		if not _known.has(path):
			new_missing.append(str(path))
	new_missing.sort()

	if _update:
		_write_baseline()
		quit(0)
		return

	var fixed: Array[String] = []
	for path in _known.keys():
		if not _missing.has(path):
			fixed.append(str(path))
	fixed.sort()

	print("[validate_refs] 扫描 %d 个文本文件；悬空 %d 个（新增 %d，基线残留 %d）" %
		[_scanned, _missing.size(), new_missing.size(), _missing.size() - new_missing.size()])

	if fixed.size() > 0:
		print("[validate_refs] 以下基线项已恢复（可从基线移除）：")
		for path in fixed:
			print("  FIXED ", path)

	if new_missing.is_empty():
		print("[validate_refs] OK：没有新增悬空引用")
		quit(0)
		return

	print("[validate_refs] 新增悬空引用 %d 个：" % new_missing.size())
	for path in new_missing:
		print("  MISSING ", path)
		for src in _missing[path]:
			print("      <- ", src)
	quit(1)

# ---------------------------------------------------------------- 基线

func _load_baseline() -> Dictionary:
	var result: Dictionary = {}
	if not FileAccess.file_exists(BASELINE_PATH):
		return result
	var file := FileAccess.open(BASELINE_PATH, FileAccess.READ)
	if file == null:
		return result
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.has("missing") and parsed["missing"] is Dictionary:
		for key in parsed["missing"]:
			result[str(key)] = true
	return result

func _write_baseline() -> void:
	var missing_map := {}
	for path in _missing.keys():
		missing_map[path] = _missing[path]
	var file := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[validate_refs] 无法写入基线: %s" % BASELINE_PATH)
		return
	file.store_string(JSON.stringify({"missing": missing_map}, "    "))
	file.close()
	print("[validate_refs] 基线已更新: %s（%d 项）" % [BASELINE_PATH, _missing.size()])

# ---------------------------------------------------------------- 扫描

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
			_check_file(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _check_file(path: String) -> void:
	if not TEXT_EXTS.has(path.get_extension().to_lower()):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_scanned += 1

	var refs: Dictionary = {}
	# 1) 引号内的完整路径（允许空格）
	var masked := text
	for m in _quoted_re.search_all(text):
		var whole := m.get_string()
		refs[whole.substr(1, whole.length() - 2)] = true
		var blank := ""
		for _i in range(whole.length()):
			blank += " "
		masked = masked.substr(0, m.get_start()) + blank + masked.substr(m.get_end())
	# 2) 引号外的裸路径（用等长空白覆盖引号段，避免把带空格路径截断）
	for m in _bare_re.search_all(masked):
		refs["res://" + _trim_ref(m.get_string(1))] = true

	for ref in refs.keys():
		var p := str(ref)
		if p.is_empty() or p == "res://":
			continue
		# res:// 后面必须是合法路径起始字符，避免把注释里的 “res://，...” 当成引用
		var tail := p.substr(6)
		if tail.is_empty():
			continue
		var alnum := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_."
		if not alnum.contains(tail.substr(0, 1)):
			continue
		if p.contains("%") or p.contains("{") or p.contains("$"):
			continue
		if p.contains("(") or p.contains(")") or p.contains("["):
			continue
		if p.begins_with("res://.godot/"):
			continue
		if FileAccess.file_exists(p) or DirAccess.open(p) != null:
			continue
		if not _missing.has(p):
			_missing[p] = []
		var sources: Array = _missing[p]
		if not sources.has(path):
			sources.append(path)

func _trim_ref(value: String) -> String:
	var result := value
	var trailing := [")", "]", "}", ",", ";", ">", ".", ":", "\\"]
	var changed := true
	while changed and result.length() > 0:
		changed = false
		for t in trailing:
			if result.ends_with(t):
				result = result.substr(0, result.length() - 1)
				changed = true
	return result
