extends PanelContainer

signal group_selected(group_data)
signal group_clicked()
signal group_left(group_data)
signal notification_toggled(group_data, enabled)

var group_data: Dictionary
var notify_id: int = 2

var style = StyleBoxFlat.new()
# 定义颜色常量
const NORMAL_COLOR = Color(0.9, 0.9, 0.9, 1)  # 普通状态为灰色
const HOVER_COLOR = Color(1, 1, 1, 1)  # 悬浮状态为亮色（白色）
const SELECTED_COLOR = Color(1, 0.95, 0.7, 1)  # 选中状态为黄色

func _ready():
	gui_input.connect(_on_gui_input)
	
	# 设置管理菜单
	var popup = $MarginContainer/HBoxContainer/ManageButton.get_popup()
	popup.add_item("退出俱乐部", 0)
	popup.add_separator()
	popup.add_check_item("接收消息通知", notify_id)
	popup.id_pressed.connect(_on_manage_option_selected)
	
	# 初始化颜色
	self_modulate = NORMAL_COLOR
	_setup_panel_style(false)

func setup(data: Dictionary):
	group_data = data
	$MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/GroupName.text = data["name"]
	$MarginContainer/HBoxContainer/VBoxContainer/MemberCount.text = "成员数: %d" % data["member_count"]
	
	# 设置通知状态
	var popup = $MarginContainer/HBoxContainer/ManageButton.get_popup()
	popup.set_item_checked(notify_id, data.get("notification_enabled", true))
	_update_notification_icon()


func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.double_click:
			group_selected.emit(group_data)
		elif event.is_pressed and event.button_index == MOUSE_BUTTON_LEFT:
			group_clicked.emit()

func _on_manage_option_selected(id: int):
	match id:
		0:  # 退出俱乐部
			_show_leave_confirmation()
		notify_id:  # 切换通知状态
			var popup = $MarginContainer/HBoxContainer/ManageButton.get_popup()
			var enabled = not popup.is_item_checked(id)
			popup.set_item_checked(id, enabled)
			group_data["notification_enabled"] = enabled
			notification_toggled.emit(group_data, enabled)
			_update_notification_icon()

func _show_leave_confirmation():
	var dialog = ConfirmationDialog.new()
	dialog.title = "退出俱乐部"
	dialog.dialog_text = "确定要退出该俱乐部吗？"
	
	add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func():
		group_left.emit(group_data)
		dialog.queue_free()
	)

func _update_notification_icon():
	var icon = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/NotificationIcon
	if group_data.get("notification_enabled", true):
		icon.modulate = Color(0.2, 0.8, 0.2)  # 绿色
	else:
		icon.modulate = Color(0.6, 0.6, 0.6)  # 灰色


func _setup_panel_style(isSelected: bool):
	style.bg_color = Color.DARK_GREEN if isSelected else Color(0.019, 0.388, 0.575)  # 白色背景
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.1)  # 半透明黑色阴影
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	add_theme_stylebox_override("panel", style)
	
func get_group_data():
	return group_data