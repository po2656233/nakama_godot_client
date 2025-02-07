extends Node

signal player_data_updated()
signal login_success()

const USER_DIR = 'user://'
const CREDENTIALS = 'credentials.json'
const CREDENTIALS_FILENAME = USER_DIR + CREDENTIALS

var email: String = ''
var password: String = ''

var _reconnect: bool = false
var _save_credentials: bool = false
var player_data: NakamaAPI.ApiUser = null

# 初始化
func _ready() -> void:
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
	login_success.connect(_on_login_success)
	pass


# 保存账号密码
func on_credentials() -> void:
	var file = FileAccess.open(CREDENTIALS_FILENAME, FileAccess.WRITE)
	var credentials = {
		email = email,
		password = password,
	}
	file.store_line(JSON.stringify(credentials))
	file.close()
	print("保存账号密码成功")
	pass

# func _show_screen(info: Dictionary = {}) -> void:
# 	_reconnect = info.get('reconnect', false)
# 	_next_screen = info.get('next_screen', 'home')
	
# 	# If we have a stored email and password, attempt to login straight away.
# 	if email != '' and password != '':
# 		do_login()
# 	pass


# 账密登录
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
	
	SignalManager.LoadingSIG.emit(10)
	var nakama_session = await Online.nakama_client.authenticate_email_async(email, password, null, false)
	if nakama_session.is_exception():
		PopupManager.show_dynamic("登录失败")
		print(nakama_session.get_exception().message)
		# Clear stored email and password, but leave the fields alone so the
		# user can attempt to correct them.
		email = ''
		password = ''
		player_data = null
		# We always set Online.nakama_session in case something is yielding
		# on the "session_changed" signal.
		Online.nakama_session = null
		return false
	
	_save_credentials = save_credentials
	Online.set_nakama_session(nakama_session)
	login_success.emit()
	return true

# 设备登录
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
	print("设备登录",result)
	Online.set_nakama_session(result)
	_save_credentials = save_credentials
	login_success.emit()
	return true


# 退出
func logout():
	_save_credentials = false
	player_data = null
	if Online.nakama_socket:
		Online.nakama_socket.close()
		Online.nakama_socket = null
	if Online.nakama_client and Online.nakama_session:
		Online.nakama_client.session_logout_async(Online.nakama_session)
		# 清除当前 session
		Online.set_nakama_session(null)
		var dir = DirAccess.open(USER_DIR)
		if dir and OK == dir.remove(CREDENTIALS_FILENAME):
			PopupManager.show_dynamic("清除缓存成功")
		print("Logged out successfully")	

# 注册账号(注册完后直登)
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
		_save_credentials = save_credentials
		Online.nakama_session = nakama_session
		PopupManager.show_dynamic("创建账号成功!")
		login_success.emit()
	pass



# 登录成功
func _on_login_success():
	load_player_data()
	on_credentials()
	SignalManager.LoadingSIG.emit(100)
	pass



####################################用户信息###########################################################
func load_player_data() -> void:
	var result = await Online.nakama_client.read_storage_objects_async(Online.nakama_session, [{
		"collection": "player_data",
		"key": "profile",
		"user_id": Online.nakama_session.user_id
	}])
	print("读取玩家数据: ", result)
	if not result.is_exception():
		if result.objects.size() > 0:
			player_data = JSON.parse_string(result.objects[0].value)
		else:
			var ret = await Online.nakama_client.get_account_async(Online.nakama_session)
			if ret.is_exception():
				push_error("获取用户信息失败: " + ret.get_exception().message)
				return
			player_data = ret.user
			print('用户信息:',player_data)	
			await save_player_data()
		print("已读取玩家数据: ", player_data)
	player_data_updated.emit()
	pass

func save_player_data() -> void:
	var objects = [{
		"collection": "player_data",
		"key": "profile",
		"value": JSON.stringify(player_data),
		"permission_read": 1,
		"permission_write": 1
	}]
	await Online.nakama_client.write_storage_objects_async(Online.nakama_session, objects)
	pass

# 获取当前用户 ID
func get_my_id() -> String:
	if not player_data:
		return ""
	return player_data.id

# 获取当前用户名
func get_my_name() -> String:
	if not player_data:
		return ""
	return player_data.username

# 获取当前用户名
func get_my_nickname() -> String:
	if not player_data:
		return ""
	return player_data.display_name

# 获取当前用户头像
func get_my_headIcon():
	if not player_data:
		return ""
	return player_data.avatar_url
	

###################################################################################################