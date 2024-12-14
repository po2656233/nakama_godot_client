extends Control

var group_item_scene = preload("res://scenes/club/group_item.tscn")
var member_list_scene = preload("res://scenes/club/member_list.tscn")
var join_group_dialog_scene = preload("res://scenes/club/join_group_dialog.tscn")
var create_group_dialog_scene = preload("res://scenes/club/create_group_dialog.tscn")

var groups = []
var filtered_groups = []
var current_selected_item: Node = null  # 当前选中的群组项
enum SortType { NAME, MEMBER_COUNT }
var current_sort = SortType.NAME

enum MgrType { CREATE, JOIN }


func _ready():
	# 设置管理菜单
	var mgrPopup = $VBoxContainer/SearchBar/MarginContainer/HBoxContainer/ManagerButton.get_popup()
	mgrPopup.add_item("创建群组", MgrType.CREATE)
	mgrPopup.add_item("加入群组", MgrType.JOIN)
	mgrPopup.id_pressed.connect(_on_mgr_selected)
	
	# 设置排序菜单
	var popup = $VBoxContainer/SearchBar/MarginContainer/HBoxContainer/SortButton.get_popup()
	popup.add_item("按名称排序", SortType.NAME)
	popup.add_item("按成员数排序", SortType.MEMBER_COUNT)
	popup.id_pressed.connect(_on_sort_selected)

	# 连接搜索信号
	$VBoxContainer/SearchBar/MarginContainer/HBoxContainer/SearchInput.text_changed.connect(_on_search_text_changed)
	
	# 连接按钮信号
	$VBoxContainer/Header/HBoxContainer/JoinButton.pressed.connect(_on_join_button_pressed)
	$VBoxContainer/Header/HBoxContainer/CreateButton.pressed.connect(_on_create_button_pressed)
	
	# 模拟数据
	groups = [
		{
			"id": 1,
			"name": "技术交流群",
			"description": "技术分享与交流",
			"member_count": 120,
			"notification_enabled": false,
			"owner_id": 1
		},
		{
			"id": 2,
			"name": "游戏开发群",
			"description": "游戏开发经验分享",
			"member_count": 85,
			"notification_enabled": true,
			"owner_id": 2
		},
		{
			"id": 3,
			"name": "产品设计群",
			"description": "产品设计与用户体验",
			"member_count": 56,
			"notification_enabled": true,
			"owner_id": 3
		},
		{
			"id": 4,
			"name": "UI设计交流",
			"description": "界面设计与交互体验",
			"member_count": 92,
			"notification_enabled": true,
			"owner_id": 4
		},
		{
			"id": 5,
			"name": "程序员之家",
			"description": "程序员日常交流",
			"member_count": 150,
			"notification_enabled": true,
			"owner_id": 5
		}
	]
	
	filtered_groups = groups.duplicate()
	update_group_list()

func update_group_list():
	# 清除现有项目
	for child in $VBoxContainer/ScrollContainer/GroupContainer.get_children():
		child.queue_free()
	
	# 排序
	filtered_groups.sort_custom(func(a, b):
		if current_sort == SortType.NAME:
			return a["name"] < b["name"]
		else:
			return a["member_count"] > b["member_count"]
	)
	
	# 添加排序后的项目
	for group in filtered_groups:
		var group_item = group_item_scene.instantiate()
		$VBoxContainer/ScrollContainer/GroupContainer.add_child(group_item)
		group_item.setup(group)
		group_item.group_selected.connect(func(data): _on_group_selected(data, group_item))
		group_item.group_clicked.connect(func(): _on_cliecked_group(group_item))
		group_item.group_left.connect(_on_group_left)
		group_item.notification_toggled.connect(_on_notification_toggled)

func _clear_group_selection():
	if current_selected_item:
		current_selected_item = null

func _on_cliecked_group(item: Node):
	if current_selected_item:
		current_selected_item.style.bg_color = Color(0.019, 0.388, 0.575) 
	item.style.bg_color =  Color.GREEN
	current_selected_item = item

func _on_group_selected(group_data: Dictionary, item: Node):
	if current_selected_item != item:
		_clear_group_selection()
		current_selected_item = item 
	# 这里可以添加其他选中群组后的逻辑
	var member_list = member_list_scene.instantiate()
	add_child(member_list)
	member_list.setup(group_data)

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
	dialog.group_joined.connect(_on_group_joined)

func _on_create_button_pressed():
	var dialog = create_group_dialog_scene.instantiate()
	add_child(dialog)
	dialog.group_created.connect(_on_group_created)

func _on_group_created(group_data):
	groups.append(group_data)
	filtered_groups = groups.duplicate()
	update_group_list()

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
