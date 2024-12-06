extends Control

@onready var title_label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var content_label = $Panel/MarginContainer/VBoxContainer/ContentLabel
@onready var time_label = $Panel/MarginContainer/VBoxContainer/TimeLabel
@onready var claim_button = $Panel/MarginContainer/VBoxContainer/ClaimButton
@onready var reward_label = $Panel/MarginContainer/VBoxContainer/RewardLabel

var current_mail_id: int = -1
var mail_system

func _ready():
	mail_system = get_node("/root/MailSystem")
	mail_system.mail_selected.connect(_on_mail_selected)
	mail_system.mail_claimed.connect(_on_mail_claimed)
	hide()

func _on_mail_selected(mail_data: Dictionary):
	show()
	current_mail_id = mail_data["id"]
	title_label.text = mail_data["title"]
	content_label.text = mail_data["content"]
	time_label.text = mail_data["send_time"]
	
	var reward_text = "奖励: "
	if "gold" in mail_data["reward"]:
		reward_text += str(mail_data["reward"]["gold"]) + " 金币 "
	if "gems" in mail_data["reward"]:
		reward_text += str(mail_data["reward"]["gems"]) + " 宝石"
	reward_label.text = reward_text
	
	claim_button.disabled = mail_data["is_claimed"]
	claim_button.text = "领取奖励" if not mail_data["is_claimed"] else "已领取"

func _on_claim_button_pressed():
	if current_mail_id != -1:
		if mail_system.claim_mail_reward(current_mail_id):
			claim_button.disabled = true
			claim_button.text = "已领取"

func _on_mail_claimed(mail_id: int):
	if mail_id == current_mail_id:
		claim_button.disabled = true
		claim_button.text = "已领取"

func _on_back_button_pressed():
	hide()
