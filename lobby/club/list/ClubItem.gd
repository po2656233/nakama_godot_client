extends Button

var club_data = {}
var hover_tween: Tween

func _ready():
	# 连接鼠标悬停信号
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_button_pressed)

func setup(club):
	club_data = club
	$MarginContainer/VBoxContainer/ClubName.text = club.name
	
	# 设置成员列表
	var members_text = ", ".join(club.members)
	$MarginContainer/VBoxContainer/HBoxContainer/MembersContainer/MembersList.text = members_text
	
	# 设置游戏列表
	var games_text = ", ".join(club.games)
	$MarginContainer/VBoxContainer/HBoxContainer/GamesContainer/GamesList.text = games_text

func _on_mouse_entered():
	# 取消之前的动画（如果存在）
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
	
	# 创建鼠标悬停效果
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1.03, 1.03), 0.15).set_ease(Tween.EASE_OUT)
	
	# 使用粒子效果
	$Sparkles.restart()
	$Sparkles.emitting = true

func _on_mouse_exited():
	# 取消之前的动画（如果存在）
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
	
	# 恢复正常大小
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1, 1), 0.1).set_ease(Tween.EASE_IN)

func _on_button_pressed():
	# 创建点击效果
	var click_tween = create_tween()
	click_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)
	click_tween.tween_property(self, "scale", Vector2(1, 1), 0.1) 
