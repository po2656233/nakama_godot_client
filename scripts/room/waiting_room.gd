extends Control

var player_scene = preload("res://scenes/room/player_item.tscn") 
var max_players = 4
var last_wait_time = 5
var room_id = ""
var current_players = []
@onready var player_list = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayerList
@onready var waiting_animation = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/WaitingAnimation
@onready var room_info = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RoomInfo
@onready var countdown = $CenterContainer/PanelContainer/Control/CountdownTimer
func _ready():
	# 初始化房间信息
	room_info.text = "房间号：" + str(randi() % 10000).pad_zeros(4)
	
	# 启动等待动画
	start_waiting_animation()
	
	# # 模拟其他玩家加入
	# if OS.has_feature("editor"):
	 #     _debug_add_test_players()
	countdown.timeout.connect(_on_countdown_timeout)
	pass

func reset(roomId: String = "",playerMax:int=10):
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

func add_player(player_name: String):
	var player_item = player_scene.instantiate()
	player_item.get_node("PlayerName").text = player_name
	player_list.add_child(player_item)
	current_players.append(player_name)
	room_info.text= "房间号:" + room_id +"    最小人数:"+str(max_players) +"人    当前人数:"+str(current_players.size()) +"人"
	if current_players.size() >= max_players:
		countdown.show()
		countdown.start(last_wait_time)
		SignalManager.FullRoomSIG.emit(room_id)

func remove_player(player_name: String):
	for i in range(player_list.get_child_count()):
		var player_item = player_list.get_child(i)
		if player_item.get_node("PlayerName").text == player_name:
			player_list.remove_child(player_item)
			current_players.remove(player_name)
			room_info.text= "房间号:" + room_id +"    最小人数:"+str(max_players) +"人    当前人数:"+str(current_players.size()) +"人"

func start_waiting_animation():
	var tween = create_tween()
	tween.tween_property(waiting_animation, "modulate:a", 0.3, 1.0)
	tween.tween_property(waiting_animation, "modulate:a", 1.0, 1.0)
	tween.set_loops()

func _on_countdown_timeout():
	if current_players.size() >= max_players:
		var timer = get_tree().create_timer(1)
		await timer.timeout
		SceneManager.switch_to_scene("xiangqi")
	
func _on_cancel_button_pressed():
	# 这里添加取消等待的逻辑
	countdown.stop()
	countdown.hide()
	SceneManager.switch_to_scene("roomlist")

func _debug_add_test_players():
	# 仅用于测试：模拟其他玩家陆续加入
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): add_player("玩家2"))
	
	timer = get_tree().create_timer(4.0)
	timer.timeout.connect(func(): add_player("玩家3"))
	pass