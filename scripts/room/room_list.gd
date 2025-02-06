extends Control

signal room_selected(room_data: Dictionary)

const roomItem = preload("res://scenes/room/room_item.tscn")
const room_for_waiting = preload("res://scenes/room/waiting_room.tscn")
const SAVE_PATH = "user://room_data.json"

@onready var search_input = $VBoxContainer/SearchBar/SearchInput
@onready var status_filter = $VBoxContainer/SearchBar/FilterOptions/StatusFilter
@onready var game_type_filter = $VBoxContainer/SearchBar/FilterOptions/GameTypeFilter
@onready var sort_options = $VBoxContainer/SearchBar/FilterOptions/SortOptions
@onready var show_favorites = $VBoxContainer/SearchBar/ShowFavorites
@onready var show_history = $VBoxContainer/SearchBar/ShowHistory
@onready var show_myrooms = $VBoxContainer/SearchBar/ShowMyRooms
@onready var create_button = $VBoxContainer/SearchBar/CreateButton
@onready var room_container = $VBoxContainer/MarginContainer2/HBoxContainer/ScrollContainer/RoomContainer
@onready var detail_panel = $VBoxContainer/MarginContainer2/HBoxContainer/DetailPanel
@onready var detail_info = $VBoxContainer/MarginContainer2/HBoxContainer/DetailPanel/MarginContainer/ScrollContainer/VBoxContainer/RoomInfo
@onready var refresh_timer = $RefreshTimer

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

