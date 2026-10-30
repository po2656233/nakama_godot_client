extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	$AudioStreamPlayer.play()
	
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_start_button_pressed():
	if Global.has_global("GameLauncher") and Global.GameLauncher.start_game("mahjong_matching"):
		return
	Global.SceneMgr.switch_to_scene("mahjong_matching")

func _on_quit_button_pressed():
	get_tree().quit()
	pass
