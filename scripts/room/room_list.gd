extends Control

const roomItem = preload("res://scenes/room/room_item.tscn")
const SAVE_PATH = "user://room_list_info.json"

@onready var search_input = $VBoxContainer/SearchBar/SearchInput
# @onready var sort_options = $VBoxContainer/SearchBar/SortOptions
@onready var game_options = $VBoxContainer/SearchBar/GameOptions
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

# 等待游戏开始
@onready var waitingStart = $WaitingRoom

# 房间列表
@onready var room_container = $VBoxContainer/RoomContainer/ScrollContainer/RoomList
@onready var prev_button = $PrevButton
@onready var next_button = $NextButton
@onready var page_label = $PageLabel

var favorite_rooms = []
# var room_history = []
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
var favorite_list = []

# 准备
func _ready():
	SettingsManager.show_settings()
	SceneManager.set_previous_name("roomlist")
	# WindowDrag.register_drag_zone(self)

	# 适配房间子项的列数
	var width = get_viewport_rect().size.x
	var columns = 2
	if width>450:
		columns = width/ 450
	var space = (columns-1)*35+2*85
	if width>space:
		columns = floor((width-space)/450)
		items_per_page = 2*columns # 展示两行
	# room_container.columns = columns

	if not Util.isFullScreen():
		items_per_page = 2
	# 加载保存的数据
	_load_saved_data()
	var games = await OnlineGame.getGameList()
	for game in games:
		game_options.add_item(game.name,game.id)
	jion_dialog.visible = false
	print("初始化房间列表数据!!!")
	_refresh_room_list()
	

	# 绑定事件
	search_input.text_changed.connect(_on_search_changed)
	# sort_options.item_selected.connect(_on_sort_changed)
	show_favorites.toggled.connect(_on_show_favorites_toggled)
	show_myrooms.toggled.connect(_on_show_myrooms_toggled)
	create_button.pressed.connect(_on_create_pressed)
	create_room_dialog.room_created.connect(_on_room_created)# 创建房间
	waitingStart.quitRoomSIG.connect(_on_cancel_waiting)
	SignalManager.CreateRoomSIG.connect(_recv_created_room)
	SignalManager.RemoveRoomSIG.connect(_recv_remove_room)
	SignalManager.JoinRoomSIG.connect(_recv_join_room)
	SignalManager.LeaveRoomSIG.connect(_recv_leave_room)
	pass

# 添加房间数据
func append(data):
	# print("添加 房间数据:", data)
	room_list_info.append({
			"id": data.get("id",0),
			"room_id": str(data.get("id",0)).md5_text().substr(8, 16),
			"room_name": data.get("name",""),
			"room_key": data.get("key",""), 
			"is_locked": data.get("isLock",false),
			"game_name": OnlineGame.getGameName(data.gid),
			"game_type": data.get("gid",0),
			"creator_id": data.get("creatorId",""),
			"author": data.get("creator",""),
			"base_score": data.get("baseScore",0),
			"enter_score": data.get("enterScore",0),
			"current_round": data.get("maxRound",0),
			"player_count": data.get("sitCount",0),
			"max_players": data.get("maxSitter",0),
			"status": data.get("state",""),
			"create_time": data.get("openTime",""),
			"description": data.get("description",""),
			"players": data.get("players",[]),
		})
	pass

func remove(data):
	room_list_info.erase(data)
	pass


# 获取房间列表
func loadRooms(creatorId="",order="",name1="",isDesc=true):
	room_list_info.clear()
	var result = await OnlineGame.getTabelList({
		"creatorId": creatorId,
		"order":order,
		"name":name1,
		"isDesc":isDesc,
		"pageNum":1,
		"pageSize":20
	})
	if not result:
		return
	for data in result.items:
		append(data)
	update_total_pages(result.total)
	pass

# 更新总页数
func update_total_pages(list_size:int):
	total_pages = ceil(float(list_size) / items_per_page)
	if current_page >= total_pages:
		current_page = max(0, total_pages - 1)
	_update_stats()


