extends Node

signal login_failed(error: String)

# signal session_connected(session)
signal loading_percent(val)

const USER_DIR = 'user://'
const CREDENTIALS = 'credentials.json'
const CREDENTIALS_FILENAME = USER_DIR + CREDENTIALS

var email: String = ''
var password: String = ''
var login_method: String = 'dev'
var _first_dev_login = true
var _reconnect: bool = false
var _save_credentials: bool = false
var player_data: NakamaAPI.ApiUser : get = get_my_info

var cur_progress_percent = 0

# 初始化
func _ready() -> void:
	reset()
	if FileAccess.file_exists(CREDENTIALS_FILENAME):
		var file: FileAccess = FileAccess.open(CREDENTIALS_FILENAME, FileAccess.READ)
		var test_json_conv: JSON = JSON.new()
		var error = test_json_conv.parse(file.get_as_text())
		assert(error == OK, test_json_conv.get_error_message())
		var result: Dictionary = test_json_conv.get_data()
		if result is Dictionary:
			email = result['email']
			password = result['password']
		file.close()
	loading_percent.connect(update_loading_progress)
	login_failed.connect(_on_login_fail)
	pass

func reset():
	# email = ''
	# password = ''
	player_data = null
	login_method = ''
	cur_progress_percent = 0
	_save_credentials = false
	pass

# 保存账号密码
func on_credentials() -> void:
	if login_method == 'dev':
		return
	var file = FileAccess.open(CREDENTIALS_FILENAME, FileAccess.WRITE)
	if file.is_open():
		var credentials = {
			email = email,
			password = password,
		}
		file.store_line(JSON.stringify(credentials))
		file.close()
	print("保存账号密码成功")
	pass
	
# 更新加载百分比 只有主动设置成100%
func update_loading_progress(scope: int = 20,isRand:bool = true):
	if scope >= 100:
		cur_progress_percent = 100
		SignalManager.LoadingSIG.emit(cur_progress_percent)
		cur_progress_percent = 0
		return

	
	if isRand :
		if scope <= 0:
			scope = 20
		cur_progress_percent = cur_progress_percent + randi()%scope
	else:
		cur_progress_percent = scope
	if cur_progress_percent >= 100:
		cur_progress_percent = 99
	SignalManager.LoadingSIG.emit(cur_progress_percent)
	pass
# func _show_screen(info: Dictionary = {}) -> void:
# 	_reconnect = info.get('reconnect', false)
# 	_next_screen = info.get('next_screen', 'home')
	
# 	# If we have a stored email and password, attempt to login straight away.
# 	if email != '' and password != '':
# 		do_login()
# 	pass

############################################【注册】#######################################################################
# 注册处理
func _on_register_success(result):
	Online.set_nakama_session(result)
	PopupManager.show_dynamic("创建账号成功!")
	

# 注册失败
func _on_register_failure(result):
	var msg = result.get_exception().message
	# Nakama treats registration as logging in, so this is what we get if the
	# the email is already is use but the password is wrong.
	if msg == 'Invalid credentials.':
		msg = '账号已经被使用了,请换个账号'
	elif msg == '':
		msg = "创建账号失败"
	# PopupManager.show_dynamic(msg)
	# We always set Online.nakama_session in case something is yielding
	# on the "session_changed" signal.
	login_failed.emit(msg)


	
# 注册账号(注册完后直登)
func register_account(myEmail, myPassword, save_credentials = false) -> void:
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
	login_method = 'acc'
	_save_credentials = save_credentials
	await Util.Asyn_Call(Online.nakama_client, "authenticate_email_async", [email, password, username, true], _on_register_success, _on_register_failure)
	pass


############################################【登录】#######################################################################
# 成功回调函数
func _on_auth_success(result):
	print("获取 Authentication success!",result.username,result.user_id)
	loading_percent.emit()
	Online.nakama_session = result
	loading_percent.emit()
	player_data = NakamaAPI.ApiUser.create(NakamaAPI,{
		username = result.username,
		id = result.user_id,
	})
	on_credentials()
	loading_percent.emit(100)
	call_thread_safe("load_player_data",result)
	


	

# 失败回调函数
func _on_auth_failure(error):
	print("获取 Authentication failed: ", error)
	if error == "Password must be at least 8 characters long.":
		error = "密码长度至少为8位"
	if error == "":
		error = "登录失败，请检查您的网络设置"
	login_failed.emit(error)
	

