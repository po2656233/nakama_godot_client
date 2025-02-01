extends Control
@onready var _search_box: LineEdit = $Panel/HBoxContainer/LineEdit_find
@onready var _list: ItemList = $Panel/ScrollContainer/ItemList

@export var placeholder_text: String = "提示文本"
@export var isClub: bool = false

var popup_menu: PopupMenu
var selected_index: int = -1  # 用于存储当前选中的项目索引
var isNothing = false

#长按选中
var long_press_time = 1.0  # 长按时间（秒）
var press_start_time = 0.0
var is_long_press = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 取消窗口拖动
	WindowDrag.unregister_drag_zone(self)
	_search_box.placeholder_text = placeholder_text
	# Create the popup menu
	popup_menu = PopupMenu.new()
	popup_menu.set_size(Vector2(20, 10))
	if isClub:
		popup_menu.add_item("加入")
		# popup_menu.add_item("退出")
	else:
		popup_menu.add_item("添加好友")
	add_child(popup_menu)
	popup_menu.id_pressed.connect(_on_popup_menu_item_selected)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_popup_menu_item_selected(id: int):
	# Handle the "Add" button press
	if id == 0:  # First item in the menu
		# 处理添加按钮的点击事件
		_on_tb_add_pressed()
	pass

	# elif id == 1:  # Second item in the menu
	#     clubListItem.add_item("添加俱乐部")

func _on_line_edit_find_text_submitted(new_text:String):
	if new_text == "":
		return
	isNothing = false
	if isClub:
		var result = await Online.nakama_client.search_groups(new_text)
		print("俱乐部搜索",result)
		_list.clear()
		if result == null or result.groups.size() == 0:
			_list.add_item("没有找到")
			isNothing = true
			return
		for club in result.groups:
			var texture:Texture2D
			if club.avatar_url:
				texture = await Util.load_texture_async(club.avatar_url)
			# var index = _list.add_item_with_buttons(user.username,texture,"添加",Callable(Network,"add_friends_async").bind(user.id))
			var index = _list.add_item(club.name,texture)
			if index != -1:
				_list.set_item_metadata(index,club)
	else:
		var result = await Online.nakama_client.search_users(new_text)
		print("好友搜索",result)
		_list.clear()
		if result == null or result.users.size() == 0:
			_list.add_item("没有找到")
			isNothing = true 
			return
		for user in result.users:
			var texture:Texture2D
			if user.avatar_url:
				texture = await Util.load_texture_async(user.avatar_url)
			# var index = _list.add_item_with_buttons(user.username,texture,"添加",Callable(Network,"add_friends_async").bind(user.id))
			var index = _list.add_item(user.username,texture)
			if index != -1:
				_list.set_item_metadata(index,user)
			print('信息',user.id,user.username,user.display_name,user.avatar_url)
		# emit_signal("search_room",new_text)
	pass # Replace with function body.





func _on_item_list_gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			press_start_time = Time.get_ticks_msec()
			if event.button_index == MOUSE_BUTTON_RIGHT  and not isNothing:
				popup_menu.position = get_viewport().get_mouse_position()
				popup_menu.popup()
		else:
			var press_duration = (Time.get_ticks_msec() - press_start_time) / 1000.0
			if press_duration >= long_press_time and not isNothing:
				popup_menu.position = get_viewport().get_mouse_position()
				popup_menu.popup()
	pass # Replace with function body.


func _on_item_list_item_selected(index:int) -> void:
	selected_index = index
	print("点击",index)
	pass # Replace with function body.


func _on_item_list_item_clicked(index:int, _at_position:Vector2, _mouse_button_index:int) -> void:
	selected_index = index
	print("选择点击",index)
	pass # Replace with function body.


func _on_tb_add_pressed() -> void:
	var selected_items = _list.get_selected_items()
	var ids = []
	if not OnlineChat.player_data:
		PopupManager.show_message("未登录")
		return
	var uid = OnlineChat.player_data.id
	for item in selected_items:
		var info = _list.get_item_metadata(selected_index)
		if info:
			var friend = DataManager.get_instance().get_uid_friendInfo(uid,info.id)
			if friend:
				PopupManager.show_message("已是好友,请勿重复添加")
				return
			ids.append(info.id)
		pass
	if ids.size() == 0:
		# 创建俱乐部
		if isClub:
			var result = await Online.nakama_client.create_group_async(Online.nakama_session,_search_box.text)
			if result:
				PopupManager.show_message("创建俱乐部成功")
			else:
				PopupManager.show_message("创建俱乐部失败")
		else:
			PopupManager.show_message("没有选中用户")
		return

	# 添加俱乐部
	if isClub:
		for id in ids:
			await Online.nakama_client.add_group_async(id)
		return

	# 添加好友
	var ret = await Online.nakama_client.add_friends_async(ids)	
	if ret:
		PopupManager.show_message("已添加,请等待对方通过")
		_list.clear()
		_search_box.text = ""
	else:
		PopupManager.show_message("添加失败")

	pass # Replace with function body.


func _on_line_edit_find_text_changed(new_text:String) -> void:
	if new_text == "":
		_list.clear()
		return
	_on_line_edit_find_text_submitted(new_text)
	pass # Replace with function body.
