extends Control
#@onready var inner_panel: Panel = $HBoxContainer/MembersPanel/InnerPanel

#@onready var scroll_container: ScrollContainer = $HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer/ScrollContainer
@onready var player_info_content: VBoxContainer = $HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer/ScrollContainer/PlayerInfoContent
@onready var tab_container: TabContainer = $HBoxContainer/GameMatchPanel/InnerPanel/VBoxContainer/TabContainer

@onready var chat_input: LineEdit = $HBoxContainer/ChatPanel/InnerPanel/ChatContainer/ChatInputContainer/ChatInput
@onready var send_button: Button = $HBoxContainer/ChatPanel/InnerPanel/ChatContainer/ChatInputContainer/SendButton
@onready var club_button: Button = $HBoxContainer/ChatPanel/InnerPanel/ChatContainer/BackButton
@onready var messages_list: VBoxContainer = $HBoxContainer/ChatPanel/InnerPanel/ChatContainer/ChatMessages/MessagesList
@onready var members_panel: Panel = $HBoxContainer/MembersPanel
@onready var chat_panel: Panel = $HBoxContainer/ChatPanel
@onready var chat_messages: ScrollContainer = $HBoxContainer/ChatPanel/InnerPanel/ChatContainer/ChatMessages
@onready var chat_input_container: HBoxContainer = $HBoxContainer/ChatPanel/InnerPanel/ChatContainer/ChatInputContainer
@onready var chat_title_label: Label = $HBoxContainer/ChatPanel/InnerPanel/ChatContainer/ChatTitleLabel
@onready var info_section: GridContainer = $HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer/ScrollContainer/PlayerInfoContent/InfoSection


var club_data = preload("res://scripts/clublist/ClubData.gd").clubs[0]
#var club_data = {}
var member_item_scene = preload("res://scenes/clublist/MemberItem.tscn")
var game_match_scene = preload("res://scenes/clublist/GameMatchTab.tscn")
var current_player_popup = null
var current_member_name = ""
var is_in_game = false

# 玩家统计数据（随机生成，仅作演示）
var player_stats = {
	"level": [20, 100],
	"points": [1000, 10000],
	"rank": [1, 50],
	"games_played": [100, 500]
}

# 可能的游戏列表
var possible_games = [
	"DOTA2", "英雄联盟", "CS:GO", "Apex英雄", 
	"绝地求生", "守望先锋", "王者荣耀", "和平精英",
	"全面战争", "文明6", "Among Us", "糖豆人"
]

# 聊天消息样式
var message_style = {
	"system": {
		"color": Color(0.8, 0.8, 0.8, 1),
		"font_size": 16
	},
	"player": {
		"color": Color(1, 1, 1, 1),
		"font_size": 16
	},
	"self": {
		"color": Color(1, 1, 0.5, 1),
		"font_size": 16
	}
}

func _ready():
	# 设置初始状态
	modulate.a = 0
	# 入场动画
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1, 0.3)
	setup(club_data)
	
	switchPanel(true)
	# 初始化聊天界面状态
	update_chat_interface()

func setup(club):
	club_data = club
	$HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer/PlayerNameLabel.text = club.name
	# 填充成员列表
	populate_members_list()
	
	# 填充游戏匹配标签
	populate_game_tabs()

func switchPanel(isChat:bool):
	members_panel.visible = !isChat
	chat_panel.visible = isChat
	pass

func populate_members_list():
	var members_list = $HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer/ScrollContainer/PlayerInfoContent
	# 清除现有内容
	for child in members_list.get_children():
		child.queue_free()
	
	# 添加成员（带动画）
	for i in range(club_data.members.size()):
		var member_name = club_data.members[i]
		var member_item = member_item_scene.instantiate()
		members_list.add_child(member_item)
		member_item.set_member_name(member_name)
		
		# 添加点击处理
		member_item.member_clicked.connect(_on_member_clicked)
		
		# 设置初始状态和动画
		member_item.modulate.a = 0
		member_item.position.x = -20
		
		var delay = i * 0.1
		var tween = create_tween()
		tween.tween_property(member_item, "position:x", 0, 0.3).set_delay(delay)
		tween.parallel().tween_property(member_item, "modulate:a", 1, 0.3).set_delay(delay)

