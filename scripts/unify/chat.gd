extends Control
@onready var addfirendPanle = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/AddFirends
@onready var addclubPanle = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/AddClub
# var is_fullscreen = false  # 跟踪全屏状态

# func _input(event):
#     if event is InputEventMouseButton:
#         if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
#             # 双击时执行全屏和隐藏操作
#             toggle_fullscreen_and_hide()

# func toggle_fullscreen_and_hide():
#     if !is_fullscreen:
#         # 进入全屏并隐藏其他节点
#         get_window().mode = Window.MODE_FULLSCREEN
#         # hide_other_nodes()
#         is_fullscreen = true
#     else:
#         # 退出全屏并显示其他节点
#         get_window().mode = Window.MODE_WINDOWED
#         show_other_nodes()
#         is_fullscreen = false

# # 隐藏其他节点
# func hide_other_nodes():
#     for node in get_parent().get_children():
#         if node != self:  # 如果不是当前节点
#             node.hide()  # 隐藏节点
#             # 可选：禁用节点处理
#             node.process_mode = Node.PROCESS_MODE_DISABLED

# # 显示其他节点
# func show_other_nodes():
#     for node in get_parent().get_children():
#         if node != self:
#             node.show()  # 显示节点
#             # 可选：恢复节点处理
#             node.process_mode = Node.PROCESS_MODE_INHERIT

func _on_show_addfriend_pressed() -> void:
	if addfirendPanle.visible:
		addfirendPanle.hide()
	else:
		addfirendPanle.show()
	pass # Replace with function body.


func _on_show_addclub_pressed() -> void:
	if addclubPanle.visible:
		addclubPanle.hide()
	else:
		addclubPanle.show()
	pass # Replace with function body.
