extends Control

# 匹配游戏名称
@export var gamename: String = ""
@export var maxplayer: int = 1
# 信号
signal match_start()
signal match_cancel()
signal match_sucess()


# 匹配状态
enum MatchState { IDLE, MATCHING, SUCCESS, FAILED }
var current_state: MatchState = MatchState.IDLE

# 计时相关变量
var elapsed_time: float = 0
var is_matching: bool = false

# 动画相关变量
var progress_rotation: float = 0
var progress_speed: float = 1.2
var progress_value: float = 0.0

var base_text = "正在匹配中"
var dots = [".", ".", "."]
var time = 0.0
var dot_speed = 3.0  # 动画速度
# 节点引用
@onready var game_name = $Panel/VBoxContainer/NameLabel
@onready var timer_label = $Panel/VBoxContainer/TimerLabel
@onready var status_label = $Panel/VBoxContainer/StatusLabel
@onready var progress_circle = $Panel/VBoxContainer/ProgressCircle
@onready var cancel_button = $Panel/VBoxContainer/HBoxContainer/CancelButton
@onready var start_button = $Panel/VBoxContainer/HBoxContainer/StartButton
@onready var animation_player = $AnimationPlayer
@onready var match_sound = $MatchSound
@onready var success_sound = $SuccessSound
@onready var fail_sound = $FailSound


# 初始化
func _ready():
	# 初始化UI状态
	reset_ui()
	# 连接信号
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	match_start.connect(_on_start_button_pressed)
	SignalManager.MatchStateEventSIG.connect(_on_match_state_event)
	SignalManager.MatchPresenceEventSIG.connect(_on_match_presence_event)
	SignalManager.MatchMakerSIG.connect(_on_match_maker_event)
	
	pass


func _process(delta):
	if is_matching:
		elapsed_time += delta 
		update_timer_display()
		# 更新进度圈
		progress_rotation += delta * progress_speed
		progress_value = fmod(progress_rotation, 1.0)
		progress_circle.material.set_shader_parameter("progress", progress_value)
		#
		time += delta
		var dot_count = int(fmod(time * dot_speed, 4))  # 0到3之间循环
		status_label.text = base_text + "".rpad(dot_count,"." )
	pass

func start_matching():
	current_state = MatchState.MATCHING
	is_matching = true
	game_name.text = gamename
	status_label.text = base_text
	elapsed_time = 0
	cancel_button.visible = true
	start_button.visible = false
	animation_player.play("matching_pulse")
	match_sound.play()
	
	# 显示进度动画
	progress_circle.visible = true
	progress_rotation = 0
	progress_value = 0

	OnlineMatch.create_match(Online.nakama_socket)
	# var result = await OnlineMatch.create_match(Online.nakama_socket)
	# if result.is_exception():
	# 	_on_match_failed()
	# 	print("错误信息: ", result.get_exception().message)
	# else:
	# 	print("当前匹配信息: ", result, gamename, maxplayer, result.ticket)
	# 	PopupManager.show_dynamic("已添加至匹配池,请您耐心等待")

	# await get_tree().create_timer(randf_range(2, 5)).timeout
	# _on_match_success()
	# if randf() > 0.5:
	# 	_on_match_success()
	# else:
	# 	_on_match_failed()
	# pass

func stop_matching():
	is_matching = false
	current_state = MatchState.IDLE
	reset_ui()
	animation_player.stop()
	match_sound.stop()
	match_cancel.emit()

func reset_ui():
	game_name.text = gamename
	status_label.text = "等待开始匹配..."
	timer_label.text = "00:00"
	cancel_button.visible = false
	start_button.visible = true
	progress_circle.visible = false
	progress_circle.material.set_shader_parameter("progress", 0.0)

func update_timer_display():
	var minutes = floor(elapsed_time / 60)
	var seconds = fmod(elapsed_time, 60)
	timer_label.text = "%02d:%02d" % [minutes, seconds]


func _on_cancel_button_pressed():
	stop_matching()
	
func _on_start_button_pressed():
	start_matching()


func _on_match_state_event(state):
	print("匹配 state:", state)
	pass

func _on_match_presence_event(state):
	print("匹配 presence:", state)
	pass

func _on_match_maker_event(state):
	print("匹配 maker:", state)
	pass

func _on_match_success():
	current_state = MatchState.SUCCESS
	is_matching = false
	status_label.text = "匹配成功"
	cancel_button.visible = false
	animation_player.play("success_flash")
	progress_circle.visible = false
	match_sound.stop()
	success_sound.play()
	
	# 这里添加切换到游戏场景的代码
	match_sucess.emit()
	print("切换到游戏场景")

func _on_match_failed():
	current_state = MatchState.FAILED
	is_matching = false
	status_label.text = "匹配到的房间已关闭,请重试"
	cancel_button.visible = true
	start_button.visible = true
	animation_player.play("failed_shake")
	progress_circle.visible = false
	match_sound.stop()
	fail_sound.play()
