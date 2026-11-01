extends Node

## 模块：子游戏启动器（Global.GameLauncher）
## 职责：
##   1. 按 key 从 GameRegistry 解析场景并启动；
##   2. 注入 GameContext、挂载统一返回按钮、通知服务端“地图加载完成”；
##   3. 统一处理退出/重开/结算，避免每个子游戏各写一套。
## 依赖：Global.GameRegistry / Global.SceneMgr / Global.Online*。
## 对外：start_game() / restart_game() / exit_game() / finish_game() / is_game_running()。

signal game_started(context: GameContext)
signal game_finished(result: GameResult)
signal game_exited(context: GameContext)
signal game_restarted(context: GameContext)

const REBACK_SCENE := preload("res://shared/ui/reback.tscn")

var current_context: GameContext = null
## 子游戏桥（插件唯一对外通道）
var bridge: GameBridge = null
var current_game: Node = null
var last_result: GameResult = null

var _exit_in_progress := false

## 启动一个子游戏。返回 false 表示未找到游戏/场景，调用方通常只需提示，不必回退。
func start_game(key: String, options: Dictionary = {}) -> bool:
	if _exit_in_progress:
		push_warning("[GameLauncher] 正在退出游戏，忽略启动请求")
		return false
	return _launch(key, options, false)

## 用当前上下文重开一局（不会离开对局）。
func restart_game() -> bool:
	if current_context == null:
		push_warning("[GameLauncher] 没有正在运行的游戏，无法重开")
		return false
	return _launch(current_context.key, current_context.options, true)

## 结束当前游戏并返回上一页；result 非空时先广播结算结果。
func exit_game(result: GameResult = null) -> void:
	if _exit_in_progress:
		return
	var context := current_context
	var game := current_game
	if context == null:
		Global.SceneMgr.go_back()
		return

	_exit_in_progress = true
	var exit_transition := str(context.get_option("exit_transition", "cross"))
	if is_instance_valid(game):
		if result != null and game.has_method("on_game_result"):
			game.call("on_game_result", result)
		if game.has_method("on_game_exit"):
			game.call("on_game_exit", result)

	if result != null:
		last_result = result
		game_finished.emit(result)

	await _leave_online_match(context)

	current_game = null
	current_context = null
	bridge = null
	GameBridge.clear()
	_exit_in_progress = false
	game_exited.emit(context)
	Global.SceneMgr.go_back(exit_transition, 1.0)

## 只上报结算，不退出（子游戏可以展示自己的结算界面）。
func finish_game(result: GameResult) -> void:
	last_result = result
	if is_instance_valid(current_game) and current_game.has_method("on_game_result"):
		current_game.call("on_game_result", result)
	game_finished.emit(result)

func is_game_running() -> bool:
	return current_context != null and is_instance_valid(current_game)

func get_context() -> GameContext:
	return current_context

func get_game() -> Node:
	return current_game

func current_key() -> String:
	return current_context.key if current_context != null else ""

func _launch(key: String, options: Dictionary, is_restart: bool) -> bool:
	var descriptor := _resolve(key)
	if descriptor == null:
		Global.WindowPopup.show_dynamic("%s 正在招商中..." % key)
		return false

	if not descriptor.scene_exists():
		Global.WindowPopup.show_dynamic("%s 场景缺失：%s" % [descriptor.title, descriptor.scene_path])
		push_error("[GameLauncher] 场景不存在: %s" % descriptor.scene_path)
		return false

	var packed := load(descriptor.scene_path) as PackedScene
	if packed == null:
		Global.WindowPopup.show_dynamic("%s 加载失败" % descriptor.title)
		return false

	var game := packed.instantiate()
	if game == null:
		push_error("[GameLauncher] 实例化失败: %s" % descriptor.scene_path)
		return false

	var context := GameContext.create(descriptor, options)
	current_game = game
	current_context = context
	last_result = null
	bridge = GameBridge.create(context)
	_bind_context(game, context, bridge)

	var transition := str(options.get("transition", "cross"))
	var transition_time := float(options.get("transition_time", 0.6))
	Global.SceneMgr.switch_to_scene_instance(game, transition, transition_time)

	# 等场景真正进入树后再挂 HUD / 通知对局服务，避免和转场抢同一帧。
	_finish_launch(game, descriptor, context, is_restart)
	return true

func _resolve(key: String) -> GameDescriptor:
	if not Global.has_global("GameRegistry"):
		push_error("[GameLauncher] GameRegistry 未注册，请检查 core/bootstrap/global_config.cfg")
		return null
	return Global.GameRegistry.find(key)

func _bind_context(game: Node, context: GameContext, bridge1: GameBridge) -> void:
	# 约定 0：子游戏通过桥访问框架能力，不直接碰 Global.Online*。
	if game.has_method("on_game_bridge"):
		game.call("on_game_bridge", bridge1)
	game.set_meta("game_bridge", bridge1)
	# 约定 1：实现 on_game_context() 的游戏（推荐继承 GameBase2D/GameBaseControl）直接拿到上下文。
	if game.has_method("on_game_context"):
		game.call("on_game_context", context)
	# 约定 2：普通场景也可以通过 meta 读取上下文。
	game.set_meta("game_context", context)

func _finish_launch(game: Node, descriptor: GameDescriptor, context: GameContext, is_restart: bool) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(game) or current_game != game:
		return

	_install_hud(game, descriptor)
	if game.has_method("on_game_launched"):
		game.call("on_game_launched", context)

	if is_restart:
		game_restarted.emit(context)
	else:
		game_started.emit(context)
		_notify_map_loaded(context)

func _install_hud(game: Node, descriptor: GameDescriptor) -> void:
	if not descriptor.show_back_button:
		return
	if game.has_node("__GameHUD"):
		return

	var hud := CanvasLayer.new()
	hud.name = "__GameHUD"
	hud.layer = 100
	game.add_child(hud)

	var reback := REBACK_SCENE.instantiate()
	hud.add_child(reback)

func _notify_map_loaded(context: GameContext) -> void:
	# 联机对局：通知服务端进入游戏场景，避免服务端一直等待。
	if not context.is_online():
		return
	if not Global.has_global("Online") or Global.Online.nakama_socket == null:
		return
	await Global.OnlineGame.sendToMatch(Global.OnlineMatch.MatchState.LOADING_MAP_FINISH, "1")

func _leave_online_match(context: GameContext) -> void:
	if context == null or context.match_id.is_empty():
		return
	if not Global.has_global("OnlineMatch") or not Global.has_global("Online"):
		return
	if Global.Online.nakama_socket == null:
		return
	await Global.OnlineMatch.LeaveMatch(context.match_id)
