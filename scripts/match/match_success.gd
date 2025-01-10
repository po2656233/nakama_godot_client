extends Window

@export var countdown: int = 20
@export var gamename: String = ""

@onready var grid_container = $Panel/VBoxContainer/GridContainer
@onready var timer_label = $Panel/VBoxContainer/HBoxContainer/TimerLabel
@onready var ready_label = $Panel/VBoxContainer/HBoxContainer/ReadyLabel
@onready var accept_button = $Panel/VBoxContainer/ButtonContainer/AcceptButton
@onready var decline_button = $Panel/VBoxContainer/ButtonContainer/DeclineButton
var timer = Timer.new()
var ready_count = 0
var png = preload("res://assets/game/snake.png")
var player_icons: Array[TextureRect] = []
var player_total = 10
var timer_value: int = 10
var game_id = 0 #当前的游戏ID
signal cancle_game(id)
func _ready():
	# SettingsManager.show_settings(1)
	add_child(timer)
	timer.wait_time = 1.0
	timer.timeout.connect(_on_timer_timeout)
	
	reset()
	# start_countdown()
	setup_buttons()

func setup_player_icons():
	# Create 10 player icons (5x2 grid)
	for i in range(player_total):
		var icon = TextureRect.new()
		icon.texture = png
		icon.custom_minimum_size = Vector2(80, 80)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(0.5, 0.5, 0.6)  # Gray color
		# First 6 icons are ready (gold), rest are not ready (gray)
		grid_container.add_child(icon)
		player_icons.append(icon)

func setup_buttons():
	accept_button.pressed.connect(_on_accept_pressed)
	decline_button.pressed.connect(_on_decline_pressed)


func add_player():
	ready_count += 1
	if ready_count > player_total:
		return
	player_icons[ready_count-1].modulate = Color(1, 0.84, 0)  # Gold color
	pass

func reset(player_max:int=10):
	player_total = player_max
	player_icons.clear()
	# 清除子项
	for child in grid_container.get_children():
		child.queue_free()
	
	# 重置准备图标
	setup_player_icons()
	timer.stop()
	ready_count = 0
	timer_value = countdown
	for i in range(player_total):
		player_icons[i].modulate = Color(0.5, 0.5, 0.6)
	pass

func start():
	visible = true
	timer.start()
	pass

func _on_timer_timeout():
	timer_value -= 1
	if timer_value >= 0 and ready_count < player_total:
		add_player()
		timer_label.text = "进入游戏倒计时: %d 秒   " % timer_value
		ready_label.text = "   %d/10已准备就绪" % ready_count
	else:
		reset()
		print("匹配到游戏",timer_value,ready_count, player_total)
		SceneManager.switch_to_scene("xiangqi")
	pass

func _on_accept_pressed():
	# Handle accept logic
	accept_button.disabled = true
	decline_button.visible = false
	accept_button.text = "已准备"

func _on_decline_pressed():
	# Handle decline logic
	reset()
	# queue_free()
	cancle_game.emit(game_id)
	pass
