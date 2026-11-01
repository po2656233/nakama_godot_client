extends Control

## 模块：加载页
## 职责：
##   1. 登录/切页时的进度展示；
##   2. 子游戏资源检查、下载、解压、注册到 GameRegistry；
##   3. 完成后交给 GameLauncher 启动，不再自己实例化游戏场景。
## 依赖：Global.SignalMgr / Global.SceneMgr / Global.GameRegistry / Global.GameLauncher。
## 对外：Show() / Hide() / set_next_scene() / set_progress()。

@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var progress_label: Label = $MarginContainer/VBoxContainer/ProgressLabel
@onready var board = $board

const GAME_PACK := ".zip"
const LOCAL_ROOT := "user://"
const RES_ROOT := "res://"
const RESOURCE_URL := "http://60.205.90.152:5567/"
## 下载游戏解压根目录：压缩包内应包含 games/<key>/entry.tscn 与 games/<key>/game_meta.tres。
## 注意：当前仍写入 res://（导出包只读），正式发布前应改为 user:// + PCK，见 docs/PLUGIN_REFACTOR_PLAN.md。
const GAME_SCENE_ROOT := "res://games/"

enum LoadType {
	PROGRESS,
	GAME,
}

var next_scene := "home"
var load_type: LoadType = LoadType.PROGRESS
var progress := 0.0
var target_progress := 0.0

var game_key := ""
var game_zip_path := ""
var url_path := ""
var scene_files := PackedStringArray()

var _http: HTTPRequest
var _is_downloading := false
var _is_closing := false

func _ready() -> void:
	set_process(false)
	_reset()

	_http = HTTPRequest.new()
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_http_request_completed)

	Global.SignalMgr.LoadingSIG.connect(_on_loading)
	Global.SignalMgr.LoadingGameSIG.connect(_on_load_game)

func _process(delta: float) -> void:
	if _is_downloading and _http != null:
		var total_size := _http.get_body_size()
		if total_size > 0:
			progress = clampf(float(_http.get_downloaded_bytes()) / float(total_size) * 99.0, 1.0, 99.0)

	if target_progress <= -1.0:
		reback()
		return

	if progress < target_progress:
		progress = minf(progress + delta * 100.0, target_progress)
	progress_bar.value = progress
	_update_progress_label(progress)

	if progress >= 100.0:
		close_loading()

# ---------------------------------------------------------------------
# 对外接口
# ---------------------------------------------------------------------

func Show() -> void:
	_reset()
	show()
	Global.SettingsMgr.settings_toggle.emit()

func Hide() -> void:
	hide()
	Global.SettingsMgr.settings_toggle.emit()

func set_next_scene(scene_name: String) -> void:
	next_scene = scene_name

## 设置目标进度（0~100，-1 表示失败）。
func set_progress(value: float) -> void:
	set_process(true)
	target_progress = clampf(value, -5.0, 100.0)
	if target_progress <= -1.0:
		progress = -1.0

func reback() -> void:
	if _is_closing:
		return
	_is_closing = true
	Global.SceneMgr.go_back()
	queue_free()

func close_loading() -> void:
	if _is_closing:
		return
	_is_closing = true
	set_process(false)
	await get_tree().create_timer(0.2).timeout

	match load_type:
		LoadType.GAME:
			# 走 SceneRouter：消费导航上下文（房间列表/游戏列表来源），退出时才能精准回退。
			var started := false
			var load_options := {
				"transition": "tile_reveal",
				"transition_time": 1.0,
			}
			if Global.has_global("SceneRouter"):
				started = Global.SceneRouter.enter_pending_game(game_key, load_options)
			else:
				started = Global.GameLauncher.start_game(game_key, load_options)
			if not started:
				_is_closing = false
				reback()
				return
		_:
			Global.SceneMgr.switch_to_scene(next_scene, "tile_reveal", 1.0)

	queue_free()

# ---------------------------------------------------------------------
# 进度与游戏资源
# ---------------------------------------------------------------------

func _on_loading(value: float) -> void:
	set_progress(value)

