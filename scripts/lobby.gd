extends Control
var login_scene = load("res://scenes/login.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



func _on_btn_out_pressed() -> void:
	FancyFade.wipe_square(login_scene.instantiate(),0.5)
	# get_tree().quit()
	pass # Replace with function body.
