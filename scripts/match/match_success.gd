extends Window

@export var countdown: int = 20
@export var gamename: String = ""

@onready var grid_container = $Panel/VBoxContainer/GridContainer
@onready var timer_label = $Panel/VBoxContainer/HBoxContainer/TimerLabel
@onready var ready_label = $Panel/VBoxContainer/HBoxContainer/ReadyLabel
@onready var accept_button = $Panel/VBoxContainer/ButtonContainer/AcceptButton
@onready var decline_button = $Panel/VBoxContainer/ButtonContainer/DeclineButton

var png = preload("res://assets/game/snake1.png")
var png1 = preload("res://assets/game/snake2.png")
var timer = Timer.new()
var player_icons: Array[TextureRect] = []
var player_total = 0
var timer_value: int = 10
var timer_warn: int = 8
var game_id = 0 # 当前的游戏ID
var match_id = ""
var ready_count = 0
var isStart = false
var base_text_1 = "进入游戏倒计时: %02d 秒   "
var base_text_2 = "进入游戏倒计时: [b][color=red]%02d[/color][/b] 秒   "
enum MatchState {
	GameReady = 1000,
	GameReadyCancel,
	GameStart,
}


func _ready():
	# SettingsManager.show_settings(1)
	add_child(timer)
	timer.wait_time = 1.0
	timer.timeout.connect(_on_timer_timeout)
	accept_button.pressed.connect(_on_accept_pressed)
	decline_button.pressed.connect(_on_decline_pressed)
	SignalManager.MatchStateEventSIG.connect(_on_match_state_event)
	pass

# 初始化玩家图标
func setup_player_icons():
	# Create 10 player icons (5x2 grid)
	for i in range(player_total):
		var icon = TextureRect.new()
		icon.texture = png
		icon.custom_minimum_size = Vector2(100, 100)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(0.5, 0.5, 0.6) # Gray color
		# First 6 icons are ready (gold), rest are not ready (gray)
		grid_container.add_child(icon)
		player_icons.append(icon)

# 添加一个玩家
func add_player(is_ready=true):
	ready_count += 1
	if ready_count > player_total:
		return
	if is_ready:
		SignalManager.MatchSuccessOkMusicSIG.emit()
		player_icons[ready_count - 1].modulate = Color(1, 0.84, 0) # Gold color
	else:
		timer.stop()
		SignalManager.MatchSuccessTimeMusicSIG.emit(true)
		SignalManager.MatchSuccessFailedMusicSIG.emit()
		player_icons[ready_count - 1].texture = png1
		player_icons[ready_count - 1].modulate = Color(1, 1, 1)
	pass


func reset(gid: int, playerMax: int = 10, readyCount: int = 0):
	game_id = gid
	player_total = playerMax
	timer.stop()
	player_icons.clear()
	isStart = false
	accept_button.disabled = false
	decline_button.visible = true
	accept_button.text = "准备"
	SignalManager.MatchSuccessTimeMusicSIG.emit(true)
	# 清除子项
	for child in grid_container.get_children():
		child.queue_free()
	
	# 重置准备图标
	if playerMax > 3:
		grid_container.columns = floor(playerMax / 2.0) if playerMax % 2 == 0 else floor(playerMax / 2.0) + 1
	setup_player_icons()
	
	# 重置准备人数
	ready_count = 0
	for i in range(readyCount):
		add_player()
	timer_value = countdown

	# 重置文本
	timer_label.text = base_text_1 % timer_value
	ready_label.text = "   %d/%d已准备就绪" % [ready_count, player_total]
	pass

func start(delay: float = -1, warn: int = 6):
	visible = true
	timer_warn = warn
	timer.start(delay)
	pass

func check_ready():
	if ready_count >= player_total:
		# 匹配成功
		print("匹配到游戏 时间:%d 准备人数:%d 总人数:%d" % [timer_value, ready_count, player_total])
		visible = false
		SignalManager.StartGameSIG.emit(game_id)
		reset(game_id, player_total)
		return true
	return false

# 倒计时
func _on_timer_timeout():
	if check_ready():
		return

	timer_value -= 1
	if timer_value >= 0 and ready_count < player_total:
		if timer_value <= timer_warn:
			if not accept_button.disabled:
				SignalManager.MatchSuccessTimeMusicSIG.emit(false)
			timer_label.text = base_text_2 % timer_value
		else:
			timer_label.text = base_text_1 % timer_value

		ready_label.text = "   %d/%d已准备就绪" % [ready_count, player_total]
	elif timer_value == -1:
		SignalManager.CancleGameSIG.emit(game_id)
		_on_decline_pressed()
	pass


func _on_accept_pressed():
	# Todo 请求服务端
	print("准备游戏 ", match_id)
	accept_button.disabled = true
	decline_button.visible = false
	SignalManager.MatchSuccessTimeMusicSIG.emit(true)
	var ret = await OnlineGame.sendToMatch(MatchState.GameReady, "1")
	if not ret or (ret and ret.is_exception()):
		accept_button.disabled = false
		decline_button.visible = true
		accept_button.text = "准备"
		print("准备游戏失败",ret)
	else:
		accept_button.text = "已准备"

func _on_decline_pressed():
	# Handle decline logic
	print("取消游戏 match_id:", match_id)
	timer_label.text = base_text_2 % [0]
	await OnlineGame.sendToMatch(MatchState.GameReadyCancel, "0")
	pass


func _on_match_state_event(state):
	if isStart:
		return
	match state.op_code:
		MatchState.GameReady:
			add_player()
		MatchState.GameReadyCancel:
			add_player(false)
			SignalManager.CancleGameSIG.emit(game_id)
		MatchState.GameStart:
			isStart = true
	return
