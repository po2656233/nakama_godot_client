extends Control

@onready var chatPanle = $VBoxContainer/Chat
@onready var homePanle = $PanelContainer
func _ready():
	SceneManager.set_current_scene("home")
	SettingsManager.show_settings(1)

	print("当前运行的节点名", SceneManager.get_current_scene_name())
	WindowDrag.register_drag_zone(self)
	# 取消窗口拖动
	WindowDrag.unregister_drag_zone(chatPanle)
	pass

func _on_btn_store_pressed() -> void:
	pass # Replace with function body.


func _on_btn_ranking_pressed() -> void:
	SceneManager.switch_to_scene("leaderboard","circle-out",0.5) 
	pass # Replace with function body.


func _on_btn_zhanji_pressed() -> void:
	# SceneManager.switch_to_scene("gamelist","square",0.5) 
	pass # Replace with function body.


# 任务
func _on_btn_renwu_pressed() -> void:
	SceneManager.switch_to_scene("game","custom",0.2) 
	pass # Replace with function body.

# 比赛
func _on_btn_match_pressed() -> void:
	SceneManager.switch_to_scene("roomlist","vertical-paint-brush",0.2) 
	pass # Replace with function body.

# 匹配
func _on_btn_start_pressed() -> void:
	SceneManager.switch_to_scene("gamelist","horizontal-paint-brush",0.2) 
	pass # Replace with function body.

