extends Control

@onready var menuBtn = $HBoxContainerRightTop/MB_setting
@onready var notifyBtn = $btn_what
@onready var emailBtn = $HBoxContainerRightTop/btn_email
@onready var fullBtn = $HBoxContainerRightTop/btn_full

@onready var bgMusic = $music/background
@onready var sendMusic = $music/send
@onready var recvMusic = $music/recv
@onready var comingMusic = $music/comming
@onready var welcomegMusic = $music/welcome
@onready var emailMusic = $music/email
@onready var notifyMusic = $music/notify
@onready var onlineMusic = $music/online
var login_scene = load("res://scenes/login.tscn")
var mail_scene = load("res://scenes/email/mail.tscn")

# Called when the node enters the scene tree for the first time.
var isMute = false
func _ready() -> void: 
	var popup_menu = menuBtn.get_popup()
	popup_menu.index_pressed.connect(on_setting_pressed)
	notifyBtn.lookSIG.connect(_on_look_notify)
	emailBtn.lookSIG.connect(_on_look_email)
	SignalManager.NewMessageSIG.connect(_on_msg_notify)
	SignalManager.SendMessageSIG.connect(_on_send_msg)
	SignalManager.RecvMessageSIG.connect(_on_recv_msg)
	SignalManager.OnlineSIG.connect(_on_online_msg)

	SignalManager.NewEmailSIG.connect(_on_email_notify)
	SignalManager.NewNotifySIG.connect(_on_recv_notify)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


# 显示邮件系统
func show_mail():
	if mail_scene and not mail_scene.visible:
		mail_scene.show()  # 或者 mail_scene.visible = true

# 隐藏邮件系统
func hide_mail():
	if mail_scene:
		mail_scene.hide()  # 或者 mail_scene.visible = false

# 切换显示/隐藏状态
func toggle_mail():
	if mail_scene:
		mail_scene.visible = !mail_scene.visible

func on_setting_pressed(index: int) -> void:
	var popup_menu = menuBtn.get_popup()
	var check:bool = popup_menu.is_item_checked(index)
	var new_check:bool = not check
	popup_menu.set_item_checked(index, new_check)
	WindowDrag.dragging = false
	print("Setting pressed ",index)
	match index:
		0:
			if not bgMusic.playing and not bgMusic.stream_paused:
				bgMusic.play()
			else:
				bgMusic.stream_paused=!bgMusic.stream_paused
			
			var hints = "打开音量" if bgMusic.stream_paused else "关闭音量"
			isMute = bgMusic.stream_paused
			popup_menu.set_item_text(index, hints)
			pass
		3:#返回登录页
			Network.logout() 
			SceneManager.switch_to_scene("login",SceneManager.get_transition_key("WIPE_LEFT"),0.5)
		# 	pass
		5:# 退出
			get_tree().quit()
			pass
		6:#返回上一页
			SceneManager.go_back()
		_:
			print("Setting error",index)
			pass
	pass

func _on_btn_full_pressed() -> void:
	if Window.MODE_FULLSCREEN == get_window().mode:
		restore_window()
	else:
		maximize_window()
	pass # Replace with function body.


# 最大化窗口
func maximize_window():
	get_window().mode = Window.MODE_FULLSCREEN 
	
# 最小化窗口
func minimize_window():
	get_window().mode = Window.MODE_MINIMIZED
	
# 恢复窗口(恢复到普通窗口模式)
func restore_window():
	get_window().mode = Window.MODE_WINDOWED

##########################################
func _on_recv_notify(args) -> void:
	if args:
		# notifyMusic.set_volume(1.0)
		notifyMusic.play()
	notifyBtn.newMsgSIG.emit()
	pass # Replace with function body.

func _on_msg_notify(_args) -> void:
	pass

func _on_send_msg(_args) -> void:
	if isMute:
		return
	sendMusic.play()
	pass

func _on_recv_msg(_args) -> void:
	if isMute:
		return
	recvMusic.play()
	pass
func _on_online_msg() -> void:
	if isMute:
		return
	onlineMusic.play()
	pass
func _on_email_notify(args) -> void:
	if args and not isMute:
		emailMusic.play()
	emailBtn.newMsgSIG.emit()
	pass

#############################
func _on_btn_notify_pressed() -> void:
	#铃铛停止播放
	notifyMusic.stop()
	pass # Replace with function body.


func _on_btn_email_pressed() -> void:
	pass # Replace with function body.

func _on_look_notify()->void:
	SceneManager.show_scene_in_center("approval",0.9)
	pass

func _on_look_email()->void:
	SceneManager.show_scene_in_center("email")
	# FancyFade.wipe_left(mail_scene.instantiate(),0.5)
	pass
#######################################
func showNotify(isShow:bool):
	notifyBtn.visible = isShow
	emailBtn.visible = isShow
	# fullBtn.visible = isShow
	pass
