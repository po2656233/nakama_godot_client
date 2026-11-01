extends Node2D

@onready var dynamic_text = $DynamicText

func _ready():
	# Test the dynamic text
	display_message("Welcome to Dynamic Text!")

func display_message(message: String):
	dynamic_text.display_text(message)

# For testing - press Space to show a test message
# Up arrow: Increase speed
# Down arrow: Decrease speed
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space bar
		display_message("Test Message " + str(randi()))
	elif event.is_action_pressed("ui_up"):    # Up arrow
		dynamic_text.set_speed(dynamic_text.get_speed() + 50.0)
		display_message("Speed increased to: " + str(dynamic_text.get_speed()))
	elif event.is_action_pressed("ui_down"):  # Down arrow
		dynamic_text.set_speed(max(50.0, dynamic_text.get_speed() - 50.0))
		display_message("Speed decreased to: " + str(dynamic_text.get_speed()))
