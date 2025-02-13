extends Control


const roomItem = preload("res://scenes/room/room_item.tscn")
const room_for_waiting = preload("res://scenes/room/waiting_room.tscn")
const SAVE_PATH = "user://room_list_info.json"

@onready var search_input = $VBoxContainer/SearchBar/SearchInput
@onready var sort_options = $VBoxContainer/SearchBar/FilterOptions/SortOptions
@onready var show_favorites = $VBoxContainer/SearchBar/ShowFavorites
@onready var show_myrooms = $VBoxContainer/SearchBar/ShowMyRooms
@onready var create_button = $VBoxContainer/SearchBar/CreateButton

# 统计信息标签
@onready var total_rooms_label = $VBoxContainer/MarginContainer/VBoxContainer/StatsPanel/MarginContainer/HBoxContainer/TotalRooms
@onready var active_rooms_label = $VBoxContainer/MarginContainer/VBoxContainer/StatsPanel/MarginContainer/HBoxContainer/ActiveRooms
@onready var total_players_label = $VBoxContainer/MarginContainer/VBoxContainer/StatsPanel/MarginContainer/HBoxContainer/TotalPlayers

# 创建房间
@onready var create_room_dialog = $CreateRoomDialog

# 加入房间
@onready var jion_dialog = $CenterContainer
@onready var jion_room = $CenterContainer/Panel/RoomID
@onready var jion_input = $CenterContainer/Panel/RoomPsw

# 房间列表
@onready var room_container = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/RoomContainer
@onready var prev_button = $VBoxContainer/MarginContainer2/HBoxContainer/PrevButton
@onready var next_button = $VBoxContainer/MarginContainer2/HBoxContainer/NextButton
@onready var page_label = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/PageLabel

var favorite_rooms = []
var room_history = []
var my_rooms = []

@export var items_per_page: int = 4
@export var button_size: Vector2 = Vector2(200, 200)
@export var spacing: float = 20.0

var current_page: int = 0
var total_pages: int = 0
# var items: Array = []

var pre_room_id = ""
var pre_room_count = 0
var selected_room_info = {}
var already_selectd_favorite = false
var tween:Tween
var room_list_info = [
	# {
	# 	"room_name": "军棋道场",
	# 	"game_name": "军棋",
	# 	"game_type": 6,
	# 	"room_id": "R010",
	# 	"is_locked": false,
	# 	"creator_id": "xxxxxx01",
	# 	"base_score": 500,
	# 	"entry_score": 5000,
	# 	"current_round": 1,
	# 	"player_count": 2,
	# 	"max_players": 2,
	# 	"status": "进行中",
	# 	"create_time": "2024-01-08 10:30:00",
	# 	"description": "围棋爱好者的修炼场所",
	# 	"rules": ["中国规则", "60分钟限时"],
	# 	"players": [{"uid": "xxxxxx01", "username": "黑棋手","headIcon":""}, {"uid": "xxxxxx02", "username": "白棋手"}],
	# 	"favorite": true,
	# },
	# }
]




# 准备
func _ready():
	SettingsManager.show_settings()
	SceneManager.set_previous_name("roomlist")
	# WindowDrag.register_drag_zone(self)

	# 适配房间子项的列数
	# var width = get_viewport_rect().size.x
	# var columns = 2
	# if width>450:
	# 	columns = width/ 450
	# var space = columns*35
	# if width>space:
	# 	columns = ceil((width-space)/450)
	# room_container.columns = columns
	# items_per_page = columns
	if not Util.isFullScreen():
		items_per_page = 2
	# 加载保存的数据
	_load_saved_data()
	
	jion_dialog.visible = false
	print("初始化房间列表数据!!!")
	_refresh_room_list()
	_update_stats()

	# 绑定事件
	create_room_dialog.room_created.connect(_on_room_created)# 创建房间
	search_input.text_changed.connect(_on_search_changed)
	sort_options.item_selected.connect(_on_sort_changed)
	show_favorites.toggled.connect(_on_show_favorites_toggled)
	show_myrooms.toggled.connect(_on_show_myrooms_toggled)
	create_button.pressed.connect(_on_create_pressed)
	if Online.nakama_socket:
		Online.nakama_socket.received_matchmaker_matched.connect(_on_received_matchmaker_matched)
		Online.nakama_socket.received_match_state.connect(_on_received_match_state)
		Online.nakama_socket.received_match_presence.connect(_on_received_match_presence)
		Online.nakama_socket.received_status_presence.connect(_on_received_status_presence)
	pass


