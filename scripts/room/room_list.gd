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

var allgames = []
var my_rooms = []
var favorite_rooms = []
var favorite_ids = []
# var room_history = []
var all_count = 0
var my_count = 0
var favorite_count = 0


@export var items_per_page: int = 8
@export var button_size: Vector2 = Vector2(200, 200)
@export var spacing: float = 20.0

# 网络请求的单页数据
var page_size: int = 8

# 本地处理的分页
var current_page: int = 0
var total_pages: int = 0
var total_size: int = 0
# var items: Array = []

var pre_room_id = ""
var pre_room_count = 0
var selected_room_info = {}
var already_selectd_favorite = false
var is_doing_enter = false
var tween: Tween
var room_list_info = []
var favorite_list = []
enum SearchType {
	all,
	favorite,
	my
}
var curSelect = SearchType.all
# 准备
func _ready():
	Global.SettingsMgr.show_settings()
	Global.SceneMgr.set_previous_name("roomlist")
	# Global.WindowDrag.register_drag_zone(self)

	# 适配房间子项的列数
	var width = get_viewport_rect().size.x
	var columns = 2
	if width > 450:
		columns = width / 450
	var space = (columns - 1) * 35 + 2 * 85
	if width > space:
		columns = floor((width - space) / 450)
		items_per_page = 2 * columns # 展示两行
	# room_container.columns = columns

	if not Util.isFullScreen():
		items_per_page = columns
		
	enableBtn(false)
	# 加载保存的数据
	print("初始化房间列表数据!!!page:%d,columns:%d,width:%d,space:%d"%[items_per_page,columns,width,space])
	load_data()


	
	# 加入房间的对话框
	jion_dialog.visible = false
	# 绑定事件
	search_input.text_changed.connect(_on_search_changed)
	# sort_options.item_selected.connect(_on_sort_changed)
	show_favorites.toggled.connect(_on_show_favorites_toggled)
	show_myrooms.toggled.connect(_on_show_myrooms_toggled)
	create_button.pressed.connect(_on_create_pressed)
	create_room_dialog.room_created.connect(_on_room_created) # 创建房间
	waitingStart.quitRoomSIG.connect(_on_cancel_waiting)
	Global.SignalMgr.CreateRoomSIG.connect(_on_append_room)
	Global.SignalMgr.RemoveRoomSIG.connect(_on_remove_room)
	# Global.SignalMgr.JoinRoomSIG.connect(_recv_join_room)
	Global.SignalMgr.LeaveRoomSIG.connect(_recv_leave_room)
	Global.SignalMgr.MatchStateEventSIG.connect(_on_received_match_state)
	Global.SignalMgr.MatchPresenceEventSIG.connect(_on_received_match_presence)
	Global.SignalMgr.OnlineCountSIG.connect(_on_received_table_online)
	pass

func load_data():
	# 游戏列表
	await Global.OnlineGame.getGameList(-1,self,"_on_game_list")
	pass
# 添加房间数据

func append_room(data):
	print("添加 房间数据:", data)
	var game_name = "未知游戏"
	for game in allgames:
		if int(game.id) == int(data.get("gid", 0)):
			game_name = game.name
			break
	var item = {
			"id": int(data.get("id", 0)),
			"room_id": data.get("mid", 0), # str().md5_text().substr(8, 16),
			"room_name": data.get("name", ""),
			"room_key": data.get("key", ""),
			"is_locked": data.get("isLock", false),
			"game_name": game_name,
			"game_type": data.get("gid", 0),
			"game_mode": data.get("mode", 0),
			"game_section": data.get("section", 0),
			"creator_id": data.get("creatorId", ""),
			"author": data.get("creator", ""),
			"base_score": data.get("baseScore", 0),
			"enter_score": data.get("enterScore", 0),
			"current_round": data.get("maxRound", 0),
			"player_count": data.get("sitCount", 0),
			"max_players": data.get("maxSitter", 0),
			"status": data.get("state", 0),
			"create_time": Util.format_china_time(data.get("openTime", 0), true),
			"description": data.get("description", ""),
			"players": data.get("players", []),
		}
	var rooms = []
	match curSelect:
		SearchType.all:
			rooms = room_list_info
		SearchType.favorite:
			rooms = favorite_rooms
		SearchType.my:
			rooms = my_rooms
		pass
	var index = -1
	for i in range(len(rooms)):
		if rooms[i].id == item.id:
			index = i
			break
	if index != -1:
		print("更新 房间数据1:", item.id)
		rooms[index] = item
	else:
		print("添加 房间数据1:", item.id)
		rooms.append(item)
	match curSelect:
		SearchType.all:
			room_list_info = rooms
		SearchType.favorite:
			favorite_rooms = rooms
			for room in favorite_rooms:
				if not favorite_ids.has(room.id):
					favorite_ids.append(room.id)
		SearchType.my:
			my_rooms = rooms
		pass
	pass

