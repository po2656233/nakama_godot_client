extends PanelContainer

signal game_selected(game_data)

@onready var game_name_label = $MarginContainer/VBoxContainer/HeaderContainer/TitleContainer/GameName
@onready var game_author_label = $MarginContainer/VBoxContainer/HeaderContainer/TitleContainer/GameAuthor
@onready var game_logo = $MarginContainer/VBoxContainer/HeaderContainer/GameLogo
@onready var release_date_label = $MarginContainer/VBoxContainer/FooterContainer/ReleaseDate
@onready var animation_player = $AnimationPlayer

var game_data = {}
var is_hovering = false
var hover_style_box
var normal_style_box
var is_selected = false
var float_tween: Tween
var original_position: Vector2
var click_count = 0
var click_timer: Timer

func _ready():
	# 获取样式盒子引用
	normal_style_box = get_theme_stylebox("panel")
	# Create a hover style box or get it from theme
	hover_style_box = get_theme_stylebox("panel", "PanelContainer")
	# If you need a different style for hover, you can modify it or load a specific resource
	set_hover_style()
	
	# 初始化双击计时器
	click_timer = Timer.new()
	click_timer.wait_time = 0.5  # 500ms双击间隔
	click_timer.one_shot = true
	click_timer.timeout.connect(_on_click_timer_timeout)
	add_child(click_timer)
	
	# 等待一帧后保存原始位置，确保布局完成
	await get_tree().process_frame
	original_position = position
	
	# 开始浮动动画
	start_floating_animation()
	
	# 随机延迟开始动画，让卡片不同步
	await get_tree().create_timer(randf() * 2.0).timeout
	animation_player.seek(randf() * 3.0)

func setup_game_data(data: Dictionary):
	"""设置游戏数据并更新UI"""
	game_data = data
	
	# 设置游戏名称
	if game_name_label:
		if data.has("title"):
			game_name_label.text = data["title"]
		elif data.has("name"):
			game_name_label.text = data["name"]
	
	# 设置作者
	if game_author_label:
		if data.has("author"):
			game_author_label.text = data["author"]
		else:
			game_author_label.text = "未知作者"
	
	# 原始卡片场景没有简介标签，跳过
	
	# 设置发布日期
	if release_date_label:
		if data.has("release_date"):
			release_date_label.text = data["release_date"]
		else:
			release_date_label.text = "未知"
	
	# 原始卡片场景没有游戏时长标签，跳过
	
	# 原始卡片场景没有收藏图标，跳过
	
	# 设置游戏logo
	setup_game_logo(data)

func setup_game_logo(data: Dictionary):
	"""设置游戏logo"""
	if not game_logo:
		return
		
	if data.has("logo_path") and data["logo_path"] != "":
		# 尝试加载指定的logo文件
		var logo_path = data["logo_path"]
		var texture = load_image_texture(logo_path)
		if texture:
			game_logo.texture = texture
		else:
			# 加载失败，使用默认logo
			game_logo.texture = create_elegant_logo(data)
	else:
		# 使用优雅风格默认logo
		game_logo.texture = create_elegant_logo(data)

func load_image_texture(path: String) -> Texture2D:
	"""加载图片文件，支持SVG、PNG、JPG格式"""
	if not FileAccess.file_exists(path):
		return null
	
	var extension = path.get_extension().to_lower()
	match extension:
		"svg":
			# SVG支持（需要特殊处理）
			return load(path) as Texture2D
		"png", "jpg", "jpeg":
			# 位图支持
			var image = Image.new()
			var error = image.load(path)
			if error == OK:
				var texture = ImageTexture.new()
				texture.set_image(image)
				return texture
			
	return null

