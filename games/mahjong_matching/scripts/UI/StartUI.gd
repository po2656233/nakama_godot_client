extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	$AudioStreamPlayer.play()
	
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_start_button_pressed():
	if GameHostBridge.current != null and GameHostBridge.current.restart():
		return
	GameHostBridge.current.restart()

func _on_quit_button_pressed():
	get_tree().quit()
	pass
