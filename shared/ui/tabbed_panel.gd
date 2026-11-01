extends Control

@onready var tab_container = $MarginContainer/TabContainer

func _ready() -> void:
	# 连接选项卡切换信号
	tab_container.tab_changed.connect(_on_tab_changed)
	
	# 设置选项卡图标（可选）
	# tab_container.set_tab_icon(0, preload("res://icons/dashboard.png") if ResourceLoader.exists("res://icons/dashboard.png") else null)
	# tab_container.set_tab_icon(1, preload("res://icons/profile.png") if ResourceLoader.exists("res://icons/profile.png") else null)
	# tab_container.set_tab_icon(2, preload("res://icons/settings.png") if ResourceLoader.exists("res://icons/settings.png") else null)
	# tab_container.set_tab_icon(3, preload("res://icons/help.png") if ResourceLoader.exists("res://icons/help.png") else null)
	
	# 自定义选项卡样式
	_setup_tab_style()

func _setup_tab_style() -> void:
	# 创建选中状态的样式
	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.2, 0.22, 0.27)
	selected_style.corner_radius_top_left = 8
	selected_style.corner_radius_top_right = 8
	selected_style.expand_margin_bottom = 2
	selected_style.border_width_bottom = 2
	selected_style.border_color = Color(0.3, 0.5, 0.8)
	
	# 创建未选中状态的样式
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.17, 0.22)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	
	# 创建悬停状态的样式
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.17, 0.19, 0.24)
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	
	# 应用样式
	tab_container.add_theme_stylebox_override("tab_selected", selected_style)
	tab_container.add_theme_stylebox_override("tab_unselected", normal_style)
	tab_container.add_theme_stylebox_override("tab_hovered", hover_style)
	
	# 设置面板背景
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.22, 0.27)
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	tab_container.add_theme_stylebox_override("panel", panel_style)

func _on_tab_changed(tab: int) -> void:
	# 当选项卡改变时的处理逻辑
	match tab:
		0: # Dashboard
			pass
		1: # Profile
			pass
		2: # Settings
			pass
		3: # Help
			pass