func create_elegant_logo(data: Dictionary) -> ImageTexture:
	"""创建优雅简洁的默认logo"""
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	# 优雅的颜色方案
	var elegant_colors = [
		Color(0.85, 0.9, 0.95, 1.0),   # 淡蓝灰
		Color(0.9, 0.85, 0.95, 1.0),   # 淡紫灰
		Color(0.85, 0.95, 0.9, 1.0),   # 淡绿灰
		Color(0.95, 0.9, 0.85, 1.0),   # 淡橙灰
		Color(0.9, 0.95, 0.85, 1.0),   # 淡黄绿
		Color(0.95, 0.85, 0.9, 1.0),   # 淡粉灰
	]
	
	# 根据游戏名称选择颜色
	var game_name = data.get("title", data.get("name", "Game"))
	var color_index = game_name.hash() % elegant_colors.size()
	var base_color = elegant_colors[color_index]
	
	# 创建简洁的圆形背景
	var center_x = 32
	var center_y = 32
	var radius = 28
	
	for y in range(64):
		for x in range(64):
			var distance = sqrt((x - center_x) * (x - center_x) + (y - center_y) * (y - center_y))
			if distance <= radius:
				# 内部渐变
				var alpha = 1.0 - (distance / radius) * 0.3
				var color = Color(base_color.r, base_color.g, base_color.b, alpha)
				image.set_pixel(x, y, color)
			else:
				# 透明背景
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	# 添加简单的边框
	add_elegant_border(image, center_x, center_y, radius, base_color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func add_elegant_border(image: Image, center_x: int, center_y: int, radius: int, base_color: Color):
	"""添加优雅的边框"""
	var border_color = Color(base_color.r * 0.7, base_color.g * 0.7, base_color.b * 0.7, 0.8)
	
	for angle in range(0, 360, 2):
		var rad = deg_to_rad(angle)
		var x = center_x + int(cos(rad) * radius)
		var y = center_y + int(sin(rad) * radius)
		
		if x >= 0 and x < 64 and y >= 0 and y < 64:
			image.set_pixel(x, y, border_color)

func add_anime_decorations(image: Image, _colors: Array):
	"""添加动漫风格装饰"""
	# 添加星星装饰
	for i in range(8):
		var x = randi() % 100 + 14
		var y = randi() % 100 + 14
		draw_star(image, x, y, 4, Color.WHITE)
	
	# 添加光晕效果
	for i in range(64):
		for j in range(64):
			var center_x = 64
			var center_y = 64
			var dist = sqrt((i - center_x) * (i - center_x) + (j - center_y) * (j - center_y))
			if dist < 20:
				var alpha = (20 - dist) / 20.0 * 0.3
				var highlight = Color(1.0, 1.0, 1.0, alpha)
				var current = image.get_pixel(i + 32, j + 32)
				image.set_pixel(i + 32, j + 32, current.blend(highlight))

func draw_star(image: Image, center_x: int, center_y: int, star_size: int, color: Color):
	"""绘制星星"""
	for i in range(-star_size, star_size + 1):
		for j in range(-star_size, star_size + 1):
			var x = center_x + i
			var y = center_y + j
			if x >= 0 and x < 128 and y >= 0 and y < 128:
				if abs(i) + abs(j) <= star_size:
					image.set_pixel(x, y, color)

func add_game_initial(_image: Image, game_name: String):
	"""添加游戏名称的首字母"""
	if game_name.is_empty():
		return
	
	# 获取首字符（中文或英文）
	var _initial = game_name.substr(0, 1).to_upper()
	
	# 简单的字母绘制（这里只是示例，实际可以使用更复杂的字体渲染）
	var _letter_color = Color(1.0, 1.0, 1.0, 0.8)
	# 这里可以添加字母的像素绘制逻辑
	# 由于复杂性，这里略过实现
	pass

func create_default_logo() -> ImageTexture:
	"""创建默认的优雅logo（保留兼容）"""
	return create_elegant_logo({"title": "Game"})

func _on_mouse_entered():
	if not is_hovering:
		is_hovering = true
		animation_player.play("hover_in")
		
		# 更改样式
		if hover_style_box:
			add_theme_stylebox_override("panel", hover_style_box)

func _on_mouse_exited():
	if is_hovering:
		is_hovering = false
		animation_player.play("hover_out")
		
		# 恢复原始样式
		add_theme_stylebox_override("panel", normal_style_box)

func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			animation_player.play("click")
			
			# 双击检测
			click_count += 1
			if click_count == 1:
				# 第一次点击，开始计时
				click_timer.start()
			elif click_count == 2:
				# 双击，停止计时器并启动游戏
				click_timer.stop()
				click_count = 0
				launch_game()
				return
			
			is_selected = true

func _on_click_timer_timeout():
	"""双击计时器超时，执行单击操作"""
	click_count = 0
	# 发射单击信号
	game_selected.emit(game_data)

func launch_game():
	"""启动游戏"""
	if not game_data.has("installed") or not game_data["installed"]:
		# 游戏未安装
		print("游戏未安装：", game_data.get("title", "未知游戏"))
		# 尝试使用PopupManager显示提示
		if PopupManager:
			Global.PopupManager.show_message("游戏未安装，请先安装游戏。", "提示", false)
		return
	
	var game_title = game_data.get("title", "未知游戏")
	var executable_path = game_data.get("executable_path", "")
	
	if executable_path == "":
		print("找不到游戏执行文件：", game_title)
		if PopupManager:
			Global.PopupManager.show_message("找不到游戏执行文件。", "错误", false)
		return
	
	# 显示启动提示
	print("正在启动游戏：", game_title)
	if PopupManager:
		Global.PopupManager.show_message("正在启动 " + game_title + "...", "启动游戏", false)
	
	# 这里应该调用系统API启动游戏
	# OS.execute(executable_path, [])
	
	# 模拟启动成功
	print("模拟启动游戏：", executable_path)

func set_hover_style():
	"""设置悬停样式"""
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.3, 0.95)
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_right = 12
	style_box.corner_radius_bottom_left = 12
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color(0.5, 0.7, 1.0, 1.0)
	style_box.shadow_color = Color(0.2, 0.4, 0.8, 0.5)
	style_box.shadow_size = 8
	style_box.shadow_offset = Vector2(3, 3)
	
	hover_style_box = style_box