var favorite_rooms = []
var room_history = []
var pre_room_id = ""
var pre_room_count = 0
var selected_room_info = {}
var tween:Tween
var room_data = [
	{
		"room_id": "R001",
		"room_name": "欢乐场",
		"is_locked": true,
		"game_name": "德州扑克",
		"game_type": 1,
		"creator_id": "xxxxxx01",
		"base_score": 100,
		"entry_score": 1000,
		"current_round": 5,
		"player_count": 9,
		"max_players": 10,
		"status": "等待中",
		"create_time": "2024-01-08 10:00:00",
		"description": "适合新手的休闲场，气氛轻松友好",
		"rules": ["基础规则", "休闲模式", "15分钟限时"],
		"players": ["玩家1", "玩家2", "玩家3", "玩家4", "玩家5", "玩家6", "玩家7", "玩家8", "玩家9"],
		"favorite": false,
	},
	{
		"room_name": "21点新手场",
		"game_name": "21点",
		"game_type": 2,
		"room_id": "R006",
		"is_locked": false,
		"creator_id": "xxxxxx01",
		"base_score": 50,
		"entry_score": 500,
		"current_round": 1,
		"player_count": 2,
		"max_players": 5,
		"status": "等待中",
		"create_time": "2024-01-08 10:45:00",
		"description": "适合新手的21点游戏房间",
		"rules": ["基础规则", "新手教学"],
		"players": ["新手A", "新手B"],
		"favorite": true,
	},
	{
		"room_name": "五子棋竞技场",
		"game_name": "五子棋",
		"game_type": 3,
		"room_id": "R007",
		"is_locked": false,
		"creator_id": "xxxxxx01",
		"base_score": 200,
		"entry_score": 2000,
		"current_round": 3,
		"player_count": 1,
		"max_players": 2,
		"status": "等待中",
		"create_time": "2024-01-08 10:40:00",
		"description": "五子棋爱好者的对战平台",
		"rules": ["标准规则", "15分钟限时"],
		"players": ["棋手1"],
		"favorite": true,
	},
	{
		"room_name": "象棋大师场",
		"game_name": "象棋",
		"game_type": 4,
		"room_id": "R008",
		"is_locked": true,
		"creator_id": "xxxxxx01",
		"base_score": 300,
		"entry_score": 3000,
		"current_round": 2,
		"player_count": 2,
		"max_players": 2,
		"status": "进行中",
		"create_time": "2024-01-08 10:35:00",
		"description": "象棋大师的竞技场所",
		"rules": ["标准规则", "30分钟限时"],
		"players": ["棋手A", "棋手B"],
		"favorite": true,
	},
	{
		"room_name": "围棋道场",
		"game_name": "围棋",
		"game_type": 5,
		"room_id": "R009",
		"is_locked": false,
		"creator_id": "xxxxxx01",
		"base_score": 500,
		"entry_score": 5000,
		"current_round": 1,
		"player_count": 2,
		"max_players": 2,
		"status": "进行中",
		"create_time": "2024-01-08 10:30:00",
		"description": "围棋爱好者的修炼场所",
		"rules": ["中国规则", "60分钟限时"],
		"players": ["黑棋手", "白棋手"],
		"favorite": true,
	},
	{
		"room_name": "军棋道场",
		"game_name": "军棋",
		"game_type": 6,
		"room_id": "R010",
		"is_locked": false,
		"creator_id": "xxxxxx01",
		"base_score": 500,
		"entry_score": 5000,
		"current_round": 1,
		"player_count": 2,
		"max_players": 2,
		"status": "进行中",
		"create_time": "2024-01-08 10:30:00",
		"description": "围棋爱好者的修炼场所",
		"rules": ["中国规则", "60分钟限时"],
		"players": ["黑棋手", "白棋手"],
		"favorite": true,
	},
	{
		"room_name": "飞机棋道场",
		"game_name": "飞机棋",
		"game_type": 7,
		"room_id": "R011",
		"is_locked": false,
		"creator_id": "xxxxxx01",
		"base_score": 500,
		"entry_score": 5000,
		"current_round": 1,
		"player_count": 2,
		"max_players": 2,
		"status": "进行中",
		"create_time": "2024-01-08 10:30:00",
		"description": "围棋爱好者的修炼场所",
		"rules": ["中国规则", "60分钟限时"],
		"players": ["黑棋手", "白棋手"],
		"favorite": true,
	},
	{
		"room_name": "大富翁道场",
		"game_name": "大富翁",
		"game_type": 8,
		"room_id": "R012",
		"is_locked": false,
		"creator_id": "xxxxxx01",
		"base_score": 500,
		"entry_score": 5000,
		"current_round": 1,
		"player_count": 2,
		"max_players": 2,
		"status": "进行中",
		"create_time": "2024-01-08 10:30:00",
		"description": "围棋爱好者的修炼场所",
		"rules": ["中国规则", "60分钟限时"],
		"players": ["黑棋手", "白棋手"],
		"favorite": true,
	}
]




# 准备
func _ready():
	SettingsManager.show_settings()
	SceneManager.set_previous_name("roomlist")
	# WindowDrag.register_drag_zone(self)
	var width = get_viewport_rect().size.x
	if width>500:
		room_container.columns = (width-350)/ 500

	# 创建房间
	create_room_dialog.room_created.connect(_on_room_created)
	# 初始化动画
	detail_panel.modulate.a = 0
	
	# 加载保存的数据
	_load_saved_data()
	
	jion_dialog.visible = false
	_refresh_room_list()
	_update_stats()

	# 绑定事件
	search_input.text_changed.connect(_on_search_changed)
	status_filter.item_selected.connect(_on_filter_changed)
	game_type_filter.item_selected.connect(_on_filter_changed)
	sort_options.item_selected.connect(_on_sort_changed)
	show_favorites.toggled.connect(_on_show_favorites_toggled)
	show_history.toggled.connect(_on_show_history_toggled)
	show_myrooms.toggled.connect(_on_show_myrooms_toggled)
	create_button.pressed.connect(_on_create_pressed)
	refresh_timer.timeout.connect(_on_refresh_timer_timeout)
	room_selected.connect(_on_room_selected)


