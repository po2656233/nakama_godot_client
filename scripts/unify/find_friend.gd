extends Control
@onready var _search_box: LineEdit = $Panel/LineEdit_find
@onready var _list: ItemList = $Panel/ScrollContainer/ItemList

@export var placeholder_text: String = "提示文本"
@export var isClub: bool = false

signal addFinishSIG()
var popup_menu: PopupMenu
var selected_index: int = -1  # 用于存储当前选中的项目索引
var isNothing = false

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
		var info = _list.get_item_metadata(selected_index)
		if info:
			var ret = await Network.add_friends_async(info.id)
			if ret:
				print("添加",info)
				addFinishSIG.emit()
	pass

	# elif id == 1:  # Second item in the menu
	#     clubListItem.add_item("添加俱乐部")

func _on_line_edit_find_text_submitted(new_text:String):
	if new_text == "":
		return
	isNothing = false
	if isClub:
		var result = await Network.search_groups(new_text)
		print("俱乐部搜索",result)
		_list.clear()
		if result == null or result.groups.size() == 0:
			_list.add_item("没有找到")
			isNothing = true
			return
	else:
		var result = await Network.search_users(new_text)
		print("好友搜索",result)
		_list.clear()
		if result == null or result.users.size() == 0:
			_list.add_item("没有找到")
			isNothing = true
			return
		for user in result.users:
			var index = -1
			if user.avatar_url:
				var texture = await Network.load_texture_async(user.avatar_url)
				if texture:
					index = _list.add_item(user.username,texture)
			else:
				index = _list.add_item(user.username)
			if index != -1:
				_list.set_item_metadata(index,user)
			print('信息',user.id,user.username,user.display_name,user.avatar_url)
		# emit_signal("search_room",new_text)
	pass # Replace with function body.





func _on_item_list_gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not isNothing:
			popup_menu.position = get_viewport().get_mouse_position()
			popup_menu.popup()
			print("Popup menu item selected: ")
	pass # Replace with function body.


func _on_item_list_item_selected(index:int) -> void:
	selected_index = index
	print("点击",index)
	pass # Replace with function body.


func _on_item_list_item_clicked(index:int, _at_position:Vector2, _mouse_button_index:int) -> void:
	selected_index = index
	print("选择点击",index)
	pass # Replace with function body.
