extends Control
@onready var _search_box: LineEdit = $Panel/LineEdit_find
@export var placeholder_text: String = "提示文本"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_search_box.placeholder_text = placeholder_text
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