func append(data):
	room_list_info.append({
			"id": data.match_id,
			"room_id": data.match_id.split("-")[0],
			"room_name": data.MatchData.room_name,
			"is_locked": true if data.MatchData.room_psw != "" else false,
			"game_name": data.MatchData.game_name,
			"game_type": data.MatchData.game_type,
			"creator_id": data.MatchData.creator_id,
			"author": data.MatchData.author if data.MatchData.has("author") else "",
			"base_score": data.MatchData.base_score,
			"entry_score": data.MatchData.entry_score,
			"current_round": data.MatchData.current_round,
			"player_count": data.size if data.has("size")  else 0,
			"max_players": data.MatchData.max_players,
			"status": data.MatchData.status,
			"create_time": data.MatchData.create_time,
			"description": data.MatchData.description,
			"rules": data.MatchData.rules,
			"players": data.MatchData.players,
		})
	pass

# 获取房间列表
func loadRooms():
	var matchs = await OnlineGame.getMatchList()
	for data in matchs:
		append(data)
	update_total_pages()
	pass

# 更新总页数
func update_total_pages():
	total_pages = ceil(float(room_list_info.size()) / items_per_page)


# 刷新房间列表
func _refresh_room_list():
	# 清除现有房间
	for child in room_container.get_children():
		child.queue_free()
	room_list_info.clear()
	# 加载房间数据
	await loadRooms()
	if room_list_info.size() == 0:
		return
		
	# 应用过滤器和排序
	var filtered_rooms = _apply_filters(room_list_info)
	filtered_rooms = _sort_rooms(filtered_rooms)

	var start_idx = current_page * items_per_page
	var end_idx = min(start_idx + items_per_page, room_list_info.size())

	# 创建房间列表项
	for i in range(start_idx, end_idx):
		var data = filtered_rooms[i]
		var room_item = roomItem.instantiate()
		room_container.add_child(room_item)
		room_item.setup(data)
		room_item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		room_item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		room_item.join_room.connect(_on_join_room)
		room_item.favorite_toggled.connect(_on_room_favorite_toggled.bind(data))
		
		# 设置收藏状态
		room_item.is_favorite = favorite_rooms.any(func(id): return id == data.id)
		
		# 添加进入动画
		room_item.show()
		# room_item.modulate.a = 0
		# tween.chain().tween_property(room_item, "modulate:a", 1.0, 0.2)
		# Update navigation buttons and page label
	prev_button.disabled = current_page == 0
	next_button.disabled = current_page >= total_pages - 1
	page_label.text = "%d/%d" % [current_page + 1, total_pages]
	pass


func _apply_filters(rooms: Array) -> Array:
	var search_text = search_input.text.to_lower()
	# 如果显示收藏，只显示收藏的房间
	if show_favorites.button_pressed: 
		rooms = room_list_info.filter(func(r): return r.id in favorite_rooms)

	# 如果显示我创建的，只显示我创建的房间
	if show_myrooms.button_pressed: 	
		if not OnlineLogin.player_data:
			return []
		my_rooms = room_list_info.filter(func(r): return r.creator_id == OnlineLogin.get_my_id())
		rooms = my_rooms.duplicate()

	var filtered = []
	for room in rooms:
		# 搜索文本过滤
		if search_text:
			var room_text = "%s%s%s" % [room.room_name, room.game_type, room.room_id]
			if not room_text.to_lower().contains(search_text):
				continue
		filtered.append(room)
	return filtered

