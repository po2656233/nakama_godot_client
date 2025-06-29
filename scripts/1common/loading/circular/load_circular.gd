extends Control

@onready var circular_progress: CircularProgress = $CircularProgress
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var progress_label: Label = $VBoxContainer/ProgressLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready():
	# 连接信号
	circular_progress.loading_completed.connect(_on_loading_completed)
	start_button.pressed.connect(_on_start_button_pressed)
	
	# 初始化状态
	status_label.text = "准备就绪"
	progress_label.text = "进度: 0%"

func _on_start_button_pressed():
	start_button.disabled = true
	status_label.text = "正在加载..."
	
	# 重置控件状态
	circular_progress.reset()
	
	# 开始模拟加载
	circular_progress.simulate_loading(3.0)
	
	# 更新进度显示
	var tween = create_tween()
	tween.tween_method(_update_progress_label, 0.0, 1.0, 3.0)

func _update_progress_label(progress: float):
	progress_label.text = "进度: " + str(int(progress * 100)) + "%"

func _on_loading_completed():
	status_label.text = "加载完成！"
	progress_label.text = "进度: 100%"
	
	# 延迟后重新启用按钮，允许重复模拟
	await get_tree().create_timer(2.5).timeout
	start_button.disabled = false
	status_label.text = "准备就绪" 
