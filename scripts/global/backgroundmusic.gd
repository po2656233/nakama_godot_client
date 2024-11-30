extends AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	stream.loop = true
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	
	pass
# 暂停音乐的方法
func pause():
	stream_paused = true

# 继续播放音乐的方法
func resume():
	stream_paused = false


# 调整音量的方法
func set_volume(volume: float):
	volume_db = linear_to_db(volume)  # volume应该在0.0到1.0之间