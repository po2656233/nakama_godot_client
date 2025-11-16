extends Control

# signal group_joined(group_data)

func _ready():
	# 连接按钮
	$Panel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton.pressed.connect(_on_cancel_pressed)
	$Panel/MarginContainer/VBoxContainer/ButtonContainer/JoinButton.pressed.connect(_on_join_pressed)

func _on_cancel_pressed():
	queue_free()

func _on_join_pressed():
	var group_name = $Panel/MarginContainer/VBoxContainer/GroupIDInput.text.strip_edges()
	if group_name.is_empty():
		return
	var ret = await Global.OnlineChat.add_group_async(group_name)
	if not ret:
		Global.WindowPopup.show_message("加入俱乐部失败")
		return 
	# group_joined.emit(new_group)
	Global.WindowPopup.show_message("已申请,请等待审批")
	queue_free()
