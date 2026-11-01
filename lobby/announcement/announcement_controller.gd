extends Control

# 公告内容
var announcements = [
	"欢迎来到游戏世界！",
	"第一梯队准备战斗！",
	"第二梯队准备接力！",
	"第三梯队跟上！",
	"第四梯队准备跟上！",
]
var current_index = 0
var next_index = 1

# 显示设置
var char_interval: float = 0.1    # 字符显示间隔（秒）
var display_time: float = 1.0     # 完整显示时间
var fade_interval: float = 0.1    # 字符消失间隔（秒）
var scroll_speed: float = 150.0   # 滚动速度（像素/秒）
var transition_time: float = 1.0  # 过渡时间（秒）

# 状态控制
enum State { TYPING, SCROLLING, FADING, TRANSITIONING }
var current_state = State.TYPING

# 当前文本控制
var current_text: String = ""      # 完整的文本
var visible_chars: int = 0         # 当前可见的字符数
var char_timer: float = 0.0        # 字符计时器
var scroll_pos: float = 0.0        # 滚动位置

# 下一条文本控制
var next_text: String = ""         # 下一条完整文本
var next_visible_chars: int = 0    # 下一条可见字符数
var next_char_timer: float = 0.0   # 下一条字符计时器
var next_scroll_pos: float = 0.0   # 下一条滚动位置
var next_alpha: float = 0.0        # 下一条整体透明度

# 字符显示控制
class CharacterControl:
	var text: String
	var visible: bool
	var alpha: float
	
	func _init(t: String):
		text = t
		visible = false
		alpha = 1.0

var current_chars: Array[CharacterControl] = []
var next_chars: Array[CharacterControl] = []

# 节点引用
@onready var current_label = $ColorRect/CurrentText
@onready var next_label = $ColorRect/NextText
@onready var screen_width = get_parent().size.x

func _ready():
	# 初始化位置
	scroll_pos = screen_width
	next_scroll_pos = screen_width
	
	# 初始化第一条公告
	start_new_announcement()
	
	# 更新标签位置
	current_label.position.x = scroll_pos
	next_label.position.x = next_scroll_pos

func _process(delta: float) -> void:
	match current_state:
		State.TYPING:
			process_typing(delta)
		State.SCROLLING:
			process_scrolling(delta)
		State.FADING:
			process_fading(delta)
		State.TRANSITIONING:
			process_transition(delta)
	
	update_text_display()

func process_typing(delta: float) -> void:
	char_timer += delta
	if char_timer >= char_interval:
		char_timer = 0.0
		if visible_chars < current_chars.size():
			current_chars[visible_chars].visible = true
			visible_chars += 1
		
		# 如果所有字符都显示完了
		if visible_chars >= current_chars.size():
			#print("显示完了.开始滚动")
			current_state = State.SCROLLING

func process_scrolling(delta: float) -> void:
	scroll_pos -= scroll_speed * delta
	current_label.position.x = scroll_pos
	#print('正在滚动的文本:',current_label.text)
	
	# 如果即将滚动到头，开始准备下一条
	if scroll_pos <= 0:#transition_time * scroll_speed:
		#print('当前位置',scroll_pos,' 时间',transition_time,'速度',scroll_speed)
		current_state = State.TRANSITIONING
		next_scroll_pos = screen_width
		next_label.position.x = next_scroll_pos
		next_alpha = 0.0
		next_label.modulate.a = next_alpha
		next_visible_chars = 0
		#print("滚动到头,开始转换")

func process_fading(delta: float) -> void:
	char_timer += delta
	if char_timer >= fade_interval:
		char_timer = 0.0
		
		var all_faded = true
		for char_control in current_chars:
			if char_control.visible:
				char_control.alpha = max(0.1, char_control.alpha - 0.1)
				current_label.modulate.a = char_control.alpha
				if char_control.alpha > 0.1:
					all_faded = false
		for char_control in next_chars:
			if char_control.visible:
				char_control.alpha = max(0.1, char_control.alpha - 0.1)
				next_label.modulate.a = char_control.alpha
				if char_control.alpha > 0.1:
					all_faded = false
		if all_faded:
			#print("淡出后,切换至下一条")
			switch_to_next_announcement()

func process_transition(delta: float) -> void:
	# 继续滚动当前文本
	scroll_pos -= scroll_speed * delta
	current_label.position.x = scroll_pos
	if current_label.position.x < 0:
		current_label.position.x = 0
		current_label.visible = false

	# 处理下一条文本的打字效果
	next_char_timer += delta
	if next_char_timer >= char_interval:
		next_char_timer = 0.0
		if next_visible_chars < next_chars.size():
			next_chars[next_visible_chars].visible = true
			next_visible_chars += 1
	
	# 移动和淡入下一条文本
	next_scroll_pos -= scroll_speed * delta * 0.5  # 稍慢的速度
	next_label.position.x = next_scroll_pos
	if next_label.position.x < 0:
		next_label.position.x = 0
		next_label.visible = false
	next_alpha = min(1.0, next_alpha + delta)
	next_label.modulate.a = next_alpha
	
	# 如果当前文本滚动出屏幕，切换到消失状态
	if scroll_pos <= -2*current_label.size.x:
		#print("当前文本滚动出屏幕,切换到消失状态")
		current_state = State.FADING

func update_text_display() -> void:
	# 更新当前文本显示
	var current_final_text = ""
	for char_control in current_chars:
		if char_control.visible:
			if current_state == State.FADING:
				current_final_text += char_control.text
				current_label.modulate.a = char_control.alpha
			else:
				current_final_text += char_control.text
	current_label.text = current_final_text
	next_label.text = current_final_text #先调整为当前文本
	### 更新下一条文本显示
	#if current_state == State.TRANSITIONING:
		#var next_final_text = ""
		#for i in range(next_visible_chars):
			#if i < next_chars.size():
				#next_final_text += next_chars[i].text
		#next_label.text = next_final_text
	#print("当前文本",current_label.text," 下一条",next_label.text)

func start_new_announcement() -> void:
	# 设置当前文本
	current_text = announcements[current_index]
	next_text = announcements[next_index]
	
	# 初始化字符控制数组
	current_chars.clear()
	next_chars.clear()
	for c in current_text:
		current_chars.append(CharacterControl.new(c))
	for c in next_text:
		next_chars.append(CharacterControl.new(c))
	
	# 重置显示状态
	visible_chars = 0
	next_visible_chars = 0
	char_timer = 0.0
	next_char_timer = 0.0
	
	# 重置位置
	scroll_pos = screen_width/2
	next_scroll_pos = screen_width
	
	# 重置透明度
	next_alpha = 0.0
	
	# 更新标签
	current_label.visible = true
	next_label.visible = true
	current_label.modulate.a = 1.0
	next_label.modulate.a = 0.0
	current_label.position.x = scroll_pos
	next_label.position.x = next_scroll_pos
	
	# 重置状态
	current_state = State.TYPING

func switch_to_next_announcement() -> void:
	# 更新索引
	current_index = next_index
	next_index = (next_index + 1) % announcements.size()
	
	# 重新开始显示
	start_new_announcement()

# 公共接口函数
func add_announcement(text: String) -> void:
	announcements.append(text)

func set_char_speed(interval: float) -> void:
	char_interval = interval

func set_scroll_speed(speed: float) -> void:
	scroll_speed = speed

func set_fade_speed(interval: float) -> void:
	fade_interval = interval

func set_transition_time(time: float) -> void:
	transition_time = time
