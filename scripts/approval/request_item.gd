extends PanelContainer

signal approved
signal rejected

enum Status {
	PENDING,           # 待审批
	APPROVED,         # 已同意
	REJECTED,         # 已拒绝
	WAITING_OTHER,    # 等待对方通过
	OTHER_APPROVED,   # 对方已通过
	OTHER_REJECTED    # 对方已拒绝
}

var _type: String
var _name: String
var _apply_time: String      # 申请时间
var _approval_time: String   # 审批时间
var _status: Status = Status.PENDING

func _ready():
	# 连接按钮信号
	$MarginContainer/HBoxContainer/ButtonContainer/ApproveButton.pressed.connect(_on_approve_button_pressed)
	$MarginContainer/HBoxContainer/ButtonContainer/RejectButton.pressed.connect(_on_reject_button_pressed)

func setup(type: String, name1: String, time: String, status: Status = Status.PENDING) -> void:
	_type = type
	_name = name1
	_apply_time = time
	_status = status
	
	$MarginContainer/HBoxContainer/TypeLabel.text = type
	$MarginContainer/HBoxContainer/NameLabel.text = name1
	$MarginContainer/HBoxContainer/ApplyTimeLabel.text = time
	$MarginContainer/HBoxContainer/ApprovalTimeLabel.text = "-"
	
	_update_status_display()
	_update_buttons()

func _update_status_display() -> void:
	var status_text = ""
	var status_color = Color(0.4, 0.4, 0.4)  # 默认灰色
	
	match _status:
		Status.PENDING:
			status_text = "待审批"
			status_color = Color(0.4, 0.4, 0.4)  # 灰色
		Status.APPROVED:
			status_text = "已同意"
			status_color = Color(0.188, 0.514, 0.302)  # 绿色
		Status.REJECTED:
			status_text = "已拒绝"
			status_color = Color(0.851, 0.275, 0.275)  # 红色
		Status.WAITING_OTHER:
			status_text = "等待对方通过"
			status_color = Color(0.2, 0.6, 1.0)  # 蓝色
		Status.OTHER_APPROVED:
			status_text = "对方已通过"
			status_color = Color(0.188, 0.514, 0.302)  # 绿色
		Status.OTHER_REJECTED:
			status_text = "对方已拒绝"
			status_color = Color(0.851, 0.275, 0.275)  # 红色
	
	$MarginContainer/HBoxContainer/StatusLabel.text = status_text
	$MarginContainer/HBoxContainer/StatusLabel.add_theme_color_override("font_color", status_color)

func _update_buttons() -> void:
	var show_buttons = _status == Status.PENDING
	$MarginContainer/HBoxContainer/ButtonContainer/ApproveButton.visible = show_buttons
	$MarginContainer/HBoxContainer/ButtonContainer/RejectButton.visible = show_buttons

func get_request_info() -> Dictionary:
	return {
		"type": _type,
		"name": _name,
		"apply_time": _apply_time,
		"approval_time": _approval_time,
		"status": _status
	}

func _on_approve_button_pressed() -> void:
	_status = Status.WAITING_OTHER
	_approval_time = Time.get_datetime_string_from_system().split(".")[0]
	$MarginContainer/HBoxContainer/ApprovalTimeLabel.text = _approval_time
	_update_status_display()
	_update_buttons()
	approved.emit()

func _on_reject_button_pressed() -> void:
	_status = Status.REJECTED
	_approval_time = Time.get_datetime_string_from_system().split(".")[0]
	$MarginContainer/HBoxContainer/ApprovalTimeLabel.text = _approval_time
	_update_status_display()
	_update_buttons()
	rejected.emit()

# 更新为其他状态（等待对方通过、对方已通过、对方已拒绝）
func update_other_status(new_status: Status) -> void:
	_status = new_status
	if new_status != Status.WAITING_OTHER:
		_approval_time = Time.get_datetime_string_from_system().split(".")[0]
		$MarginContainer/HBoxContainer/ApprovalTimeLabel.text = _approval_time
	_update_status_display()
	_update_buttons()

func get_status() -> Status:
	return _status
