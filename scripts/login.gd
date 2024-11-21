extends Control
var register_scene = load("res://scenes/register.tscn")
var lobby_scene = load("res://scenes/lobby.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_tb_register_pressed() -> void:
	const DISSOLVE_IMAGE = preload('res://addons/transitions/images/blurry-noise.png')
	FancyFade.custom_fade(register_scene.instantiate(), 1.5, DISSOLVE_IMAGE)
	pass # Replace with function body.


func _on_tr_login_pressed() -> void:
	const DISSOLVE_IMAGE = preload('res://addons/transitions/images/blurry-noise.png')
	FancyFade.custom_fade(lobby_scene.instantiate(), 1.5, DISSOLVE_IMAGE)
	pass # Replace with function body.


func _on_tr_wxlogin_pressed() -> void:
	const DISSOLVE_IMAGE = preload('res://addons/transitions/images/blurry-noise.png')
	FancyFade.custom_fade(lobby_scene.instantiate(), 1, DISSOLVE_IMAGE)
	pass # Replace with function body.