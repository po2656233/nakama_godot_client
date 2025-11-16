extends Control

# 匹配游戏名称
@export var gamename: String = ""
@export var maxplayer: int = 1

# 信号
signal match_start()
signal match_cancel()
signal match_sucess(data)

# 匹配状态
enum MatchState {IDLE, MATCHING, SUCCESS, FAILED}
var current_state: MatchState = MatchState.IDLE

# 计时相关变量
var elapsed_time: float = 0
var is_matching: bool = false

# 动画相关变量
var progress_rotation: float = 0
var progress_speed: float = 1.0
var progress_value: float = 0.0

var base_text = "正在匹配中"
var dots = [".", ".", "."]
var time = 0.0
var accumulator := 0.0
var dot_speed = 3.0 # 动画速度
# 已匹配的玩家数量
var players = []
const HIGHT_LIMIT = 10000000

# 节点引用
@onready var game_name = $Panel/VBoxContainer/NameLabel
@onready var timer_label = $Panel/VBoxContainer/TimerLabel
@onready var status_label = $Panel/VBoxContainer/StatusLabel
@onready var progress_circle = $Panel/VBoxContainer/ProgressCircle
@onready var cancel_button = $Panel/VBoxContainer/HBoxContainer/CancelButton
@onready var start_button = $Panel/VBoxContainer/HBoxContainer/StartButton
@onready var animation_player = $AnimationPlayer



# 初始化
func _ready():
	# 初始化UI状态
	reset_ui()
	# 连接信号
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	match_start.connect(_on_start_button_pressed)

	Global.SignalMgr.MatchMakerSIG.connect(_on_match_maker_event)
	Global.SignalMgr.MatchMakerFailedSIG.connect(_on_match_failed)
	pass


func _process(delta):	
	if is_matching:
		accumulator += delta
		elapsed_time += delta
		update_timer_display()
		# 更新进度圈
		progress_rotation += delta * progress_speed
		progress_value = fmod(progress_rotation, 1.0)
		if accumulator >= 2.0:
			accumulator = fmod(accumulator, 2.0) # 保留余数防止误差累积
			var hue = randf()                # 0.0 ~ 1.0 之间的色相
			var saturation = randf_range(0.3, 1.0)  # 高饱和度
			var value = randf_range(0.9, 1.0)       # 高亮度
			progress_circle.material.set_shader_parameter("color", Color.from_hsv(hue, saturation, value, 1.0))
			Global.SignalMgr.MatchingTimeMusicSIG.emit(false)
		progress_circle.material.set_shader_parameter("progress", progress_value)
		#
		time += delta
		var dot_count = int(fmod(time * dot_speed, 4)) # 0到3之间循环
		status_label.text = base_text + "".rpad(dot_count, ".")
	pass

func _exit_tree():
	if is_matching:
		print("离开前,停止匹配")
		stop_matching()
	pass
		
		

#####################################################################
func start_matching():
	current_state = MatchState.MATCHING
	is_matching = true
	game_name.text = gamename
	status_label.text = base_text
	elapsed_time = 0
	cancel_button.visible = true
	start_button.visible = false
	animation_player.play("matching_pulse")
	Global.SignalMgr.MatchingTimeMusicSIG.emit(true)
	# 显示进度动画
	progress_circle.visible = true
	accumulator = 0
	progress_rotation = 0
	progress_value = 0
	var minplayer = 1
	var gname = Global.OnlineGame.getGameEnName_by(gamename)
	if maxplayer < minplayer:
		maxplayer = HIGHT_LIMIT
	Global.OnlineMatch.joinMatchmaker({
		"query": " +properties.game:%s +properties.name:%s" %[gname,gamename],
		"min_count": minplayer,
		"max_count": maxplayer,
		"string_properties": {
			"game": gname,
			"name": gamename,
		},
		"numeric_properties": {
			"maxplayer": maxplayer,
			"vip": 1,
			"tickRate":30,
		}
		})
	# Global.OnlineMatch.create_match(Global.Online.nakama_socket)
	# var result = await Global.OnlineMatch.create_match(Global.Online.nakama_socket)
	# if result.is_exception():
	# 	_on_match_failed()
	# 	print("错误信息: ", result.get_exception().message)
	# else:
	# 	print("当前匹配信息: ", result, gamename, maxplayer, result.ticket)
	# 	Global.WindowPopup.show_dynamic("已添加至匹配池,请您耐心等待")

	# await get_tree().create_timer(randf_range(2, 5)).timeout
	# _on_match_success()
	# if randf() > 0.5:
	# 	_on_match_success()
	# else:
	# 	_on_match_failed()
	# pass

func stop_matching():
	var leave = await Global.OnlineMatch.LeaveMatch()
	if leave and leave.is_exception():
		Global.WindowPopup.show_dynamic("停止匹配失败")
		print("错误信息: ", leave.get_exception().message)
		return
	print("停止匹配",leave)
	is_matching = false
	current_state = MatchState.IDLE
	reset_ui()
	animation_player.stop()
	Global.SignalMgr.MatchingTimeMusicSIG.emit(true)
	match_cancel.emit()

func reset_ui():
	await Global.OnlineMatch.LeaveMatch()
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


# 匹配成功事件
func _on_match_maker_event(p_matched: NakamaRTAPI.MatchmakerMatched):
	print("匹配 maker:", p_matched)
	players.clear()
	var joined_match: NakamaRTAPI.Match = await Global.OnlineMatch.joinMatched(p_matched)
	if joined_match.is_exception():
		_on_match_failed()
		print("错误信息: ", joined_match.get_exception().message)
		return
	if joined_match.match_id and joined_match.match_id != "":
		Global.OnlineMatch.set_match_id(joined_match.match_id)
	
	for player in p_matched.users:
		players.append(player)
	# if players.size() == maxplayer:服务器已经处理了
	_on_match_success()
	await get_tree().create_timer(1.0).timeout
	match_sucess.emit(p_matched)
	pass

func _on_match_success():
	current_state = MatchState.SUCCESS
	is_matching = false
	status_label.text = "匹配成功"
	cancel_button.visible = false
	animation_player.play("success_flash")
	progress_circle.visible = false
	Global.SignalMgr.MatchingTimeMusicSIG.emit(true)
	Global.SignalMgr.MatchingOkMusicSIG.emit()
	
	# 这里添加切换到游戏场景的代码
	
	print("切换到游戏场景")

func _on_match_failed():
	current_state = MatchState.FAILED
	is_matching = false
	status_label.text = "房间已关闭,请重试"
	cancel_button.visible = true
	start_button.visible = true
	animation_player.play("failed_shake")
	progress_circle.visible = false
	Global.SignalMgr.MatchingTimeMusicSIG.emit(true)
	Global.SignalMgr.MatchingFailedMusicSIG.emit()
