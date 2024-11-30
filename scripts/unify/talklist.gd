extends ItemList

# 是否自动滚动到底部
var auto_scroll: bool = true

func _ready():
    # 连接垂直滚动条的值改变信号
    get_v_scroll_bar().connect("value_changed", _on_scroll_changed)

# 添加消息并保持滚动在底部
func add_message(text: String):
    add_item(text)
    
    if auto_scroll:
        scroll_to_bottom()

# 滚动到底部的方法
func scroll_to_bottom():
    # 确保在下一帧执行滚动，以便正确计算内容高度
    call_deferred("_deferred_scroll_to_bottom")

func _deferred_scroll_to_bottom():
    # 选择最后一项并确保它可见
    var last_idx = item_count - 1
    if last_idx >= 0:
        ensure_current_is_visible()
        select(last_idx)
        deselect(last_idx)
        # 直接设置滚动条到最大值
        get_v_scroll_bar().value = get_v_scroll_bar().max_value

# 当用户手动滚动时检测是否应该继续自动滚动
func _on_scroll_changed(value: float):
    var scroll_bar = get_v_scroll_bar()
    # 如果滚动条接近底部，启用自动滚动
    if value >= scroll_bar.max_value - scroll_bar.page:
        auto_scroll = true
    else:
        # 如果用户向上滚动，禁用自动滚动
        auto_scroll = false