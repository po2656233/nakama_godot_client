extends Control

# var dragging := false
# var drag_offset := Vector2i()

func _ready():
	WindowDrag.register_drag_zone(self)
	# 取消窗口拖动
	# WindowDrag.unregister_drag_zone(self)
