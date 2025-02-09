extends PanelContainer

# 节点引用
@onready var status_label = $MarginContainer/Panel/Status
@onready var room_name_label = $MarginContainer/Panel/RoomName
@onready var game_name_label = $MarginContainer/Panel/GameName
@onready var room_id_label = $MarginContainer/Panel/RoomID
@onready var base_score_label = $MarginContainer/Panel/BaseScore
@onready var player_count_label = $MarginContainer/Panel/PlayerCount
@onready var join_button = $MarginContainer/HBoxContainer/JoinButton
@onready var favorite_button = $MarginContainer/HBoxContainer/FavoriteButton
@onready var room_lock = $MarginContainer/Panel/Lock
@onready var author = $author

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

signal room_clicked(room_data: Dictionary)
signal join_room(room_data: Dictionary)
signal favorite_toggled(is_favorite: bool)

# 收藏按钮样式
const FAVORITE_NORMAL_COLOR = Color(0.84, 0.402, 0.136, 0.741)
const FAVORITE_ACTIVE_COLOR = Color(0.49, 0.55, 0.14)

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	join_button.pressed.connect(_on_join_button_pressed)
	favorite_button.toggled.connect(_on_favorite_button_toggled)
	
	# 初始化收藏按钮样式
	_update_favorite_button()

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
	
	# 设置完数据后启动脉冲动画
	_start_pulse_animation()

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
	if not is_instance_valid(self):
		return
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.2).set_trans(Tween.TRANS_CUBIC)
	
	# # 添加光晕效果
	# var style = get_theme_stylebox("panel").duplicate()
	# style.shadow_size = 5
	# style.shadow_color = Color(0.2, 0.4, 0.8, 0.3)
	# add_theme_stylebox_override("panel", style)

func _on_mouse_exited():
	if not is_instance_valid(self):
		return
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_CUBIC)
	
	# 移除光晕效果
	# var style = load(room_style_path)
	# if style:
	# 	add_theme_stylebox_override("panel", style)

func _on_gui_input(event: InputEvent):
	if not is_instance_valid(self):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		room_clicked.emit(room_data)
		
		# 点击动画
		var scale_tween = create_tween()
		scale_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)
		scale_tween.tween_property(self, "scale", Vector2(1, 1), 0.1) 

func _on_join_button_pressed():
	if not is_instance_valid(self) or not is_instance_valid(join_button):
		return
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
	if not is_instance_valid(favorite_button):
		return
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
