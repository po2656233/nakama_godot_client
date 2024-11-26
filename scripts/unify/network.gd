extends Node

# Nakama client instance
var client: NakamaClient
var session: NakamaSession
var socket: NakamaSocket

# Game data
var player_data: Dictionary = {}
var pets_data: Dictionary = {}
var home_data: Dictionary = {}

# Configuration
const SERVER_KEY: String = "superman"
const HOST: String = "60.205.90.152"
const PORT: int = 7350
const SCHEME: String = "http"

signal player_data_updated
signal pet_data_updated
signal home_data_updated
signal connection_established
signal connection_failed

var social_system = null

func _ready() -> void:
	# Initialize client
	client = Nakama.create_client(
		SERVER_KEY,
		HOST,
		PORT,
		SCHEME
	)
	
	# Initialize socket
	socket = Nakama.create_socket_from(client)

	connect_signals()
	var success = await restore_session()
	if not success:
		await authenticate_device()
	else:
		connection_established.emit()

func _exit_tree():
	if social_system:
		social_system.queue_free()
		social_system = null
	if client:
		client.cancel_free()
		client = null
		

func initialize_client() -> void:
	if client:
		client.cancel_free()
		client = null
	client = Nakama.create_client(SERVER_KEY, HOST, PORT, SCHEME)
	connect_signals()
	var success = await restore_session()
	if not success:
		await authenticate_device()
	else:
		connection_established.emit()

func connect_signals() -> void:
	if socket:
		socket.connection_error.connect(_on_connection_failed)
		socket.connected.connect(_on_connection_succeeded)
		socket.received_error.connect(_on_received_error)

# Authentication
func authenticate_device(username: String="", created:bool=false) -> bool:
	var device_id = OS.get_unique_id()
	var result = await client.authenticate_device_async(device_id,username,created)
	
	if result.is_exception():
		connection_failed.emit()
		return false
	
	session = result
	save_session()
	
	# Connect socket after authentication
	if socket.is_connected_to_host():
		return true
	var socket_result = await socket.connect_async(session)
	if socket_result.is_exception():
		push_error("Socket connection failed: " + socket_result.get_exception().message)
		connection_failed.emit()
		return false
	
	connection_established.emit()
	return true


# Authentication
func authenticate_email(username: String,password: String,email: String="",  created:bool=false) -> bool:
	if username.is_empty():
		return await self.authenticate_device(username,created)
	
	if password.is_empty():
		push_error("password is empty")
		return false
	
	if email.is_empty():
		email = username+"@game.com"
	var result = await client.authenticate_email_async(email,password,username,created)
	if result.is_exception():
		print("发送登录请求失败",result.get_exception().message)
		connection_failed.emit()
		return false
	
	print("发送登录请求成功",result)
	session = result
	save_session()
	# Connect socket after authentication
	if socket.is_connected_to_host():
		return true

	var socket_result = await socket.connect_async(session)
	if socket_result.is_exception():
		push_error("Socket失败: " , socket_result)
		connection_failed.emit()
		return false
	print("Socket连接成功")
	connection_established.emit()
	return true


# Session Management
func save_session() -> void:
	if session:
		var file = FileAccess.open("user://nakama_session.save", FileAccess.WRITE)
		file.store_line(session.token)
		file.close()

func restore_session() -> bool:
	var session_token = load_session_token()
	print("当前的 session: " + session_token)
	if session_token.is_empty():
		return false
		
	var result = await NakamaClient.restore_session(session_token)
	if result.is_exception():
		return false

	session = result
	await setup_socket()
	await load_player_data()
	return true

func load_session_token() -> String:
	if not FileAccess.file_exists("user://nakama_session.save"):
		return ""
		
	var file = FileAccess.open("user://nakama_session.save", FileAccess.READ)
	var token = file.get_line()
	file.close()
	print("缓存的Session token: " + token)
	return token

# Socket Setup
func setup_socket() -> void:
	if session:
		if socket:
			socket.close()
		socket = Nakama.create_socket_from(client)
		await socket.connect_async(session)
		connect_signals()

# Data Management
func load_player_data() -> void:
	if !session:
		return
		
	var result = await client.read_storage_objects_async(session, [{
		"collection": "player_data",
		"key": "profile",
		"user_id": session.user_id
	}])
	
	if not result.is_exception():
		if result.objects.size() > 0:
			player_data = JSON.parse_string(result.objects[0].value)
		else:
			# Create new player data
			player_data = {
				"nickname": "Player" + str(randi() % 1000),
				"level": 1,
				"coins": 1000,
				"gems": 10,
				"home_data": {
					"furniture_list": [],
					"decoration_theme": "default",
					"layout": {}
				},
				"pets": []
			}
			await save_player_data()
	
	player_data_updated.emit()

func save_player_data() -> void:
	if !session:
		return
		
	var objects = [{
		"collection": "player_data",
		"key": "profile",
		"value": JSON.stringify(player_data),
		"permission_read": 1,
		"permission_write": 1
	}]
	
	await client.write_storage_objects_async(session, objects)

# Pet Management
func add_pet(species: String, name1: String) -> void:
	var new_pet = {
		"pet_id": str(Time.get_unix_time_from_system()),
		"species": species,
		"name": name1,
		"level": 1,
		"stats": {
			"hunger": 100,
			"happiness": 100,
			"energy": 100
		},
		"skills": []
	}
	
	player_data.pets.append(new_pet)
	save_player_data.call_deferred()
	pet_data_updated.emit()

func feed_pet(pet_id: String) -> void:
	for pet in player_data.pets:
		if pet.pet_id == pet_id:
			pet.stats.hunger = minf(pet.stats.hunger + 30, 100)
			pet.stats.happiness = minf(pet.stats.happiness + 10, 100)
			break
	
	save_player_data.call_deferred()
	pet_data_updated.emit()

# Social Features
func send_friend_request(friend_id: String) -> void:
	if socket:
		await socket.add_friends_async(session, [friend_id])

func accept_friend_request(friend_id: String) -> void:
	if socket:
		await socket.add_friends_async(session, [friend_id])

# Signal Handlers
func _on_connection_failed():
	connection_failed.emit()

func _on_connection_succeeded():
	connection_established.emit()

func _on_received_error(error: String):
	push_error("Nakama error: " + error)
