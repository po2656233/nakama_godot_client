extends Control

var game_card_scene = preload("res://scenes/gamelist/game_card.tscn")

@onready var game_list = $Background/MarginContainer/VBoxContainer/HBoxContainer/ScrollContainer/MarginContainer/HBoxContainer
@onready var scrollContainer = $Background/MarginContainer/VBoxContainer/HBoxContainer/ScrollContainer
@onready var matchSuccess = $MatchSuccess

# 示例游戏数据
var games_data =[]
# var games_data =[
# 	{
# 		"title": "Adventure Quest",
# 		"description": "[center][b]史诗冒险之旅[/b][/center]\n\n在这个充满魔法和神秘的世界中，你将扮演一位勇敢的冒险者，探索未知的土地，与强大的怪物战斗，解开古老的谜题。\n\n[b]特色：[/b]\n- 开放世界探索\n- 丰富的任务系统\n- 独特的战斗机制",
# 		# "image": preload("res://icon.svg"),
# 		"selectTime": Time.get_datetime_dict_from_system(),
# 	},
# 	{
# 		"title": "Space Explorer",
# 		"description": "[center][b]星际探索[/b][/center]\n\n穿越星际，探索未知的星系。在这个科幻世界中，你将指挥自己的飞船，与外星文明接触，发现宇宙的奥秘。\n\n[b]特色：[/b]\n- 真实的物理系统\n- 多样的星球生态\n- 深度的剧情体验",
# 		# "image": preload("res://assets/placeholder.svg"),
# 		"selectTime": Time.get_datetime_dict_from_system(),
# 	},
# 	{
# 		"title": "Racing Master",
# 		"description": "[center][b]极速赛车大师[/b][/center]\n\n体验极速与激情！在世界各地的赛道上展现你的驾驶技巧，解锁各种精美的赛车，成为赛道之王。\n\n[b]特色：[/b]\n- 真实的赛车物理\n- 丰富的赛道选择\n- 多人在线竞技",
# 		# "image": preload("res://assets/placeholder.svg"),
# 		"selectTime": Time.get_datetime_dict_from_system(),
# 	},
# 	{
# 		"title": "Puzzle World",
# 		"description": "[center][b]解谜世界[/b][/center]\n\n进入一个充满智慧挑战的世界。解开错综复杂的谜题，探索隐藏的秘密，提升你的逻辑思维能力。\n\n[b]特色：[/b]\n- 渐进的难度曲线\n- 独特的解谜机制\n- 精美的艺术风格",
# 		# "image": preload("res://assets/placeholder.svg"),
# 		"selectTime": Time.get_datetime_dict_from_system(),
# 	}
# ]

func _ready(): 
	# WindowDrag.register_drag_zone(self) 
	SettingsManager.show_settings() 
	scrollContainer.get_h_scroll_bar().custom_minimum_size.y = 25
	# 获取游戏列表
	var result = await Network.sendDataRPC("list_games")
	print("获取游戏列表",result)
	if result and result.id == "list_games":
		var games = JSON.parse_string(result.payload)
		for item in games:
			var description = "[center][b][color=yellow]"+item.name+"[/color][/b][/center]\n\n规则介绍:\n[color=black]"+item.how_to_play+"[/color]"
			if item.special:
				description += "\n\n[b]特色：[/b][color=read]\n"+item.special+"[/color]"
			games_data.append({
				"id": item.id,
				"title": item.en_name,
				"description": description,
				"image": item.logo,
				"version": item.updated_at,
			})
	# 添加游戏
	for item in games_data:
		on_add_game_data(item)
	pass

# 添加游戏
func on_add_game_data(data):
	var card = game_card_scene.instantiate()
	game_list.add_child(card)
	card.setup(data)
	card.game_selected.connect(_on_game_selected)


# 游戏选择
func _on_game_selected(itemNode):
	game_list.move_child(itemNode,0)
	matchSuccess.visible = true
