extends Control

@onready var menuBtn = $HBoxContainerRightTop/MB_setting
@onready var notifyBtn = $btn_what
@onready var emailBtn = $HBoxContainerRightTop/btn_email

@onready var bgMusic = $HBoxContainerRightTop/btn_full/background
@onready var msgMusic = $HBoxContainerRightTop/btn_email/messagecoming
@onready var notifyMusic = $btn_what/lingdang
var login_scene = load("res://scenes/login.tscn")
var mail_scene = load("res://scenes/email/mail.tscn")

# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	var popup_menu = menuBtn.get_popup()
	popup_menu.index_pressed.connect(on_setting_pressed)
	notifyBtn.lookSIG.connect(_on_look_notify)
	emailBtn.lookSIG.connect(_on_look_email)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


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
			if bgMusic.stream_paused:
				notifyMusic.stop()
				msgMusic.stop()
			popup_menu.set_item_text(index, hints)
			pass
		6:
			notifyBtn.shakeSIG.emit()
			pass
		7: 
			emailBtn.shakeSIG.emit()
			pass
		3:
			Network.reset_network() 
			FancyFade.wipe_left(login_scene.instantiate(),0.5)
			pass
		5:
			get_tree().quit()
			pass
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


func recv_notify() -> void:
	#铃铛播放
	# notifyMusic.set_volume(1.0)
	notifyMusic.play()
	#铃铛闪烁
	notifyBtn.shakeSIG.emit()
	pass # Replace with function body.

func msg_notify() -> void:
	msgMusic.play()
	pass

func email_notify() -> void:
	msgMusic.play()
	emailBtn.shakeSIG.emit()
	pass


func _on_btn_notify_pressed() -> void:
	#铃铛停止播放
	notifyMusic.stop()
	pass # Replace with function body.


func _on_btn_email_pressed() -> void:
	msgMusic.stop()
	pass # Replace with function body.

func _on_look_notify()->void:
	pass

func _on_look_email()->void:
	# mail_scene.instantiate().visible = true 
	FancyFade.wipe_left(mail_scene.instantiate(),0.5)
	pass