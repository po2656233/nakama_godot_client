extends Window

@export var timer_value: int = 15

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

func _ready():
	add_child(timer)
	setup_player_icons()
	start_countdown()
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

func start_countdown():
	timer.wait_time = 1.0
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func add_player():
	ready_count += 1
	if ready_count > player_total:
		return
	player_icons[ready_count-1].modulate = Color(1, 0.84, 0)  # Gold color
	pass

func reset():
	timer.stop()
	ready_count = 0
	timer_value = 15
	timer.start()
	for i in range(player_total):
		player_icons[i].modulate = Color(0.5, 0.5, 0.6)
	pass

func _on_timer_timeout():
	timer_value -= 1
	if timer_value >= 0 and ready_count < player_total:
		add_player()
		timer_label.text = "进入游戏倒计时: %d 秒   " % timer_value
		ready_label.text = "   %d/10已准备就绪" % ready_count
	else:
		reset()
		visible = false
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
	pass