func _sort_rooms(rooms: Array) -> Array:
	var sort_id = sort_options.selected
	var sorted = rooms.duplicate()
	match sort_id:
		1: # 底分升序
			sorted.sort_custom(func(a, b): return a.base_score < b.base_score)
		2: # 底分降序
			sorted.sort_custom(func(a, b): return a.base_score > b.base_score)
		3: # 人数升序
			sorted.sort_custom(func(a, b): return a.player_count < b.player_count)
		4: # 人数降序
			sorted.sort_custom(func(a, b): return a.player_count > b.player_count)
		5: # 创建时间
			sorted.sort_custom(func(a, b): return a.create_time > b.create_time)
		6: # 需要密码
			sorted.sort_custom(func(a, b): return not a.is_locked and b.is_locked)
	return sorted

func _update_stats():
	var total_rooms = room_list_info.size()
	var active_rooms = room_list_info.filter(func(r): return r.status != "已满员").size()
	var total_players = room_list_info.reduce(func(acc, r): return acc + r.player_count, 0)
	
	total_rooms_label.text = "总房间数: %d" % total_rooms
	active_rooms_label.text = "活跃房间: %d" % active_rooms
	total_players_label.text = "在线玩家: %d" % total_players
	pass

func _save_data():
	var save_data = {
		"favorite_rooms": favorite_rooms,
		"my_rooms": my_rooms,
		"room_history": room_history
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	pass

func _load_saved_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json_string = file.get_as_text()
		var data = JSON.parse_string(json_string)
		if data:
			favorite_rooms = data.favorite_rooms
			room_history = data.room_history
			my_rooms = data.my_rooms
	pass

###############################################################
func _on_received_matchmaker_matched(matchmaker_matched):
	print("收到匹配的数据:", matchmaker_matched)
	pass

func _on_received_match_state(match_state):
	print("收到匹配状态:", match_state)
	pass

func _on_received_match_presence(match_presence):
	print("收到匹配的玩家数据:", match_presence)
	pass

func _on_received_status_presence(status_presence):	
	print("收到状态的玩家数据:", status_presence)
	pass

###############################################################
func _on_search_changed(_new_text: String):
	print("搜索关键字:", _new_text)
	_refresh_room_list()


func _on_sort_changed(_index: int):
	print("排序方式:", _index)
	_refresh_room_list()

# 收藏房间
func _on_room_favorite_toggled(is_favorite: bool, room_info: Dictionary):
	if is_favorite:
		var index = favorite_rooms.find(func(id): return id == room_info.id)
		if index == -1:
			favorite_rooms.push_front(room_info.id)
	else:
		favorite_rooms.erase(room_info.id)
	print("收藏的房间列表: ", favorite_rooms)
	_save_data()
	_refresh_room_list()

# 显示收藏房间
func _on_show_favorites_toggled(button_pressed: bool):
	print("显示收藏:", button_pressed)
	if show_myrooms.button_pressed:
		if  not button_pressed:
			return
		show_myrooms.button_pressed = false
		return 
	if button_pressed:
		show_myrooms.button_pressed = false
	_refresh_room_list()

# 显示我创建的房间
func _on_show_myrooms_toggled(button_pressed: bool):
	if button_pressed:
		show_favorites.button_pressed = false
		# 左右移动
		if tween:
			tween.kill()
		tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		# 获取按钮当前的x位置
		var original_x = show_myrooms.position.x
		# 向右移动30像素
		tween.chain().tween_property(show_myrooms, "position:x", original_x - 30, 0.05)
		tween.chain().tween_property(show_myrooms, "position:x", original_x, 0.05)
		tween.chain().tween_property(show_myrooms, "position:x", original_x + 30, 0.05)
		tween.chain().tween_property(show_myrooms, "position:x", original_x, 0.05)
	print("显示我创建的:", button_pressed)
	_refresh_room_list()
	

func _on_create_pressed():
	# 添加刷新动画
	# 左右移动
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	# # 获取按钮当前的x位置
	# var original_x = create_button.position.x
	# # 向右移动30像素
	# tween.tween_property(create_button, "position:x", original_x - 30, 0.15)
	# tween.tween_property(create_button, "position:x", original_x, 0.15)
	# tween.tween_property(create_button, "position:x", original_x + 30, 0.15)
	# tween.tween_property(create_button, "position:x", original_x, 0.15)

	# # 招手
	# var rotation_tween = create_tween()
	# tween.set_ease(Tween.EASE_IN_OUT)
	# tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(create_button, "rotation_degrees", -15, 0.1)
	tween.tween_property(create_button, "rotation_degrees", 15, 0.2)
	tween.tween_property(create_button, "rotation_degrees", -15, 0.1)
	tween.tween_property(create_button, "rotation_degrees", 15, 0.2)
	tween.tween_property(create_button, "rotation_degrees", 0, 0.1)
	# # 旋转
	# var rotation_tween = create_tween()
	# tween.tween_property(create_button, "rotation", PI * 2, 0.5)
	# tween.tween_property(create_button, "rotation", 0, 0)
	create_room_dialog.popup_centered()
	print("公开匹配")
	# 这里可以添加从服务器刷新数据的逻辑
	# _refresh_room_list()
	# _update_stats()
	pass


# 等待房间开始
func wait_for_room_to_start():
	var room_info = selected_room_info
	# 进入房间
	var waitingStart = room_for_waiting.instantiate()
	add_child(waitingStart)
	waitingStart.reset(room_info.room_id, room_info.max_players)
	waitingStart.add_player(OnlineLogin.get_my_id(), OnlineLogin.get_my_name(), OnlineLogin.get_my_headIcon())
	for player in room_info.players:
		waitingStart.add_player(player.uid, player.username, player.headIcon)
	pass # Replace with function body.




# 加入房间
func _on_join_room(room_info: Dictionary):
	if room_info.max_players == room_info.player_count:
		PopupManager.show_dynamic("房间已满员")
		return
	if not Online.nakama_socket:
		PopupManager.show_dynamic("未连接服务器")
		return
	var p_metadata = room_info.room_psw if room_info.has("room_psw") else null
	var result = await Online.nakama_socket.join_match_async(room_info.id,p_metadata)
	if result.is_exception():
		PopupManager.show_dynamic("加入房间失败 "+result.get_exception().message)
		return
	print("加入房间成功",result)
	selected_room_info = room_info

	# 添加到历史记录
	if not room_history.any(func(r): return r.room_id == room_info.room_id):
		room_history.push_front(room_info)
		if room_history.size() > 10: # 限制历史记录数量
			room_history.pop_back()
		_save_data()
	if room_info.is_locked:
		jion_dialog.visible = true
		jion_room.text = "%s\nID:%s"%[room_info.room_name,room_info.room_id]
	else:
		wait_for_room_to_start()
	pass

# 创建房间
func _on_room_created(_room_info: Dictionary):
	if Online.nakama_socket:
		# 匹配创建参数
		# var match_maker_ticket = await Online.nakama_socket.add_matchmaker_async()
		# print("匹配创建成功，票据: ", match_maker_ticket)

		# 服务端创建
		var res = await Online.nakama_socket.rpc_async("create_match",_room_info)
		if res.is_exception():
			print("创建房间失败:",res.get_exception().message)
			PopupManager.show_dynamic("创建房间失败")
			return
		print("创建服务端托管成功",res)
		var timer = get_tree().create_timer(1.0)
		await timer.timeout
		_refresh_room_list()
	pass


# 确认房间密码
func _on_confirm_btn_pressed() -> void:
	# 校验房间密码
	if jion_input.text != "1234":
		PopupManager.show_dynamic("房间密码错误")
		return
	wait_for_room_to_start()
	pass


# 取消房间
func _on_cancle_btn_pressed() -> void:
	selected_room_info = {}
	jion_dialog.visible = false
	jion_input.text = ""
	pass # Replace with function body.

func _on_prev_button_pressed():
	if current_page > 0:
		current_page -= 1
		_refresh_room_list()

func _on_next_button_pressed():
	if current_page < total_pages - 1:
		current_page += 1
		_refresh_room_list()

func _on_search_input_focus_entered() -> void:
	# 获取目标编辑控件的全局位置和大小
	if Util.isMobile():
		DisplayServer.virtual_keyboard_show("中文输入法") 
	pass # Replace with function body.


func _on_search_input_focus_exited() -> void:
	if Util.isMobile():
		DisplayServer.virtual_keyboard_hide()
	pass # Replace with function body.
