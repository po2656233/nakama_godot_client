extends Control


@onready var progress_bar = $MarginContainer/VBoxContainer/ProgressBar
@onready var progress_label = $MarginContainer/VBoxContainer/ProgressLabel
@onready var board = $board
var progress: float = 0.0
var target_progress: float = 0.0
var current: float = 0.0

var next_scene: String = "home"

# 预加载按钮节点和 HTTPRequest 节点
const game_pack = ".zip"
const local_path = "user://"
const res_path = "res://"
const resource_url = "http://60.205.90.152:5567/"
const default_scene_path = "res://scenes/game/"
const default_script_path = "res://scripts/game/"
const default_assets_path = "res://assets/game/"

var game_name = "game_01"
var game_zip_path = ""
var url_path = ""
var http_request = HTTPRequest.new()
var scene_files = []
var is_http_request = false
var is_full = false
enum LOAD_TEPE{
	LOADING = 1,
	LOAD_GAME = 2
}

var load_type = LOAD_TEPE.LOADING

func _ready():
	# 初始化进度条
	init_data()
	progress_bar.value = 0
	update_progress_label(0)
	add_child(http_request)
	http_request.use_threads = true
	
	SignalMgr.LoadingSIG.connect(_on_loading)
	# 连接按钮的按下信号到加载函数
	SignalMgr.LoadingGameSIG.connect(_on_load_game)
	# 连接 HTTPRequest 的请求完成信号到处理函数
	http_request.request_completed.connect(_on_http_request_request_completed)
	
	# example_loading()

func _process(delta):
	if is_http_request:
		var total_size = http_request.get_body_size()
		var current_size = http_request.get_downloaded_bytes()
		print("下载进度:", total_size, " 已下载", current_size)
		if total_size > 0:
			progress = current_size / float(total_size) * 99

	# 平滑更新进度条
	if progress < target_progress:
		is_full = false
		progress = min(progress + delta * 100, target_progress)
	progress_bar.value = progress
	update_progress_label(progress)
	if progress == 100 and not is_full:
		is_full = true
		close_loading()
	elif progress <= -1.0:
		reback()
	pass

# ###############################初始化数据##########################################
func init_data():
	progress = 0.0
	target_progress = 0.0
	current = 0.0
	load_type = LOAD_TEPE.LOADING
	pass

func Show():
	init_data()
	show()
	SettingsMgr.settings_toggle.emit()

func Hide():
	hide()
	SettingsMgr.settings_toggle.emit()

func reback():
	SceneMgr.go_back()
	queue_free()
	pass

func close_loading():
	if load_type == LOAD_TEPE.LOADING:
		SceneMgr.switch_to_scene(next_scene, "tile_reveal", 1)
	elif load_type == LOAD_TEPE.LOAD_GAME:
		SceneMgr.ToGameScene(next_scene)
		await OnlineGame.sendToMatch(OnlineMatch.MatchState.LOADING_MAP_FINISH, "1")
	var timer = get_tree().create_timer(0.2)
	await timer.timeout
	queue_free()
	pass


func set_next_scene(scene_name: String):
	next_scene = scene_name
	pass

func set_progress(value: float):
	# 设置目标进度值（0-100）
	target_progress = clamp(value, -5, 100)
	pass

func update_progress_label(value: float):
	# 更新进度文本
	progress_label.text = "Loading... %d%%" % [round(value)]
	pass


# 加载进度
func _on_loading(value):
	set_progress(value)
	pass

###########################加载游戏资源##########################################

# 加载游戏资源
func _on_load_game(game_id):
	print("开始下载游戏资源：", game_id)
	# 发送 HTTP 请求下载资源
	var gameName = OnlineGame.getGameEnName(game_id)
	print("开始下载游戏资源：", gameName, " ID:", game_id)
	gameName = gameName.to_lower()
	if not SceneMgr.has_scene(gameName):
		reback()
		Global.PopupManager.show_dynamic("%s游戏正在招商中..."%[gameName])
		return
	game_name = gameName
	load_type = LOAD_TEPE.LOAD_GAME
	if SceneMgr.check_scene(game_name):
		set_next_scene(game_name)
		SignalMgr.LoadingSIG.emit(100)
		return
	SignalMgr.LoadingSIG.emit(1)
	is_http_request = true
	game_zip_path = local_path + game_name + game_pack
	url_path = resource_url + game_name + game_pack
	print("请求接口:", url_path, " 游戏路径:", SceneMgr.get_scene_path(game_name))
	var error = http_request.request(url_path)
	if error != OK:
		SignalMgr.LoadingSIG.emit(-1.0)
		Global.PopupManager.show_dynamic("游戏资源不足...")
		print("Failed to send HTTP request: ", error)

# 处理 HTTP 请求完成事件
func _on_http_request_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_http_request = false
	if response_code == 200:
		# 将下载的资源保存到本地
		var file = FileAccess.open(game_zip_path, FileAccess.WRITE)
		if file:
			file.store_buffer(body)
			file.close()
			# 加载本地保存的资源
			_load_local_resource()
			print("Resource downloaded and saved to: ", game_zip_path)
		else:
			print("Failed to save resource to local path")
			SignalMgr.LoadingSIG.emit(-1)
			Global.PopupManager.show_dynamic("游戏资源解压失败...")
	else:
		SignalMgr.LoadingSIG.emit(-1)
		Global.PopupManager.show_dynamic("游戏资源下载失败...")
		print("Failed to download resource, response code: ", response_code)

