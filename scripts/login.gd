extends Control

@onready var usernameEdit = $Panel/VBoxContainer/HBoxContainerUser/LineEdit
@onready var passwordEdit = $Panel/VBoxContainer/HBoxContainerPsw/LineEdit
@onready var checkbox = $Panel/VBoxContainer/HBoxContainerRead/CheckBox
@onready var keyboardContainer = $Panel/VBoxContainer
@onready var loading = $LoadingScreen

# 微信登录
const WECHAT_APPID = "wxcf2136ff70f7726a"
const REDIRECT_URI = "http://60.205.90.152:8080/callback"
const STATE = "godot_wechat_login"
var is_mobile:bool = false
var is_psw_editing:bool = false
var last_keyboard_height = 0
var origin_height = 0


# var http_request: HTTPRequest
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 基础信息
	is_mobile = Util.isMobile()
	origin_height = keyboardContainer.position.y

	# 禁用 SSL 验证 【todo 正式环境建议解除】
	ProjectSettings.set_setting("network/ssl/verify_hosts", false)
	SceneManager.set_current_scene("login")
	SettingsManager.show_settings(2) 
	
	print("当前运行的节点名",SceneManager.get_current_scene_name())
	WindowDrag.register_drag_zone(self)
	if ProjectSettings.has_setting("username"):
		usernameEdit.text = ProjectSettings.get("username")
	# # 创建HTTP请求节点
	# http_request = HTTPRequest.new()
	# add_child(http_request)
	# http_request.request_completed.connect(_on_request_completed)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# 在进程中检查键盘高度变化
	if not is_mobile: return
	var current_height = DisplayServer.virtual_keyboard_get_height()
	if current_height != last_keyboard_height:
		_on_virtual_keyboard_height_changed(current_height)
		last_keyboard_height = current_height

func _on_tb_register_pressed() -> void:
	SceneManager.switch_to_scene("register","tile_reveal")
	pass # Replace with function body.


func _on_tr_login_pressed() -> void:
	login()

func _on_tr_wxlogin_pressed() -> void:
	# login()
	# wechatLogin()
	loading.show()
	loading.set_next_scene("home")
	if await OnlineLogin.do_device_login("",false,true) or await OnlineLogin.do_device_login("",true):
		SignalManager.LoadingSIG.emit(10)
		await OnlineChat.load_player_data()  
		SignalManager.LoadingSIG.emit(100)
	else:
		loading.hide()
		PopupManager.show_message("登录失败，请检查网络连接")
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
	loading.show()
	if await OnlineLogin.do_login(usernameEdit.text,passwordEdit.text,false):
		SignalManager.LoadingSIG.emit(10)
		await OnlineChat.load_player_data()  
		SignalManager.LoadingSIG.emit(100)
		# ProjectSettings.set("username",usernameEdit.text)
		# FancyFade.custom_fade(home_scene.instantiate(), 1.5, DISSOLVE_IMAGE)
	else:
		loading.hide()
		# PopupManager.show_message("账号或密码错误","提示",false)
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

#############################################################################################
func _on_texture_button_button_down() -> void:
	passwordEdit.secret = false
	pass # Replace with function body.

func _on_texture_button_button_up() -> void:
	passwordEdit.secret = true
	pass # Replace with function body.

func _on_virtual_keyboard_height_changed(keyboard_height):
	# 如果键盘显示，确保输入框可见
	if keyboard_height > 0:
		var viewport_size = get_viewport_rect().size
		var editY = passwordEdit.size.y if is_psw_editing else usernameEdit.size.y
		var editGlobalY = passwordEdit.global_position.y if is_psw_editing else usernameEdit.global_position.y

		var target_position = viewport_size.y - keyboard_height - editY - 20
		
		# 如果输入框被键盘遮挡，调整VBoxContainer的位置
		if editGlobalY > target_position:
			var offset = editGlobalY - target_position
			keyboardContainer.position.y -= offset
	else:
		keyboardContainer.position.y = origin_height
	pass


func _on_line_edit_focus_exited() -> void:
	if is_mobile:
		DisplayServer.virtual_keyboard_hide()
	pass # Replace with function body.


func _on_line_edit_focus_entered() -> void:
	# 获取目标编辑控件的全局位置和大小
	if is_mobile:
		DisplayServer.virtual_keyboard_show("中文输入法") 
	pass # Replace with function body.


func _on_line_edit_focus_entered_psw() -> void:
	is_psw_editing = true
	if is_mobile:
		DisplayServer.virtual_keyboard_show("中文输入法") 
	pass # Replace with function body.

func _on_line_edit_focus_exited_psw() -> void:
	is_psw_editing = false
	if is_mobile:
		DisplayServer.virtual_keyboard_hide()
	pass # Replace with function body.
