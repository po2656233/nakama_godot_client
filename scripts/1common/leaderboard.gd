extends Control

var home_scene = load("res://scenes/home.tscn")
# 排行榜类型枚举
enum RankType {
	DAILY,
	WEEKLY,
	MONTHLY,
	QUARTERLY,
	HALF_YEARLY,
	YEARLY
}

# 玩家数据结构
class PlayerScore:
	var player_name: String
	var score: int
	var rank: int
	var timestamp: int
	
	func _init(name: String, score_value: int, rank_value: int = 0):
		player_name = name
		score = score_value
		rank = rank_value
		timestamp = int(Time.get_unix_time_from_system())

# 节点引用
@onready var tab_container = $MarginContainer/VBoxContainer/TabContainer
var rank_lists = {}

# 模拟数据库
var leaderboard_data = {}

func _ready():
	# 初始化排行榜数据结构
	for type in RankType.values():
		leaderboard_data[type] = []
		
	# 获取所有排行榜容器引用
	rank_lists[RankType.DAILY] = $MarginContainer/VBoxContainer/TabContainer/"日排行"/RankList
	rank_lists[RankType.WEEKLY] = $MarginContainer/VBoxContainer/TabContainer/"周排行"/RankList
	rank_lists[RankType.MONTHLY] = $MarginContainer/VBoxContainer/TabContainer/"月排行"/RankList
	rank_lists[RankType.QUARTERLY] = $MarginContainer/VBoxContainer/TabContainer/"季度排行"/RankList
	rank_lists[RankType.HALF_YEARLY] = $MarginContainer/VBoxContainer/TabContainer/"年中排行"/RankList
	rank_lists[RankType.YEARLY] = $MarginContainer/VBoxContainer/TabContainer/"年终排行"/RankList
	
	# 添加一些测试数据
	add_test_data()
	
	# 更新所有排行榜显示
	update_all_leaderboards()

# 添加测试数据
func add_test_data():
	# 添加一些随机玩家数据用于测试
	var test_names = ["玩家A", "玩家B", "玩家C", "玩家D", "玩家E"]
	for type in RankType.values():
		for name1 in test_names:
			add_score(type, name1, randi_range(1000, 10000))

# 添加分数
func add_score(type: RankType, player_name: String, score: int):
	var player_score = PlayerScore.new(player_name, score)
	leaderboard_data[type].append(player_score)
	sort_leaderboard(type)
	update_leaderboard_display(type)

# 排序排行榜
func sort_leaderboard(type: RankType):
	leaderboard_data[type].sort_custom(func(a, b): return a.score > b.score)
	# 更新排名
	for i in range(leaderboard_data[type].size()):
		leaderboard_data[type][i].rank = i + 1

# 更新所有排行榜显示
func update_all_leaderboards():
	for type in RankType.values():
		update_leaderboard_display(type)

# 更新指定排行榜显示
func update_leaderboard_display(type: RankType):
	var rank_list = rank_lists[type]
	
	# 清除现有项目
	for child in rank_list.get_children():
		child.queue_free()
	
	# 添加新的排行项目
	for score_data in leaderboard_data[type]:
		add_rank_item(rank_list, score_data)

# 添加排行项目
func add_rank_item(rank_list: VBoxContainer, score_data: PlayerScore):
	var item = create_rank_item(score_data)
	rank_list.add_child(item)

# 创建排行项目
func create_rank_item(score_data: PlayerScore) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 50)
	panel.add_child(hbox)
	
	# 排名
	var rank_label = Label.new()
	rank_label.text = str(score_data.rank)
	rank_label.custom_minimum_size = Vector2(50, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(rank_label)
	
	# 玩家名称
	var name_label = Label.new()
	name_label.text = score_data.player_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)
	
	# 分数
	var score_label = Label.new()
	score_label.text = str(score_data.score)
	score_label.custom_minimum_size = Vector2(100, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(score_label)
	
	return panel

# 清除指定类型的排行榜数据
func clear_leaderboard(type: RankType):
	leaderboard_data[type].clear()
	update_leaderboard_display(type)

# 获取指定类型的前N名
func get_top_n(type: RankType, n: int) -> Array:
	var result = []
	for i in range(min(n, leaderboard_data[type].size())):
		result.append(leaderboard_data[type][i])
	return result

# 检查玩家是否在前N名
func is_in_top_n(type: RankType, player_name: String, n: int) -> bool:
	var top_players = get_top_n(type, n)
	for player in top_players:
		if player.player_name == player_name:
			return true
	return false

# 获取玩家在指定排行榜中的排名
func get_player_rank(type: RankType, player_name: String) -> int:
	for score_data in leaderboard_data[type]:
		if score_data.player_name == player_name:
			return score_data.rank
	return -1  # 未找到玩家


func _on_btn_out_pressed() -> void:
	FancyFade.circle_in(home_scene.instantiate())
	pass # Replace with function body.