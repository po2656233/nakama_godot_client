extends Node

## 模块：上下文感知导航（Global.SceneRouter）
## 职责（PROMPT_REFACTOR 2.2 ②）：
##   1. 维护“进入子游戏”的导航栈（NavigationContext）；
##   2. 统一入口：enter_game() / enter_pending_game()；
##   3. 统一出口：exit_game() —— 先让子游戏 on_game_destroy() 释放资源，
##      再按来源（房间列表 / 游戏列表 / 俱乐部 / 聊天邀请）回到对应页面。
## 边界：
##   - 不直接实例化子游戏场景（交给 GameLauncher）；
##   - 不做页面内部 UI 刷新，只发 GameReturnedSIG 让目标页面自行刷新；
##   - 转场/路由仍由 SceneMgr 执行。
## 对外：prepare() / enter_game() / enter_pending_game() / exit_game() /
##       current_context() / stack_depth() / resolve_return_route()。

signal entered_game(context: NavigationContext)
signal exited_game(context: NavigationContext)

const HISTORY_LIMIT := 16
const ROUTE_ROOM_LIST := "roomlist"
const ROUTE_GAME_LIST := "gamelist"
const ROUTE_CLUB_HOME := "clubhome"
const ROUTE_HOME := "home"

## 导航栈：进入游戏时压栈，退出时出栈。
var _stack: Array[NavigationContext] = []
## 加载流程（下载/解压）期间的待进入上下文。
var _pending: NavigationContext = null
var _exiting := false

# ---------------------------------------------------------------------
# 进入游戏
# ---------------------------------------------------------------------

## 在触发 LoadingGameSIG 之前登记来源；loading_screen 下载完成后调用 enter_pending_game()。
func prepare(context: NavigationContext) -> void:
	_pending = context

# ---------------------------------------------------------------------
# 便捷登记（调用方不需要自己 new NavigationContext）
# ---------------------------------------------------------------------

func prepare_game_list(game_id: String = "") -> void:
	prepare(NavigationContext.for_game_list(game_id))

func prepare_room_list(game_id: String, room_id: String = "", extra: Dictionary = {}) -> void:
	prepare(NavigationContext.for_room_list(game_id, room_id, extra))

func prepare_club_room_list(game_id: String, room_id: String = "", extra: Dictionary = {}) -> void:
	prepare(NavigationContext.for_club_room_list(game_id, room_id, extra))

func prepare_chat_invite(game_id: String, room_id: String = "", extra: Dictionary = {}) -> void:
	prepare(NavigationContext.for_chat_invite(game_id, room_id, extra))

## 只按来源解析回退路由（测试/调试用，不需要构造完整上下文）。
func resolve_return_route_by_source(source: int) -> String:
	return resolve_return_route(NavigationContext.new(source))

func has_pending() -> bool:
	return _pending != null

func peek_pending() -> NavigationContext:
	return _pending

## 取出并清空待进入上下文。
func consume_pending() -> NavigationContext:
	var context := _pending
	_pending = null
	return context

## loading_screen 在资源就绪后调用：消费 pending 上下文并启动子游戏。
## expected_key 为下载/注册时确定的游戏 key（空则用上下文里的 game_id）。
func enter_pending_game(expected_key: String = "", extra_options: Dictionary = {}) -> bool:
	var context := consume_pending()
	var game_key := expected_key.strip_edges()
	if game_key.is_empty() and context != null:
		game_key = context.game_id
	if game_key.is_empty():
		push_warning("[SceneRouter] enter_pending_game 缺少游戏 key")
		return false
	if context == null:
		context = NavigationContext.for_game_list(game_key)
	return _enter(game_key, extra_options, context)

## 直接进入一个子游戏（调用方已确定来源时使用）。
func enter_game(game_id: String, room_info: Dictionary = {}, context: NavigationContext = null) -> bool:
	var game_key := game_id.strip_edges()
	if game_key.is_empty():
		push_warning("[SceneRouter] enter_game 缺少 game_id")
		return false
	var nav := context if context != null else NavigationContext.for_game_list(game_key)
	return _enter(game_key, room_info, nav)

