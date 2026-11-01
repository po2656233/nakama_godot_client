extends "res://games/fishgame/scripts/main/Screen.gd"

@onready var matchmaker_player_count_control := $PanelContainer/VBoxContainer/MatchPanel/SpinBox
@onready var join_match_id_control := $PanelContainer/VBoxContainer/JoinPanel/LineEdit

func _ready() -> void:
	$PanelContainer/VBoxContainer/MatchPanel/MatchButton.connect("pressed", Callable(self, "_on_match_button_pressed").bind(GameProtocol.MatchMode.MATCHMAKER))
	$PanelContainer/VBoxContainer/CreatePanel/CreateButton.connect("pressed", Callable(self, "_on_match_button_pressed").bind(GameProtocol.MatchMode.CREATE))
	$PanelContainer/VBoxContainer/JoinPanel/JoinButton.connect("pressed", Callable(self, "_on_match_button_pressed").bind(GameProtocol.MatchMode.JOIN))
	GameHostBridge.current.connect_match_signal("matchmaker_matched", Callable(self, "_on_OnlineMatch_matchmaker_matched"))
	GameHostBridge.current.connect_match_signal("match_created", Callable(self, "_on_OnlineMatch_created"))
	GameHostBridge.current.connect_match_signal("match_joined", Callable(self, "_on_OnlineMatch_joined"))
	pass

func _show_screen(_info: Dictionary = {}) -> void:
	matchmaker_player_count_control.value = 2
	join_match_id_control.text = ''

func _on_match_button_pressed(mode) -> void:
	# If our session has expired, show the ConnectionScreen again.
	if GameHostBridge.current.nakama_session == null or GameHostBridge.current.nakama_session.is_expired():
		ui_layer.show_screen("ConnectionScreen", { reconnect = true, next_screen = null })
		# Wait to see if we get a new valid session.
		await GameHostBridge.current.wait_session_changed()
		if GameHostBridge.current.nakama_session == null:
			return

	# Connect socket to realtime Nakama API if not connected.
	#if not GameHostBridge.current.is_nakama_socket_connected():
		#print("socket not connected")
		#GameHostBridge.current.connect_nakama_socket()
		#await GameHostBridge.current.wait_socket_connected()

	ui_layer.hide_message()
	# Call internal method to do actual work.
	match mode:
		GameProtocol.MatchMode.MATCHMAKER:
			_start_matchmaking()
		GameProtocol.MatchMode.CREATE:
			_create_match()
		GameProtocol.MatchMode.JOIN:
			_join_match()

func _start_matchmaking() -> void:
	var min_players = matchmaker_player_count_control.value
	ui_layer.hide_screen()
	ui_layer.show_message("Looking for match...")
	print("Looking for a match")
	#var data = {
		#min_count = min_players,
		#string_properties = {
			#game = "fish_game",
			#engine = "godot",
		#},
		#query = "+properties.game:fish_game +properties.engine:godot",
	#}
	var gamename= "fish_game"
	GameHostBridge.current.join_matchmaker({
		"query": " +properties.game:%s " %gamename,
		"min_count": min_players,
		"max_count": min_players,
		"string_properties": {
			"game": gamename,
		},
		"numeric_properties": {
			"maxplayer": min_players,
			"vip": 1,
			"tickRate":60,
		}
		})
	print("Match_screen_start_matchmaking")
	#GameHostBridge.current.start_matchmaking(GameHostBridge.current.nakama_socket, data)

func _on_OnlineMatch_matchmaker_matched(_players: Dictionary):
	print("Joined Match function")
	ui_layer.hide_message()
	ui_layer.show_screen("ReadyScreen", { players = _players })

func _create_match() -> void:
	GameHostBridge.current.create_match()

func _on_OnlineMatch_created(match_id: String):
	ui_layer.show_screen("ReadyScreen", { match_id = match_id, clear = true })

func _join_match() -> void:
	var match_id = join_match_id_control.text.strip_edges()
	if match_id == '':
		ui_layer.show_message("Need to paste Match ID to join")
		return
	if not match_id.ends_with('.'):
		match_id += '.'
	print("Joining Match with ID: " + match_id)
	GameHostBridge.current.join_match(match_id)

func _on_OnlineMatch_joined(match_id: String):
	print("Match Joined")
	ui_layer.show_screen("ReadyScreen", { match_id = match_id, clear = true })

func _on_PasteButton_pressed() -> void:
	join_match_id_control.text = DisplayServer.clipboard_get()

func _on_LeaderboardButton_pressed() -> void:
	ui_layer.show_screen("LeaderboardScreen")