func remove_room(room_data):
	var room_id = room_data.get("tid", 0)
	print("删除:", room_id)
	for i in range(room_list_info.size()):
		if room_list_info[i].id == room_id:
			room_list_info.remove_at(i)
			break
	for i in range(my_rooms.size()):
		if my_rooms[i].id == room_id:
			my_rooms.remove_at(i)
			break
	for i in range(favorite_rooms.size()):
		if favorite_rooms[i].id == room_id:
			favorite_rooms.remove_at(i)
			break
	total_pages -= 1
	if total_pages < 0:
		total_pages = 0
	_refresh_room_list()
	pass


# 获取房间列表
func loadRooms(page=1, creatorId="", order="", name1="", isDesc=true):
	# room_list_info.clear()
	print("当前查询类型",curSelect)
	match curSelect:
		SearchType.all:
			await Global.OnlineGame.getTabelList({
				"creatorId": creatorId,
				"order": order,
				"name": name1,
				"isDesc": isDesc,
				"pageNum": int(page),
				"pageSize": int(page_size)
			},self,"_on_get_table_list")
		SearchType.favorite:
			await Global.OnlineGame.getFavoriteList({},self,"_on_get_favorite_list")
		SearchType.my:
			await Global.OnlineGame.getTabelList({
				"creatorId": Global.OnlineLogin.get_my_id(),
				"order": order,
				"name": name1,
				"isDesc": isDesc,
				"pageNum": int(page),
				"pageSize": int(page_size)
			},self,"_on_get_table_list")
		pass
	pass


# 更新总页数
func update_total_pages(list_size = -1):
	if list_size == -1:
		match curSelect:
			SearchType.all:
				list_size = all_count
			SearchType.favorite:
				list_size = favorite_count
			SearchType.my:
				list_size = my_count
	total_pages = ceil(float(list_size) / items_per_page)
	if current_page >= total_pages:
		current_page = max(0, total_pages - 1)
	_update_stats()

func enableBtn(is_disabled:bool):
	game_options.disabled = !is_disabled
	show_favorites.disabled = !is_disabled
	show_myrooms.disabled = !is_disabled
	create_button.disabled = !is_disabled

func add_item(result):
	if result.has("items"):
		print("获取房间数量:",result.items.size())
		# 按 id 从大到小排序
		for data in result.items:
			append_room(data)
		pass
	var total = 0
	if result.has("total"):
		print("房间总数量:", result.total)
		total = result.total
	match curSelect:
		SearchType.all:
			all_count = total
		SearchType.favorite:
			favorite_count = total
		SearchType.my:
			my_count = total
	_refresh_room_list()

# 游戏列表
func _on_game_list(result):
	print("房间--游戏列表",result)
	allgames = Util.sort_by_filed(result,"id")
	for game in allgames:
		game_options.add_item(game.name, game.id)
		game_options.set_item_metadata(game_options.item_count-1, game)
	if allgames.size() == 0:
		Global.WindowPopup.show_message("没有找到任何游戏,请检查网络连接或稍后再试。", "提示", false)
		return
	# 需要标记收藏按钮状态，因此需要提前知道用户的收藏房间
	curSelect = SearchType.favorite
	loadRooms()
	curSelect = SearchType.all
	loadRooms()
	# 启用功能
	enableBtn(true)
	pass