func start_floating_animation():
	"""开始轻微摇摆动画 - 在展示位置轻微来回摇摆"""
	if float_tween:
		float_tween.kill()
	
	# 随机延迟开始，让卡片不同步
	var delay = randf_range(0.3, 1.2)
	await get_tree().create_timer(delay).timeout
	
	# 开始轻微摇摆
	start_gentle_sway()

func start_gentle_sway():
	"""开始温和浮动 - 在展示位置温和浮动"""
	if not is_inside_tree():
		return
	
	# 确保原始位置有效
	if original_position == Vector2.ZERO:
		original_position = position
	
	# 创建新的循环tween
	float_tween = create_tween()
	float_tween.set_loops()
	float_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	float_tween.set_ease(Tween.EASE_IN_OUT)
	float_tween.set_trans(Tween.TRANS_SINE)
	
	# 温和的浮动距离（1-3像素，更明显但不重叠）
	var float_distance = randf_range(1.0, 3.0)
	var float_duration = randf_range(3.0, 5.0)
	
	# 温和的左右浮动：中心 -> 右 -> 中心 -> 左 -> 中心
	float_tween.tween_property(self, "position:x", original_position.x + float_distance, float_duration)
	float_tween.tween_property(self, "position:x", original_position.x - float_distance, float_duration * 2)
	float_tween.tween_property(self, "position:x", original_position.x, float_duration)

func stop_floating_animation():
	"""停止浮动动画"""
	if float_tween:
		float_tween.kill()
		float_tween = null
	
	# 恢复到原始位置
	var reset_tween = create_tween()
	reset_tween.tween_property(self, "position", original_position, 0.3)