func populate_game_tabs():
	# 清除现有标签
	for child in tab_container.get_children():
		child.queue_free()
	
	# 为每个游戏创建标签（带动画）
	for i in range(club_data.games.size()):
		var game_name = club_data.games[i]
		var game_tab = game_match_scene.instantiate()
		tab_container.add_child(game_tab)
		game_tab.name = game_name
		game_tab.setup(game_name)
		
		# 连接游戏状态变化信号
		game_tab.join_queue_button_pressed.connect(_on_game_joined)
		game_tab.leave_queue_button_pressed.connect(_on_game_left)
		game_tab.show_player_info.connect(show_player_info)
		
		# 设置初始状态和动画
		game_tab.modulate.a = 0
		
		var delay = i * 0.15 + 0.3
		var tween = create_tween()
		tween.tween_property(game_tab, "modulate:a", 1, 0.4).set_delay(delay)

func _on_back_button_pressed():
	if members_panel.visible:
		switchPanel(true)
		return

	# 退出动画
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.3)
	tween.tween_callback(func(): 
		# 返回俱乐部列表
		Global.SignalMgr.ChangeSceneSIG.emit("clublist")
		queue_free()
		#var parent = get_parent()
		#if parent and parent.get_node("ClubsPanel"):
			#parent.get_node("ClubsPanel").visible = true
	)

func _on_member_clicked(member_name):
	current_member_name = member_name
	
	# 隐藏成员列表，显示玩家信息
	#$HBoxContainer/MembersPanel/InnerPanel/MembersListContainer.visible = false
	
	# 显示玩家信息并设置数据
	show_player_info(member_name)
	$HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer.visible = true
	
	# 添加动画效果
	$HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer.modulate.a = 0
	$HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer.position.x = -20
	
	var tween = create_tween()
	tween.tween_property($HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer, "modulate:a", 1, 0.3)
	tween.parallel().tween_property($HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer, "position:x", 0, 0.3)

#func _on_back_to_list_button_pressed():
	# 隐藏玩家信息，显示成员列表
	#$HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer.visible = false
	# 添加动画效果
	#$HBoxContainer/MembersPanel/InnerPanel/MembersListContainer.modulate.a = 0
	#$HBoxContainer/MembersPanel/InnerPanel/MembersListContainer.visible = true
	#var tween = create_tween()
	#tween.tween_property($HBoxContainer/MembersPanel/InnerPanel/MembersListContainer, "modulate:a", 1, 0.3)

func show_player_info(player_name):
	if player_name == "" or player_name == "我":
		switchPanel(true)
		return
	
	switchPanel(false)
	# 设置玩家名称
	$HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer/PlayerNameLabel.text = player_name
	
	# 生成随机玩家数据
	var level = randi_range(player_stats.level[0], player_stats.level[1])
	var points = randi_range(player_stats.points[0], player_stats.points[1])
	var rank = randi_range(player_stats.rank[0], player_stats.rank[1])
	
	# 设置玩家信息
	info_section.get_node("LevelValue").text = str(level)
	info_section.get_node("PointsValue").text = _format_number(points)
	info_section.get_node("RankValue").text = "#" + str(rank)
	
	# 设置游戏记录
	_setup_game_records()

