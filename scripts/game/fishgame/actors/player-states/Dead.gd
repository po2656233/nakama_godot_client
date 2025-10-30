extends "res://addons/snopek-state-machine/State.gd"

var ExplodeEffect: PackedScene = preload("res://scenes/game/fishgame/actors/ExplodeEffect.tscn")

@onready var host = $"../.."

func _state_enter(_info: Dictionary) -> void:
	var explosion = ExplodeEffect.instantiate()
	host.get_parent().add_child(explosion)
	explosion.global_position = host.global_position
	
	host.die()
