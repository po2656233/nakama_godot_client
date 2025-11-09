extends PanelContainer

signal approved
signal rejected

enum Status {
	APPROVED = 0, # 已同意
	WAITING_OTHER = 1, # 等待对方通过
	PENDING = 2, # 待审批
	REJECTED = 3, # 已拒绝
	OTHER_APPROVED = 4, # 对方已通过
	OTHER_REJECTED = 5, # 对方已拒绝
	ABSOLE = 6, # 等待解除
}

var _type: String
var _level: int
var _uid: String
var _gid: String
var _gname: String
var _name: String
var _apply_time: String # 申请时间
var _approval_time: String # 审批时间
var _status: Status = Status.PENDING

func _ready():
	# 连接按钮信号
	$MarginContainer/HBoxContainer/ButtonContainer/ApproveButton.pressed.connect(_on_approve_button_pressed)
	$MarginContainer/HBoxContainer/ButtonContainer/RejectButton.pressed.connect(_on_reject_button_pressed)

func setup(type: String, uid:String, name1: String, create_time: String, gid:String="-", gname1: String="-",level: int = 0, update_time: String = "-", status: Status = Status.PENDING) -> void:
	_type = type
	_level = level
	_uid = uid
	_gid = gid
	_name = name1
	_gname = gname1
	_apply_time = create_time
	_approval_time = update_time
	_status = status
	if status == Status.WAITING_OTHER or status == Status.PENDING:
		update_time = "-"
	
	$MarginContainer/HBoxContainer/TypeLabel.text = type
	$MarginContainer/HBoxContainer/NameLabel.text = name1
	$MarginContainer/HBoxContainer/ClubLabel.text = gname1
	$MarginContainer/HBoxContainer/ApplyTimeLabel.text = create_time
	$MarginContainer/HBoxContainer/ApprovalTimeLabel.text = update_time
	
	_update_status_display()
	_update_buttons()

func _update_status_display() -> void:
	var status_text = ""
	var status_color = Color(0.4, 0.4, 0.4) # 默认灰色
	
	match _status:
		Status.PENDING:
			status_text = "待审批"
			status_color = Color(0.4, 0.4, 0.4) # 灰色
		Status.APPROVED:
			status_text = "已同意"
			status_color = Color(0.188, 0.514, 0.302) # 绿色
		Status.REJECTED:
			status_text = "已拉黑"
			status_color = Color(0.851, 0.275, 0.275) # 红色
		Status.WAITING_OTHER:
			status_text = "等待对方通过"
			status_color = Color(0.2, 0.6, 1.0) # 蓝色
		Status.OTHER_APPROVED:
			status_text = "对方已通过"
			status_color = Color(0.188, 0.514, 0.302) # 绿色
		Status.OTHER_REJECTED:
			status_text = "对方已拒绝"
			status_color = Color(0.851, 0.275, 0.275) # 红色
		Status.ABSOLE:
			status_text = "已解除"
			status_color = Color(0.2, 0.6, 1.0) # 蓝色
	$MarginContainer/HBoxContainer/StatusLabel.text = status_text
	$MarginContainer/HBoxContainer/StatusLabel.add_theme_color_override("font_color", status_color)

func _update_buttons() -> void:
	var show_buttons = _status == Status.PENDING
	$MarginContainer/HBoxContainer/ButtonContainer/ApproveButton.visible = show_buttons
	$MarginContainer/HBoxContainer/ButtonContainer/RejectButton.visible = show_buttons
	if _status == Status.REJECTED:
		$MarginContainer/HBoxContainer/ButtonContainer/RejectButton.text = "解除"
		$MarginContainer/HBoxContainer/ButtonContainer/RejectButton.visible = true

func get_request_info() -> Dictionary:
	return {
					"type":_type,
					"level":_level,#0超管 1 管理员 2成员
					"uid":_uid,
					"name":_name,
					"time":_apply_time,
					"group_id":_gid,
					"group_name":_gname,
					"update_time":_approval_time,
					"status":_status,
				}

func _on_approve_button_pressed() -> void:
	_status = Status.APPROVED
	if _type == "用户":
		if await OnlineChat.add_friends_async([_uid]):
			approve()
			SignalMgr.FreshFriendListSIG.emit()
			return	
	elif _type == "俱乐部":
		if await OnlineChat.add_group_users_async(_gid, [_uid]):
			approve()
			SignalMgr.FreshClubListSIG.emit()
			return
	Global.PopupManager.show_message("无效操作", "提示")
	pass

func approve() -> void:
	_approval_time = Time.get_datetime_string_from_system().split(".")[0]
	$MarginContainer/HBoxContainer/ApprovalTimeLabel.text = _approval_time
	_update_status_display()
	_update_buttons()
	approved.emit()
	DataManager.get_instance().add_uid_approval(OnlineLogin.get_my_id(),get_request_info())
	pass


func _on_reject_button_pressed() -> void:
	if _type == "用户":
		if _status == Status.REJECTED:
			_status = Status.ABSOLE
			if await OnlineChat.remove_friend(_uid):
				_approval_time = Time.get_datetime_string_from_system().split(".")[0]
				$MarginContainer/HBoxContainer/ApprovalTimeLabel.text = _approval_time
				_update_status_display()
				_update_buttons()
				rejected.emit()
				DataManager.get_instance().add_uid_approval(OnlineLogin.get_my_id(),get_request_info())
			return
		_status = Status.REJECTED
		if await OnlineChat.refuse_friends_async(_uid):
			_approval_time = Time.get_datetime_string_from_system().split(".")[0]
			$MarginContainer/HBoxContainer/ApprovalTimeLabel.text = _approval_time
			_update_status_display()
			_update_buttons()
			rejected.emit()
			DataManager.get_instance().add_uid_approval(OnlineLogin.get_my_id(),get_request_info())
	elif _type == "俱乐部":
		_status = Status.REJECTED
		if await OnlineChat.remove_gourp_user(_gid,_uid):
			_approval_time = Time.get_datetime_string_from_system().split(".")[0]
			$MarginContainer/HBoxContainer/ApprovalTimeLabel.text = _approval_time
			_update_status_display()
			_update_buttons()
			rejected.emit()
			DataManager.get_instance().add_uid_approval(OnlineLogin.get_my_id(),get_request_info())
		pass
	else:
		Global.PopupManager.show_message("网络错误，请重试", "提示")
	pass


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
