extends Sprite2D

@export var red:Texture
@export var black:Texture
@onready var player = $movePlayer

func _ready() -> void:
	player.play("blink")
	_change_color()
	pass

func _change(posi:Vector2)->void:
	position=posi
	pass
	
	
var V_color:bool=false
func _change_color()->void:
	if V_color:
		V_color=false
		texture=red
	else :
		V_color=true
		texture=black

func stop():
	player.stop()
