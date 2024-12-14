extends Control

signal group_created(group_data)

func _ready():
	 # 设置布局模式为居中
	set_anchors_preset(Control.PRESET_CENTER)
	# 或者更详细的设置
	set_anchors_preset(Control.PRESET_CENTER, true)  # true 表示保持边距
	$Panel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton.pressed.connect(_on_cancel_pressed)
	$Panel/MarginContainer/VBoxContainer/ButtonContainer/CreateButton.pressed.connect(_on_create_pressed)

func _on_cancel_pressed():
	queue_free()

func _on_create_pressed():
	var group_name = $Panel/MarginContainer/VBoxContainer/GroupNameInput.text.strip_edges()
	var group_desc = $Panel/MarginContainer/VBoxContainer/GroupDescInput.text.strip_edges()
	
	if group_name.is_empty():
		return
	
	# 创建新群组数据
	var new_group = {
		"id": randi() % 10000 + 1000,  # 随机生成群组ID
		"name": group_name,
		"description": group_desc,
		"member_count": 1,  # 创建者为第一个成员
		"notification_enabled": true,
		"created_at": Time.get_datetime_string_from_system(),
		"owner_id": 1  # 假设当前用户ID为1
	}
	
	group_created.emit(new_group)
	queue_free()
