extends Control
func _ready():
	$VBoxContainer/Header/BackButton.pressed.connect(_on_back_button_pressed)

func setup(user_data: Dictionary):
	# 设置基本信息
	$VBoxContainer/ScrollContainer/ContentContainer/BasicInfo/MarginContainer/HBoxContainer/VBoxContainer/Nickname.text = user_data["name"]
	$VBoxContainer/ScrollContainer/ContentContainer/BasicInfo/MarginContainer/HBoxContainer/VBoxContainer/Signature.text = user_data["signature"]
	
	if user_data["avatar"]:
		$VBoxContainer/ScrollContainer/ContentContainer/BasicInfo/MarginContainer/HBoxContainer/Avatar.texture =await Network.load_texture_async(user_data["avatar"]) 
	
	$VBoxContainer/ScrollContainer/ContentContainer/Stats/MarginContainer/HBoxContainer/Level/Value.text = str(user_data["level"])
	$VBoxContainer/ScrollContainer/ContentContainer/Stats/MarginContainer/HBoxContainer/Score/Value.text = str(user_data["score"])
	$VBoxContainer/ScrollContainer/ContentContainer/Stats/MarginContainer/HBoxContainer/Rank/Value.text = str(user_data["rank"])
	
	# 设置游戏统计
	var stats = $VBoxContainer/ScrollContainer/ContentContainer/GameStats/MarginContainer/VBoxContainer/GridContainer
	stats.get_node("TotalGames").text = "总场次：%d" % user_data["total_games"]
	stats.get_node("WinRate").text = "胜率：%.1f%%" % (user_data["win_rate"] * 100)
	stats.get_node("HighestScore").text = "最高分：%d" % user_data["highest_score"]
	stats.get_node("AverageScore").text = "平均分：%d" % user_data["average_score"]

func _on_back_button_pressed():
	queue_free()
