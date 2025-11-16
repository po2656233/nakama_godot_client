extends Control

signal closeMailSIG()

@onready var mail_list_container = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var mail_item_scene = preload("res://scenes/email/mail_item.tscn")
# @onready var home_scene = preload("res://scenes/home.tscn").instantiate()
@onready var clear_button = $Panel/ClearButton

#var mail_manger: MailMgr

func _ready():
	#mail_manger = get_node("/root/MailMgr")
	Global.MailMgr.set_mail_list_node(self)  # 设置引用
	clear_button.pressed.connect(_on_clear_button_pressed)
	_load_mail_list()
	# _update_clear_button()

func _load_mail_list():
	# 清除现有邮件
	for child in mail_list_container.get_children():
		child.queue_free()
	
	# 加载邮件列表
	var mails = Global.MailMgr.get_mail_list()
	for mail_data in mails:
		var mail_item = mail_item_scene.instantiate()
		mail_list_container.add_child(mail_item)
		mail_item.setup(mail_data)
		print("_account",mail_data)
		# 展示具体内容
		mail_item.pressed.connect(_on_mail_item_pressed.bind(mail_data))
	# _update_clear_button()  # 更新清理按钮状态

func _on_mail_item_pressed(mail_data: Dictionary):
	print("选中了")
	Global.MailMgr.mail_selected.emit(mail_data)

func _on_clear_button_pressed():
	if Global.MailMgr.clear_claimed_mails():
		_load_mail_list()

func _update_clear_button():
	# 检查是否有已领取的邮件
	var has_claimed = false
	for mail in Global.MailMgr.get_mail_list():
		if mail["is_claimed"]:
			has_claimed = true
			break
	clear_button.disabled = not has_claimed
 
func _on_close_button_pressed():
	closeMailSIG.emit()
