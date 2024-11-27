extends Control

# var dragging := false
# var drag_offset := Vector2i()

func _ready():
	WindowDrag.register_drag_zone(self)
