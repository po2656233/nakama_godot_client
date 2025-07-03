extends Control
class_name CircularProgress

signal loading_completed

@export var radius: float = 50.0
@export var line_width: float = 8.0
@export var progress_color: Color = Color.WHITE
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.5)
@export var flash_duration: float = 2.0
@export var completion_text: String = "成"
@export var text_color: Color = Color.WHITE
@export var text_size: int = 68

var progress: float = 0.0
var is_loading: bool = false
var is_completed: bool = false
var flash_timer: float = 0.0
var flash_alpha: float = 0.0
var completion_label: Label

func _ready():
	# 设置控件大小
	custom_minimum_size = Vector2(radius * 2 + line_width, radius * 2 + line_width)
	size = custom_minimum_size
	
	# 创建完成文本Label
	create_completion_label()
	
	await get_tree().create_timer(3).timeout
	simulate_loading(3.0)

func create_completion_label():
	completion_label = Label.new()
	completion_label.text = completion_text
	completion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 设置字体
	var font_file = load("res://assets/font/SourceHanSansSC-Normal.otf")
	if font_file != null:
		completion_label.add_theme_font_override("font", font_file)
	
	completion_label.add_theme_font_size_override("font_size", text_size)
	completion_label.add_theme_color_override("font_color", text_color)
	
	# 设置Label大小和位置
	completion_label.custom_minimum_size = Vector2(radius * 2, radius * 2)
	completion_label.size = completion_label.custom_minimum_size
	completion_label.position = Vector2(line_width/2, line_width/2)
	
	# 初始时隐藏
	completion_label.visible = false
	
	add_child(completion_label)

func _draw():
	var center = size / 2
	
	# 只在加载状态时绘制进度条
	if is_loading:
		# 绘制背景圆环
		draw_arc(center, radius, 0, TAU, 32, background_color, line_width)
		
		# 绘制进度扇形（从顶部开始，顺时针填充）
		var progress_angle = progress * TAU
		draw_arc(center, radius, -PI/2, progress_angle - PI/2, 32, progress_color, line_width)
		
		# 如果进度大于0，绘制扇形填充
		if progress > 0:
			# 绘制扇形填充
			var points = PackedVector2Array()
			points.append(center)  # 圆心
			
			# 添加弧线上的点
			var segments = 32
			for i in range(segments + 1):
				var angle = -PI/2 + (progress_angle * i / segments)
				var point = center + Vector2(cos(angle), sin(angle)) * radius
				points.append(point)
			
			# 绘制扇形填充
			draw_colored_polygon(points, progress_color)
	elif is_completed:
		# 完成状态：只在闪烁期间显示闪烁的圆环
		if flash_timer < flash_duration:
			var flash_color_with_alpha = progress_color
			flash_color_with_alpha.a = flash_alpha
			draw_arc(center, radius, 0, TAU, 32, flash_color_with_alpha, line_width)
	else:
		# 初始状态：显示圆环包裹着感叹号
		# 绘制背景圆环
		draw_arc(center, radius, 0, TAU, 32, background_color, line_width)
		# 绘制感叹号形状图（占满整个圆形）
		draw_exclamation_shape(center)

func draw_exclamation_shape(center: Vector2):
	# 绘制感叹号形状图（颠倒）
	var exclamation_color = Color.HOT_PINK  # 感叹号颜色
	var shape_radius = radius * 0.8  # 感叹号形状的半径
	
	# 绘制感叹号的下半部分（圆点）- 现在是底部，增加间隔
	var dot_radius = shape_radius * 0.15
	var dot_center = center + Vector2(0, shape_radius * 0.5)  # 增加间隔，从0.3改为0.5
	draw_circle(dot_center, dot_radius, exclamation_color)
	
	# 绘制感叹号的上半部分（竖线）- 现在是顶部，增加间隔
	var line_width_shape = shape_radius * 0.2
	var line_start = center + Vector2(-line_width_shape/2, -shape_radius * 0.5)  # 改为负数，移到上方
	var line_end = center + Vector2(line_width_shape/2, shape_radius * 0.1)  # 改为正数，移到下方，但减少长度
	
	# 绘制矩形竖线
	var line_points = PackedVector2Array([
		line_start,
		line_start + Vector2(line_width_shape, 0),
		line_end,
		line_end - Vector2(line_width_shape, 0)
	])
	draw_colored_polygon(line_points, exclamation_color)

func start_loading():
	is_loading = true
	is_completed = false
	progress = 0.0
	flash_timer = 0.0
	flash_alpha = 0.0
	
	# 隐藏完成Label，显示绘制内容
	if completion_label:
		completion_label.visible = false
	
	visible = true  # 确保控件可见
	queue_redraw()

func set_progress(value: float):
	progress = clamp(value, 0.0, 1.0)
	queue_redraw()
	
	if progress >= 1.0 and is_loading:
		complete_loading()

func complete_loading():
	is_loading = false
	is_completed = true
	flash_timer = 0.0
	
	# 不立即显示Label，等待闪烁完成后再显示
	if completion_label:
		completion_label.visible = false
	
	# 清除绘制内容，开始闪烁
	queue_redraw()
	
	loading_completed.emit()

func _process(delta):
	if is_completed:
		flash_timer += delta
		
		# 闪烁效果（加快频率）
		var flash_progress = flash_timer / flash_duration
		if flash_progress <= 1.0:
			flash_alpha = sin(flash_progress * PI * 8) * 0.5 + 0.5  # 闪烁8次（原来是4次）
			queue_redraw()
		else:
			# 闪烁完成，显示Label并清除绘制内容
			if completion_label and not completion_label.visible:
				completion_label.visible = true
				# 清除绘制内容，只显示Label
				queue_redraw()

# 便捷方法：模拟加载过程
func simulate_loading(duration: float = 3.0):
	start_loading()
	var tween = create_tween()
	tween.tween_method(set_progress, 0.0, 1.0, duration)

# 重置控件状态，可以重新开始
func reset():
	is_loading = false
	is_completed = false
	progress = 0.0
	flash_timer = 0.0
	flash_alpha = 0.0
	
	# 隐藏完成Label
	if completion_label:
		completion_label.visible = false
	
	visible = true
	queue_redraw()

# 设置完成时显示的文本
func set_completion_text(text: String):
	completion_text = text
	if completion_label:
		completion_label.text = text

# 设置文本颜色
func set_text_color(color: Color):
	text_color = color
	if completion_label:
		completion_label.add_theme_color_override("font_color", color)

# 设置文本大小
func set_text_size(size1: int):
	text_size = size1
	if completion_label:
		completion_label.add_theme_font_size_override("font_size", size1)
	
