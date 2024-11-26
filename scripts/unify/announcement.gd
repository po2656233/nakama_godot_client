extends Control

# 节点引用
@onready var viewport_container = $Background/SubViewportContainer
@onready var viewport = $Background/SubViewportContainer/SubViewport
@onready var announcement_container = $Background/SubViewportContainer/SubViewport/VBoxContainer
@onready var background_panel = $Background

# 公告设置
var announcements = [
	"欢迎来到我们的游戏！",
	"新版本即将推出，敬请期待！",
	"今日活动：双倍积分奖励！",
	"加入我们的社区，获取更多乐趣！",
]

# 滚动设置
var scroll_speed = 40.0  # 滚动速度
var scroll_position = 0.0  # 当前滚动位置
var content_height = 0.0   # 内容总高度
var label_height = 10.0    # 每个标签的高度
var total_announcement_height = 0.0  # 一组公告的总高度
var transition_offset = 0.0  # 过渡偏移量

func _ready():
	# 等待一帧确保所有节点都准备好
	await get_tree().process_frame
	# 连接窗口大小变化信号
	get_tree().root.size_changed.connect(_on_window_resized)
	_on_window_resized()
	setup_announcements()

func _on_window_resized():
	if !is_instance_valid(viewport) or !is_instance_valid(background_panel):
		return
		
	# 计算合适的视口大小
	var window_size = get_viewport_rect().size
	var target_width = min(window_size.x * 0.3, 500)  # 最大宽度500
	var target_height = min(window_size.y * 0.4, 60)  # 最大高度400
	
	# 更新视口大小
	viewport.size = Vector2i(target_width, target_height)
	viewport_container.custom_minimum_size = Vector2(target_width, target_height)
	
	# # 更新背景面板大小
	# var panel_margin = Vector2(20, 20)
	# background_panel.custom_minimum_size = Vector2(target_width, target_height) + panel_margin * 2
	
	# # 更新容器大小
	announcement_container.custom_minimum_size.x = target_width-40
	
	# 重新设置公告以适应新的大小
	setup_announcements()

func setup_announcements():
	# 清除现有公告
	for child in announcement_container.get_children():
		child.queue_free()
	
	# 创建两组公告以实现无缝滚动
	for i in range(2):
		for text in announcements:
			add_announcement_label(text)
	
	# 更新内容总高度和一组公告的高度
	await get_tree().process_frame
	content_height = announcement_container.size.y
	total_announcement_height = content_height / 2  # 因为我们创建了两组
	
	# 重置滚动位置
	scroll_position = 0.0
	transition_offset = 0.0
	announcement_container.position.y = 0

func add_announcement_label(text: String):	
	var label = Label.new()
	var panel = PanelContainer.new()
	
	# 设置面板样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	
	# 设置标签属性
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(viewport.size.x - 40, label_height)  # 左右留出20像素边距
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# 组装UI
	panel.add_child(label)
	announcement_container.add_child(panel)
	
	# 添加间距
	var margin = Control.new()
	margin.custom_minimum_size = Vector2(10, 10)  # 10像素的间距
	announcement_container.add_child(margin)

func _process(delta):
	if content_height <= 0 or total_announcement_height <= 0:
		return
		
	# 更新滚动位置
	scroll_position += scroll_speed * delta
	
	# 当滚动到第一组公告末尾时，开始平滑过渡
	if scroll_position >= total_announcement_height:
		# 重置滚动位置到开头
		scroll_position = 0
		
	# 计算实际显示位置（使用线性插值实现平滑过渡）
	var target_position = -scroll_position
	announcement_container.position.y = target_position

# 动态添加新公告
func add_announcement(text: String):
	announcements.append(text)
	setup_announcements()

# 设置滚动速度
func set_scroll_speed(speed: float):
	scroll_speed = speed
