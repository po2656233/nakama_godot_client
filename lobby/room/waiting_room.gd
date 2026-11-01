extends Control

signal quitRoomSIG()
var player_scene = preload("res://lobby/room/player_item.tscn") 
var tween:Tween
var is_no_enter = false
var max_players = 4
var limit_time = 2.0 #最后读秒 禁止操作
var last_wait_time = 8
var time_left:float = 20.0
var room_id = ""
var game_name = ""
var current_players = []

@onready var player_list = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayerList
@onready var waiting_animation = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/WaitingAnimation
@onready var room_info = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RoomInfo
@onready var countdown = $CenterContainer/PanelContainer/Control/CountdownTimer
@onready var cancleBtn = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CancelButton
@onready var loading_scene = $LoadingScreen

const PLAYER_COLORS := [
	Color("#e6194b"),
	Color("#3cb44b"),
	Color("#ffe119"),
	Color("#4363d8"),
	Color("#f58231"),
	Color("#911eb4"),
	Color("#46f0f0"),
	Color("#f032e6"),
	Color("#bcf60c"),
	Color("#fabebe"),
	Color("#008080"),
	Color("#e6beff"),
	Color("#9a6324"),
	Color("#fffac8"),
	Color("#800000"),
	Color("#aaffc3"),
	Color("#808000"),
	Color("#ffd8b1"),
	Color("#000075"),
	Color("#808080"),
]
func _ready():
	# 初始化房间信息
	room_info.text = "[center]房间号:[b][color=yellow]0000[/color][/b]    最小人数:[b][color=red]10[/color][/b]人    当前:[color=green]10[/color]人[/center] (满)" #"房间号：" + str(randi() % 10000).pad_zeros(4)
	
	# 启动等待动画
	start_waiting_animation()
	
	# # 模拟其他玩家加入
	# if OS.has_feature("editor"):
	 #     _debug_add_test_players()
	countdown.timeout.connect(_on_countdown_timeout)
	countdown.timeleft.connect(_on_countdown_timeleft)
	Global.SignalMgr.LoadingSIG.connect(_on_loading_value)
	pass

func Show():
	show()
	Global.SettingsMgr.settings_toggle.emit()
	pass

func Hide():
	hide()
	Global.SettingsMgr.settings_toggle.emit()
	pass
	

func Comming():
	is_no_enter = true
	waiting_animation.text = "正在进入..."
	room_info.text= "[center]房间号: [b][color=gold]%s[/color][/b]    最小人数: [b][color=#c0c0c0]%d[/color][/b]人"%[room_id.substr(0, 16),max_players] 
	pass
	
func Waiting():
	is_no_enter = false
	if current_players.size() < max_players:
		waiting_animation.text = "等待中..."
	pass

func ToBegin():
	is_no_enter = true
	waiting_animation.text = "即将开始..."
	pass

# 重置房间信息
func reset(name1: String,roomId: String = "",playerMax:int=10):
	time_left = 20.0
	cancleBtn.disabled = false
	max_players = playerMax
	room_id = roomId
	game_name = name1
	current_players = []
	loading_scene.hide()
	for child in player_list.get_children():
		child.queue_free()
	if playerMax > 3:
		if playerMax%5 == 0:
			player_list.columns = floor(playerMax/5.0)
		if playerMax%4 == 0:
			player_list.columns = floor(playerMax/4.0)
		elif playerMax%3 == 0:
			player_list.columns = floor(playerMax/3.0)
		elif playerMax%2 == 0:
			player_list.columns = floor(playerMax/2.0)
		else:
			player_list.columns = 4
	else:
		player_list.columns = playerMax
	Comming()
	Show()
	pass

# 加入房间
func add_player(player_uid, player_name: String, player_avatar = null):
	var player_index = current_players.size()
	if player_index >= max_players:
		Global.WindowPopup.show_dynamic("房间已满，无法加入")
		return

	var player_item = player_scene.instantiate()
	player_list.add_child(player_item)

	# 更新房间信息
	player_item.set_player_info(player_uid, player_name, player_avatar)

	# 将玩家名称添加到当前玩家列表中
	current_players.append(player_name)
	print("加入房间", player_name, " 剩下", current_players)
	room_info.text= "[center]房间号: [b][color=gold]%s[/color][/b]    最小人数: [b][color=#c0c0c0]%d[/color][/b]人    当前: [color=green]%d[/color]人[/center]"%[room_id.substr(0, 16),max_players,current_players.size()] 
	
	#"[b]房间号:[/b]" + room_id +"    [b]最小人数:[/b][color=blue]"+str(max_players) +"[/color]人    [b]当前人数:[/b][color=green]"+str(current_players.size()) +"[/color]人"
	if current_players.size() >= max_players:
		ToBegin()
		room_info.text += "  [color=red](满)[/color]"
		countdown.show()
		countdown.start(last_wait_time)
		Global.SignalMgr.FullRoomSIG.emit(room_id)

	# 对玩家列表进行排序，确保显示顺序与加入顺序一致
	var children = player_list.get_children()
	children.sort_custom(func(a,b):
		return a.uid.naturalnocasecmp_to(b.uid) > 0
	)
	for i in children.size():
		player_list.move_child(children[i], i)	
	
	# 重新分配颜色	
	var player_count = 0
	for item in player_list.get_children():
		if player_count < PLAYER_COLORS.size():
			item.setColor(PLAYER_COLORS[player_count])
		player_count = player_count + 1
	pass