func _enter(game_key: String, extra_options: Dictionary, nav: NavigationContext) -> bool:
	if Global.has_global("GameLauncher") and Global.GameLauncher.is_game_running():
		push_warning("[SceneRouter] 已有子游戏在运行，先退出再进入: %s" % game_key)
		return false
	if nav.game_id.is_empty():
		nav.game_id = game_key
	_push_context(nav)

	var options := extra_options.duplicate(true)
	options["nav_context"] = nav
	if not nav.room_id.is_empty():
		options["room_id"] = nav.room_id
	if not options.has("transition"):
		options["transition"] = "cross"

	var started: bool = Global.GameLauncher.start_game(game_key, options) if Global.has_global("GameLauncher") else false
	if not started:
		# 启动失败（场景缺失/招商中）：回滚导航栈，避免下次退出回错页面。
		var dropped := _pop_context()
		if dropped != null and Global.has_global("WindowPopup"):
			Global.WindowPopup.show_dynamic("%s 启动失败" % game_key)
		return false

	entered_game.emit(nav)
	return true

# ---------------------------------------------------------------------
# 退出游戏
# ---------------------------------------------------------------------

## 退出当前子游戏，并按进入来源回到对应页面。
func exit_game(result: GameResult = null) -> void:
	if _exiting:
		return
	if not Global.has_global("GameLauncher") or not Global.GameLauncher.is_game_running():
		if Global.has_global("SceneMgr"):
			Global.SceneMgr.go_back()
		return

	_exiting = true
	var context := _pop_context()
	if context == null:
		context = _context_from_launcher()

	_destroy_game_instance()
	await _notify_leave_room(context)

	# 交给启动器做结算/离开对局；导航由本路由负责（navigate_back=false）。
	await Global.GameLauncher.exit_game(result, false)

	var route := resolve_return_route(context)
	if Global.has_global("SceneMgr") and not route.is_empty():
		Global.SceneMgr.switch_to_scene(route, "cross", 1.0)
	if Global.has_global("SignalMgr"):
		Global.SignalMgr.GameReturnedSIG.emit(context.source, context.game_id, context.room_id)

	exited_game.emit(context)
	_exiting = false

## 根据来源解析退出后应回到的路由名（纯函数，便于测试）。
func resolve_return_route(context: NavigationContext) -> String:
	if context == null:
		return ROUTE_GAME_LIST
	match context.source:
		NavigationContext.EntrySource.ROOM_LIST:
			return ROUTE_ROOM_LIST
		NavigationContext.EntrySource.CLUB_ROOM_LIST:
			return ROUTE_CLUB_HOME
		NavigationContext.EntrySource.CHAT_INVITE:
			return ROUTE_HOME
		_:
			return ROUTE_GAME_LIST

# ---------------------------------------------------------------------
# 导航栈
# ---------------------------------------------------------------------

func current_context() -> NavigationContext:
	return _stack.back() if not _stack.is_empty() else null

func stack_depth() -> int:
	return _stack.size()

func clear_stack() -> void:
	_stack.clear()
	_pending = null
	_exiting = false

func _push_context(context: NavigationContext) -> void:
	_stack.append(context)
	while _stack.size() > HISTORY_LIMIT:
		_stack.remove_at(0)

func _pop_context() -> NavigationContext:
	return _stack.pop_back() if not _stack.is_empty() else null

func _context_from_launcher() -> NavigationContext:
	var context := NavigationContext.new()
	if Global.has_global("GameLauncher"):
		var game_context: GameContext = Global.GameLauncher.get_context()
		if game_context != null:
			context.game_id = game_context.key
			context.room_id = str(game_context.room_id) if game_context.room_id != null else ""
			if game_context.options.get("nav_context") is NavigationContext:
				context = game_context.options["nav_context"]
	return context

# ---------------------------------------------------------------------
# 资源释放与联机清理
# ---------------------------------------------------------------------

## 触发子游戏 on_game_destroy()（只触发一次），切断信号/定时器/Tween。
func _destroy_game_instance() -> void:
	if not Global.has_global("GameLauncher"):
		return
	var game: Node = Global.GameLauncher.get_game()
	if game == null or not is_instance_valid(game):
		return
	if game.get_meta("__game_destroyed", false):
		return
	game.set_meta("__game_destroyed", true)
	if game.has_method("on_game_destroy"):
		game.call("on_game_destroy")

## 通知服务端离开房间（best-effort，失败只告警）。
func _notify_leave_room(context: NavigationContext) -> void:
	if context == null or context.room_id.is_empty():
		return
	if not Global.has_global("OnlineGame") or not Global.has_global("Online"):
		return
	if not bool(Global.Online.is_socket_connected):
		return
	if not Global.OnlineGame.has_method("leaveTable"):
		return
	var payload := {
		"room_id": context.room_id,
		"game_id": context.game_id,
	}
	await Global.OnlineGame.leaveTable(JSON.stringify(payload))
