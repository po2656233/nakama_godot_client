extends Control
@onready var settings = $Setting

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	settings.showNotify(false)
	SceneManager.set_current_scene("match")
	print("当前运行的节点名",SceneManager.get_running_scene_name())
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
