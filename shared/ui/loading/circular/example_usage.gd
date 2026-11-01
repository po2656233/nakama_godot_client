extends Control

# 示例：如何在实际项目中使用圆形进度控件

@onready var progress_control: CircularProgress

func _ready():
	# 创建圆形进度控件
	progress_control = CircularProgress.new()
	progress_control.radius = 40.0
	progress_control.line_width = 6.0
	progress_control.progress_color = Color(0.2, 0.8, 1.0, 1.0)  # 蓝色进度条（也是闪烁颜色）
	progress_control.background_color = Color(0.3, 0.3, 0.3, 0.3)
	progress_control.flash_duration = 1.5
	
	# 设置位置
	progress_control.position = Vector2(100, 100)
	
	# 添加到场景
	add_child(progress_control)
	
	# 连接完成信号
	progress_control.loading_completed.connect(_on_loading_completed)

# 示例1：模拟文件加载（扇形填充效果）
func simulate_file_loading():
	progress_control.reset()  # 重置状态
	progress_control.start_loading()
	
	# 模拟文件加载过程
	var tween = create_tween()
	tween.tween_method(_update_file_progress, 0.0, 1.0, 2.0)

func _update_file_progress(progress: float):
	progress_control.set_progress(progress)

# 示例2：网络请求加载
func simulate_network_request():
	progress_control.reset()
	progress_control.start_loading()
	
	# 模拟网络请求
	var tween = create_tween()
	tween.tween_method(_update_network_progress, 0.0, 1.0, 1.5)

func _update_network_progress(progress: float):
	progress_control.set_progress(progress)

# 示例3：手动控制进度（展示扇形填充）
func manual_progress_control():
	progress_control.reset()
	progress_control.start_loading()
	
	# 手动设置不同进度值，展示扇形填充效果
	await get_tree().create_timer(0.5).timeout
	progress_control.set_progress(0.25)  # 25% - 扇形
	
	await get_tree().create_timer(0.5).timeout
	progress_control.set_progress(0.5)   # 50% - 半圆
	
	await get_tree().create_timer(0.5).timeout
	progress_control.set_progress(0.75)  # 75% - 大半圆
	
	await get_tree().create_timer(0.5).timeout
	progress_control.set_progress(1.0)   # 100% - 完整圆

func _on_loading_completed():
	print("加载完成！")
	# 在这里可以执行加载完成后的操作
	# 比如显示内容、播放音效等

# 示例4：创建多个进度控件（支持重复）
func create_multiple_progress_controls():
	for i in range(3):
		var progress = CircularProgress.new()
		progress.radius = 30.0
		progress.line_width = 4.0
		progress.position = Vector2(50 + i * 80, 200)
		progress.progress_color = Color(1.0, 0.5 + i * 0.2, 0.2, 1.0)
		
		add_child(progress)
		
		# 延迟启动每个进度条
		await get_tree().create_timer(i * 0.5).timeout
		progress.simulate_loading(1.0 + i * 0.5)

# 示例5：重复模拟加载
func repeat_loading_simulation():
	while true:
		# 重置并开始加载
		progress_control.reset()
		progress_control.simulate_loading(2.0)
		
		# 等待加载完成
		await progress_control.loading_completed
		
		# 等待一段时间后重复
		await get_tree().create_timer(1.0).timeout

# 示例6：不同颜色的扇形效果（闪烁时保持原色）
func create_colorful_progress():
	var colors = [
		Color(1.0, 0.2, 0.2, 1.0),  # 红色
		Color(0.2, 1.0, 0.2, 1.0),  # 绿色
		Color(0.2, 0.2, 1.0, 1.0),  # 蓝色
		Color(1.0, 1.0, 0.2, 1.0),  # 黄色
		Color(1.0, 0.2, 1.0, 1.0)   # 紫色
	]
	
	for i in range(colors.size()):
		progress_control.progress_color = colors[i]  # 设置颜色（扇形和闪烁都使用这个颜色）
		progress_control.reset()
		progress_control.simulate_loading(1.0)
		await progress_control.loading_completed
		await get_tree().create_timer(0.5).timeout 
