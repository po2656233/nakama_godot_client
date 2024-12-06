extends Control

@onready var mail_list_container = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var mail_item_scene = preload("res://scenes/email/mail_item.tscn")
var mail_system: MailSystem

func _ready():
	mail_system = get_node("/root/MailSystem")
	_load_mail_list()

func _load_mail_list():
	# 清除现有邮件
	for child in mail_list_container.get_children():
		child.queue_free()
	
	# 加载邮件列表
	var mails = mail_system.get_mail_list()
	for mail_data in mails:
		var mail_item = mail_item_scene.instantiate()
		mail_list_container.add_child(mail_item)
		mail_item.setup(mail_data)
		mail_item.pressed.connect(_on_mail_item_pressed.bind(mail_data))

func _on_mail_item_pressed(mail_data: Dictionary):
	mail_system.mail_selected.emit(mail_data)
