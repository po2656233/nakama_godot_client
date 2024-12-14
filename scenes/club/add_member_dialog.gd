extends Control

signal member_added(member_data)

func _ready():
	$Panel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton.pressed.connect(_on_cancel_pressed)
	$Panel/MarginContainer/VBoxContainer/ButtonContainer/AddButton.pressed.connect(_on_add_pressed)

func _on_cancel_pressed():
	queue_free()

func _on_add_pressed():
	var user_id = $Panel/MarginContainer/VBoxContainer/UserIDInput.text.strip_edges()
	var note = $Panel/MarginContainer/VBoxContainer/NoteInput.text.strip_edges()
	
	if user_id.is_empty():
		return
	
	# 模拟添加新成员
	var new_member = {
		"id": randi() % 1000 + 100,  # 随机ID
		"name": user_id,  # 使用输入的ID作为名称
		"avatar": null,
		"status": "离线",
		"signature": "新成员",
		"level": 1,
		"coins": 0,
		"rank": 999,
		"total_games": 0,
		"win_rate": 0.0,
		"highest_score": 0,
		"average_score": 0,
		"note": note
	}
	
	member_added.emit(new_member)
	queue_free()
