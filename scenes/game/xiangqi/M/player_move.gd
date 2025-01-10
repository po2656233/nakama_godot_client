extends Sprite2D

@export var red:Texture
@export var black:Texture

func _ready() -> void:
	_change_color()
func _change(posi:Vector2)->void:
	position=posi
	
	
var V_color:bool=false
func _change_color()->void:
	if V_color:
		V_color=false
		texture=red
	else :
		V_color=true
		texture=black
