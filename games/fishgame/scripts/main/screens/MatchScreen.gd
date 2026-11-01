extends "res://games/fishgame/scripts/main/Screen.gd"

@onready var matchmaker_player_count_control := $PanelContainer/VBoxContainer/MatchPanel/SpinBox
@onready var join_match_id_control := $PanelContainer/VBoxContainer/JoinPanel/LineEdit

func _ready() -> void:
	$PanelContainer/VBoxContainer/MatchPanel/MatchButton.connect("pressed", Callable(self, "_on_match_button_pressed").bind(Global.OnlineMatch.MatchMode.MATCHMAKER))
	$PanelContainer/VBoxContainer/CreatePanel/CreateButton.connect("pressed", Callable(self, "_on_match_button_pressed").bind(Global.OnlineMatch.MatchMode.CREATE))
	$PanelContainer/VBoxContainer/JoinPanel/JoinButton.connect("pressed", Callable(self, "_on_match_button_pressed").bind(Global.OnlineMatch.MatchMode.JOIN))
	Global.OnlineMatch.connect("matchmaker_matched", Callable(self, "_on_OnlineMatch_matchmaker_matched"))
	Global.OnlineMatch.connect("match_created", Callable(self, "_on_OnlineMatch_created"))
	Global.OnlineMatch.connect("match_joined", Callable(self, "_on_OnlineMatch_joined"))
	pass

func _show_screen(_info: Dictionary = {}) -> void:
	matchmaker_player_count_control.value = 2
	join_match_id_control.text = ''

func _on_match_button_pressed(mode) -> void:
	# If our session has expired, show the ConnectionScreen again.
	if Global.Online.nakama_session == null or Global.Online.nakama_session.is_expired():
		ui_layer.show_screen("ConnectionScreen", { reconnect = true, next_screen = null })
		# Wait to see if we get a new valid session.
		await Global.Online.session_changed
		if Global.Online.nakama_session == null:
			return

	# Connect socket to realtime Nakama API if not connected.
	#if not Global.Online.is_nakama_socket_connected():
		#print("socket not connected")
		#Global.Online.connect_nakama_socket()
		#await Global.Online.socket_connected

	ui_layer.hide_message()
	# Call internal method to do actual work.
	match mode:
		Global.OnlineMatch.MatchMode.MATCHMAKER:
			_start_matchmaking()
		Global.OnlineMatch.MatchMode.CREATE:
			_create_match()
		Global.OnlineMatch.MatchMode.JOIN:
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
	Global.OnlineMatch.joinMatchmaker({
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
	#Global.OnlineMatch.start_matchmaking(Global.Online.nakama_socket, data)

func _on_OnlineMatch_matchmaker_matched(_players: Dictionary):
	print("Joined Match function")
	ui_layer.hide_message()
	ui_layer.show_screen("ReadyScreen", { players = _players })

func _create_match() -> void:
	Global.OnlineMatch.create_match(Global.Online.nakama_socket)

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
	Global.OnlineMatch.join_match(Global.Online.nakama_socket, match_id)

func _on_OnlineMatch_joined(match_id: String):
	print("Match Joined")
	ui_layer.show_screen("ReadyScreen", { match_id = match_id, clear = true })

func _on_PasteButton_pressed() -> void:
	join_match_id_control.text = DisplayServer.clipboard_get()

func _on_LeaderboardButton_pressed() -> void:
	ui_layer.show_screen("LeaderboardScreen")
