extends Node2D

@onready var game = $Game
@onready var ui_layer: UILayer = $UILayer
@onready var ready_screen = $UILayer/Screens/ReadyScreen
@onready var music := $Music
@onready var match_screen: Control = $UILayer/Screens/MatchScreen

var players := {}

var players_ready := {}
var players_score := {}

var match_started := false

func _ready() -> void:
	GameBridge.current.connect_match_signal("error", Callable(self, "_on_OnlineMatch_error"))
	GameBridge.current.connect_match_signal("disconnected", Callable(self, "_on_OnlineMatch_disconnected"))
	GameBridge.current.connect_match_signal("player_status_changed", Callable(self, "_on_OnlineMatch_player_status_changed"))
	GameBridge.current.connect_match_signal("player_left", Callable(self, "_on_OnlineMatch_player_left"))
	ready_screen.connect("ready_pressed",Callable(self, "_on_ReadyScreen_ready_pressed"))

	randomize()
	music.play_random()
	#_on_TitleScreen_play_online()
	#match_screen.matchmaker_player_count_control.value = GameBridge.current.get_game_max_people(32)
	#match_screen._on_OnlineMatch_joined(GameBridge.current.get_match_id())
		#

func _get_custom_rpc_methods() -> Array:
	return [
		'player_ready',
		'show_winner'
	]

#####
# UI callbacks
#####

func _on_TitleScreen_play_local() -> void:
	GameBridge.current.online_play = false

	ui_layer.hide_screen()
	ui_layer.show_back_button()

	start_game()

func _on_TitleScreen_play_online() -> void:
	GameBridge.current.online_play = true

	# Show the game map in the background because we have nothing better.
	game.reload_map()

	ui_layer.show_screen("ConnectionScreen")

func _on_UILayer_change_screen(name1: String, _screen) -> void:
	if name1 == 'TitleScreen':
		ui_layer.hide_back_button()
	else:
		ui_layer.show_back_button()

	if name1 != 'ReadyScreen':
		if match_started:
			match_started = false
			music.play_random()

func _on_UILayer_back_button() -> void:
	ui_layer.hide_message()

	stop_game()

	if GameBridge.current.online_play:
		GameBridge.current.leave()

	if ui_layer.current_screen_name in ['ConnectionScreen', 'MatchScreen', 'CreditsScreen']:
		ui_layer.show_screen("TitleScreen")
	elif not GameBridge.current.online_play:
		ui_layer.show_screen("TitleScreen")
	else:
		ui_layer.show_screen("MatchScreen")

func _on_ReadyScreen_ready_pressed() -> void:
	GameBridge.current.custom_rpc_sync(self, "player_ready", [GameBridge.current.get_my_session_id()])

#####
# OnlineMatch callbacks
#####

func _on_OnlineMatch_error(message: String):
	if message != '':
		ui_layer.show_message(message)
	ui_layer.show_screen("MatchScreen")

func _on_OnlineMatch_disconnected():
	#_on_OnlineMatch_error("Disconnected from host")
	_on_OnlineMatch_error('')

func _on_OnlineMatch_player_left(player) -> void:
	ui_layer.show_message(player.username + " has left")

	game.kill_player(player.peer_id)

	players.erase(player.peer_id)
	players_ready.erase(player.peer_id)

func _on_OnlineMatch_player_status_changed(player, status) -> void:
	if status == GameProtocol.PlayerStatus.CONNECTED:
		if GameBridge.current.is_server():
			# Tell this new player about all the other players that are already ready.
			for session_id in players_ready:
				GameBridge.current.custom_rpc_id(self, player.peer_id, "player_ready", [session_id])

#####
# Gameplay methods and callbacks
#####

func player_ready(session_id: String) -> void:
	ready_screen.set_status(session_id, "READY!")

	if GameBridge.current.is_server() and not players_ready.has(session_id):
		players_ready[session_id] = true
		if players_ready.size() == GameBridge.current.players.size():
			if GameBridge.current.match_state != GameProtocol.MatchState.PLAYING:
				GameBridge.current.start_playing()
			start_game()

func start_game() -> void:
	if GameBridge.current.online_play:
		players = GameBridge.current.get_player_names_by_peer_id()
	else:
		players = {
			1: "Player1",
			2: "Player2",
		}

	game.game_start(players)

func stop_game() -> void:
	GameBridge.current.leave()

	players.clear()
	players_ready.clear()
	players_score.clear()

	game.game_stop()

func restart_game() -> void:
	stop_game()
	start_game()

func _on_Game_game_started() -> void:
	ui_layer.hide_screen()
	ui_layer.hide_all()
	ui_layer.show_back_button()

	if not match_started:
		match_started = true
		music.play_random()

func _on_Game_player_dead(player_id: int) -> void:
	if GameBridge.current.online_play:
		var my_id = GameBridge.current.get_unique_id()
		if player_id == my_id:
			ui_layer.show_message("You lose!")

func _on_Game_game_stopped(player_id: int) -> void:
	players_ready.clear()

	if not GameBridge.current.online_play:
		show_winner(players[player_id])
	elif GameBridge.current.is_server():
		if not players_score.has(player_id):
			players_score[player_id] = 1
		else:
			players_score[player_id] += 1

		var player_session_id = GameBridge.current.get_session_id(player_id)
		var is_match: bool = players_score[player_id] >= 5
		GameBridge.current.custom_rpc_sync(self, "show_winner", [players[player_id], player_session_id, players_score[player_id], is_match])

func update_wins_leaderboard() -> void:
	if not GameBridge.current.nakama_session or GameBridge.current.nakama_session.is_expired():
		# If our session has expired, then wait until a new session is setup.
		await GameBridge.current.wait_session_connected()

	GameBridge.current.nakama_client.write_leaderboard_record_async(GameBridge.current.nakama_session, 'fish_game_wins', 1)

func show_winner(name1: String, session_id: String = '', score: int = 0, is_match: bool = false) -> void:
	if is_match:
		ui_layer.show_message(name1 + " WINS THE WHOLE MATCH!")
	else:
		ui_layer.show_message(name1 + " wins this round!")

	await get_tree().create_timer(2.0).timeout
	if not game.game_playing:
		return

	if GameBridge.current.online_play:
		if is_match:
			stop_game()
			if session_id == GameBridge.current.my_session_id:
				update_wins_leaderboard()
			ui_layer.show_screen("MatchScreen")
		else:
			ready_screen.hide_match_id()
			ready_screen.reset_status("Waiting...")
			ready_screen.set_score(session_id, score)
			ready_screen.set_ready_button_enabled()
			ui_layer.show_screen("ReadyScreen")
	else:
		restart_game()

func _on_Music_song_finished(_song) -> void:
	if not music.current_song.playing:
		music.play_random()
