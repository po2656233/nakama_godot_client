extends Control

@onready var chatPanle = $VBoxContainer/Chat
@onready var homePanle = $PanelContainer
@onready var settings = $Setting
func _ready():
	WindowDrag.register_drag_zone(self)
	# 取消窗口拖动
	WindowDrag.unregister_drag_zone(chatPanle)
	WindowDrag.unregister_drag_zone(settings)
	# WindowDrag.unregister_drag_zone(homePanle)
	Network.chat_message_received.connect(_on_received_message)
	pass

func _on_received_message(msg):
	print("id--->",msg)
	if msg.sender_id != Network.session.user_id:
		# settings.recv_notify()
		settings.msg_notify()
	pass
