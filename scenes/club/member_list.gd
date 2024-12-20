extends Control

var member_item_scene = preload("res://scenes/club/member_item.tscn")
var user_details_scene = preload("res://scenes/club/user_details.tscn")
var add_member_dialog_scene = preload("res://scenes/club/add_member_dialog.tscn")
var members = []
var group_id = ""
var group_name = ""
var filtered_members = []
var selected_item: Node = null  # 当前选中的俱乐部项
var isOp = false #是否进行了操作,操作后，返回界面则刷新俱乐部列表

func _ready():
	$VBoxContainer/Header/BackButton.pressed.connect(_on_back_button_pressed)
	$VBoxContainer/Header/AddButton.pressed.connect(_on_add_button_pressed)
	$VBoxContainer/SearchBar/MarginContainer/SearchInput.text_changed.connect(_on_search_text_changed)

func setup(group_data: Dictionary):
	$VBoxContainer/Header/GroupName.text = group_data["name"]
	group_id = group_data["id"]
	group_name = group_data["name"]
	
	isOp = false
	# 刷新成员数据
	update_member_list()

func update_member_list():
	# 清除现有项目
	for child in $VBoxContainer/ScrollContainer/MemberContainer.get_children():
		child.queue_free()
	
	# 拉取最新数据
	members = []
	var result = await Network.get_group_member_list_async(group_id)
	if result:
		print("更新俱乐部信息:", result)
		for info in result.group_users:
			if info.state == 3:
				continue
			var member = info.user
			members.append({
				"id": member.id, 
				"name": member.username, 
				"avatar": member.avatar_url, 
				"status": "在线"if member.online else "离线",
				"signature": member.display_name, 
				"level": 15, 
				"score": 1500,
				"rank": 25, 
				"total_games": 150, 
				"win_rate": 0.65,
				"highest_score": 12800, 
				"average_score": 8500,
				"note": "",#"资深玩家"
			}
			)
	filtered_members = members.duplicate()

		# 排序
	filtered_members.sort_custom(func(a, b):
		var status_order = {"在线": 0, "离线": 1, "忙碌": 2, "隐身": 3}
		if a.has("status") and b.has("status"):
			return status_order[a["status"]] < status_order[b["status"]] 
		return false
	)

	# 添加成员项目
	for member in filtered_members:
		add_member_item(member)

func add_member_item(member_data: Dictionary):
	var member_item = member_item_scene.instantiate()
	$VBoxContainer/ScrollContainer/MemberContainer.add_child(member_item)
	member_item.setup(member_data)
	member_item.member_selected.connect(_on_member_selected)
	member_item.member_deleted.connect(_on_member_deleted)
	member_item.member_band.connect(_on_member_band)
	member_item.member_add_friend.connect(_on_member_add_friend)
	member_item.member_clicked.connect(func(): _on_member_clicked(member_item))
	
	
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
	for member in filtered_members:
		if member["id"] == member_data["id"]:
			return 
	# 查找用户ID
	if not member_data["id"].is_empty() and member_data["id"].length() <16:
		var result = await Network.search_users(member_data["id"])
		print("好友搜索",result,member_data["id"])
		if result and result.users.size() > 0:
			var ret = await Network.add_group_users_async(group_id, [result.users[0].id])
			if not ret:
				PopupManager.show_message("添加失败")
				return	
	isOp = true
	update_member_list()

func _on_member_deleted(member_id: String):
	var ret = await Network.remove_gourp_user(group_id, member_id)
	if not ret:
		PopupManager.show_message("删除失败")
		return
	isOp = true
	# members = members.filter(func(m): return m["id"] != member_id)
	# filtered_members = filtered_members.filter(func(m): return m["id"] != member_id)
	update_member_list()
	# 删除成功后返回主列表
	# queue_free() 

func _on_member_band(member_id: String):
	var ret = await Network.ban_group_users_async(group_id, member_id)
	if not ret:
		PopupManager.show_message("拉黑失败")
		return
	isOp = true
	update_member_list()
	pass

func _on_member_add_friend(member_id: String):
	var data = DataManager.get_instance().get_uid_friendInfo(Network.player_data.id, member_id)
	if data:
		PopupManager.show_message("对方已是好友")
		return
	var ret = await Network.add_friends_async([member_id])
	if not ret:
		PopupManager.show_message("添加好友失败")
		return
	PopupManager.show_message("已请求,需等待审批")
	pass

func _on_member_clicked(item: Node):
	var sleceteNode = selected_item
	if sleceteNode != null:
		sleceteNode.setup_panel_style(false)
	if item:
		item.setup_panel_style(true)
	selected_item = item

func _on_member_note_changed(member_data: Dictionary, new_note: String):
	for member in members:
		if member["id"] == member_data["id"]:
			member["note"] = new_note
			break
	update_member_list()

func _on_back_button_pressed():
	if isOp:
		SignalManager.UpdateClubSIG.emit(group_name)
	queue_free()


# 模拟成员数据
	# members = [
		# {
		# 	"id": 1, "name": "用户1", "avatar": null, "status": "在线",
		# 	"signature": "热爱游戏的开发者", "level": 15, "score": 1500,
		# 	"rank": 25, "total_games": 150, "win_rate": 0.65,
		# 	"highest_score": 12800, "average_score": 8500,
		# 	"note": "资深玩家"
		# },
		# {
		# 	"id": 2, "name": "用户2", "avatar": null, "status": "离线",
		# 	"signature": "游戏设计爱好者", "level": 8, "score": 800,
		# 	"rank": 68, "total_games": 80, "win_rate": 0.45,
		# 	"highest_score": 9600, "average_score": 6200,
		# 	"note": ""
		# },
		# {
		# 	"id": 3, "name": "用户3", "avatar": null, "status": "忙碌",
		# 	"signature": "休闲玩家", "level": 12, "score": 1200,
		# 	"rank": 42, "total_games": 120, "win_rate": 0.55,
		# 	"highest_score": 10400, "average_score": 7300,
		# 	"note": "积极参与者"
		# },
		# {
		# 	"id": 4, "name": "开发者A", "avatar": null, "status": "在线",
		# 	"signature": "开发者", "level": 20, "score": 2000,
		# 	"rank": 10, "total_games": 200, "win_rate": 0.75,
		# 	"highest_score": 16000, "average_score": 10000,
		# 	"note": ""
		# },
		# {
		# 	"id": 5, "name": "设计师B", "avatar": null, "status": "离线",
		# 	"signature": "设计师", "level": 18, "score": 1800,
		# 	"rank": 15, "total_games": 180, "win_rate": 0.70,
		# 	"highest_score": 14000, "average_score": 9000,
		# 	"note": ""
		# },
	# ]
