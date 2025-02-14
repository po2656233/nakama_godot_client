extends PanelContainer

signal room_selected(room_data: Dictionary)
signal join_room(room_data: Dictionary)
signal favorite_toggled(is_favorite: bool)

# 节点引用
@onready var roomFront = $Front
@onready var status_label = $Front/MarginContainer/Panel/Status
@onready var room_name_label = $Front/MarginContainer/Panel/RoomName
@onready var game_name_label = $Front/MarginContainer/Panel/GameName
@onready var room_id_label = $Front/MarginContainer/Panel/RoomID
@onready var base_score_label = $Front/MarginContainer/Panel/BaseScore
@onready var player_count_label = $Front/MarginContainer/Panel/PlayerCount
@onready var join_button = $Front/MarginContainer/HBoxContainer/JoinButton
@onready var favorite_button = $Front/MarginContainer/HBoxContainer/FavoriteButton
@onready var room_lock = $Front/MarginContainer/Panel/Lock
@onready var author = $Author

@onready var roomBack = $Back
@onready var detail_panel = $Back/DetailPanel
@onready var detail_info = $Back/DetailPanel/MarginContainer/ScrollContainer/VBoxContainer/RoomInfo
@onready var animation = $AnimationPlayer
var room_style_path = "res://styles/room_panel_style.tres"
var waiting_style_path = "res://styles/waiting_style.tres"
var playing_style_path = "res://styles/playing_style.tres"
var full_style_path = "res://styles/full_style.tres"
var default_style_path = "res://styles/default_style.tres"

var hover_tween: Tween
var pulse_tween: Tween
var room_data: Dictionary = {}  # 初始化为空字典
var is_favorite: bool = false:
	set(value):
		is_favorite = value
		_update_favorite_button()

# 收藏按钮样式
const FAVORITE_NORMAL_COLOR = Color(0.84, 0.402, 0.136, 0.741)
const FAVORITE_ACTIVE_COLOR = Color(0.49, 0.55, 0.14)
# 滑动相关变量
var is_flipped = true
var is_hovering = false
var is_animating = false
var is_dragging = false
var drag_start_position = Vector2.ZERO
var min_swipe_distance = 200  # 最小滑动距离

func _ready():
	# 初始化收藏按钮样式
	_update_favorite_button()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	join_button.pressed.connect(_on_join_button_pressed)
	favorite_button.toggled.connect(_on_favorite_button_toggled)

# 获取BBCode格式的内容
func getBBCodeContent(field, value):
	return "[indent][color=black]%s:[/color]  [/indent][color=#98eed1]%s[/color]\n"%[field, value]
	

func setup(data: Dictionary):
	room_data = data
	room_name_label.text = data.get("room_name", "")
	game_name_label.text = data.get("game_name", "")
	room_id_label.text = data.get("room_id", "")
	base_score_label.text = str(data.get("base_score", 0))+" 分"
	player_count_label.text = "%d/%d" % [data.get("player_count", 0), data.get("max_players", 0)]
	status_label.text = data.get("status", "")
	room_lock.visible = data.get("is_locked", false)
	author.text = "@"+data.get("author", "")+" "
	# 根据状态设置状态标签样式
	var style_path: String
	match data.get("status", ""):
		"等待中":
			style_path = waiting_style_path
		"进行中":
			style_path = playing_style_path
		"已满员":
			style_path = full_style_path
		_:
			style_path = default_style_path
	
	var style = load(style_path)
	if style:
		status_label.add_theme_stylebox_override("normal", style)
	
	# 根据状态设置加入按钮
	join_button.disabled = data.get("status", "") == "已满员"
	if join_button.disabled:
		join_button.text = "房间已满"
	
	# 设置详情面板数据
	var content = getBBCodeContent("房间名称", data.get("room_name", ""))
	content += getBBCodeContent("游戏类型", data.get("game_name", ""))
	content += getBBCodeContent("房间ID", data.get("room_id", ""))
	content += getBBCodeContent("底分", str(data.get("base_score", 0)))
	content += getBBCodeContent("入场分", str(data.get("entry_score", 0)))
	content += getBBCodeContent("房间状态", data.get("status", ""))
	content += getBBCodeContent("最大人数", str(data.get("max_players", 0)))
	content += getBBCodeContent("创建时间", data.get("create_time", ""))
	content += getBBCodeContent("房间描述", data.get("description", ""))
	var rules = data.get("rules", []).map(func(rule): return "- " + rule)
	content += getBBCodeContent("规则", rules)
	var players = data.get("players", []).map(func(player): return "- " + player.username)
	content += getBBCodeContent("当前玩家", players)
	detail_info.clear()
	detail_info.text = content

	# 设置完数据后启动脉冲动画
	_start_pulse_animation()
	pass

