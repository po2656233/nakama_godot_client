extends PanelContainer

signal member_selected(member_data)
signal member_deleted(member_data)
signal member_clicked()
signal note_changed(member_data, new_note)

var member_data: Dictionary

var style = StyleBoxFlat.new()
# 定义颜色常量
const NORMAL_COLOR = Color(0.9, 0.9, 0.9, 1)  # 普通状态为灰色
const HOVER_COLOR = Color(1, 1, 1, 1)  # 悬浮状态为亮色（白色）
const SELECTED_COLOR = Color(1, 0.95, 0.7, 1)  # 选中状态为黄色

func _ready():
	gui_input.connect(_on_gui_input)
	
	# 设置管理菜单
	var popup = $MarginContainer/HBoxContainer/ManageButton.get_popup()
	popup.add_item("修改备注", 0)
	popup.add_item("删除成员", 1)
	popup.id_pressed.connect(_on_manage_option_selected)

	# 设置默认样式
		# 初始化颜色
	self_modulate = NORMAL_COLOR
	_setup_panel_style(false)
	pass

func setup(data: Dictionary):
	member_data = data
	$MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/Name.text = data["name"]
	$MarginContainer/HBoxContainer/VBoxContainer/Status.text = data["status"]
	 
	# 显示备注
	var note_label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/Note
	if data.has("note") and not data["note"].is_empty():
		note_label.text = "(%s)" % data["note"]
	else:
		note_label.text = ""
	
	if data["avatar"]:
		$MarginContainer/HBoxContainer/Avatar.texture =await Network.load_texture_async(data["avatar"]) 

func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.double_click:
			member_selected.emit(member_data)
		elif event.is_pressed and event.button_index == MOUSE_BUTTON_LEFT:
			member_clicked.emit()
	pass

func _on_manage_option_selected(id: int):
	match id:
		0:  # 修改备注
			_show_note_dialog()
		1:  # 删除成员
			_show_delete_confirmation()

func _show_note_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "修改备注"
	
	var vbox = VBoxContainer.new()
	var note_edit = TextEdit.new()
	note_edit.custom_minimum_size = Vector2(300, 100)
	note_edit.placeholder_text = "输入备注"
	if member_data.has("note"):
		note_edit.text = member_data["note"]
	
	vbox.add_child(note_edit)
	dialog.add_child(vbox)
	
	add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func():
		var new_note = note_edit.text.strip_edges()
		note_changed.emit(member_data, new_note)
		dialog.queue_free()
	)

func _show_delete_confirmation():
	var dialog = ConfirmationDialog.new()
	dialog.title = "删除成员"
	dialog.dialog_text = "确定要删除该成员吗？"
	
	add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func():
		member_deleted.emit(member_data)
		dialog.queue_free()
	)

func _setup_panel_style(isSelected: bool):
	style.bg_color = Color.DARK_GREEN if isSelected else Color(0.019, 0.388, 0.575) 
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.1)  # 半透明黑色阴影
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	add_theme_stylebox_override("panel", style)
