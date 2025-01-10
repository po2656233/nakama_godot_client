extends Node

@onready var bgMusic = $background
@onready var sendMusic = $send
@onready var recvMusic = $recv
@onready var comingMusic = $comming
@onready var welcomegMusic = $welcome
@onready var emailMusic = $email
@onready var notifyMusic = $notify
@onready var onlineMusic = $online
@onready var newmsgMusic = $newmsg
var isMute = false 
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalManager.NewMessageSIG.connect(_on_new_msg)
	SignalManager.SendMessageSIG.connect(_on_send_msg)
	SignalManager.RecvMessageSIG.connect(_on_recv_msg)
	SignalManager.OnlineSIG.connect(_on_online_msg)

	SignalManager.NewEmailSIG.connect(_on_email_notify)
	SignalManager.NewNotifySIG.connect(_on_recv_notify)

	SignalManager.BackgroundMusicSIG.connect(_on_backgroundMusic)
	SignalManager.GameMusicSIG.connect(_on_gameMusic)
	SignalManager.MuteSIG.connect(_on_mute)
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
	if isMute:
		return
	newmsgMusic.play()
	pass

# 发送声音
func _on_send_msg(_args) -> void:
	if isMute:
		return
	sendMusic.play()
	pass

# 接收声音
func _on_recv_msg(_args) -> void:
	if isMute:
		return
	recvMusic.play()
	pass

# 上线声音
func _on_online_msg() -> void:
	if isMute:
		return
	onlineMusic.play()
	pass

# 邮件声音
func _on_email_notify(args) -> void:
	if args and not isMute:
		emailMusic.play()
	pass

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
