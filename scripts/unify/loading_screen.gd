extends Control

@onready var progress_bar = $MarginContainer/VBoxContainer/ProgressBar
@onready var progress_label = $MarginContainer/VBoxContainer/ProgressLabel

var progress: float = 0.0
var target_progress: float = 0.0
var current: float = 0.0

func _ready():
	# 初始化进度条
	progress_bar.value = 0
	update_progress_label(0)
	# example_loading()

func _process(delta):
	# 平滑更新进度条
	if progress < target_progress:
		progress = min(progress + delta * 100, target_progress)
		progress_bar.value = progress
		update_progress_label(progress)
	if progress >= 100:
		progress = 0.0
		target_progress = 0.0
		current = 0.0
		queue_free()


func set_progress(value: float):
	# 设置目标进度值（0-100）
	target_progress = clamp(value, 0, 100)

func update_progress_label(value: float):
	# 更新进度文本
	progress_label.text = "Loading... %d%%" % [round(value)]

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