# 刷新房间列表
func _refresh_room_list():
	# 清除现有房间
	for child in room_container.get_children():
		child.queue_free()
		
	# 应用过滤器和排序
	var rooms = []
	match curSelect:
		SearchType.all:
			rooms = room_list_info
		SearchType.favorite:
			rooms = favorite_rooms
		SearchType.my:
			rooms = my_rooms
		pass
	var filtered_rooms = _apply_filters(rooms)
	# filtered_rooms = _sort_rooms(filtered_rooms)

	update_total_pages( filtered_rooms.size() if game_options.selected>0 or search_input.text != "" else -1)
	# 房间当前页的起始和结束索引
	var start_idx = current_page * items_per_page
	var end_idx = min(start_idx + items_per_page, filtered_rooms.size())
	print("过滤后的房间数量:", filtered_rooms.size(), "当前查询类型:",curSelect)
	# 创建房间列表项
	for i in range(start_idx, end_idx):
		var data = filtered_rooms[i]
		var room_item = roomItem.instantiate()
		room_container.add_child(room_item)
		# print(i," - 房间数据:", data)
		data.is_favorite = favorite_ids.has(data.id)
		room_item.setup(data)
		room_item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		room_item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		room_item.join_room.connect(_on_join_room)
		room_item.favorite_toggled.connect(_on_room_favorite_toggled.bind(data))
		
		# 设置收藏状态
		print("收藏了列表:", favorite_ids, " 房间ID:",data.id)
		
		# 添加进入动画
		#room_item.show()
		# room_item.modulate.a = 0
		# tween.chain().tween_property(room_item, "modulate:a", 1.0, 0.2)
		# Update navigation buttons and page label
		# 房间分页比值
	print("当前页:", current_page + 1, "总页数:", total_pages)
	prev_button.disabled = current_page == 0
	next_button.disabled = current_page >= total_pages - 1

	page_label.text = "%d/%d" % [current_page + 1, total_pages]
	pass

# 优化：提取重复的动画逻辑到单独的函数
func _animate_button(button, property: String, values: Array, duration: float = 0.1) -> void:
	if tween:
		tween.kill()
	tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	for value in values:
		tween.tween_property(button, property, value, duration)

# 优化：简化按钮动画逻辑
func _on_show_favorites_toggled(button_pressed: bool):
	print("显示收藏:", button_pressed)
	if button_pressed:
		show_myrooms.button_pressed = false
		curSelect = SearchType.favorite
		await loadRooms()
		var original_y = show_favorites.position.y
		_animate_button(show_favorites, "position:y", [original_y - 30, original_y, original_y + 30, original_y],0.06)
	else:
		show_favorites.button_pressed = false
		show_myrooms.button_pressed = false
		curSelect = SearchType.all
		_refresh_room_list()

func _on_show_myrooms_toggled(button_pressed: bool):
	if button_pressed:
		show_favorites.button_pressed = false
		curSelect = SearchType.my
		my_rooms.clear()
		await loadRooms()
		var original_x = show_myrooms.position.x
		_animate_button(show_myrooms, "position:x", [original_x - 30, original_x, original_x + 30, original_x],0.06)
	else:
		show_favorites.button_pressed = false
		show_myrooms.button_pressed = false
		curSelect = SearchType.all
		_refresh_room_list()

func _on_create_pressed():
	_animate_button(create_button, "rotation_degrees", [-15, 15, -15, 15, 0], 0.1)
	create_room_dialog.popup_centered()
	print("公开匹配")

# 优化：减少重复的过滤逻辑
func _apply_filters(rooms: Array) -> Array:
	if rooms.size() == 0:
		return []

	var filtered = []
	var search_text = search_input.text.to_lower()
	var selectGame = game_options.get_item_metadata(game_options.selected)
	rooms.sort_custom(func(a, b):return a.id > b.id)
	for room in rooms:
		if search_text and not ("%s%s%s" % [room.room_name, room.game_name, room.room_id]).to_lower().contains(search_text):
			continue
		if game_options.selected > 0 and int(room.game_type) != int(selectGame.id):
			continue
		filtered.append(room)
	return filtered

# 优化：简化房间数据更新逻辑
func _update_items(room_info):
	if not room_info:
		return
	for child in room_container.get_children():
		if child.room_data.room_id == room_info.room_id:
			print("更新房间:", room_info)
			child.setup(room_info)
			break
	#_refresh_room_list()

# 更新统计信息
func _update_stats():
	var total_rooms = all_count  #room_list_info.size()
	var active_rooms = room_list_info.filter(func(r): return r.status != 2).size()
	var total_players = room_list_info.reduce(func(acc, r): return acc + r.player_count, 0)
	
	total_rooms_label.text = "总房间数: %d" % total_rooms
	active_rooms_label.text = "活跃房间: %d" % active_rooms
	total_players_label.text = "在线玩家: %d" % total_players
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
		var index = favorite_ids.find(func(id): return id == room_info.id)
		if index == -1:
			favorite_ids.push_front(room_info.id)
	else:
		favorite_ids.erase(room_info.id)
	print("收藏请求2",is_favorite)
	await Global.OnlineGame.favoriteTable({
		"tableId": room_info.id,
		"isFavorite": is_favorite,
	},self,"_on_favorite_table_cb")
	pass


