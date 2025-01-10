extends Sprite2D
class_name player_chess

@export var chess_color:int

@export var red:Texture
@export var black:Texture

func _ready() -> void:
	change(chess_color)
	scale=Vector2(1.5,1.5)
func change(chess_color_:int)->void:
	chess_color=chess_color_
	if chess_color==0:
		texture=red
	else :
		texture=black

func move(_start:chess_position,_end:chess_position,_chess_array:Array)->bool:
	return true

func game_over()->bool:
	return false

func distance(start:Vector2,end:Vector2)->Vector2:
	return abs(Vector2(start-end))
