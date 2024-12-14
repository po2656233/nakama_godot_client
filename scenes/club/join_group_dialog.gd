extends Control

signal group_joined(group_data)

func _ready():
	# 连接按钮
	$Panel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton.pressed.connect(_on_cancel_pressed)
	$Panel/MarginContainer/VBoxContainer/ButtonContainer/JoinButton.pressed.connect(_on_join_pressed)

func _on_cancel_pressed():
	queue_free()

func _on_join_pressed():
	var group_id = $Panel/MarginContainer/VBoxContainer/GroupIDInput.text.strip_edges()
	
	if group_id.is_empty():
		return
	
	# 模拟加入新群组
	var new_group = {
		"id": randi() % 1000 + 100,  # 随机ID
		"name": "群组 " + group_id,
		"member_count": randi() % 100 + 10,
		"notification_enabled": true
	}
	
	group_joined.emit(new_group)
	queue_free()