# 确认房间密码
func _on_confirm_btn_pressed() -> void:
	if jion_input.text == "":
		Global.WindowPopup.show_dynamic("请输入房间密码")
		return
	# 校验房间密码
	selected_room_info.room_key = jion_input.text
	_on_join_room(selected_room_info)
	pass

func _set_join_btn(room_id,is_join = true):
	for child in room_container.get_children():
		if child.room_data.room_id == room_id:
			child.set_join_btn(is_join)
			break
	pass

# 取消房间
func _on_cancle_btn_pressed() -> void:
	if selected_room_info != {}:
		_set_join_btn(selected_room_info.room_id)
	jion_dialog.visible = false
	jion_input.text = ""
	selected_room_info = {}
	pass # Replace with function body.


func _on_prev_button_pressed():
	if current_page > 0:
		current_page -= 1
		_refresh_room_list()
	pass

func _on_next_button_pressed():
	if current_page < total_pages - 1:
		current_page += 1 # 它从0开始
	# 判断是否需要加载下一页
	var current_size = room_list_info.size()
	var plan_size = (current_page + 1) * items_per_page
	print("当前房间数量:", current_size, "计划房间数量:", plan_size, "当前页:", current_page, "总页数:", page_size)
	if plan_size > current_size && plan_size >= page_size:
		var page = ceil(float(plan_size) / page_size)
		print("加载下一页:", page)
		await loadRooms(page)
	else:
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

#################################################################
func _on_append_room(info):
	var data = info.get("table", {})
	var item = {
			"id": data.get("id", 0),
			"room_id": data.get("mid", 0), # str().md5_text().substr(8, 16),
			"room_name": data.get("name", ""),
			"room_key": data.get("key", ""),
			"is_locked": data.get("isLock", false),
			"game_name": Global.OnlineGame.getGameName(data.get("gid", 0)),
			"game_type": data.get("gid", 0),
			"creator_id": data.get("creatorId", ""),
			"author": data.get("creator", ""),
			"base_score": data.get("baseScore", 0),
			"enter_score": data.get("enterScore", 0),
			"current_round": data.get("maxRound", 0),
			"player_count": data.get("sitCount", 0),
			"max_players": data.get("maxSitter", 0),
			"status": data.get("state", 0),
			"create_time": Util.format_china_time(data.get("openTime", 0), true),
			"description": data.get("description", ""),
			"players": data.get("players", []),
		}
	print(item.id, "添加房间:", item.room_name)
	room_list_info.append(item)
	room_list_info.sort_custom(func(a, b): return a.id > b.id)
	all_count = info.get("total", 0)
	_refresh_room_list()

func _on_remove_room(data):
	remove_room(data)

func _recv_leave_room(data):
	print("离开房间---:", data)

func _on_received_match_state(data):
	if data.op_code == 101:
		var obj = JSON.parse_string(data.data)
		for info in obj.infos:
			if waitingStart.room_id == info.mid:
				waitingStart.add_player(info.uid, info.username)
		pass
	print("匹配状态:", data)
	pass

# 接收匹配状态
func _on_received_match_presence(data):
	var joins = []
	var leaves = []

	for adder in data.joins:
		joins.append({
			"uid": adder.user_id,
			"username": adder.username
		})
		if waitingStart.room_id == data.match_id:
			waitingStart.add_player(adder.user_id, adder.username)
	for adder in data.leaves:
		leaves.append({
			"uid": adder.user_id,
			"username": adder.username
		})
		if waitingStart.room_id == data.match_id:
			waitingStart.remove_player(adder.user_id)
	for i in range(room_list_info.size()):
		var info = room_list_info[i]
		if info.room_id == data.match_id:
			info.players.append_array(joins)
			for j in leaves:
				info.players.erase(j)
			info.player_count = info.players.size()
			room_list_info[i] = info
			_update_items(info)
			return
	pass

# 接收在线桌子信息
func _on_received_table_online(data):
	print("桌子在线:", data.mid)
		# 清除现有房间
	for info in room_list_info:
		if info.room_id == data.mid:
			info.player_count = int(data.online)
			_update_items(info)
			return
	pass

#################################################################