## 收到“加载游戏”信号：本地已有就直接启动，没有就下载。
func _on_load_game(game_id: int) -> void:
	var key := _resolve_game_key(game_id)
	if key.is_empty():
		_fail("游戏资源不存在...")
		return

	game_key = key
	load_type = LoadType.GAME
	next_scene = key

	if Global.SceneMgr.check_scene(key):
		Global.SignalMgr.LoadingSIG.emit(100)
		return

	_start_download()

func _resolve_game_key(game_id: int) -> String:
	var key := str(Global.OnlineGame.getGameEnName(game_id)).strip_edges().to_lower()
	if key.is_empty():
		key = str(game_id).strip_edges().to_lower()
	return key

func _start_download() -> void:
	game_zip_path = LOCAL_ROOT + game_key + GAME_PACK
	url_path = RESOURCE_URL + game_key + GAME_PACK
	_is_downloading = true
	Global.SignalMgr.LoadingSIG.emit(1)

	var err := _http.request(url_path)
	if err != OK:
		_fail("游戏资源请求失败...")
		push_error("[LoadingScreen] HTTP 请求失败: %s (%s)" % [url_path, err])

func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail("游戏资源下载失败...")
		push_error("[LoadingScreen] 下载失败: result=%s code=%s url=%s" % [result, response_code, url_path])
		return

	var file := FileAccess.open(game_zip_path, FileAccess.WRITE)
	if file == null:
		_fail("游戏资源保存失败...")
		return
	file.store_buffer(body)
	file.close()
	_extract_and_start()

## 解压 zip -> 找到主场景 -> 注册到 GameRegistry。
func _extract_and_start() -> void:
	var zip := ZIPReader.new()
	if zip.open(game_zip_path) != OK:
		_fail("游戏资源解压失败...")
		return

	scene_files.clear()
	for file_path in zip.get_files():
		_extract_file(file_path, zip.read_file(file_path))
	zip.close()

	var main_path := _pick_main_scene()
	if main_path.is_empty():
		main_path = GAME_SCENE_ROOT.path_join(game_key).path_join("entry.tscn")

	if not FileAccess.file_exists(main_path):
		_fail("缺乏主场景资源,游戏启动失败... " + main_path)
		return

	Global.GameRegistry.register_external(game_key, main_path)
	Global.SignalMgr.LoadingSIG.emit(100)

func _extract_file(file_path: String, data: PackedByteArray) -> void:
	# 禁止绝对路径与 ../，避免恶意 zip 覆盖工程/系统文件。
	var relative := file_path.replace("\\", "/").strip_edges()
	if relative.begins_with("res://"):
		relative = relative.trim_prefix("res://")
	if relative.is_empty() or relative.begins_with("/") or relative.contains(".."):
		push_warning("[LoadingScreen] 跳过不安全的压缩包路径: %s" % file_path)
		return

	var target := (RES_ROOT.path_join(relative)).simplify_path()
	if not target.begins_with(RES_ROOT):
		push_warning("[LoadingScreen] 跳过越界路径: %s" % file_path)
		return

	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		push_warning("[LoadingScreen] 写入失败: %s" % target)
		return
	file.store_buffer(data)
	file.close()

	if target.ends_with(".tscn"):
		scene_files.append(target)

## 优先入口场景 <key>/entry.tscn，其次 <key>/<key>.tscn（旧插件），最后第一个场景。
func _pick_main_scene() -> String:
	for path in scene_files:
		if path.get_file() == "entry.tscn" and path.get_base_dir().get_file() == game_key:
			return path
	for path in scene_files:
		if path.get_file().get_basename() == game_key:
			return path
	return scene_files[0] if scene_files.size() > 0 else ""

func _fail(message: String) -> void:
	_is_downloading = false
	push_warning("[LoadingScreen] " + message)
	Global.WindowPopup.show_dynamic(message)
	set_progress(-1)

func _update_progress_label(value: float) -> void:
	progress_label.text = "Loading... %d%%" % [round(value)]

func _reset() -> void:
	progress = 0.0
	target_progress = 0.0
	load_type = LoadType.PROGRESS
	game_key = ""
	game_zip_path = ""
	url_path = ""
	scene_files.clear()
	_is_downloading = false
	_is_closing = false
