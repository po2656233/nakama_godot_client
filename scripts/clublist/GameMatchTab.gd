extends Control
@onready var players_list = $VBoxContainer/MarginContainer2/VBoxContainer/ScrollContainer/WaitingPlayersList
@onready var game_status_label: Label = $VBoxContainer/MarginContainer/HBoxContainer/GameStatusLabel
@onready var join_queue_button: Button = $VBoxContainer/MarginContainer3/VBoxContainer/JoinQueueButton
@onready var leave_queue_button: Button = $VBoxContainer/MarginContainer3/VBoxContainer/LeaveQueueButton
@onready var players_count_label: Label = $VBoxContainer/MarginContainer/HBoxContainer/PlayersCountLabel

signal join_queue_button_pressed(game)
signal leave_queue_button_pressed(game)
signal show_player_info(info)

var game_name = ""
var max_players = 10
var current_players = []
var in_queue = false
var waiting_player_scene = preload("res://scenes/clublist/WaitingPlayerItem.tscn")

# 模拟玩家列表
var sample_players = [
	"玩家A", "玩家B", "玩家C", "玩家D", "玩家E",
	"玩家F", "玩家G", "玩家H", "玩家I", "玩家J",
	"玩家K", "玩家L", "玩家M", "玩家N", "玩家O"
]

func _ready():
	# 禁用离开队列按钮，因为默认不在队列中
	leave_queue_button.disabled = true
	
	# 添加按钮动画效果
	join_queue_button.mouse_entered.connect(_on_join_button_hover)
	join_queue_button.mouse_exited.connect(_on_join_button_exit)
	leave_queue_button.mouse_entered.connect(_on_leave_button_hover)
	leave_queue_button.mouse_exited.connect(_on_leave_button_exit)
	SignalManager.JoinGameSIG.connect(_on_join_game)
	SignalManager.LeaveGameSIG.connect(_on_leave_game)
	# 定时更新匹配状态（模拟）
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 5.0
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func setup(game):
	game_name = game
	# 随机设置最大玩家数
	max_players = randi_range(4, 16)
	players_count_label.text = "玩家数: 0/" + str(max_players)
	
	# 随机添加一些等待中的玩家
	var initial_players_count = randi_range(0, max_players - 1)
	for i in range(initial_players_count):
		var player = sample_players[randi() % sample_players.size()]
		if player not in current_players:
			current_players.append(player)
	update_players_display()
	pass

func update_players_display():
	# 更新玩家计数
	players_count_label.text = "玩家数: " + str(current_players.size()) + "/" + str(max_players)
	
	# 清除现有等待玩家列表
	for child in players_list.get_children():
		child.queue_free()
	
	# 添加等待中的玩家（带动画）
	for i in range(current_players.size()):
		var player = current_players[i]
		var player_item = waiting_player_scene.instantiate()
		players_list.add_child(player_item)
		player_item.set_player_name(player)
		
		# 设置初始状态和动画
		player_item.modulate.a = 0
		
		var delay = i * 0.05
		var tween = create_tween()
		tween.tween_property(player_item, "modulate:a", 1, 0.3).set_delay(delay)
		player_item.player_info_requested.connect(_on_player_info)
		
		
	# 更新匹配状态
	if current_players.size() >= max_players:
		game_status_label.text = "匹配状态: 游戏即将开始!"
		game_status_label.add_theme_color_override("font_color", Color.GREEN)
		
		# 添加特效
		$MatchAnimationParticles.emitting = true
	else:
		game_status_label.text = "匹配状态: 等待中"
		game_status_label.add_theme_color_override("font_color", Color.DARK_CYAN)

func _on_join_queue_button_pressed():
	if not in_queue:
		in_queue = true
		join_queue_button.disabled = true
		leave_queue_button.disabled = false
		
		# 添加自己到玩家列表中（带特效）
		current_players.append("我")
		update_players_display()
		
		# 添加按钮点击动画
		var button = join_queue_button
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.1)
		tween.tween_property(button, "scale", Vector2(1, 1), 0.1)
		join_queue_button_pressed.emit(game_name)
		SignalManager.JoinGameSIG.emit(game_name)

func _on_leave_queue_button_pressed():
	if in_queue:
		in_queue = false
		join_queue_button.disabled = false
		leave_queue_button.disabled = true
		
		# 从玩家列表中移除自己
		current_players.erase("我")
		update_players_display()
		
		# 添加按钮点击动画
		var button = leave_queue_button
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.1)
		tween.tween_property(button, "scale", Vector2(1, 1), 0.1)
		leave_queue_button_pressed.emit(game_name)
		SignalManager.LeaveGameSIG.emit(game_name)
	
func _on_player_info(info):
	show_player_info.emit(info)
	pass

func _on_timer_timeout():
	# 模拟随机玩家加入或离开
	if randf() > 0.5 and current_players.size() < max_players:
		# 添加随机玩家
		var player = sample_players[randi() % sample_players.size()]
		if player not in current_players:
			current_players.append(player)
	elif current_players.size() > 0:
		# 移除随机玩家，但不移除"我"
		var removable_players = current_players.duplicate()
		if "我" in removable_players:
			removable_players.erase("我")
			
		if removable_players.size() > 0:
			var to_remove = removable_players[randi() % removable_players.size()]
			current_players.erase(to_remove)
	
	update_players_display()

func _on_join_button_hover():
	var button = join_queue_button
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)

func _on_join_button_exit():
	var button = join_queue_button
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1, 1), 0.1)

func _on_leave_button_hover():
	var button = leave_queue_button
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)

func _on_leave_button_exit():
	var button = leave_queue_button
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1, 1), 0.1) 

func _on_join_game(gameName):
	join_queue_button.disabled = true
	leave_queue_button.disabled = false if game_name == gameName else true

func _on_leave_game(_gameName):
	join_queue_button.disabled = false
	leave_queue_button.disabled = true
	pass