# 取消等待
func _on_cancel_waiting():
	if is_doing_enter:
		Global.WindowPopup.show_dynamic("正在进入房间,请等待",250)
		return
	waitingStart.Hide()
	waitingStart.remove_player(Global.OnlineLogin.get_my_id())
	if selected_room_info:
		var cur_room_id = selected_room_info.room_id
		print("离开房间:", cur_room_id)
		for i in range(selected_room_info.players.size()):
			if selected_room_info.players[i].uid == Global.OnlineLogin.get_my_id():
				selected_room_info.players.remove_at(i)
				break
		_set_join_btn(cur_room_id)
		await Global.OnlineMatch.LeaveMatch(cur_room_id)
		selected_room_info = {}
		# _refresh_room_list()
	pass

# 加入房间
func _on_join_room(room_info: Dictionary)->bool:
	# 检查是否正在加入房间
	if selected_room_info != {} and jion_input.text == "":
		Global.WindowPopup.show_dynamic("已有房间,请等待离开")
		_set_join_btn(room_info.room_id)
		return false
	var enName = Global.OnlineGame.getGameEnName(room_info.game_type).to_lower() 
	# 检查游戏本地是否存在，不存在则网络下载
	if not Global.SceneMgr.has_scene(enName):
		print('第一次加载游戏...',enName)
		#Global.SignalMgr.LoadingGameSIG.emit(room_info.game_type)
	else:
		print('已有游戏...',enName)

	# 检查是否已满
	if room_info.max_players == room_info.player_count:
		Global.WindowPopup.show_dynamic("房间已满员")
		selected_room_info = {}
		_set_join_btn(room_info.room_id)
		return false

	# 检查是否需要密码	
	selected_room_info = room_info
	if room_info.is_locked and jion_input.text == "":
		jion_dialog.visible = true
		jion_room.text = "%s\nID:%s" % [room_info.room_name, room_info.room_id.substr(0,16)]
		return true
	print("加入房间-key:", jion_input.text)
	# 初始化等待房间
	waitingStart.reset(enName, room_info.room_id, room_info.max_players)
	# 不加入网络重试
	is_doing_enter = true
	var result = await Global.Online.nakama_socket.rpc_async("join_table",{
		"tableId": int(room_info.id),
		"tableKey": jion_input.text
	})
	_on_join_table_cb(result)
	return true


# 创建房间
func _on_room_created(_room_info: Dictionary):
	var timer = get_tree().create_timer(1.0)
	await timer.timeout
	_refresh_room_list()
	pass


############################################################################
# 获取游戏名称更新回调
func _on_update_games_name(games):
	print("更新游戏列表:", games)
	for item in room_list_info:
		for game in games:
			if item.game_type == game.gid:
				item.game_name = game.name
				break
		# _update_items(item)
	pass

# 获取房间列表回调
func _on_get_table_list(result):
	add_item(result)
	pass

# 获取收藏房间列表回调
func _on_get_favorite_list(result):
	print("收藏列表返回结果",result)
	favorite_rooms.clear()
	favorite_ids.clear()
	add_item(result)
	pass
##################################################################################
# 加入牌桌
func _on_join_table_cb(result):
	if result == null:
		_on_join_table_err("")
		return
	if result.is_exception():
		_on_join_table_err(result.get_exception().message)
		return
	var tab_info = JSON.parse_string(result.payload )
	if tab_info.tableId != selected_room_info.id:
		_on_join_table_err("")
		return 
	# 进入房间
	var result_1 = await Global.OnlineMatch.joinMatch(selected_room_info.room_id, {
		"name": selected_room_info.room_name,
		"key": selected_room_info.room_key
	})
	
	if not result_1:
		_on_join_table_err("")
		return
		
	waitingStart.Waiting()
	print("加入房间成功", result_1)
	Global.SignalMgr.JoinSuccessMusicSIG.emit(selected_room_info.room_id)
	is_doing_enter = false
	pass

func _on_join_table_err(result):
	print("加入房间失败:", result)
	if result in Errors.ResponeMapping:
		Global.WindowPopup.show_dynamic("加入房间失败: %s" % Errors.ResponeMapping[result])
	else:
		Global.WindowPopup.show_dynamic("加入房间失败: %s" % result)
	await get_tree().create_timer(0.5).timeout
	waitingStart.Hide()
	Global.SignalMgr.JoinErrorMusicSIG.emit()
	
	jion_dialog.visible = false
	jion_input.text = ""
	selected_room_info = {}
	_refresh_room_list()
	pass

# 显示收藏房间
func _on_favorite_table_cb(result):
	if result == null:
		return 
	await loadRooms()
	# print("收藏牌桌: ",result)
	# _refresh_room_list()
	pass
