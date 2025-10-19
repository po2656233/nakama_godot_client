extends Button

@onready var title_label = $HBoxContainer/VBoxContainer/TitleLabel
@onready var time_label = $HBoxContainer/VBoxContainer/TimeLabel
@onready var status_label = $HBoxContainer/StatusLabel

var mail_data: Dictionary

func _ready():
	var mail_system = get_node("/root/MailMgr")
	mail_system.mail_claimed.connect(_on_mail_claimed)

func setup(data: Dictionary):
	mail_data = data
	title_label.text = data["title"]
	time_label.text = data["send_time"]
	_update_status()

func _update_status():
	status_label.text = "已领取" if mail_data["is_claimed"] else "未领取"
	status_label.modulate = Color.DARK_GRAY if mail_data["is_claimed"] else Color.GREEN

func _on_mail_claimed(mail_id: int):
	if mail_data["id"] == mail_id:
		mail_data["is_claimed"] = true
		_update_status()
