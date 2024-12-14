extends Control

var member_item_scene = preload("res://scenes/club/member_item.tscn")
var user_details_scene = preload("res://scenes/club/user_details.tscn")
var add_member_dialog_scene = preload("res://scenes/club/add_member_dialog.tscn")
var members = []
var filtered_members = []

func _ready():
	$VBoxContainer/Header/BackButton.pressed.connect(_on_back_button_pressed)
	$VBoxContainer/Header/AddButton.pressed.connect(_on_add_button_pressed)
	$VBoxContainer/SearchBar/MarginContainer/SearchInput.text_changed.connect(_on_search_text_changed)

func setup(group_data: Dictionary):
	$VBoxContainer/Header/GroupName.text = group_data["name"]
	
	# 模拟成员数据
	members = [
		{
			"id": 1, "name": "用户1", "avatar": null, "status": "在线",
			"signature": "热爱游戏的开发者", "level": 15, "coins": 1500,
			"rank": 25, "total_games": 150, "win_rate": 0.65,
			"highest_score": 12800, "average_score": 8500,
			"note": "资深玩家"
		},
		{
			"id": 2, "name": "用户2", "avatar": null, "status": "离线",
			"signature": "游戏设计爱好者", "level": 8, "coins": 800,
			"rank": 68, "total_games": 80, "win_rate": 0.45,
			"highest_score": 9600, "average_score": 6200,
			"note": ""
		},
		{
			"id": 3, "name": "用户3", "avatar": null, "status": "忙碌",
			"signature": "休闲玩家", "level": 12, "coins": 1200,
			"rank": 42, "total_games": 120, "win_rate": 0.55,
			"highest_score": 10400, "average_score": 7300,
			"note": "积极参与者"
		},
		{
			"id": 4, "name": "开发者A", "avatar": null, "status": "在线",
			"signature": "开发者", "level": 20, "coins": 2000,
			"rank": 10, "total_games": 200, "win_rate": 0.75,
			"highest_score": 16000, "average_score": 10000,
			"note": ""
		},
		{
			"id": 5, "name": "设计师B", "avatar": null, "status": "离线",
			"signature": "设计师", "level": 18, "coins": 1800,
			"rank": 15, "total_games": 180, "win_rate": 0.70,
			"highest_score": 14000, "average_score": 9000,
			"note": ""
		},
	]
	
	filtered_members = members.duplicate()
	update_member_list()

func update_member_list():
	# 清除现有项目
	for child in $VBoxContainer/ScrollContainer/MemberContainer.get_children():
		child.queue_free()
	
	# 添加成员项目
	for member in filtered_members:
		add_member_item(member)

func add_member_item(member_data: Dictionary):
	var member_item = member_item_scene.instantiate()
	$VBoxContainer/ScrollContainer/MemberContainer.add_child(member_item)
	member_item.setup(member_data)
	member_item.member_selected.connect(_on_member_selected)
	member_item.member_deleted.connect(_on_member_deleted)
	member_item.note_changed.connect(_on_member_note_changed)

func _on_search_text_changed(new_text: String):
	filtered_members = members.filter(func(member):
		return member["name"].to_lower().contains(new_text.to_lower()) or \
			   (member.has("note") and member["note"].to_lower().contains(new_text.to_lower()))
	)
	update_member_list()

func _on_member_selected(member_data: Dictionary):
	var user_details = user_details_scene.instantiate()
	add_child(user_details)
	user_details.setup(member_data)

func _on_add_button_pressed():
	var dialog = add_member_dialog_scene.instantiate()
	add_child(dialog)
	dialog.member_added.connect(_on_new_member_added)

func _on_new_member_added(member_data: Dictionary):
	members.append(member_data)
	filtered_members = members.duplicate()
	update_member_list()

func _on_member_deleted(member_data: Dictionary):
	members = members.filter(func(m): return m["id"] != member_data["id"])
	filtered_members = filtered_members.filter(func(m): return m["id"] != member_data["id"])
	update_member_list()

func _on_member_note_changed(member_data: Dictionary, new_note: String):
	for member in members:
		if member["id"] == member_data["id"]:
			member["note"] = new_note
			break
	update_member_list()

func _on_back_button_pressed():
	queue_free()