func _refresh_room_list():
	# 清除现有房间
	for child in room_container.get_children():
		child.queue_free()
	
	# 应用过滤器和排序
	var filtered_rooms = _apply_filters(room_data)
	filtered_rooms = _sort_rooms(filtered_rooms)

	if filtered_rooms.size() == 0:
		return

	# if tween:
	# 	tween.kill()
	# tween = get_tree().create_tween()
	# 创建房间列表项
	for data in filtered_rooms:
		var room_item = roomItem.instantiate()
		room_container.add_child(room_item)
		room_item.setup(data)
		room_item.room_clicked.connect(_on_room_clicked)
		room_item.join_room.connect(_on_join_room)
		room_item.favorite_toggled.connect(_on_room_favorite_toggled.bind(data))
		
		# 设置收藏状态
		room_item.is_favorite = data.favorite 
		
		# 添加进入动画
		room_item.show()
		# room_item.modulate.a = 0
		# tween.chain().tween_property(room_item, "modulate:a", 1.0, 0.2)
		


func _apply_filters(rooms: Array) -> Array:
	var search_text = search_input.text.to_lower()
	var status_id = status_filter.selected
	var game_type_id = game_type_filter.selected
	
	# 如果显示收藏，只显示收藏的房间
	if show_favorites.button_pressed:
		favorite_rooms = room_data.filter(func(r): return r.favorite)
		rooms = favorite_rooms.duplicate()
	
	# 如果显示历史，只显示历史记录
	if show_history.button_pressed:
		rooms = room_history.duplicate()

	# 如果显示我创建的，只显示我创建的房间
	if show_myrooms.button_pressed:
		if not OnlineChat.player_data:
			return []
		rooms = room_data.filter(func(r): return r.creator_id == OnlineChat.player_data.id)
	
	
	var filtered = []
	for room in rooms:
		# 搜索文本过滤
		if search_text:
			var room_text = "%s%s%s" % [room.room_name, room.game_type, room.room_id]
			if not room_text.to_lower().contains(search_text):
				continue

		# 是否我创建的过滤
		
		# 状态过滤
		match status_id:
			1: # 等待中
				if room.status != "等待中":
					continue
			2: # 进行中
				if room.status != "进行中":
					continue
			3: # 已满员
				if room.status != "已满员":
					continue
		
		# 游戏类型过滤
		match game_type_id:
			1: # 德州扑克
				if room.game_type != "德州扑克":
					continue
			2: # 斗地主
				if room.game_type != "斗地主":
					continue
			3: # 麻将
				if room.game_type != "麻将":
					continue
			4: # 21点
				if room.game_type != "21点":
					continue
			5: # 五子棋
				if room.game_type != "五子棋":
					continue
			6: # 象棋
				if room.game_type != "象棋":
					continue
			7: # 围棋
				if room.game_type != "围棋":
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
		6: # 创建时间
			sorted.sort_custom(func(a, b): return not a.is_locked and b.is_locked)
	
	return sorted

func _update_stats():
	var total_rooms = room_data.size()
	var active_rooms = room_data.filter(func(r): return r.status != "已满员").size()
	var total_players = room_data.reduce(func(acc, r): return acc + r.player_count, 0)
	
	total_rooms_label.text = "总房间数: %d" % total_rooms
	active_rooms_label.text = "活跃房间: %d" % active_rooms
	total_players_label.text = "在线玩家: %d" % total_players

func _save_data():
	var save_data = {
		"favorite_rooms": favorite_rooms,
		"room_history": room_history
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))

func _load_saved_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json_string = file.get_as_text()
		var data = JSON.parse_string(json_string)
		if data:
			favorite_rooms = data.favorite_rooms
			room_history = data.room_history

func _on_search_changed(_new_text: String):
	_refresh_room_list()

func _on_filter_changed(_index: int):
	_refresh_room_list()

func _on_sort_changed(_index: int):
	_refresh_room_list()

func _on_show_favorites_toggled(button_pressed: bool):
	if button_pressed:
		show_history.button_pressed = false
		show_myrooms.button_pressed = false
	_refresh_room_list()

