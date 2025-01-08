extends Control
var home_scene = load("res://scenes/home.tscn")
@onready var create_room_dialog = $CreateRoomDialog
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SceneManager.set_current_scene("game")
	SettingsManager.show_settings()
	# SettingsManager.showNotify(false)
	print("当前运行的节点名",SceneManager.get_current_scene_name())
	var result = await Network.sendDataRPC("list_games")
	print("获取游戏列表",result)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



func _on_btn_out_pressed() -> void:
	FancyFade.wipe_square(home_scene.instantiate(),0.5)
	# get_tree().quit()
	pass # Replace with function body.


func _on_create_room_dialog_room_created(room_data:Dictionary) -> void:
	print("房间类型：", room_data.game_type_text)
	print("游戏人数：", room_data.players)
	print("允许观战：", room_data.allow_spectators)
	print("游戏模式：", room_data.game_mode)
	print("游戏赛制", room_data.match_rule)
	create_room_dialog.visible = false
	pass # Replace with function body.


func _on_btn_public_match_pressed() -> void:
	create_room_dialog.visible = true
	pass # Replace with function body.
