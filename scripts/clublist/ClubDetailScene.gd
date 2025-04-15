extends Control
@onready var inner_panel: Panel = $HBoxContainer/MembersPanel/InnerPanel

#@onready var scroll_container: ScrollContainer = $HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer/ScrollContainer
@onready var player_info_content: VBoxContainer = $HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer/ScrollContainer/PlayerInfoContent

var club_data = {}
var member_item_scene = preload("res://scenes/clublist/MemberItem.tscn")
var game_match_scene = preload("res://scenes/clublist/GameMatchTab.tscn")
var current_player_popup = null
var current_member_name = ""

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

func _ready():
	# 设置初始状态
	modulate.a = 0
	
	# 入场动画
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1, 0.3)

func setup(club):
	club_data = club
	$HBoxContainer/MembersPanel/InnerPanel/MembersListContainer/ClubNameLabel.text = club.name
	
	# 填充成员列表
	populate_members_list()
	
	# 填充游戏匹配标签
	populate_game_tabs()

func populate_members_list():
	var members_list = $HBoxContainer/MembersPanel/InnerPanel/MembersListContainer/ScrollContainer/MembersList
	
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
	var tab_container = $HBoxContainer/GameMatchPanel/InnerPanel/VBoxContainer/TabContainer
	
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
		
		# 设置初始状态和动画
		game_tab.modulate.a = 0
		
		var delay = i * 0.15 + 0.3
		var tween = create_tween()
		tween.tween_property(game_tab, "modulate:a", 1, 0.4).set_delay(delay)

func _on_back_button_pressed():
	# 退出动画
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.3)
	tween.tween_callback(func(): 
		# 返回俱乐部列表
		queue_free()
		get_parent().get_node("ClubsPanel").visible = true
	)

func _on_member_clicked(member_name):
	current_member_name = member_name
	
	# 隐藏成员列表，显示玩家信息
	$HBoxContainer/MembersPanel/InnerPanel/MembersListContainer.visible = false
	
	# 显示玩家信息并设置数据
	show_player_info(member_name)
	$HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer.visible = true
	
	# 添加动画效果
	$HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer.modulate.a = 0
	$HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer.position.x = -20
	
	var tween = create_tween()
	tween.tween_property($HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer, "modulate:a", 1, 0.3)
	tween.parallel().tween_property($HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer, "position:x", 0, 0.3)

func _on_back_to_list_button_pressed():
	# 隐藏玩家信息，显示成员列表
	$HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer.visible = false
	
	# 添加动画效果
	$HBoxContainer/MembersPanel/InnerPanel/MembersListContainer.modulate.a = 0
	$HBoxContainer/MembersPanel/InnerPanel/MembersListContainer.visible = true
	
	var tween = create_tween()
	tween.tween_property($HBoxContainer/MembersPanel/InnerPanel/MembersListContainer, "modulate:a", 1, 0.3)

func show_player_info(player_name):
	# 设置玩家名称
	$HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer/PlayerNameLabel.text = player_name
	
	# 生成随机玩家数据
	var level = randi_range(player_stats.level[0], player_stats.level[1])
	var points = randi_range(player_stats.points[0], player_stats.points[1])
	var rank = randi_range(player_stats.rank[0], player_stats.rank[1])
	
	# 设置玩家信息
	var info_section = $HBoxContainer/MembersPanel/InnerPanel/PlayerInfoContainer/ScrollContainer/PlayerInfoContent/InfoSection
	info_section.get_node("LevelValue").text = str(level)
	info_section.get_node("PointsValue").text = _format_number(points)
	info_section.get_node("RankValue").text = "#" + str(rank)
	
	# 设置游戏记录
	_setup_game_records()

func _setup_game_records():
	var item_width = 80
	## 清除现有记录
	var count = player_info_content.get_child_count()
	for i in range(count):
		if i>3:
			var child = player_info_content.get_child(i)
			if child:
				child.queue_free()
	
	# 创建10条最近游戏记录
	for i in range(10):
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
