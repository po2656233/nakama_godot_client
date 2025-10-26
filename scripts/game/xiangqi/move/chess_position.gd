extends Area2D
class_name chess_position

var V_position:Vector2

var chess_color:int=0
var play:player_chess

func _process(_delta: float) -> void:
	if mouse_l:
		if Input.is_action_just_pressed("mouse_l"):
			move.emit(self)
			

signal move



var mouse_l:bool=false
func _on_mouse_entered() -> void:
	mouse_l=true


func _on_mouse_exited() -> void:
	mouse_l=false
