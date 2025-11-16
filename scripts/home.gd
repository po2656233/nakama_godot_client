extends Control

@onready var chatPanle = $VBoxContainer/Chat
@onready var homePanle = $PanelContainer
@onready var cur_game_name: Label = $HBoxContainerHome/btn_start/cur_game_name

func _ready():
	Global.SceneMgr.set_current_scene("home")
	Global.SettingsMgr.show_settings(1)
	
	print("当前运行的节点名", Global.SceneMgr.get_current_scene_name())
	Global.WindowDrag.register_drag_zone(self)
	# 取消窗口拖动
	Global.WindowDrag.unregister_drag_zone(chatPanle)
	
	var game_info = Global.DataMgr.get_instance().get_current_game()
	if game_info:
		cur_game_name.text = game_info.gname
	
	pass

func _on_btn_store_pressed() -> void:
	pass # Replace with function body.


func _on_btn_ranking_pressed() -> void:
	Global.SceneMgr.switch_to_scene("leaderboard","circle-out",0.5) 
	pass # Replace with function body.


func _on_btn_zhanji_pressed() -> void:
	# Global.SceneMgr.switch_to_scene("gamelist","square",0.5) 
	pass # Replace with function body.


# 任务
func _on_btn_renwu_pressed() -> void:
	Global.SceneMgr.switch_to_scene("roomlist","vertical-paint-brush",0.5) 
	pass # Replace with function body.

# 比赛
func _on_btn_match_pressed() -> void:
	Global.SceneMgr.switch_to_scene("clubhome","vertical-paint-brush",0.5) 
	pass # Replace with function body.

# 匹配
func _on_btn_start_pressed() -> void:
	Global.SceneMgr.switch_to_scene("gamelist","wipe-right",0.5) 
	pass # Replace with function body.


func _on_tb_home_pressed() -> void:
	#Global.SceneMgr.switch_to_scene("local_game_list","vertical-paint-brush",0.2) 
	pass # Replace with function body.