# 刷新房间列表
func _refresh_room_list():
	# 清除现有房间
	for child in room_container.get_children():
		child.queue_free()
	
	# 加载房间数据
	await loadRooms()
		
	# 应用过滤器和排序
	var filtered_rooms = _apply_filters(room_list_info)
	# filtered_rooms = _sort_rooms(filtered_rooms)
	if filtered_rooms.size() == 0:
		page_label.text = "0/0"
		return

	# 房间当前页的起始和结束索引
	var start_idx = current_page * items_per_page
	var end_idx = min(start_idx + items_per_page, filtered_rooms.size())
	# if filtered_rooms.size()<=end_idx:
	# 	page_label.text = "0/0"
	# 	return
	# 创建房间列表项
	for i in range(start_idx, end_idx):
		var data = filtered_rooms[i]
		var room_item = roomItem.instantiate()
		room_container.add_child(room_item)
		# print(i," - 房间数据:", data)
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
		# 房间分页比值
	prev_button.disabled = current_page == 0
	next_button.disabled = current_page >= total_pages - 1

	page_label.text = "%d/%d" % [current_page + 1, total_pages]
	pass


func _apply_filters(rooms: Array) -> Array:
	if 0 == rooms.size():
		return []
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
	var selectGameType = game_options.selected
	for room in rooms:
		# 搜索文本过滤
		if search_text:
			var room_text = "%s%s%s" % [room.room_name, room.game_name, room.room_id]
			if not room_text.to_lower().contains(search_text):
				continue
		if selectGameType > 0 and room.game_type != selectGameType:
			continue	
		filtered.append(room)
	print("过滤后的房间数量: ", filtered.size(),"  ",selectGameType)
	update_total_pages(filtered.size())
	return filtered

# func _sort_rooms(rooms: Array) -> Array:
# 	var sort_id = sort_options.selected
# 	var sorted = rooms.duplicate()
# 	match sort_id:
# 		1: # 底分升序
# 			sorted.sort_custom(func(a, b): return a.base_score < b.base_score)
# 		2: # 底分降序
# 			sorted.sort_custom(func(a, b): return a.base_score > b.base_score)
# 		3: # 人数升序
# 			sorted.sort_custom(func(a, b): return a.player_count < b.player_count)
# 		4: # 人数降序
# 			sorted.sort_custom(func(a, b): return a.player_count > b.player_count)
# 		5: # 创建时间
# 			sorted.sort_custom(func(a, b): return a.create_time > b.create_time)
# 		6: # 需要密码
# 			sorted.sort_custom(func(a, b): return not a.is_locked and b.is_locked)
# 	return sorted

# 更新统计信息
func _update_stats():
	var total_rooms = room_list_info.size()
	var active_rooms = room_list_info.filter(func(r): return r.status != 2).size()
	var total_players = room_list_info.reduce(func(acc, r): return acc + r.player_count, 0)
	
	total_rooms_label.text = "总房间数: %d" % total_rooms
	active_rooms_label.text = "活跃房间: %d" % active_rooms
	total_players_label.text = "在线玩家: %d" % total_players
	pass

