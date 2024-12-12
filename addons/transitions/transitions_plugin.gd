@tool
extends EditorPlugin

func _enter_tree():
    # Initialization of the plugin goes here
    add_custom_type("Transitions", "CanvasLayer", preload("res://addons/transitions/Transitions.gd"), null)
    pass

func _exit_tree():
    # Clean-up of the plugin goes here
    # Always remember to remove it from the engine when deactivated
    remove_custom_type("Transitions")
    pass
