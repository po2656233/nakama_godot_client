extends Control

enum ColorChangeMode {BRIGHTNESS, CUSTOM_COLOR}

# 颜色变化模式设置
@export var change_mode: ColorChangeMode = ColorChangeMode.BRIGHTNESS
# 亮度模式的设置
@export var brightness_factor: float = 1.2
# 自定义颜色模式的设置
@export var custom_color: Color = Color(0.8, 0.8, 1.0, 1.0)
# 过渡时间
@export var transition_duration: float = 0.3

var tween: Tween
var is_active: bool = false
var original_color: Color

func _ready():
	# 确保控件可以接收鼠标输入
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 保存原始颜色
	original_color = modulate
	
	# 连接鼠标事件信号
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			toggle_color()

func toggle_color():
	is_active = !is_active
	
	var target_color: Color
	match change_mode:
		ColorChangeMode.BRIGHTNESS:
			target_color = original_color * brightness_factor if is_active else original_color
		ColorChangeMode.CUSTOM_COLOR:
			target_color = custom_color if is_active else original_color
	
	# 如果已有正在进行的动画，先停止它
	if tween and tween.is_valid():
		tween.kill()
	
	# 创建新的颜色过渡动画
	tween = create_tween()
	tween.tween_property(self, "modulate", target_color, transition_duration)
