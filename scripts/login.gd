extends Control

@onready var usernameEdit = $Panel/VBoxContainer/HBoxContainerUser/LineEdit
@onready var passwordEdit = $Panel/VBoxContainer/HBoxContainerPsw/LineEdit
@onready var checkbox = $Panel/VBoxContainer/HBoxContainerRead/CheckBox
@onready var settings = $Setting
# 微信登录
const WECHAT_APPID = "wxcf2136ff70f7726a"
const REDIRECT_URI = "http://60.205.90.152:8080/callback"
const STATE = "godot_wechat_login"

var http_request: HTTPRequest

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	settings.showNotify(false)
	
	ProjectSettings.set_setting("network/ssl/verify_hosts", false)
	SceneManager.set_current_scene("login")
	var ret = await Network.restore_session()
	if not ret:
		Network.initialize_client()
		print("Network 初始化",ret)
	else:
		print("Network 已恢复",ret)
		# 验证 PopupManager 是否可用
	if not PopupManager:
		print("PopupManager 未正确初始化")
	else:
		print("PopupManager 已正确初始化")
	
	WindowDrag.register_drag_zone(self)
	if ProjectSettings.has_setting("username"):
		usernameEdit.text = ProjectSettings.get("username")
	# # 创建HTTP请求节点
	# http_request = HTTPRequest.new()
	# add_child(http_request)
	# http_request.request_completed.connect(_on_request_completed)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_tb_register_pressed() -> void:
	SceneManager.switch_to_scene("register","tile_reveal")
	pass # Replace with function body.


func _on_tr_login_pressed() -> void:
	login()

func _on_tr_wxlogin_pressed() -> void:
	# login()
	wechatLogin()
	pass # Replace with function body.

# 处理HTTP响应
func _on_request_completed(result, _response_code, _headers, body):
	if result == HTTPRequest.RESULT_SUCCESS:
		var response = body.get_string_from_utf8()
		print("Response: ", response)
		# 处理响应数据
	else:
		print("Error: ", result)
	pass

func _input(event):
	if event is InputEventKey:
		if event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and not PopupManager.isVisible():  # 或使用 KEY_RETURN
			login()
			get_viewport().set_input_as_handled()  # 阻止事件继续传递

func login()->void:
	print("Login: " + usernameEdit.text + " " + passwordEdit.text)
	if not checkbox.is_pressed():
		PopupManager.show_message("请阅读并同意用户协议")
		return
	if await Network.authenticate_email(usernameEdit.text, passwordEdit.text):
		await Network.load_player_data()  
		SceneManager.switch_to_scene("home","custom",1.0)
		# ProjectSettings.set("username",usernameEdit.text)
		# FancyFade.custom_fade(home_scene.instantiate(), 1.5, DISSOLVE_IMAGE)
	else:
		PopupManager.show_message("账号或密码错误","提示",false)
		print("Wrong username or password")#$Panel/VBoxContainer/HBoxContainer/Label.text = "Wrong username or password"
	pass # Replace with function body.
 
###########################################################################################
# 微信登录(暂不使用)
func wechatLogin()->void:
	var auth_url = "https://open.weixin.qq.com/connect/qrconnect"
	auth_url += "?appid=" + WECHAT_APPID
	auth_url += "&redirect_uri=" + REDIRECT_URI.uri_encode()
	auth_url += "&response_type=code"
	auth_url += "&scope=snsapi_login"
	auth_url += "&state=" + STATE
	auth_url += "#wechat_redirect"
	
	# 打开浏览器进行微信授权
	OS.shell_open(auth_url)
	pass


func _on_texture_button_button_down() -> void:
	passwordEdit.secret = false
	pass # Replace with function body.

func _on_texture_button_button_up() -> void:
	passwordEdit.secret = true
	pass # Replace with function body.