# 加载本地资源
func _load_local_resource():
	# 动态加载本地保存的游戏资源
	read_zip_file(game_zip_path, "", afterUnzipFIN)
	pass

# 加载主场景
func loadMainScene(file_path) -> bool:
	print("加载主场景: ", file_path)
	var main_scene = ResourceLoader.load(file_path)
	if main_scene:
		var instance = main_scene.instantiate()
		get_tree().root.add_child(instance)
		print("Saved scene to: ", file_path)
		return true
	return false

# 解压完成(最终处理)
func afterUnzipFIN(zip_reader: ZIPReader):
	afterUnzip(zip_reader)
	var is_add_main_scene = false
	var main_path = ""
	for file_path in scene_files:
		print('解压出来的文件路径', file_path)
		if SceneMgr.get_scene_path(game_name) == res_path + file_path and loadMainScene(file_path):
			is_add_main_scene = true
			main_path = file_path
			break
			
	# 如果忘记添加，则走默认路径
	if not is_add_main_scene:
		main_path = default_scene_path.path_join(game_name).path_join(game_name + ".tscn")
		is_add_main_scene = loadMainScene(main_path)

	if not is_add_main_scene:
		SignalMgr.LoadingSIG.emit(-1)
		Global.PopupManager.show_dynamic("缺乏主场景资源,游戏启动失败..."+main_path)
		return
	# 添加道场景管理
	SignalMgr.LoadingSIG.emit(100)
	#restart_app()
	#get_tree().reload_current_scene()
	await get_tree().process_frame
	SceneMgr.add_scene(game_name, main_path)
	SceneMgr.ToGameScene(game_name)
	pass

# 解压完成
func afterUnzip(_zip_reader: ZIPReader):
	#print(files) # ["1.txt", "2.md", "3.html", "1.jpg"]
	print("File processing completed")
	# SceneMgr.add_scenes_from_dict({
	# 	game_name: default_scene_path + game_name + ".tscn"
	# })
	pass

# 解压 ZIP 文件
func read_zip_file(zip_path: String, parent_path: String, call_back: Callable):
	var zip_reader := ZIPReader.new()
	var err := zip_reader.open(zip_path)
	if err != OK:
		return err
	
	# 获取ZIP内所有文件列表
	var files = zip_reader.get_files()
	
	# 遍历处理每个文件
	for file_path in files:
		# 获取文件数据
		var file_data = zip_reader.read_file(file_path)
		var suffix = file_path.get_extension().to_lower()
		var current_dir = ""
		var temp_sub_path = parent_path
		print('解压出来的文件路径', file_path, ' 文件后缀', temp_sub_path)
		fileLanding(file_path, file_data, suffix)
		continue
		# 检查文件后缀
		match suffix:
			"tscn": # 游戏场景路径
				current_dir = default_scene_path
			"gd": # 脚本路径
				current_dir = default_script_path
			"png", "svg", "jpge", "jpg": # 资源路径
				current_dir = default_assets_path
				if temp_sub_path == "":
					temp_sub_path = "image"
			"ogg", "wav", "mp3", "mp4":
				current_dir = default_assets_path
				if temp_sub_path == "":
					temp_sub_path = "music"
			"zip":
				var temp_zip_path = local_path + file_path.get_file()
				var file = FileAccess.open(temp_zip_path, FileAccess.WRITE)
				if file:
					file.store_buffer(file_data)
					file.close()
				print('子路径', file_path.get_base_dir())
				read_zip_file(temp_zip_path, file_path.get_base_dir(), afterUnzip)
				continue
			_:
				pass
		if current_dir != "":
			if temp_sub_path != "":
				current_dir = current_dir.path_join(temp_sub_path)
			var new_path = current_dir.path_join(file_path)
			fileLanding(new_path, file_data, suffix)
	
	zip_reader.close()
	call_back.call(zip_reader)

# 文件落地
func fileLanding(file_path, file_data, suffix):
	print('新纳入的文件', file_path)
	var file_dir = file_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(file_dir)
	var f = FileAccess.open(file_path, FileAccess.WRITE)
	if f:
		f.store_buffer(file_data)
		f.close()
		if suffix == "tscn":
			scene_files.append(file_path)
	else:
		print("Failed to save: ", file_path)
	pass
	
func restart_app():
	var executable_path = OS.get_executable_path()  # 获取当前可执行文件路径
	OS.execute(executable_path, [],[], false)          # 启动新实例
	get_tree().quit()                                # 退出当前进程
	
# 示例：如何使用此加载界面
func example_loading():
	# 模拟加载过程
	var timer = get_tree().create_timer(0.5)
	await timer.timeout
	set_progress(25)
	
	timer = get_tree().create_timer(0.5)
	await timer.timeout
	set_progress(50)
	
	timer = get_tree().create_timer(0.5)
	await timer.timeout
	set_progress(75)
	
	timer = get_tree().create_timer(0.5)
	await timer.timeout
	set_progress(100)
	
	# 加载完成后的操作
	timer = get_tree().create_timer(0.5)
	await timer.timeout
	print("Loading completed!")
