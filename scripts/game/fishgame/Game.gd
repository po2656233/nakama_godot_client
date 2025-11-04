extends Node2D

var Player = preload("res://scenes/game/fishgame/actors/Player.tscn")

@export var map_scene: PackedScene = preload("res://scenes/game/fishgame/maps/Map1.tscn")

@onready var map: Node2D = $Map
@onready var players_node := $Players
@onready var camera := $Camera2D
@onready var original_camera_position: Vector2 = camera.global_position

var game_playing := false
var game_over := false
var players_alive := {}
var players_setup := {}
var sitters := {} #sit:id

signal game_started ()
signal player_dead (player_id)
signal game_stopped (player_id)
enum OpCode {
	OpFishMove = 3000 , # 移动
	OpFishJump,					# 跳跃
	OpFishAttack,				  # 攻击
	OpFishFight,				   # 开火
	OpFishFinish,				  # 结束
}
# 进入场景
func _enter_tree():
	SignalManager.MatchStateEventSIG.connect(_on_received_match_state)
	pass
	
# 接收匹配状态事件
func _on_received_match_state(data: NakamaRTAPI.MatchData) -> void:
	#print("鱼人大作战游戏接收数据: ", data)
	var json_conv = JSON.new()
	var error_code = json_conv.parse(data.data,true)
	if error_code != OK:
		print("Error parsing JSON: " + json_conv.get_error_message(), " ---", data)
	var json_data = json_conv.get_data()
	match data.op_code:
		OnlineGame.game_status.Start:
			OnlineGame.online_play = true
			game_start(json_data['players'])	
		OpCode.OpFishMove:
			pass
		OnlineGame.game_status.Playing:
			if typeof(json_data) != TYPE_FLOAT and json_data.args:
				var parsed_args = str_to_var(json_data.args)
				# 检查解析结果是否有效
				if parsed_args != null and typeof(parsed_args) == TYPE_ARRAY:
					# 从根节点获取目标节点
					var target_node = get_node_or_null(json_data.node_path)
					if not target_node:
						if str(json_data.node_path).containsn(map.name):
							target_node = map
						elif str(json_data.node_path).containsn("Players"):
							target_node = players_node.get_node(sitters[int(json_data.peer_id)])
						else:
							target_node = get_node_or_null(json_data.node_path)
						pass
					#print(get_orphan_node_ids())
					#var target_node = players_node.get_node(sitters[int(json_data.peer_id)]) #get_node(json_data.node_path)
					
					# 检查节点是否存在以及是否有相应的方法
					if target_node and target_node.has_method(json_data.method):
						# 使用callv调用方法，传入解析后的参数数组
						target_node.callv(json_data.method, parsed_args)
					else:
						print("找不到节点或:", json_data.node_path,'  方法:', json_data.method)
				#else:
					#print("参数解析失败")
				#print("解析结果: ", json_data.args)
			pass
	pass
# 实现
func _get_custom_rpc_methods() -> Array:
	return [
		'_do_game_setup',
		'_finished_game_setup',
		'_do_game_start',
	]

func game_start(players: Dictionary) -> void:
	if OnlineGame.online_play:
		OnlineMatch.custom_rpc_sync(self, '_do_game_setup', [players])
	else:
		_do_game_setup(players)

# Initializes the game so that it is ready to really start.
func _do_game_setup(players: Dictionary) -> void:
	get_tree().set_pause(true)

	if game_playing:
		game_stop()

	game_playing = true
	game_over = false
	players_alive = players

	reload_map()
	var sit = 0
	for player_id in players:
		sit = sit + 1
		if player_id == OnlineLogin.get_my_id():
			OnlineMatch.my_peer_id = sit
		sitters[sit] = player_id
		var other_player = Player.instantiate()
		other_player.name = str(player_id)
		players_node.add_child(other_player)
		other_player.set_multiplayer_authority(sit)
		other_player.set_player_skin(sit-1)
		other_player.set_player_name(str(sit)) #players[player_id].presence.Username
		other_player.position = map.get_node("PlayerStartPositions/Player" + str(sit)).position
		other_player.rotation = map.get_node("PlayerStartPositions/Player" + str(sit)).rotation
		other_player.connect("player_dead", Callable(self, "_on_player_dead").bind(player_id))
		
		if not OnlineGame.online_play:
			other_player.player_controlled = true
			other_player.input_prefix = "player" + str(player_id) + "_"
	
	camera.update_position_and_zoom(false)

	if OnlineGame.online_play:
		var my_id := OnlineLogin.get_my_id()
		var my_player := players_node.get_node(str(my_id))
		my_player.player_controlled = true

		# Tell the host that we've finished setup.
		OnlineMatch.custom_rpc_id_sync(self, OnlineMatch.my_peer_id, "_finished_game_setup", [my_id])
	else:
		_do_game_start()

# Records when each player has finished setup so we know when all players are ready.
func _finished_game_setup(player_id) -> void:
	players_setup[player_id] = players_alive[player_id]
	#if players_setup.size() == players_alive.size():
		# Once all clients have finished setup, tell them to start the game.
	OnlineMatch.custom_rpc_sync(self, "_do_game_start")

# Actually start the game on this client.
func _do_game_start() -> void:
	if map.has_method('map_start'):
		map.map_start()
	emit_signal("game_started")
	get_tree().set_pause(false)

func game_stop() -> void:
	if map.has_method('map_stop'):
		map.map_stop()

	game_playing = false
	players_setup.clear()
	players_alive.clear()

	for child in players_node.get_children():
		players_node.remove_child(child)
		child.queue_free()

func reload_map() -> void:
	var map_index = map.get_index()
	remove_child(map)
	map.queue_free()

	map = map_scene.instantiate()
	map.name = 'Map'
	add_child(map)
	move_child(map, map_index)

	var map_rect = map.get_map_rect()
	camera.global_position = original_camera_position
	camera.limit_left = map_rect.position.x
	camera.limit_top = map_rect.position.y
	camera.limit_right = map_rect.position.x + map_rect.size.x

func kill_player(player_id) -> void:
	var player_node = players_node.get_node(str(player_id))
	if player_node:
		if player_node.has_method("die"):
			player_node.die()
		else:
			# If there is no die method, we do the most important things it
			# would have done.
			player_node.queue_free()
			_on_player_dead(player_id)

func _on_player_dead(player_id) -> void:
	emit_signal("player_dead", player_id)
	players_alive.erase(player_id)
	if not game_over and players_alive.size() == 1:
		game_over = true
		var player_keys = players_alive.keys()
		emit_signal("game_stopped", player_keys[0])