# 离开房间
func remove_player(uid: String):
	if  time_left <= limit_time:
		return

	for player_item in player_list.get_children():
		var playerUid = player_item.getUserId()
		if playerUid == uid:
			var username =  player_item.getUserName()
			current_players.erase(username)
			player_list.remove_child(player_item)
			print("离开房间", username, " 剩下", current_players)
			if playerUid != uid:
				Global.WindowPopup.show_dynamic("%s  已离开房间"%[username])
			countdown.stop()
			countdown.hide()
			Waiting()
			room_info.text= "[center]房间号: [b][color=gold]%s[/color][/b]    最小人数: [b][color=#c0c0c0]%d[/color][/b]人    当前: [color=green]%d[/color]人[/center]"%[room_id.substr(0, 16),max_players,current_players.size()] #"[b]房间号:[/b]" + room_id +"    [b]最小人数:[/b][color=blue]"+str(max_players) +"[/color]人    [b]当前人数:[/b][color=green]"+str(current_players.size()) +"[/color]人"
			break
		

	# 对玩家列表进行排序，确保显示顺序与加入顺序一致
	var children = player_list.get_children()
	children.sort_custom(func(a,b):
		return a.uid.naturalnocasecmp_to(b.uid) > 0
	)
	for i in children.size():
		player_list.move_child(children[i], i)	

	# 重新分配颜色	
	var player_count = 0
	for item in player_list.get_children():
		if player_count < PLAYER_COLORS.size():
			item.setColor(PLAYER_COLORS[player_count])
		player_count = player_count + 1
	pass

# 启动等待动画
func start_waiting_animation():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.bind_node(self)
	tween.set_loops()
	tween.tween_property(waiting_animation, "modulate:a", 0.3, 1.0)
	tween.tween_property(waiting_animation, "modulate:a", 1.0, 1.0)
	

# 计时器回调
func _on_countdown_timeout():
	if current_players.size() >= max_players:
		# cancleBtn.disabled = true
		var timer = get_tree().create_timer(1)
		await timer.timeout
		Global.SceneMgr.set_previous_name("roomlist")
		loading_scene.Show()
		
		var game_id = Global.OnlineGame.getGameID(game_name)
		print("准备游戏 game_id:", game_id, " name:", game_name)
		# 登记导航来源：从房间列表进入，退出时回到房间列表。
		if Global.has_global("SceneRouter"):
			Global.SceneRouter.prepare(NavigationContext.for_room_list(str(game_name), str(room_id)))
		Global.SignalMgr.LoadingGameSIG.emit(game_id)

# 计时器回调
func _on_countdown_timeleft(timeleft:float):
	time_left = timeleft
	if timeleft == limit_time:
		Global.WindowPopup.show_dynamic("选手已锁定,不允许离开",150)
		cancleBtn.disabled = true
		if tween:
			tween.kill()
	pass

func _on_loading_value(value:float):
	if value == -1.0:
		_on_cancel_button_pressed()
	pass

# 点击取消按钮
func _on_cancel_button_pressed():
	# 这里添加取消等待的逻辑
	if tween:
		tween.kill()
	countdown.stop()
	countdown.hide()
	quitRoomSIG.emit()
	loading_scene.hide()
	if not is_no_enter:
		Global.SignalMgr.JoinErrorMusicSIG.emit()

# func _debug_add_test_players():
# 	# 仅用于测试：模拟其他玩家陆续加入
# 	var timer = get_tree().create_timer(2.0)
# 	timer.timeout.connect(func(): add_player("玩家2"))
	
# 	timer = get_tree().create_timer(4.0)
# 	timer.timeout.connect(func(): add_player("玩家3"))
# 	pass
