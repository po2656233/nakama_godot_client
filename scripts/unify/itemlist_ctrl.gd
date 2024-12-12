extends ItemList

# 按钮的边距和间距
const BUTTON_MARGIN = 5
const BUTTON_PADDING = 10  # 按钮文字的左右内边距

# 存储每个项目的按钮状态和回调函数
var item_buttons = []

# 自定义数据结构来存储按钮信息
class ButtonInfo:
	var button1_text : String
	var button1_callback : Callable
	var button2_text : String
	var button2_callback : Callable
	
	func _init(btn1_text := "", btn1_cb : Callable = Callable(),
			   btn2_text := "", btn2_cb : Callable = Callable()):
		button1_text = btn1_text
		button1_callback = btn1_cb
		button2_text = btn2_text
		button2_callback = btn2_cb
	
	# 根据文本判断按钮是否显示
	func is_button1_visible() -> bool:
		return button1_text != ""
		
	func is_button2_visible() -> bool:
		return button2_text != ""

# 添加项目的方法
func add_item_with_buttons(text: String,  icon: Texture2D=null,
						  btn1_text := "", 
						  btn1_callback : Callable = Callable(),
						  btn2_text := "", 
						  btn2_callback : Callable = Callable()) -> int:
	var index = super.add_item(text)
	if icon:
		set_item_icon(index, icon)
	var button_info = ButtonInfo.new(btn1_text, btn1_callback,
								   btn2_text, btn2_callback)
	item_buttons.append(button_info)
	queue_redraw()
	return index

# 监听项目移除事件
func _notification(what):
	if what == NOTIFICATION_INTERNAL_PROCESS:
		# 检查并同步item_buttons的大小与实际项目数量
		while item_buttons.size() > item_count:
			item_buttons.pop_back()

func _ready():
	# 连接必要的信号
	item_clicked.connect(_on_item_clicked)
	# 启用内部处理以监控项目数量变化
	set_process_internal(true)

# 清除所有项目
func clear_items():
	super.clear()
	item_buttons.clear()
	queue_redraw()

# 计算按钮大小
func _calculate_button_size(text: String) -> Vector2:
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	# 按钮宽度 = 文字宽度 + 两边内边距
	return Vector2(text_size.x + BUTTON_PADDING * 2, text_size.y + BUTTON_PADDING)

# 重写绘制方法来添加按钮
func _draw():
	for i in range(item_count):
		if i >= item_buttons.size():
			continue
			
		var button_info = item_buttons[i]
		var rect = get_item_rect(i)
		var item_height = rect.size.y
		
		# 计算按钮位置时考虑实际显示的按钮数量和大小
		var current_x = rect.position.x + rect.size.x
		
		if button_info.is_button2_visible():
			var btn2_size = _calculate_button_size(button_info.button2_text)
			var button2_rect = Rect2(
				current_x - btn2_size.x - BUTTON_MARGIN,
				rect.position.y + (item_height - btn2_size.y) / 2,
				btn2_size.x,
				btn2_size.y
			)
			# 绘制第二个按钮
			draw_rect(button2_rect, Color.RED)
			# 绘制按钮文字
			var font = get_theme_default_font()
			var font_size = get_theme_default_font_size()
			var text_pos = Vector2(
				button2_rect.position.x + BUTTON_PADDING,
				button2_rect.position.y + button2_rect.size.y - BUTTON_PADDING
			)
			draw_string(font, text_pos, button_info.button2_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			current_x -= btn2_size.x + BUTTON_MARGIN
		
		if button_info.is_button1_visible():
			var btn1_size = _calculate_button_size(button_info.button1_text)
			var button1_rect = Rect2(
				current_x - btn1_size.x - BUTTON_MARGIN,
				rect.position.y + (item_height - btn1_size.y) / 2,
				btn1_size.x,
				btn1_size.y
			)
			# 绘制第一个按钮
			draw_rect(button1_rect, Color.BLUE)
			# 绘制按钮文字
			var font = get_theme_default_font()
			var font_size = get_theme_default_font_size()
			var text_pos = Vector2(
				button1_rect.position.x + BUTTON_PADDING,
				button1_rect.position.y + button1_rect.size.y - BUTTON_PADDING
			)
			draw_string(font, text_pos, button_info.button1_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

# 处理点击事件
func _on_item_clicked(index: int, at_position: Vector2, _mouse_button_index: int):
	if index >= item_buttons.size():
		return
		
	var button_info = item_buttons[index]
	var rect = get_item_rect(index)
	var current_x = rect.position.x + rect.size.x
	
	if button_info.is_button2_visible():
		var btn2_size = _calculate_button_size(button_info.button2_text)
		var button2_rect = Rect2(
			current_x - btn2_size.x - BUTTON_MARGIN,
			rect.position.y + (rect.size.y - btn2_size.y) / 2,
			btn2_size.x,
			btn2_size.y
		)
		if button2_rect.has_point(at_position):
			if button_info.button2_callback.is_valid():
				button_info.button2_callback.call()
			return
		current_x -= btn2_size.x + BUTTON_MARGIN
	
	if button_info.is_button1_visible():
		var btn1_size = _calculate_button_size(button_info.button1_text)
		var button1_rect = Rect2(
			current_x - btn1_size.x - BUTTON_MARGIN,
			rect.position.y + (rect.size.y - btn1_size.y) / 2,
			btn1_size.x,
			btn1_size.y
		)
		if button1_rect.has_point(at_position):
			if button_info.button1_callback.is_valid():
				button_info.button1_callback.call()
			return

# 更新某个项目的按钮
func update_item_buttons(index: int, 
						btn1_text := "", 
						btn1_callback : Callable = Callable(),
						btn2_text := "", 
						btn2_callback : Callable = Callable()):
	if index >= 0 and index < item_buttons.size():
		if btn1_text != null:  # 允许设置空字符串来隐藏按钮
			item_buttons[index].button1_text = btn1_text
		if btn2_text != null:  # 允许设置空字符串来隐藏按钮
			item_buttons[index].button2_text = btn2_text
		if btn1_callback.is_valid():
			item_buttons[index].button1_callback = btn1_callback
		if btn2_callback.is_valid():
			item_buttons[index].button2_callback = btn2_callback
		queue_redraw()