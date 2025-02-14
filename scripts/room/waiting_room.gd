extends Control

signal quitRoomSIG()
var player_scene = preload("res://scenes/room/player_item.tscn") 
var tween:Tween
var max_players = 4
var last_wait_time = 5
var time_left:float = 20.0
var room_id = ""
var current_players = []
@onready var player_list = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayerList
@onready var waiting_animation = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/WaitingAnimation
@onready var room_info = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RoomInfo
@onready var countdown = $CenterContainer/PanelContainer/Control/CountdownTimer
@onready var cancleBtn = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CancelButton

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
	
	pass

# 重置房间信息
func reset(roomId: String = "",playerMax:int=10):
	time_left = 20.0
	cancleBtn.disabled = false
	max_players = playerMax
	room_id = roomId
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
	pass

# 加入房间
func add_player(player_uid,player_name: String,player_avatar = null):
	if current_players.size() >= max_players:
		PopupManager.show_dynamic("房间已满，无法加入")
		return
	var player_item = player_scene.instantiate()
	player_item.set_player_info(player_uid,player_name,player_avatar)
	player_list.add_child(player_item)
	current_players.append(player_name)
	room_info.text= "[center]房间号: [b][color=gold]%s[/color][/b]    最小人数: [b][color=#c0c0c0]%d[/color][/b]人    当前: [color=green]%d[/color]人[/center]"%[room_id,max_players,current_players.size()] #"[b]房间号:[/b]" + room_id +"    [b]最小人数:[/b][color=blue]"+str(max_players) +"[/color]人    [b]当前人数:[/b][color=green]"+str(current_players.size()) +"[/color]人"
	if current_players.size() >= max_players:
		room_info.text += "  [color=red](满)[/color]"
		countdown.show()
		countdown.start(last_wait_time)
		SignalManager.FullRoomSIG.emit(room_id)

# 离开房间
func remove_player(player_name: String):
	if  time_left <= 1.0:
		return
	for player_item in player_list.get_children():
		print("离开房间",player_item.getUserName())
		if player_item.getUserName() == player_name:
			player_list.remove_child(player_item)
			current_players.erase(player_name)
			print("离开房间", player_name, " 剩下", current_players)
			if OnlineLogin.get_my_name() != player_name:
				PopupManager.show_dynamic("%s  已离开房间"%[player_name])
			countdown.stop()
			countdown.hide()
			room_info.text= "[center]房间号: [b][color=gold]%s[/color][/b]    最小人数: [b][color=#c0c0c0]%d[/color][/b]人    当前: [color=green]%d[/color]人[/center]"%[room_id,max_players,current_players.size()] #"[b]房间号:[/b]" + room_id +"    [b]最小人数:[/b][color=blue]"+str(max_players) +"[/color]人    [b]当前人数:[/b][color=green]"+str(current_players.size()) +"[/color]人"
			return
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
		SceneManager.switch_to_scene("xiangqi")

# 计时器回调
func _on_countdown_timeleft(timeleft:float):
	time_left = timeleft
	if timeleft == 1.0:
		PopupManager.show_dynamic("选手已锁定,不允许离开",150)
		cancleBtn.disabled = true
		if tween:
			tween.kill()
	pass

# 点击取消按钮
func _on_cancel_button_pressed():
	# 这里添加取消等待的逻辑
	if tween:
		tween.kill()
	countdown.stop()
	countdown.hide()
	remove_player(OnlineLogin.get_my_name())
	quitRoomSIG.emit()

# func _debug_add_test_players():
# 	# 仅用于测试：模拟其他玩家陆续加入
# 	var timer = get_tree().create_timer(2.0)
# 	timer.timeout.connect(func(): add_player("玩家2"))
	
# 	timer = get_tree().create_timer(4.0)
# 	timer.timeout.connect(func(): add_player("玩家3"))
# 	pass
