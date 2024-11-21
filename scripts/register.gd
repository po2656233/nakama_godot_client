extends Control
var login_scene = load("res://scenes/login.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



func _on_tb_return_pressed() -> void:
	# const DISSOLVE_IMAGE = preload('res://addons/transitions/images/blurry-noise.png')
	FancyFade.wipe_left(login_scene.instantiate(),0.5)
	pass # Replace with function body.
