extends Panel

var player_name = ""
var hover_tween: Tween
var ready_status = false

signal player_info_requested(player_name)

func _ready():
	# 连接鼠标悬停信号
	$Button.mouse_entered.connect(_on_mouse_entered)
	$Button.mouse_exited.connect(_on_mouse_exited)

func set_player_name(name1):
	player_name = name1
	$MarginContainer/HBoxContainer/PlayerNameLabel.text = player_name
	
	# 如果是自己，特殊显示
	if player_name == "我":
		$MarginContainer/HBoxContainer/PlayerNameLabel.add_theme_color_override("font_color", Color.YELLOW)
	
	# 随机设置准备状态（仅作为演示）
	if randf() > 0.3:
		ready_status = true
		$MarginContainer/HBoxContainer/ReadyLabel.text = "已准备"
		$MarginContainer/HBoxContainer/ReadyLabel.add_theme_color_override("font_color", Color.GREEN)
		$StatusParticles.color = Color(0.49, 0.92, 0.43, 0.65)
	else:
		ready_status = false
		$MarginContainer/HBoxContainer/ReadyLabel.text = "未准备"
		$MarginContainer/HBoxContainer/ReadyLabel.add_theme_color_override("font_color", Color.RED)
		$StatusParticles.color = Color(0.92, 0.35, 0.35, 0.65)

func _on_mouse_entered():
	# 取消之前的动画
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
	
	# 鼠标悬停效果
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(0.99, 1.05), 0.15).set_ease(Tween.EASE_OUT)
	
	# 播放粒子效果
	$StatusParticles.restart()
	$StatusParticles.emitting = true

func _on_mouse_exited():
	# 取消之前的动画
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
	
	# 恢复正常大小
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1, 1), 0.1).set_ease(Tween.EASE_IN)

func _on_button_pressed():
	# 创建点击动画
	var click_tween = create_tween()
	click_tween.tween_property(self, "scale", Vector2(0.97, 0.97), 0.05)
	click_tween.tween_property(self, "scale", Vector2(1.03, 1.03), 0.1)
	click_tween.tween_property(self, "scale", Vector2(1, 1), 0.05)
	
	# 如果是其他玩家，显示玩家信息
	print('点击了',player_name)
	player_info_requested.emit(player_name)
	if player_name == "我":
		# 自己可以切换准备状态
		toggle_ready_status()
		#emit_signal("player_info_requested", player_name)
	pass

func toggle_ready_status():
	ready_status = !ready_status
	
	if ready_status:
		$MarginContainer/HBoxContainer/ReadyLabel.text = "已准备"
		$MarginContainer/HBoxContainer/ReadyLabel.add_theme_color_override("font_color", Color.GREEN)
		$StatusParticles.color = Color(0.49, 0.92, 0.43, 0.65)
	else:
		$MarginContainer/HBoxContainer/ReadyLabel.text = "未准备"
		$MarginContainer/HBoxContainer/ReadyLabel.add_theme_color_override("font_color", Color.RED)
		$StatusParticles.color = Color(0.92, 0.35, 0.35, 0.65)
	
	# 播放切换效果
	$StatusParticles.restart()
	$StatusParticles.emitting = true 
