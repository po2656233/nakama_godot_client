extends Panel

signal member_clicked(member_name)

var hover_tween: Tween
var member_name = ""

func _ready():
	# 连接鼠标悬停信号
	$PanelButton.mouse_entered.connect(_on_mouse_entered)
	$PanelButton.mouse_exited.connect(_on_mouse_exited)

func set_member_name(name1):
	member_name = name1
	$MarginContainer/HBoxContainer/MemberNameLabel.text = member_name
	
	# 如果是自己，特殊显示
	if member_name == "我":
		$MarginContainer/HBoxContainer/MemberNameLabel.add_theme_color_override("font_color", Color.YELLOW)
	
	# 随机设置在线状态（仅作为演示）
	if randf() > 0.5:
		$MarginContainer/HBoxContainer/StatusLabel.text = "在线"
		$MarginContainer/HBoxContainer/StatusLabel.add_theme_color_override("font_color", Color.GREEN)
	else:
		$MarginContainer/HBoxContainer/StatusLabel.text = "离线"
		$MarginContainer/HBoxContainer/StatusLabel.add_theme_color_override("font_color", Color.RED)
	
	# 添加点击提示图标
	$MarginContainer/HBoxContainer/InfoIcon.modulate = Color(0.8, 0.9, 1.0, 0.7)

func _on_mouse_entered():
	# 取消之前的动画（如果存在）
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
	
	# 创建鼠标悬停效果
	$Glow.visible = true
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.1).set_ease(Tween.EASE_OUT)
	
	# 添加脉冲发光效果
	var glow_tween = create_tween()
	glow_tween.tween_property($Glow, "modulate:a", 0.4, 0.5)
	glow_tween.tween_property($Glow, "modulate:a", 0.1, 0.5)
	glow_tween.set_loops()

func _on_mouse_exited():
	# 取消之前的动画（如果存在）
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
	
	# 恢复正常大小
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1, 1), 0.1).set_ease(Tween.EASE_IN)
	
	# 隐藏发光效果
	$Glow.visible = false

func _on_panel_button_pressed():
	# 点击动画效果
	var click_tween = create_tween()
	click_tween.tween_property(self, "scale", Vector2(0.98, 0.98), 0.05)
	click_tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.1)
	click_tween.tween_property(self, "scale", Vector2(1, 1), 0.05)
	
	# 发送点击信号
	emit_signal("member_clicked", member_name)
