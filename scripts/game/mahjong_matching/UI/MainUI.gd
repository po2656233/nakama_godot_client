extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_back_button_pressed():
	$ClickButtonPlayer.play()
	get_tree().change_scene_to_file("res://scenes/game/mahjong_matching/level/start_ui.tscn")
	pass

func _on_restart_button_pressed():
	$ClickButtonPlayer.play()
	get_parent().start_new_game()
	pass
