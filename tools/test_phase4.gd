extends SceneTree

## 阶段 4 验收：子游戏迁移到 GameBase 契约 + 上下文感知回退 + 资源释放。
##
## 覆盖：
##   1. tetris 入口根节点实现 GameBase 生命周期（on_game_start 被调用、room_info 注入）；
##   2. 从游戏列表进入 -> 退出回到 gamelist；
##   3. 从房间列表进入 -> 退出回到 roomlist；
##   4. 退出时 on_game_destroy 被调用（GameDestroyedSIG）、场景实例被释放。
##
## 用法：godot --headless --path . --script res://tools/test_phase4.gd

var _passed := 0
var _failed := 0
var _done := false
var _returned: Array = []
var _destroyed: Array = []

func _init() -> void:
	_run.call_deferred()
	_guard.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	var global := root.get_node_or_null("Global")
	_check(global != null, "Global 自动加载存在")
	if global == null:
		_finish()
		return
	_check(global.has_global("SceneRouter"), "SceneRouter 已注册")
	var router = global.SceneRouter
	var launcher = global.GameLauncher
	global.SignalMgr.GameReturnedSIG.connect(func(source, game_id, room_id): _returned = [source, game_id, room_id])
	global.SignalMgr.GameDestroyedSIG.connect(func(game_id): _destroyed.append(game_id))

	# 1) 从游戏列表进入
	router.prepare_game_list("tetris")
	var started: bool = router.enter_pending_game("tetris")
	_check(started, "从 GAME_LIST 进入 tetris 成功")
	await process_frame
	await process_frame
	await process_frame
	var game: Node = launcher.get_game()
	_check(game != null, "tetris 实例存在")
	if game != null:
		_check(game.has_method("on_game_start"), "根节点实现 on_game_start（GameBase 契约）")
		_check(game.has_method("on_game_destroy"), "根节点实现 on_game_destroy")
		_check(bool(game.get("started")), "on_game_start 已被调用")
		var room_info = game.get("room_info")
		_check(room_info is Dictionary, "on_game_init 注入了 room_info")
		_check(game.get("bridge") != null, "GameHostBridge 已注入")
		_check(router.stack_depth() == 1, "导航栈深度为 1")

	_returned = []
	_destroyed = []
	await router.exit_game()
	await process_frame
	await process_frame
	_check(not launcher.is_game_running(), "从游戏列表退出后游戏停止")
	_check(router.stack_depth() == 0, "退出后导航栈清空")
	_check(_returned.size() == 3, "收到 GameReturnedSIG")
	if _returned.size() == 3:
		_check(_returned[0] == 0, "返回来源 == GAME_LIST")
		_check(_returned[1] == "tetris", "返回 game_id == tetris")
		_check(router.resolve_return_route_by_source(_returned[0]) == "gamelist", "GAME_LIST 回退到 gamelist")
	_check(_destroyed.has("tetris"), "on_game_destroy 已触发（GameDestroyedSIG）")
	if game != null:
		_check(not is_instance_valid(game), "退出后场景实例已释放")

	# 2) 从房间列表进入
	router.prepare_room_list("tetris", "room-phase4")
	started = router.enter_pending_game("tetris")
	_check(started, "从 ROOM_LIST 进入 tetris 成功")
	await process_frame
	await process_frame
	await process_frame
	var room_game: Node = launcher.get_game()
	_check(room_game != null, "房间入口的 tetris 实例存在")
	if room_game != null:
		var info = room_game.get("room_info")
		_check(info is Dictionary and str(info.get("room_id", "")) == "room-phase4", "room_info 携带房间号")
	_returned = []
	await router.exit_game()
	await process_frame
	await process_frame
	_check(_returned.size() == 3, "房间入口退出收到 GameReturnedSIG")
	if _returned.size() == 3:
		_check(_returned[0] == 1, "返回来源 == ROOM_LIST")
		_check(_returned[2] == "room-phase4", "返回 room_id == room-phase4")
		_check(router.resolve_return_route_by_source(_returned[0]) == "roomlist", "ROOM_LIST 回退到 roomlist")
	if room_game != null:
		_check(not is_instance_valid(room_game), "房间入口实例已释放")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", label)

func _finish() -> void:
	if _done:
		return
	_done = true
	print("\n===== 阶段 4 验收：通过 %d 项，失败 %d 项 =====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _guard() -> void:
	await create_timer(40.0).timeout
	if _done:
		return
	_done = true
	print("FAIL: 阶段 4 验收超时（40s）")
	quit(1)
