extends Control

signal game_selected(game_data)

# UI节点引用
@onready var title_label = $Background/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var search_bar = $Background/MarginContainer/VBoxContainer/HeaderContainer/SearchContainer/SearchBar
@onready var search_button = $Background/MarginContainer/VBoxContainer/HeaderContainer/SearchContainer/SearchButton
@onready var filter_button = $Background/MarginContainer/VBoxContainer/HeaderContainer/FilterButton
@onready var game_grid = $Background/MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/GameGrid
@onready var scroll_container = $Background/MarginContainer/VBoxContainer/ScrollContainer
@onready var status_label = $Background/MarginContainer/VBoxContainer/StatusLabel
@onready var prev_button = $Background/MarginContainer/VBoxContainer/PaginationContainer/PrevButton
@onready var page_info_label = $Background/MarginContainer/VBoxContainer/PaginationContainer/PageInfo
@onready var next_button = $Background/MarginContainer/VBoxContainer/PaginationContainer/NextButton
@onready var refresh_button = $Background/MarginContainer/VBoxContainer/FooterContainer/RefreshButton
@onready var settings_button = $Background/MarginContainer/VBoxContainer/FooterContainer/SettingsButton

# 游戏卡片场景
@export var game_card_scene: PackedScene = preload("res://scenes/gamelist/local_game_card.tscn")

# 数据
var local_games_data = []
var filtered_games_data = []
var selected_game_card = null

# 搜索和过滤
var current_search_text = ""
var current_filter = "all" # all, recent, favorites, installed

# 分页相关
var current_page = 0
var games_per_page = 9  # 每页显示9个游戏（3x3网格）
var total_pages = 0