func _on_show_history_toggled(button_pressed: bool):
	if button_pressed:
		show_favorites.button_pressed = false
		show_myrooms.button_pressed = false
	_refresh_room_list()

func _on_show_myrooms_toggled(button_pressed: bool):
	if button_pressed:
		show_favorites.button_pressed = false
		show_history.button_pressed = false
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

func _on_refresh_timer_timeout():
	_refresh_room_list()
	_update_stats()

func _on_room_clicked(room_info: Dictionary):
	# emit_signal("room_selected", room_info)
	room_selected.emit(room_info)
	pass

# 等待房间开始
func wait_for_room_to_start():
	var room_info = selected_room_info
	# 进入房间
	var waitingStart = room_for_waiting.instantiate()
	add_child(waitingStart)
	waitingStart.reset(room_info.room_id, room_info.max_players)
	waitingStart.add_player(OnlineChat.get_my_name())
	for playerName in room_info.players:
		waitingStart.add_player(playerName)
	# 测试人员退出
	# var timer = get_tree().create_timer(3.0)
	# await timer.timeout
	# waitingStart.remove_player(room_info.players[0])
	pass # Replace with function body.

func _on_join_room(room_info: Dictionary):
	if room_info.max_players == room_info.player_count:
		PopupManager.show_dynamic("房间已满员")
		print("房间已满员")
		return

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


func _on_room_favorite_toggled(is_favorite: bool, room_info: Dictionary):
	room_info["favorite"] = is_favorite
	if is_favorite:
		var index = room_data.find(func(r): return r.room_id == room_info.room_id)
		if index != -1:
			room_data[index] = room_info
	favorite_rooms = room_data.filter(func(r): return r.favorite)
	print("收藏的房间列表: ", favorite_rooms)
	_save_data()
	_refresh_room_list()

func _on_room_selected(room_info: Dictionary):
	# 更新详情面板
	for child in detail_info.get_children():
		child.queue_free()

	# 创建新的Label 
	var labels = [
		"房间名称: " + room_info.room_name,
		"游戏类型: " + room_info.game_name,
		"房间ID: " + room_info.room_id,
		"底分: " + str(room_info.base_score),
		"入场分: " + str(room_info.entry_score),
		"当前场数: " + str(room_info.current_round),
		# "玩家数量: %d/%d" % [room_info.player_count, room_info.max_players],
		"创建时间: " + room_info.create_time,
		# "房间状态: " + room_info.status,
		"",
		"房间描述:",
		room_info.description,
		"",
		"规则:",
	]
	
	labels.append_array(room_info.rules.map(func(rule): return "- " + rule))
	labels.append("")
	labels.append("当前玩家:")
	labels.append_array(room_info.players.map(func(player): return "- " + player))
	
	for text in labels:
		var label = Label.new()
		label.text = text
		detail_info.add_child(label)
	
	# 显示详情面板动画
	detail_panel.visible = pre_room_id != room_info.room_id or 1 == pre_room_count%2 
	pre_room_count = 0 if pre_room_id != room_info.room_id else pre_room_count+1

	pre_room_id = room_info.room_id
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(detail_panel, "modulate:a", 1.0, 0.3)
	pass


func _on_room_created(room_info: Dictionary):
	# 添加到房间列表
	# OnlineMatch.create_match(Online.nakama_socket)
	# Online.nakama_client.list_matches_async(Online.nakama_session,-1,-1,20,false,"","")
	if not room_data.any(func(r): return r.room_id == room_info.room_id):
		room_data.push_front(room_info)
		_save_data()
		_refresh_room_list()
		_update_stats()


func _on_confirm_btn_pressed() -> void:
	# 校验房间密码
	if jion_input.text != "1234":
		PopupManager.show_dynamic("房间密码错误")
		return
	wait_for_room_to_start()
	pass



func _on_cancle_btn_pressed() -> void:
	selected_room_info = {}
	jion_dialog.visible = false
	jion_input.text = ""
	pass # Replace with function body.
