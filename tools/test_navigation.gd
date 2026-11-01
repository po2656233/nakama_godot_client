extends SceneTree

## 阶段 1 验收测试：上下文感知导航（NavigationContext + SceneRouter）。
##
## 覆盖：
##   1. 来源 -> 回退路由映射（GAME_LIST / ROOM_LIST / CLUB_ROOM_LIST / CHAT_INVITE）；
##   2. pending 上下文的 prepare / peek / consume 生命周期；
##   3. 从 ROOM_LIST 来源进入 tetris，退出后导航栈清空、游戏停止、返回信号参数正确。
##
## 用法：godot --headless --path . --script res://tools/test_navigation.gd
## 退出码：0 通过；1 失败。
## 注意：不能静态引用 SceneRouter / NavigationContext，避免 autoload 就绪前编译。

var _passed := 0
var _failed := 0
var _done := false
var _returned_args: Array = []

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

	_check(global.has_global("SceneRouter"), "SceneRouter 已注册为全局服务")
	var router = global.SceneRouter
	_check(router != null, "SceneRouter 实例可用")

	# 1) 来源 -> 回退路由映射
	_check(router.resolve_return_route_by_source(0) == "gamelist", "GAME_LIST -> gamelist")
	_check(router.resolve_return_route_by_source(1) == "roomlist", "ROOM_LIST -> roomlist")
	_check(router.resolve_return_route_by_source(2) == "clubhome", "CLUB_ROOM_LIST -> clubhome")
	_check(router.resolve_return_route_by_source(3) == "home", "CHAT_INVITE -> home")

	# 2) pending 上下文
	_check(not router.has_pending(), "初始没有 pending 上下文")
	router.prepare_room_list("tetris", "room-123")
	_check(router.has_pending(), "prepare 后存在 pending 上下文")
	var pending = router.peek_pending()
	_check(pending != null and pending.game_id == "tetris", "pending.game_id == tetris")
	_check(pending != null and pending.room_id == "room-123", "pending.room_id == room-123")
	var consumed = router.consume_pending()
	_check(consumed != null and consumed.room_id == "room-123", "consume 返回上下文")
	_check(not router.has_pending(), "consume 后 pending 清空")

	# 3) 真机流程：ROOM_LIST 进入 tetris -> 退出
	global.SignalMgr.GameReturnedSIG.connect(_on_game_returned)
	router.prepare_room_list("tetris", "room-456")
	var started: bool = router.enter_pending_game("tetris")
	_check(started, "enter_pending_game(tetris) 返回 true")
	await process_frame
	await process_frame
	await process_frame

	var launcher = global.GameLauncher
	_check(launcher.is_game_running(), "进入后游戏运行中")
	_check(router.stack_depth() == 1, "导航栈深度为 1")
	var current = router.current_context()
	_check(current != null and current.room_id == "room-456", "当前上下文 room_id 正确")
	var context = launcher.get_context()
	_check(context != null, "GameContext 已创建")
	if context != null:
		_check(context.navigation().source == 1, "GameContext 携带 NavigationContext(ROOM_LIST)")
		_check(context.options.get("nav_context") != null, "options.nav_context 已注入")

	await router.exit_game()
	await process_frame
	await process_frame
	_check(not launcher.is_game_running(), "退出后游戏停止")
	_check(router.stack_depth() == 0, "退出后导航栈清空")
	_check(_returned_args.size() >= 1, "收到 GameReturnedSIG")
	if _returned_args.size() >= 3:
		_check(_returned_args[0] == 1, "返回来源 == ROOM_LIST")
		_check(_returned_args[1] == "tetris", "返回 game_id == tetris")
		_check(_returned_args[2] == "room-456", "返回 room_id == room-456")

	_finish()

func _on_game_returned(source, game_id, room_id) -> void:
	_returned_args = [source, game_id, room_id]

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
	print("\n===== 导航测试：通过 %d 项，失败 %d 项 =====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _guard() -> void:
	await create_timer(30.0).timeout
	if _done:
		return
	_done = true
	print("FAIL: 导航测试超时（30s）")
	quit(1)
