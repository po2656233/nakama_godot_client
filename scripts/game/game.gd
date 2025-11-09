extends Control
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SceneMgr.set_current_scene("game")
	SettingsMgr.show_settings()
	# SettingsMgr.showNotify(false)
	print("当前运行的节点名",SceneMgr.get_current_scene_name())
	var result = await Online.sendDataRPC("list_games")
	print("获取游戏列表",result)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



func _on_btn_out_pressed() -> void:
	# get_tree().quit()
	pass # Replace with function body.