func _on_auth_failure_dev(error):
	print("获取 Authentication failed: ", error)
	if error == "HTTPRequest failed!":
		login_failed.emit(error)
		return
	if _first_dev_login:
		_first_dev_login = false
		print("第一次设备登录")
	else:
		print("第二次设备登录")
		login_failed.emit(error)
		

func _on_login_fail(msg):
	reset()
	if msg == "HTTPRequest failed!":
		msg = "网络连接失败，请检查您的网络设置"
	elif msg == "Invalid session.":
		msg = "登录会话无效，请重新登录"
	elif msg == "Session expired.":
		msg = "登录会话已过期，请重新登录"
	elif msg == "Invalid credentials.":
		msg = "账号或密码错误，请检查后重试"
	elif msg == "":
		msg = "登录失败，请稍后重试"
	Online.set_nakama_session(null)
	PopupManager.show_dynamic(msg)
	

# 账密登录
func do_login(myemail: String = '', mypassword: String = '', save_credentials: bool = false) -> bool:
	reset()
	if myemail != '':
		email = myemail
	if mypassword != '':
		password = mypassword
	if email.is_empty():
		PopupManager.show_dynamic("账号不能为空")
		return false
	if password.is_empty():
		PopupManager.show_dynamic("密码不能为空")
		return false
	if email.find('@') == -1:
		email = email + "@game.com"
	if _reconnect:
		PopupManager.show_dynamic("重连中...")
	# 登录
	login_method = 'acc'
	_save_credentials = save_credentials
	loading_percent.emit(1,false)
	print("正在进行账号登录...")
	return await Util.Asyn_Call(Online.nakama_client, "authenticate_email_async", [email, password, null, false], _on_auth_success, _on_auth_failure)
	
# 设备登录
func do_device_login(username: String = "", created: bool = false, save_credentials: bool = false) -> bool:
	reset()
	var device_id = OS.get_unique_id()
	var p_username = null
	if username != "":
		p_username = username
	login_method = 'dev'
	_save_credentials = save_credentials
	loading_percent.emit(1,false)
	print("正在进行设备登录...")
	
	var ret = await Util.Asyn_Call(Online.nakama_client, "authenticate_device_async", [device_id, p_username, created], _on_auth_success, _on_auth_failure_dev)
	if !ret and !_first_dev_login:
		print("-----------创建设备账号------------------")
		ret = await Util.Asyn_Call(Online.nakama_client, "authenticate_device_async", [device_id, p_username, true], _on_auth_success, _on_auth_failure_dev)
	return ret


# 重新登录
func relogin():
	if login_method == 'acc':
		await Util.Asyn_Call(Online.nakama_client, "authenticate_email_async", [email, password, null, false], _on_auth_success, Util.EMPTY_CALLABLE)
	elif login_method == 'dev':
		var device_id = OS.get_unique_id()
		await Util.Asyn_Call(Online.nakama_client, "authenticate_device_async", [device_id, "", false], _on_auth_success,Util.EMPTY_CALLABLE)

# 退出
func logout():
	reset()
	OnlineGame.initGameList()
	_first_dev_login = true
	if Online.nakama_client and Online.nakama_session:
		Online.nakama_client.session_logout_async(Online.nakama_session)
		Online.nakama_session = null
		var dir = DirAccess.open(USER_DIR)
		if dir and OK == dir.remove(CREDENTIALS_FILENAME):
			PopupManager.show_dynamic("清除缓存成功")
		print("Logged out successfully")

####################################用户信息###########################################################
# 第一次加载用户信息
func _on_first_userinfo_success(result):
	loading_percent.emit(10)
	player_data = result.user
	print('第一次用户信息:', player_data)
	pass

# 加载用户信息成功
func _on_userinfo_success(result):
	print("获取用户信息成功: ", result)
	player_data = result.users[0]
	# SignalManager.UserInfoSIG.emit(player_data) # 发射用户信息信号


# 加载用户信息失败
func _on_userinfo_failure(err):
	print("获取用户信息失败: ", err)
	pass




#### 异步加载玩家数据
func load_player_data(session) -> void:
	await Util.Asyn_Call(Online.nakama_client, "get_users_async",	[session, [session.user_id]
		],_on_userinfo_success, _on_userinfo_failure)
	# 连接 Nakama Socket
	return

#### 保存玩家数据
func save_player_data(session) -> void:
	var objects = [ {
		"collection": "player_data",
		"key": "profile",
		"value": JSON.stringify(player_data),
		"permission_read": 1,
		"permission_write": 1
	}]
	await Online.nakama_client.write_storage_objects_async(session, objects)
	pass

##########################################################################
func get_my_info() -> NakamaAPI.ApiUser:
	return player_data
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
