extends Window

@export var countdown: int = 20
@export var gamename: String = ""

@onready var grid_container = $Panel/VBoxContainer/GridContainer
@onready var timer_label = $Panel/VBoxContainer/HBoxContainer/TimerLabel
@onready var ready_label = $Panel/VBoxContainer/HBoxContainer/ReadyLabel
@onready var accept_button = $Panel/VBoxContainer/ButtonContainer/AcceptButton
@onready var decline_button = $Panel/VBoxContainer/ButtonContainer/DeclineButton

var png = preload("res://assets/game/snake.png")
var timer = Timer.new() 
var player_icons: Array[TextureRect] = []
var player_total = 0
var timer_value: int = 10
var game_id = 0 #当前的游戏ID
var ready_count = 0


func _ready():
	# SettingsManager.show_settings(1)
	add_child(timer)
	timer.wait_time = 1.0
	timer.timeout.connect(_on_timer_timeout)
	accept_button.pressed.connect(_on_accept_pressed)
	decline_button.pressed.connect(_on_decline_pressed)
	pass

# 初始化玩家图标
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

# 添加一个玩家
func add_player():
	ready_count += 1
	if ready_count > player_total:
		return
	player_icons[ready_count-1].modulate = Color(1, 0.84, 0)  # Gold color
	pass

func reset(gid:int,playerMax:int=10,readyCount:int=0):
	game_id = gid
	player_total = playerMax
	timer.stop()
	player_icons.clear()
	# 清除子项
	for child in grid_container.get_children():
		child.queue_free()
	
	# 重置准备图标
	if playerMax>3:
		grid_container.columns = floor(playerMax/2.0) if playerMax%2 == 0 else floor(playerMax/2.0)+1
	setup_player_icons()
	
	# 重置准备人数
	ready_count = 0
	for i in range(readyCount):
		add_player()
	timer_value = countdown

	# 重置文本
	ready_label.text = "   %d/%d已准备就绪" % [ready_count,player_total]
	pass

func start(delay:float=-1):
	visible = true
	timer.start(delay)
	pass

# 倒计时
func _on_timer_timeout():
	timer_value -= 1
	if timer_value > 0 and ready_count < player_total:
		add_player()
		timer_label.text = "进入游戏倒计时: %d 秒   " % timer_value
		ready_label.text = "   %d/%d已准备就绪" % [ready_count,player_total]
	elif timer_value == 0:
		_on_decline_pressed()
	else:
		print("匹配到游戏 时间:%d 准备人数:%d 总人数:%d"%[timer_value, ready_count, player_total])
		SignalManager.StartGameSIG.emit(game_id)
		reset(player_total)
	pass

func _on_accept_pressed():
	# Handle accept logic
	accept_button.disabled = true
	decline_button.visible = false
	accept_button.text = "已准备"

func _on_decline_pressed():
	# Handle decline logic
	SignalManager.CancleGameSIG.emit(game_id)
	reset(player_total)
	pass
