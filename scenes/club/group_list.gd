extends Control

var group_item_scene = preload("res://scenes/club/group_item.tscn")
var member_list_scene = preload("res://scenes/club/member_list.tscn")
var join_group_dialog_scene = preload("res://scenes/club/join_group_dialog.tscn")
var create_group_dialog_scene = preload("res://scenes/club/create_group_dialog.tscn")

var groups = []
var filtered_groups = []
var current_selected_item: Node = null  # 当前选中的俱乐部项
enum SortType { NAME, MEMBER_COUNT, UPDATE_TIME }
var current_sort = SortType.NAME

enum MgrType { CREATE, JOIN }


func _ready():
	# 设置管理菜单
	var mgrPopup = $VBoxContainer/SearchBar/MarginContainer/HBoxContainer/ManagerButton.get_popup()
	mgrPopup.add_item("创建俱乐部", MgrType.CREATE)
	mgrPopup.add_item("加入俱乐部", MgrType.JOIN)
	mgrPopup.id_pressed.connect(_on_mgr_selected)
	
	# 设置排序菜单
	var popup = $VBoxContainer/SearchBar/MarginContainer/HBoxContainer/SortButton.get_popup()
	popup.add_item("按名称排序", SortType.NAME)
	popup.add_item("按成员数排序", SortType.MEMBER_COUNT)
	popup.add_item("按更新时间排序", SortType.UPDATE_TIME)
	popup.id_pressed.connect(_on_sort_selected)

	# 连接搜索信号
	$VBoxContainer/SearchBar/MarginContainer/HBoxContainer/SearchInput.text_changed.connect(_on_search_text_changed)
	
	# 连接按钮信号
	$VBoxContainer/Header/HBoxContainer/JoinButton.pressed.connect(_on_join_button_pressed)
	$VBoxContainer/Header/HBoxContainer/CreateButton.pressed.connect(_on_create_button_pressed)
	pass

func clear() :
	_clear_group_selection()
	groups = []

func update_group_list():
	# 清除现有项目
	for child in $VBoxContainer/ScrollContainer/GroupContainer.get_children():
		child.queue_free()
	
	# 排序
	filtered_groups.sort_custom(func(a, b):
		if current_sort == SortType.UPDATE_TIME:
			return Time.get_unix_time_from_datetime_string(a["update_time"]) > Time.get_unix_time_from_datetime_string(b["update_time"])
		elif current_sort == SortType.NAME:
			return a["name"] < b["name"]
		else:
			return a["member_count"] > b["member_count"]
	)
	 
	# 添加排序后的项目
	for group in filtered_groups:
		var group_item = group_item_scene.instantiate()
		$VBoxContainer/ScrollContainer/GroupContainer.add_child(group_item)
		group_item.setup(group)
		group_item.tooltip_text = "创建于:" + Network.get_chinese_time_str(group["create_time"])
		group_item.group_selected.connect(func(data): _on_group_selected(data, group_item))
		group_item.group_clicked.connect(func(): _on_cliecked_group(group_item))
		group_item.group_left.connect(_on_group_left)
		group_item.notification_toggled.connect(_on_notification_toggled)

func _clear_group_selection():
	if current_selected_item:
		current_selected_item = null

func _on_cliecked_group(item: Node):
	var sleceteNode = current_selected_item
	if sleceteNode != null:
		sleceteNode.style.bg_color = Color(0.019, 0.388, 0.575) 
	if item != null:
		item.style.bg_color =  Color.GREEN
		var clubInfo = item.get_group_data()
		await Network.set_current_channel(clubInfo.channel, true) 
	current_selected_item = item

func _on_group_selected(group_data: Dictionary, item: Node):
	if current_selected_item != item:
		_clear_group_selection()
		current_selected_item = item 
	# 这里可以添加其他选中俱乐部后的逻辑
	print("选中的群组信息:", group_data)


	var member_list = member_list_scene.instantiate()
	add_child(member_list)
	member_list.setup(group_data)
		# 获取成员列表
	var result = await Network.get_group_member_list_async(group_data["id"])
	if not result:
		return
	for info in result.group_users:
		var member = info.user
		member_list._on_new_member_added(
			{
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
	pass
	

func _on_search_text_changed(new_text: String):
	filtered_groups = groups.filter(func(group):
		var search_text = new_text.to_lower()
		if search_text.is_empty():
			return true
		return group["name"].to_lower().contains(search_text) or \
			   (group.has("description") and group["description"].to_lower().contains(search_text))
	)
	update_group_list()

func _on_mgr_selected(id: int):
	var selectId = id as MgrType
	if selectId == MgrType.CREATE:
		_on_create_button_pressed()
	elif selectId == MgrType.JOIN:
		_on_join_button_pressed()
	pass


func _on_sort_selected(id: int):
	current_sort = id as SortType
	update_group_list()

func _on_join_button_pressed():
	var dialog = join_group_dialog_scene.instantiate()
	add_child(dialog)
	# dialog.group_joined.connect(_on_group_joined)

func _on_create_button_pressed():
	var dialog = create_group_dialog_scene.instantiate()
	add_child(dialog)
	dialog.group_created.connect(_on_group_created)

func _on_group_created(group_data):
	var result = await Network.create_group_async(group_data.name, group_data.description, group_data.avatar)
	if result:
		SignalManager.FreshClubListSIG.emit()
	pass

func _on_group_joined(group_data):
	groups.append(group_data)
	filtered_groups = groups.duplicate()
	update_group_list()

func _on_group_left(group_data):
	for i in range(groups.size()):
		if groups[i]["id"] == group_data["id"]:
			groups.remove_at(i)
			break
	filtered_groups = groups.duplicate()
	update_group_list()

func _on_notification_toggled(group_data, enabled):
	for group in groups:
		if group["id"] == group_data["id"]:
			group["notification_enabled"] = enabled
			break

func GetCurrentItemData():
	return current_selected_item.get_group_data()