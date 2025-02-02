extends Node
const USER_DIR = 'user://'
const CREDENTIALS = 'credentials.json'
const CREDENTIALS_FILENAME = USER_DIR + CREDENTIALS

var email: String = ''
var password: String = ''

var _reconnect: bool = false
var _next_screen

func _ready() -> void:
#	var file = File.new()
	if FileAccess.file_exists(CREDENTIALS_FILENAME):
		var file : FileAccess = FileAccess.open(CREDENTIALS_FILENAME, FileAccess.READ)
		var test_json_conv : JSON = JSON.new()
		var error = test_json_conv.parse(file.get_as_text())
		assert(error == OK, test_json_conv.get_error_message())
		var result : Dictionary = test_json_conv.get_data()
		if result is Dictionary:
			email = result['email']
			password = result['password']
		file.close()

func _save_credentials() -> void:
#	var file = File.new()
	var file = FileAccess.open(CREDENTIALS_FILENAME, FileAccess.WRITE)
	var credentials = {
		email = email,
		password = password,
	}
	file.store_line(JSON.stringify(credentials))
	file.close()

func _show_screen(info: Dictionary = {}) -> void:
	_reconnect = info.get('reconnect', false)
	_next_screen = info.get('next_screen', 'MatchScreen')
	
	# If we have a stored email and password, attempt to login straight away.
	if email != '' and password != '':
		do_login()
	pass

func do_login(myemail: String = '', mypassword: String = '', save_credentials: bool = false) -> bool:
	if myemail != '':
		email = myemail
	if mypassword != '':
		password = mypassword
		
	if email.is_empty() :
		PopupManager.show_dynamic("账号不能为空")
		return false
	if password.is_empty():
		PopupManager.show_dynamic("密码不能为空")
		return false
	if email.find('@') == -1:
		email = email+"@game.com"
	if _reconnect:
		PopupManager.show_dynamic("重连中...")
	else:
		PopupManager.show_dynamic("登录中...")
	
	var nakama_session = await Online.nakama_client.authenticate_email_async(email, password, null, false)
	
	if nakama_session.is_exception():
		PopupManager.show_dynamic("登录失败")
		print(nakama_session.get_exception().message)
		# Clear stored email and password, but leave the fields alone so the
		# user can attempt to correct them.
		email = ''
		password = ''
		
		# We always set Online.nakama_session in case something is yielding
		# on the "session_changed" signal.
		Online.nakama_session = null
		return false
	
	if save_credentials:
		_save_credentials()
	Online.set_nakama_session(nakama_session)
	if _next_screen:
		SceneManager.switch_to_scene(_next_screen)
	return true

# Authentication
func do_device_login(username: String="", created:bool=false, save_credentials: bool = false) -> bool:
	var device_id = OS.get_unique_id()
	var p_username = null
	if username != "":
		p_username = username
	var result = await Online.nakama_client.authenticate_device_async(device_id,p_username,created)
	
	if result.is_exception():
		# PopupManager.show_dynamic("设备登录失败")
		push_error("Socket connection failed: " + result.get_exception().message)
		return false
	Online.set_nakama_session(result)
	if save_credentials:
		_save_credentials()
	print("设备登录",result)
	return true


func logout():
	if Online.nakama_client and Online.nakama_session:
		Online.nakama_client.session_logout_async(Online.nakama_session)
		# 清除当前 session
		Online.set_nakama_session(null)
		var dir = DirAccess.open(USER_DIR)
		if dir:
			dir.remove(CREDENTIALS)
			print("Credentials removed")
		print("Logged out successfully")	

func register_account(myEmail,myPassword,save_credentials=false) -> void:
	email = myEmail.strip_edges()
	password = myPassword.strip_edges()
	var username = email.split('@')[0]
	if email == '':
		PopupManager.show_dynamic("账号名不能为空")
		return
	if password == '':
		PopupManager.show_dynamic("密码不能为空")
		return
	
	PopupManager.show_dynamic("正在创建账号...")
	var nakama_session = await Online.nakama_client.authenticate_email_async(email, password, username, true)
	if nakama_session.is_exception():
		var msg = nakama_session.get_exception().message
		# Nakama treats registration as logging in, so this is what we get if the
		# the email is already is use but the password is wrong.
		if msg == 'Invalid credentials.':
			msg = '账号已经被使用了,请换个账号'
		elif msg == '':
			msg = "创建账号失败"
		PopupManager.show_dynamic(msg)
		# We always set Online.nakama_session in case something is yielding
		# on the "session_changed" signal.
		Online.nakama_session = null
	else:
		if save_credentials:
			_save_credentials()
		Online.nakama_session = nakama_session
		PopupManager.show_dynamic("创建账号成功!")
		SceneManager.switch_to_scene("home")
