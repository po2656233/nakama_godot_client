extends Control
var home_scene = load("res://scenes/home.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SceneManager.set_current_scene("game")
	print("当前运行的节点名",SceneManager.get_running_scene_name())
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



func _on_btn_out_pressed() -> void:
	FancyFade.wipe_square(home_scene.instantiate(),0.5)
	# get_tree().quit()
	pass # Replace with function body.
