extends Control


# 预加载俱乐部项目场景和详情场景
var club_item_scene = preload("res://scenes/clublist/ClubItem.tscn")
var club_detail_scene = preload("res://scenes/clublist/ClubDetailScene.tscn")
const  club_data = preload("res://scripts/clublist/ClubData.gd")
var clubs = club_data.clubs
func _ready():
	# 初始化面板，设置为从上方进入
	$ClubsPanel.modulate.a = 0
	$ClubsPanel.position.y = -50
	SceneMgr.set_current_scene("clublist")
	SettingsMgr.show_settings()
	# 使用动画效果显示面板
	var tween = create_tween()
	tween.tween_property($ClubsPanel, "position:y", 0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property($ClubsPanel, "modulate:a", 1, 0.5)
	
	# 生成俱乐部列表
	populate_clubs_list()

func populate_clubs_list():
	var clubs_list = $ClubsPanel/VBoxContainer/ScrollContainer/ClubsList
	
	# 清除现有内容
	for child in clubs_list.get_children():
		child.queue_free()
	
	# 添加俱乐部项目（带动画效果）
	for i in range(clubs.size()):
		var club = clubs[i]
		var club_item = club_item_scene.instantiate()
		clubs_list.add_child(club_item)
		club_item.setup(club)
		club_item.pressed.connect(_on_club_pressed.bind(club))
		
		# 设置初始状态并添加出现动画
		club_item.modulate.a = 0
		club_item.position.x = -50
		
		var delay = i * 0.15
		var item_tween = create_tween()
		item_tween.tween_property(club_item, "position:x", 0, 0.3).set_delay(delay).set_ease(Tween.EASE_OUT)
		item_tween.parallel().tween_property(club_item, "modulate:a", 1, 0.3).set_delay(delay)
		

func _on_club_pressed(club):
	# 创建转场效果
	var transition_rect = ColorRect.new()
	transition_rect.color = Color(0.0, 0.0, 0.0, 0)
	transition_rect.size = get_viewport_rect().size
	add_child(transition_rect)
	
	# 执行转场动画
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.5, 0.3)
	tween.tween_callback(func(): _show_club_detail(club))
	tween.tween_property(transition_rect, "color:a", 0, 0.3)
	tween.tween_callback(func(): transition_rect.queue_free())

func _show_club_detail(club):
	# 切换到俱乐部详情场景
	var detail_scene = club_detail_scene.instantiate()
	add_child(detail_scene)
	detail_scene.setup(club)
	
	# 隐藏俱乐部列表面板
	$ClubsPanel.visible = false 
