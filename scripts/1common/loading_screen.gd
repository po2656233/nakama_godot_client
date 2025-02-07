extends Control

@onready var progress_bar = $MarginContainer/VBoxContainer/ProgressBar
@onready var progress_label = $MarginContainer/VBoxContainer/ProgressLabel

var progress: float = 0.0
var target_progress: float = 0.0
var current: float = 0.0

var next_scene: String = "home"

func _ready():
	# 初始化进度条
	progress_bar.value = 0
	update_progress_label(0)
	SignalManager.LoadingSIG.connect(_on_loading)
	
	# example_loading()

func _process(delta):
	# 平滑更新进度条
	if progress < target_progress:
		progress = min(progress + delta * 100, target_progress)
	progress_bar.value = progress
	update_progress_label(progress)
	if progress == 100:
		close_loading()


func init_data():
	progress = 0.0
	target_progress = 0.0
	current = 0.0
	pass

func close_loading():
	var timer = get_tree().create_timer(0.1)
	await timer.timeout
	SceneManager.switch_to_scene(next_scene,"custom",0.2) 
	queue_free()
	pass


func set_next_scene(scene_name: String):
	next_scene = scene_name
	pass

func set_progress(value: float):
	# 设置目标进度值（0-100）
	target_progress = clamp(value, 0, 100)
	pass

func update_progress_label(value: float):
	# 更新进度文本
	progress_label.text = "Loading... %d%%" % [round(value)]
	pass


# 加载进度
func _on_loading(value):
	set_progress(value)
	pass




# 示例：如何使用此加载界面
func example_loading():
	# 模拟加载过程
	var timer = get_tree().create_timer(0.5)
	await timer.timeout
	set_progress(25)
	
	timer = get_tree().create_timer(0.5)
	await timer.timeout
	set_progress(50)
	
	timer = get_tree().create_timer(0.5)
	await timer.timeout
	set_progress(75)
	
	timer = get_tree().create_timer(0.5)
	await timer.timeout
	set_progress(100)
	
	# 加载完成后的操作
	timer = get_tree().create_timer(0.5)
	await timer.timeout
	print("Loading completed!")