func _ready():
	print("本地游戏列表界面初始化")
	
	# 设置标题
	title_label.text = "本地游戏库"
	
	# 连接信号
	search_button.pressed.connect(_on_search_pressed)
	search_bar.text_submitted.connect(_on_search_submitted)
	filter_button.pressed.connect(_on_filter_pressed)
	prev_button.pressed.connect(_on_prev_page_pressed)
	next_button.pressed.connect(_on_next_page_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	
	# 设置滚动容器
	scroll_container.get_h_scroll_bar().custom_minimum_size.y = 20
	scroll_container.get_v_scroll_bar().custom_minimum_size.x = 20
	
	# 加载本地游戏数据
	load_local_games()
	
	# 设置状态
	update_status_label()

func load_local_games():
	"""加载本地游戏数据"""
	status_label.text = "正在扫描本地游戏..."
	
	# 模拟本地游戏数据（实际项目中应该从本地文件系统扫描）
	local_games_data = [
		{
			"id": "local_001",
			"name": "折纸大师",
			"title": "折纸大师",
			"description": "一款创意十足的折纸模拟游戏，让你在虚拟世界中体验折纸的乐趣。\n\n特色：\n- 真实的折纸物理\n- 丰富的折纸教程\n- 创意分享社区",
			"author": "折纸屋工作室",
			"version": "1.2.3",
			"release_date": "2024-01-15",
			"last_played": "2024-08-01",
			"play_time": "2小时30分钟",
			"logo_path": "",
			"executable_path": "games/origami_master/game.exe",
			"installed": true,
			"favorite": true,
			"tags": ["创意", "休闲", "教育"]
		},
		{
			"id": "local_002", 
			"name": "纸飞机竞速",
			"title": "纸飞机竞速",
			"description": "驾驶各种纸飞机在天空中竞速，体验飞行的刺激与乐趣。\n\n特色：\n- 多种纸飞机模型\n- 真实的飞行物理\n- 在线排行榜",
			"author": "天空工作室",
			"version": "2.1.0",
			"release_date": "2024-02-20",
			"last_played": "2024-07-28",
			"play_time": "1小时45分钟",
			"logo_path": "",
			"executable_path": "games/paper_plane_race/game.exe",
			"installed": true,
			"favorite": false,
			"tags": ["竞速", "飞行", "多人"]
		},
		{
			"id": "local_003",
			"name": "立体拼图",
			"title": "立体拼图挑战",
			"description": "挑战你的空间想象力，完成各种复杂的立体拼图。\n\n特色：\n- 渐进式难度\n- 3D视角操作\n- 成就系统",
			"author": "智力游戏社",
			"version": "1.0.8",
			"release_date": "2024-03-10",
			"last_played": "2024-07-25",
			"play_time": "3小时20分钟",
			"logo_path": "",
			"executable_path": "games/3d_puzzle/game.exe",
			"installed": true,
			"favorite": true,
			"tags": ["解谜", "益智", "3D"]
		},
		{
			"id": "local_004",
			"name": "纸牌大师",
			"title": "纸牌大师",
			"description": "经典纸牌游戏合集，包含多种传统和创新玩法。\n\n特色：\n- 20+种纸牌游戏\n- AI对手挑战\n- 自定义牌面",
			"author": "卡牌工作室",
			"version": "3.2.1",
			"release_date": "2024-01-05",
			"last_played": "2024-08-03",
			"play_time": "5小时15分钟",
			"logo_path": "",
			"executable_path": "games/card_master/game.exe",
			"installed": true,
			"favorite": false,
			"tags": ["纸牌", "策略", "经典"]
		},
		{
			"id": "local_005",
			"name": "创意工坊",
			"title": "创意工坊",
			"description": "发挥你的创造力，制作属于自己的游戏和作品。\n\n特色：\n- 可视化编程\n- 素材库丰富\n- 作品分享平台",
			"author": "创意科技",
			"version": "1.5.2",
			"release_date": "2024-04-01",
			"last_played": "2024-07-30",
			"play_time": "4小时10分钟",
			"logo_path": "",
			"executable_path": "games/creative_workshop/game.exe",
			"installed": false,
			"favorite": true,
			"tags": ["创作", "编程", "教育"]
		},
		{
			"id": "local_006",
			"name": "音乐折纸",
			"title": "音乐折纸",
			"description": "结合音乐节拍的创新折纸游戏，让折纸变得更有趣。\n\n特色：\n- 音乐同步折纸\n- 多种音乐风格\n- 节拍挑战模式",
			"author": "音律工作室",
			"version": "2.0.3",
			"release_date": "2024-05-15",
			"last_played": "2024-08-02",
			"play_time": "2小时55分钟",
			"logo_path": "",
			"executable_path": "games/music_origami/game.exe",
			"installed": true,
			"favorite": false,
			"tags": ["音乐", "节拍", "创意"]
		},
		{
			"id": "local_007",
			"name": "星际争霸II",
			"title": "星际争霸II",
			"description": "经典即时战略游戏，三个种族的史诗对决。\n\n特色：\n- 三个独特种族\n- 精彩的战役系统\n- 全球竞技平台",
			"author": "暴雪娱乐",
			"version": "5.0.12",
			"release_date": "2010-07-27",
			"last_played": "2024-08-04",
			"play_time": "120小时",
			"logo_path": "",
			"executable_path": "games/starcraft2/game.exe",
			"installed": true,
			"favorite": true,
			"tags": ["策略", "RTS", "竞技"]
		},
		{
			"id": "local_008",
			"name": "英雄联盟",
			"title": "英雄联盟",
			"description": "全球最受欢迎的MOBA游戏，与好友一起征战召唤师峡谷。\n\n特色：\n- 160+个英雄选择\n- 精彩的团队战斗\n- 排位竞技系统",
			"author": "拳头游戏",
			"version": "14.15",
			"release_date": "2009-10-27",
			"last_played": "2024-08-03",
			"play_time": "300小时",
			"logo_path": "",
			"executable_path": "games/lol/game.exe",
			"installed": true,
			"favorite": false,
			"tags": ["MOBA", "团队", "竞技"]
		},
		{
			"id": "local_009",
			"name": "我的世界",
			"title": "我的世界",
			"description": "开放世界沙盒建造游戏，释放你的创造力。\n\n特色：\n- 无限的创造可能\n- 多人合作模式\n- 丰富的MOD支持",
			"author": "Mojang Studios",
			"version": "1.21.0",
			"release_date": "2011-11-18",
			"last_played": "2024-07-29",
			"play_time": "500小时",
			"logo_path": "",
			"executable_path": "games/minecraft/game.exe",
			"installed": false,
			"favorite": true,
			"tags": ["沙盒", "建造", "冒险"]
		},
		{
			"id": "local_010",
			"name": "守望先锋2",
			"title": "守望先锋2",
			"description": "团队射击游戏，英雄们集结在一起救世界。\n\n特色：\n- 35+个独特英雄\n- 快节奏团队战斗\n- 排位竞技模式",
			"author": "暴雪娱乐",
			"version": "2.13",
			"release_date": "2022-10-04",
			"last_played": "2024-08-01",
			"play_time": "80小时",
			"logo_path": "",
			"executable_path": "games/overwatch2/game.exe",
			"installed": true,
			"favorite": false,
			"tags": ["射击", "团队", "英雄"]
		},
		{
			"id": "local_011",
			"name": "原神",
			"title": "原神",
			"description": "开放世界冒险RPG游戏，探索提瓦特大陆的奥秘。\n\n特色：\n- 精美的二次元画风\n- 丰富的角色收集\n- 开放世界探索",
			"author": "米哈游",
			"version": "4.8.0",
			"release_date": "2020-09-28",
			"last_played": "2024-08-04",
			"play_time": "200小时",
			"logo_path": "",
			"executable_path": "games/genshin/game.exe",
			"installed": true,
			"favorite": true,
			"tags": ["RPG", "冒险", "二次元"]
		},
		{
			"id": "local_012",
			"name": "赛博朋克2077",
			"title": "赛博朋克2077",
			"description": "未来科幻开放世界RPG，体验赛博朋克的生活。\n\n特色：\n- 沉浸式未来世界\n- 多分支剧情\n- 高度自定义角色",
			"author": "CD Projekt RED",
			"version": "2.12",
			"release_date": "2020-12-10",
			"last_played": "2024-07-20",
			"play_time": "60小时",
			"logo_path": "",
			"executable_path": "games/cyberpunk2077/game.exe",
			"installed": true,
			"favorite": false,
			"tags": ["RPG", "科幻", "开放世界"]
		},
		{
			"id": "local_013",
			"name": "巫师3：狂猎",
			"title": "巫师3：狂猎",
			"description": "史诗级奇幻RPG冒险，跟随利维亚的传奇冒险。\n\n特色：\n- 庞大的开放世界\n- 深度的剧情体验\n- 丰富的支线任务",
			"author": "CD Projekt RED",
			"version": "4.04",
			"release_date": "2015-05-19",
			"last_played": "2024-07-15",
			"play_time": "150小时",
			"logo_path": "",
			"executable_path": "games/witcher3/game.exe",
			"installed": false,
			"favorite": true,
			"tags": ["RPG", "奇幻", "冒险"]
		},
		{
			"id": "local_014",
			"name": "艾尔登法环",
			"title": "艾尔登法环",
			"description": "开放世界魂系列动作RPG，挑战传说中的艾尔登法环。\n\n特色：\n- 开放世界设计\n- 高难度战斗\n- 精美的视觉效果",
			"author": "FromSoftware",
			"version": "1.12.2",
			"release_date": "2022-02-25",
			"last_played": "2024-08-02",
			"play_time": "90小时",
			"logo_path": "",
			"executable_path": "games/eldenring/game.exe",
			"installed": true,
			"favorite": true,
			"tags": ["RPG", "动作", "魂系"]
		},
		{
			"id": "local_015",
			"name": "DOTA 2",
			"title": "DOTA 2",
			"description": "经典MOBA竞技游戏，与全世界玩家一起战斗。\n\n特色：\n- 120+个独特英雄\n- 深度的策略玩法\n- 全球电竞赛事",
			"author": "Valve",
			"version": "7.36d",
			"release_date": "2013-07-09",
			"last_played": "2024-07-28",
			"play_time": "400小时",
			"logo_path": "",
			"executable_path": "games/dota2/game.exe",
			"installed": true,
			"favorite": false,
			"tags": ["MOBA", "策略", "竞技"]
		}
	]
	
	# 应用当前过滤器
	apply_filter()
	
	# 显示游戏卡片
	display_games()

func apply_filter():
	"""应用当前的搜索和过滤条件"""
	filtered_games_data.clear()
	
	for game in local_games_data:
		var matches_search = true
		var matches_filter = true
		
		# 搜索过滤
		if current_search_text != "":
			var search_lower = current_search_text.to_lower()
			matches_search = (
				game.name.to_lower().contains(search_lower) or
				game.title.to_lower().contains(search_lower) or
				game.author.to_lower().contains(search_lower) or
				game.description.to_lower().contains(search_lower)
			)
		
		# 类别过滤
		match current_filter:
			"recent":
				# 最近7天内玩过的游戏
				matches_filter = is_recently_played(game)
			"favorites":
				matches_filter = game.favorite
			"installed":
				matches_filter = game.installed
			"all":
				matches_filter = true
		
		if matches_search and matches_filter:
			filtered_games_data.append(game)
	
	# 按最后游玩时间排序
	filtered_games_data.sort_custom(func(a, b): return a.last_played > b.last_played)

func is_recently_played(game_data: Dictionary) -> bool:
	"""检查游戏是否在最近7天内玩过"""
	# 这里简化处理，实际应该解析日期
	var last_played = game_data.get("last_played", "")
	return last_played.contains("2024-08") or last_played.contains("2024-07-2")

func display_games():
	"""显示游戏卡片（分页显示）"""
	# 清除现有卡片
	for child in game_grid.get_children():
		child.queue_free()
	
	# 重置选择状态
	selected_game_card = null
	
	if filtered_games_data.is_empty():
		status_label.text = "未找到符合条件的游戏"
		status_label.visible = true
		update_pagination_ui()
		return
	
	status_label.visible = false
	
	# 计算分页
	total_pages = max(1, ceili(float(filtered_games_data.size()) / float(games_per_page)))
	current_page = min(current_page, total_pages - 1)
	
	# 获取当前页的游戏数据
	var start_index = current_page * games_per_page
	var end_index = min(start_index + games_per_page, filtered_games_data.size())
	
	# 创建当前页的游戏卡片
	for i in range(start_index, end_index):
		var game_data = filtered_games_data[i]
		var card = game_card_scene.instantiate()
		game_grid.add_child(card)
		
		# 设置游戏数据
		card.setup_game_data(game_data)
		
		# 连接选择信号
		card.game_selected.connect(_on_game_card_selected)
		
		# 显示卡片
		card.show()
	
	update_status_label()
	update_pagination_ui()

func update_status_label():
	"""更新状态标签"""
	var total_games = local_games_data.size()
	var displayed_games = filtered_games_data.size()
	var installed_games = local_games_data.filter(func(game): return game.installed).size()
	
	status_label.text = "共 %d 款游戏 | 已安装 %d 款 | 显示 %d 款" % [total_games, installed_games, displayed_games]
	status_label.visible = true

func _on_game_card_selected(game_data: Dictionary):
	"""游戏卡片被选择"""
	print("选择了游戏: ", game_data.title)
	
	# 停止所有其他卡片的闪烁
	for card in game_grid.get_children():
		if card.has_method("stop_continuous_shine"):
			card.stop_continuous_shine()
	
	# 发射选择信号
	game_selected.emit(game_data)
	
	# 这里可以添加启动游戏的逻辑
	launch_game(game_data)

func launch_game(game_data: Dictionary):
	"""启动游戏"""
	if not game_data.installed:
		PopupManager.show_message("游戏未安装，请先安装游戏。", "提示", false)
		return
	
	var executable_path = game_data.get("executable_path", "")
	if executable_path == "":
		PopupManager.show_message("找不到游戏执行文件。", "错误", false)
		return
	
	print("启动游戏: ", executable_path)
	# 这里应该调用系统API启动游戏
	# OS.execute(executable_path, [])
	
	# 模拟启动成功
	PopupManager.show_message("正在启动 " + game_data.title + "...", "启动游戏", false)

func _on_search_pressed():
	"""搜索按钮被点击"""
	_on_search_submitted(search_bar.text)

func _on_search_submitted(search_text: String):
	"""搜索提交"""
	current_search_text = search_text.strip_edges()
	apply_filter()
	display_games()
	print("搜索: ", current_search_text)

func _on_filter_pressed():
	"""过滤按钮被点击"""
	# 循环切换过滤器
	match current_filter:
		"all":
			current_filter = "recent"
			filter_button.text = "最近游玩"
		"recent":
			current_filter = "favorites"
			filter_button.text = "我的收藏"
		"favorites":
			current_filter = "installed"
			filter_button.text = "已安装"
		"installed":
			current_filter = "all"
			filter_button.text = "全部游戏"
	
	apply_filter()
	display_games()
	print("过滤器: ", current_filter)

func _on_refresh_pressed():
	"""刷新按钮被点击"""
	print("刷新游戏列表")
	load_local_games()

func _on_settings_pressed():
	"""设置按钮被点击"""
	print("打开设置")
	# 这里可以打开设置界面
	SettingsManager.show_settings()

func update_pagination_ui():
	"""更新分页UI"""
	if total_pages <= 1:
		# 只有一页或没有数据，隐藏分页控件
		prev_button.visible = false
		next_button.visible = false
		page_info_label.visible = false
	else:
		# 显示分页控件
		prev_button.visible = true
		next_button.visible = true
		page_info_label.visible = true
		
		# 更新按钮状态
		prev_button.disabled = (current_page <= 0)
		next_button.disabled = (current_page >= total_pages - 1)
		
		# 更新页面信息
		page_info_label.text = "第 %d 页 / 共 %d 页" % [current_page + 1, total_pages]

func _on_prev_page_pressed():
	"""上一页按钮被点击"""
	if current_page > 0:
		current_page -= 1
		display_games()
		print("切换到第 %d 页" % (current_page + 1))

func _on_next_page_pressed():
	"""下一页按钮被点击"""
	if current_page < total_pages - 1:
		current_page += 1
		display_games()
		print("切换到第 %d 页" % (current_page + 1))

func reset_all_cards_selection():
	"""重置所有卡片的选择状态，重新开始闪烁"""
	for card in game_grid.get_children():
		if card.has_method("reset_selection"):
			card.reset_selection()
	selected_game_card = null