func _update_favorite_button():
	var style = favorite_button.get_theme_stylebox("normal").duplicate()
	if is_favorite:
		style.bg_color = FAVORITE_ACTIVE_COLOR
		favorite_button.text = "★ 已收藏"
	else:
		style.bg_color = FAVORITE_NORMAL_COLOR
		favorite_button.text = "☆ 收藏"
	favorite_button.add_theme_stylebox_override("normal", style)
	# favorite_button.disabled = is_favorite
	pass

func _on_mouse_entered():
	if not is_hovering and not animation.is_playing():
		is_hovering = true
		animation.play("hover")
	pass

func _on_mouse_exited():
	if is_hovering:
		is_hovering = false
		scale = Vector2(1, 1)  # 直接重置缩放，不使用动画
	pass

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			 # 如果没有明显的拖动，则视为点击，且双击
			if event.double_click and  (event.position - drag_start_position).length() < min_swipe_distance:
				room_selected.emit(room_data)
				print("即将进入房间", room_data["room_name"])
				return
			if event.pressed:
				# 开始拖动
				drag_start_position = event.position
				is_dragging = true
			else:
				# 结束拖动
				is_dragging = false
	
	elif event is InputEventMouseMotion and is_dragging:
		# 计算水平滑动距离
		var drag_distance = event.position.x - drag_start_position.x
		# 如果滑动距离超过阈值，触发翻转
		if abs(drag_distance) > min_swipe_distance:
			is_dragging = false  # 防止多次触发
			flip()
	pass
	# if not is_instance_valid(self):
	# 	return
	# if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
	# 	room_selected.emit(room_data)
	# 	# 点击动画
	# 	var scale_tween = create_tween()
	# 	scale_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)
	# 	scale_tween.tween_property(self, "scale", Vector2(1, 1), 0.1) 

func _on_join_button_pressed():
	# 点击动画
	var click_tween = create_tween()
	click_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)
	click_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# 按钮动画
	var button_tween = create_tween()
	button_tween.tween_property(join_button, "modulate", Color(1.2, 1.2, 1.2), 0.1)
	button_tween.tween_property(join_button, "modulate", Color(1, 1, 1), 0.1)
	
	# 这里可以发送加入房间的信号
	join_room.emit(room_data)
	print("加入房间：", room_data.get("room_name", ""))

func _on_favorite_button_toggled(_button_pressed: bool):
	is_favorite = !is_favorite
	favorite_toggled.emit(is_favorite)
	
	# 添加收藏动画
	var rotation_tween = create_tween()
	var target_rotation = PI if is_favorite else 0.0
	rotation_tween.tween_property(favorite_button, "rotation", target_rotation, 0.3)

func _start_pulse_animation():
	if not is_instance_valid(status_label):
		return
	if room_data.has("status") and room_data.status == "等待中":
		if pulse_tween:
			pulse_tween.kill()
		pulse_tween = create_tween()
		pulse_tween.set_loops()
		pulse_tween.tween_property(status_label, "modulate:a", 0.2, 1.5)
		pulse_tween.tween_property(status_label, "modulate:a", 1.5, 1.5)


# 翻转动画
func flip():
	if is_animating:
		return
		
	is_animating = true
	animation.play("flip")
	
	# 在动画中间点切换正反面
	await get_tree().create_timer(0.4).timeout
	roomFront.visible = !is_flipped
	roomBack.visible = is_flipped
	is_flipped = !is_flipped
	
	await animation.animation_finished
	is_animating = false