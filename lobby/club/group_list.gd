extends Control
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer

var group_item_scene = preload("res://lobby/club/group_item.tscn")
var member_list_scene = preload("res://lobby/club/member_list.tscn")
var join_group_dialog_scene = preload("res://lobby/club/join_group_dialog.tscn")
var create_group_dialog_scene = preload("res://lobby/club/create_group_dialog.tscn")

var groups = []
var filtered_groups = []
var current_selected_item: Node = null  # 当前选中的俱乐部项
var is_ascending = false

enum MgrType { CREATE, JOIN }
enum SortType { NAME, MEMBER_COUNT, UPDATE_TIME }
var current_sort = SortType.UPDATE_TIME

# 定义颜色常量
const NORMAL_COLOR = Color(0.02, 0.388, 0.576)  # 普通状态为灰色
# const HOVER_COLOR = Color(1, 1, 1, 1)  # 悬浮状态为亮色（白色）
# const SELECTED_COLOR = Color.YELLOW # 选中状态为黄色


func _ready():
	# 设置管理菜单
	var mgrPopup = $VBoxContainer/SearchBar/MarginContainer/HBoxContainer/ManagerButton.get_popup()
	# 基本设置
	mgrPopup.add_theme_constant_override("item_height", 80)
	mgrPopup.add_theme_constant_override("v_separation", 5)
	
	# 设置字体
	 
	# 设置样式
	var style = StyleBoxFlat.new()
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.bg_color = NORMAL_COLOR
	mgrPopup.add_theme_stylebox_override("panel", style)

	mgrPopup.add_item("创建俱乐部", MgrType.CREATE)
	mgrPopup.add_item("加入俱乐部", MgrType.JOIN)
	mgrPopup.id_pressed.connect(_on_mgr_selected)
	mgrPopup.reset_size()
	# 设置排序菜单
	var popup = $VBoxContainer/SearchBar/MarginContainer/HBoxContainer/SortButton.get_popup()
	popup.add_item("按名称排序", SortType.NAME)
	popup.add_item("按成员数排序", SortType.MEMBER_COUNT)
	popup.add_item("按更新时间排序", SortType.UPDATE_TIME)
	popup.id_pressed.connect(_on_sort_selected)

	# 连接搜索信号
	$VBoxContainer/SearchBar/MarginContainer/HBoxContainer/SearchInput.text_changed.connect(_on_search_text_changed)
	Global.SignalMgr.OpenLightSIG.connect(_on_turnOnLight)
	Global.SignalMgr.CloseLightSIG.connect(_on_turnOffLight)
	pass

func clear() :
	groups = []
	current_selected_item = null
	pass

func update_group_list():
	# 清除现有项目
	for child in $VBoxContainer/ScrollContainer/GroupContainer.get_children():
		child.queue_free()
	
	# 排序
	filtered_groups.sort_custom(func(a, b):
		if current_sort == SortType.UPDATE_TIME and a.has("update_time") and b.has("update_time"):
			var time_a = Time.get_unix_time_from_datetime_string(a["update_time"])
			var time_b = Time.get_unix_time_from_datetime_string(b["update_time"])
			return time_a < time_b if is_ascending else time_b < time_a
			
		elif current_sort == SortType.NAME and a.has("name") and b.has("name"):
			return a["name"] < b["name"] if is_ascending else b["name"] < a["name"]
			
		elif a.has("member_count") and b.has("member_count"):
			return a["member_count"] < b["member_count"] if is_ascending else b["member_count"] < a["member_count"]
		
		return false  # 如果没有可比较的字段，返回 false
	)
	 
	# 添加排序后的项目
	var preGroup = null
	for group in filtered_groups:
		if preGroup and preGroup["id"] == group["id"]:
			continue
		var group_item = group_item_scene.instantiate()
		$VBoxContainer/ScrollContainer/GroupContainer.add_child(group_item)
		group_item.setup(group)
		group_item.tooltip_text = group["description"]+"\n创建时间:" + Util.get_chinese_time_str(group["create_time"])
		group_item.group_selected.connect(func(data): _on_group_selected(data, group_item))
		group_item.group_clicked.connect(func(): _on_cliecked_group(group_item))
		group_item.group_left.connect(_on_group_left)
		group_item.notification_toggled.connect(_on_notification_toggled)
		preGroup = group
	pass


func _on_cliecked_group(item: Node):
	if current_selected_item != null:
		current_selected_item.setup_panel_style(false)
	current_selected_item = item	
	if item != null:
		item.setup_panel_style(true)
		var clubInfo = item.get_group_data()
		await Global.OnlineChat.set_current_channel(clubInfo.channel, true) 
		


func _on_group_selected(group_data: Dictionary, item: Node):
	if current_selected_item:
		current_selected_item.setup_panel_style(false)
	current_selected_item = item 
	# 这里可以添加其他选中俱乐部后的逻辑
	print("选中的群组信息:", group_data)

	var member_list = member_list_scene.instantiate()
	add_child(member_list)
	member_list.setup(group_data)
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
	is_ascending = !is_ascending
	update_group_list()

func _on_join_button_pressed():
	var dialog = join_group_dialog_scene.instantiate()
	add_child(dialog)
	# dialog.group_joined.connect(_on_group_joined)
	pass

func _on_create_button_pressed():
	var dialog = create_group_dialog_scene.instantiate()
	add_child(dialog)
	# dialog.group_created.connect(_on_group_created)
	pass
 
func _on_group_created(group):
	groups.append({
				"id": group.id,
				"name": group.name,
				"channelId":"",
				"avatar":group.avatar_url,
				"description": group.description,
				"member_count": group.edge_count,
				"max_count": group.max_count,
				"notification_enabled": group.open,
				"owner_id":group.creator_id,
				"create_time":group.create_time,
				"update_time":group.update_time,
			})
	filtered_groups = groups.duplicate()
	update_group_list()
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

func _on_group_updated(group_data):
	for i in range(groups.size()):
		if groups[i]["id"] == group_data["id"]:
			if not group_data["channel"]:
				group_data["channel"] = groups[i].channel
			groups[i] = group_data
			break
	filtered_groups = groups.duplicate()
	update_group_list()

func _on_notification_toggled(group_data, enabled):
	for group in groups:
		if group["id"] == group_data["id"]:
			group["notification_enabled"] = enabled
			break

func _on_turnOnLight():
	var new_style = StyleBoxFlat.new()
	new_style.bg_color = Color(0.137, 0.536, 0.85, 0.914)
	scroll_container.set("theme_override_styles/panel", new_style)
	pass

func _on_turnOffLight():
	var new_style = StyleBoxFlat.new()
	new_style.bg_color = Color(0.042, 0.33, 0.544, 0.914)
	scroll_container.set("theme_override_styles/panel", new_style)
	pass
##############################
func GetCurrentItemData():
	if not current_selected_item:
		return null
	return current_selected_item.get_group_data()
