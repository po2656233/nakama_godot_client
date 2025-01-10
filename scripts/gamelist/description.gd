extends RichTextLabel

var dragging = false
var last_touch_pos = Vector2()
var scroll_velocity = 0.0
var scroll_deceleration = 1000.0  # 滚动减速度
var min_swipe_speed = 50.0  # 最小滑动速度
var max_velocity = 2000.0  # 最大滚动速度
var touch_sensitivity = 1.5  # 触摸灵敏度

# 用于计算滑动速度
var last_scroll_pos = 0.0
var last_scroll_time = 0.0
var scroll_bar: VScrollBar

func _ready():
    # 获取滚动条引用
    scroll_bar = get_v_scroll_bar()
    scroll_active = true
    
func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            # 开始触摸
            dragging = true
            last_touch_pos = event.position
            scroll_velocity = 0.0
            last_scroll_time = Time.get_ticks_msec()
            last_scroll_pos = scroll_bar.value
        else:
            # 结束触摸，计算惯性
            dragging = false
            var current_time = Time.get_ticks_msec()
            var time_diff = (current_time - last_scroll_time) / 1000.0
            if time_diff > 0:
                var velocity = (scroll_bar.value - last_scroll_pos) / time_diff
                if abs(velocity) > min_swipe_speed:
                    scroll_velocity = clamp(velocity * touch_sensitivity, -max_velocity, max_velocity)
    
    elif event is InputEventScreenDrag:
        if dragging:
            # 处理拖动
            var delta_y = (event.position - last_touch_pos).y
            var new_value = scroll_bar.value - delta_y * touch_sensitivity
            # 确保在有效范围内
            new_value = clamp(new_value, scroll_bar.min_value, scroll_bar.max_value)
            scroll_bar.value = new_value
            last_touch_pos = event.position
            
            # 更新滚动位置和时间
            var current_time = Time.get_ticks_msec()
            if current_time != last_scroll_time:
                last_scroll_pos = scroll_bar.value
                last_scroll_time = current_time

func _process(delta):
    if !dragging and scroll_velocity != 0:
        # 应用惯性滚动
        var new_value = scroll_bar.value + scroll_velocity * delta
        new_value = clamp(new_value, scroll_bar.min_value, scroll_bar.max_value)
        scroll_bar.value = new_value
        
        # 处理减速
        var deceleration = scroll_deceleration * sign(scroll_velocity)
        if abs(scroll_velocity) <= abs(deceleration * delta):
            scroll_velocity = 0
        else:
            scroll_velocity -= deceleration * delta
        
        # 检查是否到达边界
        if scroll_bar.value <= scroll_bar.min_value or \
           scroll_bar.value >= scroll_bar.max_value:
            scroll_velocity = 0

# 可选：添加滚动到指定位置的功能
func scroll_to(position1: float, duration: float = 0.3):
    var tween = create_tween()
    tween.tween_property(scroll_bar, "value", 
        clamp(position1, scroll_bar.min_value, scroll_bar.max_value),
        duration)\
        .set_trans(Tween.TRANS_CUBIC)\
        .set_ease(Tween.EASE_OUT)

# 可选：滚动到顶部
func scroll_to_top(duration: float = 0.3):
    scroll_to(scroll_bar.min_value, duration)

# 可选：滚动到底部
func scroll_to_bottom(duration: float = 0.3):
    scroll_to(scroll_bar.max_value, duration)

# 可选：添加页面滚动功能
func scroll_page(up: bool = false, duration: float = 0.3):
    var page_size = size.y
    var target = scroll_bar.value + (-page_size if up else page_size)
    scroll_to(target, duration)