extends "res://games/fishgame/scripts/main/Screen.gd"

var LeaderboardRecord = preload("res://games/fishgame/scenes/main/screens/LeaderboardRecord.tscn")

@onready var record_container = $PanelContainer/VBoxContainer/Panel/ScrollContainer/VBoxContainer

func _ready() -> void:
	clear_records()

func clear_records() -> void:
	for child in record_container.get_children():
		record_container.remove_child(child)
		child.queue_free()

func _show_screen(_info: Dictionary = {}) -> void:
	ui_layer.hide_message()

	# If our session has expired, show the ConnectionScreen again.
	if GameBridge.current.nakama_session == null or GameBridge.current.nakama_session.is_expired():
		ui_layer.show_screen("ConnectionScreen", { reconnect = true, next_screen = "LeaderboardScreen" })
		return

	var result: NakamaAPI.ApiLeaderboardRecordList = await GameBridge.current.nakama_client.list_leaderboard_records_async(GameBridge.current.nakama_session, 'fish_game_wins')
	if result.is_exception():
		ui_layer.show_message("Unable to retrieve leaderboard")
		ui_layer.show_screen("MatchScreen")

	clear_records()
	for record in result.records:
		var record_node = LeaderboardRecord.instantiate()
		record_container.add_child(record_node)
		record_node.setup(record.username, record.score)