func _setup_game_records():
	var item_width = 80
	## 清除现有记录
	var count = player_info_content.get_child_count()
	for i in range(1,count):
		var child = player_info_content.get_child(i)
		if child:
			child.queue_free()
	
	# 创建10条最近游戏记录
	for i in range(20):
		# 随机游戏数据
		var game_name = possible_games[randi() % possible_games.size()]
		var game_result = randi() % 4
		
		# 随机结束时间 (最近30天内)
		var days_ago = randi() % 30
		#var hours_ago = randi() % 24
		#var minutes_ago = randi() % 60
		#var now = Time.get_datetime_dict_from_system()
		var game_end_time = Time.get_datetime_dict_from_system()
		
		# 调整日期 (简化版，不考虑月份边界)
		game_end_time.day -= days_ago
		if game_end_time.day < 1:
			game_end_time.day = 30 - abs(game_end_time.day)  # 简化处理
		
		# 格式化时间
		var time_str = "%02d-%02d %02d:%02d" % [
			game_end_time.month, 
			game_end_time.day,
			game_end_time.hour,
			game_end_time.minute
		]
		
		# 创建水平布局
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		player_info_content.add_child(hbox)
		
		# 游戏名称标签
		var game_label = Label.new()
		game_label.text = game_name
		game_label.custom_minimum_size.x = item_width
		game_label.size_flags_horizontal = SIZE_EXPAND_FILL
		game_label.label_settings = LabelSettings.new()
		game_label.label_settings.font_color = Color.BURLYWOOD
		game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(game_label)
		
		# 时间标签
		var time_label = Label.new()
		time_label.text = time_str
		time_label.custom_minimum_size.x = item_width
		time_label.label_settings = LabelSettings.new()
		time_label.label_settings.font_color = Color.AQUAMARINE
		time_label.size_flags_horizontal = SIZE_EXPAND_FILL
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(time_label)
		
		# 游戏结果
		var gameResult = ['胜利','失败','平局','无效']
		var result_label = Label.new()
		result_label.size_flags_horizontal = SIZE_EXPAND_FILL
		result_label.label_settings = LabelSettings.new()
		result_label.text = gameResult[game_result]
		match game_result:
			0:
				result_label.label_settings.font_color = Color.GREEN
			1:
				result_label.label_settings.font_color = Color.RED
			2:
				result_label.label_settings.font_color = Color.GRAY
			3:
				result_label.label_settings.font_color = Color.DIM_GRAY
			_:
				pass
		result_label.custom_minimum_size.x = item_width
		result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(result_label)
		
		# 添加动画效果
		hbox.modulate.a = 0
		var delay = i * 0.05 + 0.1
		var tween = create_tween()
		tween.tween_property(hbox, "modulate:a", 1, 0.2).set_delay(delay)
		pass

func _format_number(number):
	var result = ""
	var str_num = str(number)
	var count = 0
	
	for i in range(str_num.length() - 1, -1, -1):
		result = str_num[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "," + result
	
	return result

func _on_game_joined(game_name):
	is_in_game = true
	club_button.disabled = true
	update_chat_interface()
	add_system_message("你已加入游戏: " + game_name)
	chat_title_label.text = "%s-聊天"%[game_name]
	

func _on_game_left(game_name):
	is_in_game = false
	club_button.disabled = false
	update_chat_interface()
	add_system_message("你已离开游戏: " + game_name)
	chat_title_label.text = "游戏聊天"

func update_chat_interface():
	# 根据游戏状态更新聊天界面
	chat_input.editable = is_in_game
	send_button.disabled = !is_in_game
	
	if is_in_game:
		chat_messages.modulate = Color(1, 1, 1, 1)
	else:
		chat_messages.modulate = Color(0.5, 0.5, 0.5, 0.7)

func _on_send_button_pressed():
	send_message()

func _on_chat_input_text_submitted(_new_text):
	send_message()

func send_message():
	if !is_in_game:
		return
		
	var message = chat_input.text.strip_edges()
	if message.is_empty():
		return
		
	# 添加自己的消息
	add_message("我", message, "self")
	
	# 模拟其他玩家回复（仅作演示）
	if randf() > 0.2:  # 30%概率有回复
		var random_player = club_data.members[randi() % club_data.members.size()]
		var random_responses = [
			"好的，收到！",
			"明白！",
			"正在执行...",
			"需要支援吗？",
			"我这边准备好了！"
		]
		var response = random_responses[randi() % random_responses.size()]
		add_message(random_player, response, "player")
	
	# 清空输入框
	chat_input.text = ""

func add_message(sender: String, content: String, type: String):
	var message_label = Label.new()
	message_label.text = sender + ": " + content
	message_label.add_theme_color_override("font_color", message_style[type].color)
	message_label.add_theme_font_size_override("font_size", message_style[type].font_size)
	
	# 添加到消息列表
	messages_list.add_child(message_label)
	
	# 滚动到底部
	var scroll_container = $HBoxContainer/ChatPanel/InnerPanel/ChatContainer/ChatMessages
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func add_system_message(content: String):
	switchPanel(true)
	add_message("系统", content, "system")
