extends Control
var login_scene = load("res://scenes/login.tscn")


@onready var usernameEdit = $Panel/VBoxContainer/HBoxContainerUser/LineEdit
@onready var passwordEdit = $Panel/VBoxContainer/HBoxContainerPsw/LineEdit
@onready var qrpasswordEdit = $Panel/VBoxContainer/HBoxContainerQrPsw2/LineEdit
@onready var phoneEdit = $Panel/VBoxContainer/HBoxContainerPhone/LineEdit
@onready var vcodeEdit = $Panel/VBoxContainer/HBoxContainerVcode/LineEdit
@onready var checkbox = $Panel/VBoxContainer/HBoxContainerRead/CheckBox

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SceneManager.set_current_scene("register")
	print("当前运行的节点名",SceneManager.get_current_scene_name())
	# WindowDrag.register_drag_zone(self)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _input(event):
	if event is InputEventKey:
		if event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and not PopupManager.isVisible():  # 或使用 KEY_RETURN
			_on_btn_register_pressed()
			get_viewport().set_input_as_handled()  # 阻止事件继续传递

# 返回登录页面
func _on_tb_return_pressed() -> void:
	FancyFade.wipe_left(login_scene.instantiate(),0.5)
	pass # Replace with function body.

# 注册
func _on_btn_register_pressed() -> void:
	print("register")
	if usernameEdit.text.is_empty():
		await Online.nakama_client.authenticate_device("",true)
	if not checkValidity():
		return
	if await Online.nakama_client.authenticate_email(usernameEdit.text, passwordEdit.text,"",true):
		ProjectSettings.set("username",usernameEdit.text)
		# ProjectSettings.set("password",passwordEdit.text)
		PopupManager.show_confirm("注册成功", Callable(self,"_on_register_success"))
	else:
		PopupManager.show_message("注册失败")
	pass # Replace with function body.

func checkValidity()-> bool:
	if usernameEdit.text == "" or usernameEdit.text.length() > 8:
		PopupManager.show_message("请填写用户名,字符数限制为1-8位")
		return false
	if passwordEdit.text.length() < 8 or passwordEdit.text.length() > 16:
		PopupManager.show_message("请填写密码,字符数限制为8-16位")
		return false
	if qrpasswordEdit.text == "":
		PopupManager.show_message("请填写确认密码")
		return false
	if passwordEdit.text!= qrpasswordEdit.text:
		PopupManager.show_message("两次密码输入不一致")
		return false
	if phoneEdit.text == "":
		PopupManager.show_message("请填写手机号码")
		return false
	if phoneEdit.text.length() != 11:
		PopupManager.show_message("手机号必须是11位")
		return	false
	if not is_valid_phone_number(phoneEdit.text):
		PopupManager.show_message("请输入有效的手机号码")
		return false
	if vcodeEdit.text == "":
		PopupManager.show_message("请填写验证码")
		return false
	if not checkbox.is_pressed():
		PopupManager.show_message("请阅读并同意用户协议")
		return false
	return true

func _on_register_success():
	FancyFade.wipe_conical(login_scene.instantiate(),0.5)
	pass

func is_valid_phone_number(phone: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^1[3-9]\\d{9}$")
	return regex.search(phone) != null


func _on_texture_psw_button_down() -> void:
	passwordEdit.secret = false
	pass # Replace with function body.


func _on_texture_psw_button_up() -> void:
	passwordEdit.secret = true
	pass # Replace with function body.



func _on_texture_qrpsw_button_up() -> void:
	qrpasswordEdit.secret = true
	pass # Replace with function body.

func _on_texture_qrpsw_button_down() -> void:
	qrpasswordEdit.secret = false
	pass # Replace with function body.
