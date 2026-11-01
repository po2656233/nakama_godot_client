extends Node

@onready var bgMusic = $background
@onready var welcomeMusic = $welcome

@onready var sendMusic = $message/send
@onready var recvMusic = $message/recv
@onready var newmsgMusic = $message/newmsg

@onready var comingMusic = $notify/comming
@onready var emailMusic = $notify/email
@onready var notifyMusic = $notify/notify
@onready var onlineMusic = $notify/online
# 加入房间
@onready var joinSuccessMusic = $room/joinSuccess
@onready var joinErrorMusic = $room/joinError

# 匹配音效
@onready var matchingOkMusic = $match/matching/SuccessSound
@onready var matchingFailedMusic = $match/matching/FailSound
@onready var matchingTimeMusic = $match/matching/TimeSound

# 匹配成功音效
@onready var matchSuccessOkMusic = $match/matchsuccess/SuccessSound
@onready var matchSuccessFailedMusic = $match/matchsuccess/FailSound
@onready var matchSuccessTimeMusic = $match/matchsuccess/TimeSound

var isMute = false 
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.SignalMgr.BackgroundMusicSIG.connect(_on_backgroundMusic)
	Global.SignalMgr.WelcomeMusicSIG.connect(_on_welcomegMusic)

	Global.SignalMgr.NewMessageSIG.connect(_on_new_msg)
	Global.SignalMgr.SendMessageSIG.connect(_on_send_msg)
	Global.SignalMgr.RecvMessageSIG.connect(_on_recv_msg)
	Global.SignalMgr.OnlineSIG.connect(_on_online_msg)

	Global.SignalMgr.NewEmailSIG.connect(_on_email_notify)
	Global.SignalMgr.NewNotifySIG.connect(_on_recv_notify)

	Global.SignalMgr.GameMusicSIG.connect(_on_gameMusic)
	Global.SignalMgr.MuteSIG.connect(_on_mute)
	Global.SignalMgr.JoinSuccessMusicSIG.connect(_on_joinSuccessMusic)
	Global.SignalMgr.JoinErrorMusicSIG.connect(_on_joinErrorMusic)
	
	Global.SignalMgr.MatchingOkMusicSIG.connect(_on_matchingOkMusic)
	Global.SignalMgr.MatchingFailedMusicSIG.connect(_on_matchingFailedMusic)
	Global.SignalMgr.MatchingTimeMusicSIG.connect(_on_matchingTimeMusic)

	Global.SignalMgr.MatchSuccessOkMusicSIG.connect(_on_matchSuccessOkMusic)
	Global.SignalMgr.MatchSuccessFailedMusicSIG.connect(_on_matchSuccessFailedMusic)
	Global.SignalMgr.MatchSuccessTimeMusicSIG.connect(_on_matchSuccessTimeMusic)

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



##########################################
func _on_recv_notify(args) -> void:
	if args and not isMute:
		notifyMusic.stream.loop = true
		notifyMusic.play()
	else:
		notifyMusic.stop()
	pass # Replace with function body.

# 新消息声音
func _on_new_msg(_args) -> void:
	# if isMute:
	# 	return
	newmsgMusic.play()
	pass

# 发送声音
func _on_send_msg(_args) -> void:
	# if isMute:
	# 	return
	sendMusic.play()
	pass

# 接收声音
func _on_recv_msg(_args) -> void:
	# if isMute:
	# 	return
	recvMusic.play()
	pass

# 上线声音
func _on_online_msg() -> void:
	# if isMute:
	# 	return
	onlineMusic.play()
	pass

# 邮件声音
func _on_email_notify(args) -> void:
	if args and not isMute:
		emailMusic.play()
	pass

# 加入房间声音
func _on_joinSuccessMusic(_rid) -> void:
	# if isMute:
	# 	return
	joinSuccessMusic.play()
	pass

func _on_joinErrorMusic() -> void:
	# if isMute:
	# 	return
	joinErrorMusic.play()
	pass

# 通知声音
func _on_welcomegMusic() -> void:
	# if isMute:
	# 	return
	welcomeMusic.play()
	pass
########################匹配################################################
func _on_matchingOkMusic() -> void:
	# if isMute:
	# 	return
	matchingOkMusic.play()
	pass

func _on_matchingFailedMusic() -> void:
	# if isMute:
	# 	return
	matchingFailedMusic.play()
	pass

func _on_matchingTimeMusic(isStop) -> void:	
	# if isMute:
	#	return
	if isStop:
		matchingTimeMusic.stop()
	else:
		matchingTimeMusic.play()

# 匹配成功
func _on_matchSuccessOkMusic() -> void:
	# if isMute:
	# 	return
	matchSuccessOkMusic.play()
	pass

func _on_matchSuccessFailedMusic() -> void:
	# if isMute:
	# 	return
	matchSuccessFailedMusic.play()
	pass

func _on_matchSuccessTimeMusic(isStop) -> void:
	# if isMute:
	# 	return
	if isStop:
		matchSuccessTimeMusic.stop()
	else:
		matchSuccessTimeMusic.play()



#########################################################################
# 游戏音乐(根据不同游戏播放)
func _on_gameMusic(_id,args) -> void:
	if args:
		comingMusic.stream.loop = true
		comingMusic.play()
	else:
		comingMusic.stream_paused = true


# 背景音乐
func _on_backgroundMusic(args) -> void:
	if not bgMusic.playing and not bgMusic.stream_paused and not args:
		bgMusic.stream.loop = true
		bgMusic.play()
	else:
		bgMusic.stream_paused = args
	pass

# 禁音
func _on_mute(args) -> void:
	isMute = args
	mute_audio_players(self)
	pass



func mute_audio_players(node):
	# 检查当前节点
	if node is AudioStreamPlayer:
		node.stream_paused = isMute
	# 递归检查所有子节点
	for child in node.get_children():
		mute_audio_players(child)
	pass