# 保存数据
func _save_data():
	var save_data = {
		"favorite_rooms": favorite_rooms,
		"my_rooms": my_rooms,
		# "room_history": room_history
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	pass

# 加载保存的数据
func _load_saved_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json_string = file.get_as_text()
		var data = JSON.parse_string(json_string)
		if data:
			favorite_rooms = data.favorite_rooms
			# room_history = data.room_history
			# my_rooms = data.my_rooms
		file.close()
	var result = await OnlineGame.getFavoriteList()
	if result:
		favorite_list = result.tidList
	print("收藏的房间列表:", favorite_list)
	pass


###############################################################
func _on_search_changed(_new_text: String):
	print("搜索关键字:", _new_text)
	_refresh_room_list()
	pass


# func _on_sort_changed(_index: int):
# 	print("排序方式:", _index)
# 	_refresh_room_list()

func _on_game_options_item_selected(_index: int):
	print("游戏类型:", _index)
	_refresh_room_list()
	pass

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
	pass

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
	pass

# 显示我创建的房间
func _on_show_myrooms_toggled(button_pressed: bool):
	if button_pressed:
		await loadRooms(OnlineLogin.get_my_id())
		my_rooms = room_list_info
		show_favorites.button_pressed = false
		# 左右移动
		if tween:
			tween.kill()
		tween = get_tree().create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		# 获取按钮当前的x位置
		var original_x = show_myrooms.position.x
		# 向右移动30像素
		tween.tween_property(show_myrooms, "position:x", original_x - 30, 0.05)
		tween.tween_property(show_myrooms, "position:x", original_x, 0.05)
		tween.tween_property(show_myrooms, "position:x", original_x + 30, 0.05)
		tween.tween_property(show_myrooms, "position:x", original_x, 0.05)
	print("显示我创建的:", button_pressed)
	_refresh_room_list()
	

func _on_create_pressed():
	# 添加刷新动画
	# 左右移动
	if tween:
		tween.kill()
	tween = get_tree().create_tween()
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
	if selected_room_info:
		var room_info = selected_room_info
		# 进入房间
		waitingStart.reset(room_info.room_id, room_info.max_players)
		for player in room_info.players:
			print("正在等待的玩家:", player)
			waitingStart.add_player(player.uid, player.username, player.headIcon)
		waitingStart.show()
	pass # Replace with function body.

#################################################################
# 接收创建房间消息
func _recv_created_room(data: Dictionary):
	var index = room_list_info.find(func(r): return r.id == data.id)
	if index == -1:
		append(data)
	pass
# 接收删除房间消息
func _recv_remove_room(data: Dictionary):
	var index = room_list_info.find(func(r): return r.id == data.id)
	if index == -1:
		remove(data)
	pass
# 接收加入房间消息
func _recv_join_room(data: Dictionary):
	var index = -1
	for i in range(room_list_info.size()):
		if room_list_info[i].id == data.get("tableId",0):
			index = i
			room_list_info[i].player_count = data.get("chairId",0)
			if waitingStart.room_id == room_list_info[i].room_id:
				waitingStart.add_player(data.get("uid",""), data.get("username",""), data.get("headIcon",""))
			print("加入房间后 人数:", room_list_info[i].player_count)
			break
	
	for child in room_container.get_children():
		if child is PanelContainer and child.room_data.id == data.tableId:
			child.setup(room_list_info[index])
			return
	pass
# 接收离开房间消息
func _recv_leave_room(data: Dictionary):
	var index = -1
	for i in range(room_list_info.size()):
		if room_list_info[i].id == data.get("tableId",0):
			index = i
			room_list_info[i].player_count = data.get("chairId",0)
			if waitingStart.room_id == room_list_info[i].room_id:
				waitingStart.remove_player(data.get("uid",""))
			print("离开房间后 人数:", room_list_info[i].player_count)
			break
	
	for child in room_container.get_children():
		if child is PanelContainer and child.room_data.id == data.tableId:
			child.setup(room_list_info[index])
			return
	pass
#################################################################

# 取消等待
func _on_cancel_waiting():
	var result = await OnlineGame.leaveTable({
		"tableId": selected_room_info.id,
	})
	if not result:
		return
	waitingStart.hide()
	if selected_room_info:
		for i in range(selected_room_info.players.size()):
			if selected_room_info.players[i].uid == OnlineLogin.get_my_id():
				selected_room_info.players.remove_at(i)
				break
		_refresh_room_list()
	pass

# 加入房间
func _on_join_room(room_info: Dictionary):
	if room_info.max_players == room_info.player_count:
		PopupManager.show_dynamic("房间已满员")
		return
	
	# 初始化等待房间
	waitingStart.reset(room_info.room_id, room_info.max_players)
	for player in room_info.players:
		print("正在等待的玩家:", player)
		waitingStart.add_player(player.uid, player.username, player.headIcon)

	# 进入房间
	var result = await OnlineGame.joinTable({
		"tableId": room_info.id, 
		"tableKey": room_info.room_key
		})
	if not result:
		#失败则返回 不用处理接口里统一处理了
		return
	print("加入房间成功",result)
	selected_room_info = room_info

	if room_info.is_locked:
		jion_dialog.visible = true
		jion_room.text = "%s\nID:%s"%[room_info.room_name,room_info.room_id]
	else:
		waitingStart.show()
	pass

# 创建房间
func _on_room_created(_room_info: Dictionary):
	var timer = get_tree().create_timer(1.0)
	await timer.timeout
	_refresh_room_list()
	pass


# 确认房间密码
func _on_confirm_btn_pressed() -> void:
	# 校验房间密码
	selected_room_info.room_key = jion_input.text
	_on_join_room(selected_room_info)
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
	pass

func _on_next_button_pressed():
	if current_page < total_pages - 1:
		current_page += 1
		_refresh_room_list()
	pass

func _on_search_input_focus_entered() -> void:
	# 获取目标编辑控件的全局位置和大小
	if Util.isMobile():
		DisplayServer.virtual_keyboard_show("中文输入法") 
	pass # Replace with function body.


func _on_search_input_focus_exited() -> void:
	if Util.isMobile():
		DisplayServer.virtual_keyboard_hide()
	pass # Replace with function body.
