extends Control

var match_scene = load("res://scenes/match.tscn")
var game_scene = load("res://scenes/game.tscn")
@onready var chatPanle = $VBoxContainer/Chat
@onready var homePanle = $PanelContainer
@onready var settings = $Setting


func _ready():
	settings.emailBtn.visible = true
	settings.notifyBtn.visible = true
	SceneManager.set_current_scene("home")
	print("当前运行的节点名",SceneManager.get_running_scene_name())
	WindowDrag.register_drag_zone(self)
	# 取消窗口拖动
	WindowDrag.unregister_drag_zone(chatPanle)
	WindowDrag.unregister_drag_zone(settings)
	# WindowDrag.unregister_drag_zone(homePanle)
	# Network.chat_message_received.connect(_on_received_message)
	pass

func _on_received_message(msg):
	print("id--->",msg)
	if msg.sender_id != Network.session.user_id:
		# settings.recv_notify()
		settings.msg_notify()
	pass



func _on_btn_store_pressed() -> void:
	pass # Replace with function body.


func _on_btn_ranking_pressed() -> void:
	pass # Replace with function body.


func _on_btn_zhanji_pressed() -> void:
	pass # Replace with function body.


func _on_btn_renwu_pressed() -> void:
	pass # Replace with function body.


func _on_btn_match_pressed() -> void:
	FancyFade.swirl(match_scene.instantiate())
	pass # Replace with function body.

func _on_btn_start_pressed() -> void:
	FancyFade.vertical_paint_brush(game_scene.instantiate())
	pass # Replace with function body.
