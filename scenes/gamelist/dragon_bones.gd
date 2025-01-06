extends DragonBones

@export var scaleX = 2.0
@export var scaleY = 2.0
# Called when the node enters the scene tree for the first time.
func _ready():
	center_in_parent()
	get_parent().connect("resized", Callable(self, "_on_parent_resized"))

func center_in_parent():
	var parent_rect = get_parent().get_rect()
	position = Vector2(
		parent_rect.size.x / scaleX,
		parent_rect.size.y / scaleY
    )

func _on_parent_resized():
	center_in_parent()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# 持续更新位置以保持居中
	center_in_parent()