extends Control

## 模块：游戏列表（匹配入口）
## 职责：拉取服务端游戏列表、渲染游戏卡片、发起匹配并在匹配成功后交给加载页。
## 依赖：Global.OnlineGame / Global.OnlineMatch / Global.SignalMgr / Global.SceneMgr。

const GAME_CARD_SCENE := preload("res://lobby/gamelist/game_card.tscn")

@onready var game_list: HBoxContainer = $Background/MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/HBoxContainer
@onready var scroll_container: ScrollContainer = $Background/MarginContainer/VBoxContainer/ScrollContainer
@onready var matching = $Matching
@onready var match_success = $MatchSuccess
@onready var loading_scene = $LoadingScreen

var game_id: int = -1
var cur_match_id := ""
var games_data: Array = []
var already_ids: Array = []

func _ready() -> void:
	Global.SettingsMgr.show_settings()
	Global.SceneMgr.set_previous_name("gamelist")
	scroll_container.get_h_scroll_bar().custom_minimum_size.y = 20
	loading_scene.hide()

	load_data()
	matching.match_sucess.connect(_on_match_success)
	matching.match_cancel.connect(_on_match_cancel)
	Global.SignalMgr.StartGameSIG.connect(_on_game_start)
	Global.SignalMgr.CancleGameSIG.connect(_on_game_cancel)

# ---------------------------------------------------------------------
# 游戏列表
# ---------------------------------------------------------------------

func load_data() -> void:
	var cached: Array = Global.OnlineGame.getGameListOld()
	if cached.size() > 0:
		set_game_list(cached)
	Global.OnlineGame.getGameList(-1, self, "_on_game_list")

func _on_game_list(result) -> void:
	set_game_list(Util.sort_by_filed(result, "id"))

func set_game_list(games: Array) -> void:
	if games.is_empty():
		Global.WindowPopup.show_message("没有找到任何游戏,请检查网络连接或稍后再试。", "提示", false)
		return

	for item in games:
		if item.id in already_ids or int(item.max_player) < 2:
			# 单机游戏不参与匹配
			continue

		already_ids.append(item.id)
		games_data.append({
			"id": item.id,
			"kid": item.kid,
			"name": item.en_name,
			"title": item.name,
			"description": _build_description(item),
			"image": item.logo,
			"version": item.updated_at,
			"max_player": int(item.max_player),
			"lessscore": item.lessscore,
			"state": int(item.state),
		})

	for item in games_data:
		_add_game_card(item)

func _build_description(item) -> String:
	var text := "[center][b]%s[/b][/center]\n\n" % item.name
	if item.special:
		text += "[color=blue][b]特色：[/b][/color]\n" + item.special + "\n\n"
	if item.rules:
		text += "[color=green][b][font_size=24]规则介绍：[/font_size][/b][/color]\n" + item.rules + "\n\n"
	return text

func _add_game_card(data: Dictionary) -> void:
	var card := GAME_CARD_SCENE.instantiate()
	game_list.add_child(card)
	card.setup(data)
	card.game_selected.connect(_on_game_selected)

# ---------------------------------------------------------------------
# 匹配流程
# ---------------------------------------------------------------------

func _on_game_selected(card) -> void:
	match_success.hide()
	if card.game_data:
		matching.gamename = card.game_data["title"]
		matching.maxplayer = card.game_data["max_player"]
		game_id = card.game_data["id"]

	game_list.move_child(card, 0)
	matching.match_start.emit()
	_switch_controls(scroll_container, matching)

func _on_match_cancel() -> void:
	match_success.hide()
	_switch_controls(matching, scroll_container)

func _on_match_success(match_data) -> void:
	cur_match_id = match_data.match_id
	match_success.reset(game_id, matching.maxplayer)
	matching.hide()
	match_success.start(1.0)
	match_success.popup_centered()

func _on_game_cancel(_game_id_value) -> void:
	await Global.OnlineMatch.LeaveMatch()
	print("[GameList] 取消准备游戏 match_id:", cur_match_id)
	await get_tree().create_timer(1.5).timeout
	Global.WindowPopup.show_dynamic("游戏已取消")
	match_success.hide()
	_switch_controls(matching, scroll_container)

func _on_game_start(game_id_value) -> void:
	Global.SignalMgr.WelcomeMusicSIG.emit()
	# 每次开局都重载加载页状态，避免上一次的 100% 进度直接触发关闭。
	loading_scene.Show()
	Global.SignalMgr.LoadingGameSIG.emit(game_id_value)

	var game_en_name: String = Global.OnlineGame.getGameEnName(game_id_value)
	print("[GameList] 游戏开始 game_id:", game_id_value, " en_name:", game_en_name)
	Global.SignalMgr.GameKeepSIG.emit(1, game_id_value, -1, cur_match_id, game_en_name)

func _switch_controls(control_hide: Control, control_show: Control) -> void:
	control_show.visible = true
	control_show.modulate.a = 0.0
	control_hide.modulate.a = 1.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(control_hide, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(control_show, "modulate:a", 1.0, 1.0)
	tween.tween_callback(func(): control_hide.visible = false)
