extends Control
const DISSOLVE_IMAGE = preload('res://addons/transitions/images/blurry-noise.png')

var register_scene = load("res://scenes/register.tscn")
var home_scene = load("res://scenes/home.tscn")
# var lobby_scene = load("res://scenes/lobby.tscn")

@onready var usernameEdit = $Panel/VBoxContainer/HBoxContainerUser/LineEdit
@onready var passwordEdit = $Panel/VBoxContainer/HBoxContainerPsw/LineEdit
@onready var checkbox = $Panel/VBoxContainer/HBoxContainerRead/CheckBox

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	WindowDrag.register_drag_zone(self)
	var ret = await Network.restore_session()
	if not ret:
		Network.initialize_client()
		print("Network 初始化",ret)
	else:
		print("Network 已恢复",ret)
		# 验证 PopupManager 是否可用
	if PopupManager:
		print("PopupManager 已正确初始化")
	else:
		print("PopupManager 未正确初始化")
	var username = ProjectSettings.get("username")
	if username:
		usernameEdit.text = username
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_tb_register_pressed() -> void:
	FancyFade.custom_fade(register_scene.instantiate(), 1.5, DISSOLVE_IMAGE)
	pass # Replace with function body.


func _on_tr_login_pressed() -> void:
	login()

func _on_tr_wxlogin_pressed() -> void:
	login()
	pass # Replace with function body.


func login()->void:
	print("Login: " + usernameEdit.text + " " + passwordEdit.text)
	if not checkbox.is_pressed():
		PopupManager.show_message("请阅读并同意用户协议")
		return
	if await Network.authenticate_email(usernameEdit.text, passwordEdit.text):
		ProjectSettings.set("username",usernameEdit.text)
		ProjectSettings.set("password",passwordEdit.text)
	
		FancyFade.custom_fade(home_scene.instantiate(), 1.5, DISSOLVE_IMAGE)
	else:
		PopupManager.show_message("账号或密码错误")
		print("Wrong username or password")#$Panel/VBoxContainer/HBoxContainer/Label.text = "Wrong username or password"
	pass # Replace with function body.
