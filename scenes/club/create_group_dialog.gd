extends Control

signal group_created(group_data)

var selected_avatar: Image

func _ready():
	$Panel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton.pressed.connect(_on_cancel_pressed)
	$Panel/MarginContainer/VBoxContainer/ButtonContainer/CreateButton.pressed.connect(_on_create_pressed)
	
	# 设置 TextureRect 可以接收输入
	var avatar_rect = $Panel/MarginContainer/VBoxContainer/Label/GroupAvatar
	avatar_rect.gui_input.connect(_on_avatar_gui_input)
	
	# 设置默认占位图
	# var placeholder = load("res://icon.svg")
	# if placeholder:
	# 	avatar_rect.texture = placeholder

func _on_cancel_pressed():
	queue_free()

func _on_avatar_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			_show_file_dialog()

func _show_file_dialog():
	var file_dialog = FileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.png, *.jpg, *.jpeg ; 支持的图片格式"]
	
	file_dialog.file_selected.connect(func(path):
		var image = Image.new()
		var error = image.load(path)
		if error == OK:
			selected_avatar = image
			var texture = ImageTexture.create_from_image(image)
			$Panel/MarginContainer/VBoxContainer/Label/GroupAvatar.texture = texture
		file_dialog.queue_free()
	)
	
	file_dialog.popup_centered(Vector2(800, 600))

func _on_create_pressed():
	var group_name = $Panel/MarginContainer/VBoxContainer/GroupNameInput.text.strip_edges()
	var group_desc = $Panel/MarginContainer/VBoxContainer/GroupDescInput.text.strip_edges()
	
	if group_name.is_empty():
		return
	
	var group = await Network.create_group_async(group_name, group_desc, selected_avatar)
	if not group:
		PopupManager.show_message("创建群组失败")
		return 
	var new_group = {
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
				}
	# 模拟创建新群组
	group_created.emit(new_group)
	queue_free()
