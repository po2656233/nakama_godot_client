extends PanelContainer

signal member_selected(member_data)
signal member_deleted(member_data)
signal note_changed(member_data, new_note)

var member_data: Dictionary

func _ready():
	gui_input.connect(_on_gui_input)
	
	# 设置管理菜单
	var popup = $MarginContainer/HBoxContainer/ManageButton.get_popup()
	popup.add_item("修改备注", 0)
	popup.add_item("删除成员", 1)
	popup.id_pressed.connect(_on_manage_option_selected)

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
		$MarginContainer/HBoxContainer/Avatar.texture = data["avatar"]

func _on_gui_input(event):
	if event is InputEventMouseButton and event.double_click:
		member_selected.emit(member_data)

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
