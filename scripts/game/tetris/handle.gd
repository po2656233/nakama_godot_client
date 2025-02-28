extends Node2D


@onready var joystick : MultidirectionnalJoystick = $MultidirectionnalJoystick
@onready var sprite_2d = $Sprite2D
@onready var line_2d = $Line2D


var dir : Vector2
var speed := 300.0

func _ready():
	connect_signals()

func connect_signals ():
	joystick.joystick_change.connect(change_direction)




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	sprite_2d.rotation = rotate_toward(sprite_2d.rotation,dir.angle(),0.6)
	sprite_2d.translate(dir*speed*delta)
	
	if dir:
		line_2d.add_point(sprite_2d.global_position)
		if line_2d.get_point_count() > 100: line_2d.remove_point(0)

func change_direction (dir_joystick: Vector2):
	dir = dir_joystick



