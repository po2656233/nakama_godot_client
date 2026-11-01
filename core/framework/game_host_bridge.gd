class_name GameHostBridge
extends RefCounted

## 模块：子游戏桥接层（插件唯一允许的框架入口）
## 职责：把子游戏需要的框架能力收敛成一个窄接口，屏蔽 Global.* 全局服务。
## 生命周期：GameLauncher 启动子游戏时创建并写入 `GameHostBridge.current`，退出/重开时清空。
## 用法：
##   GameHostBridge.current.toast("提示")
##   GameHostBridge.current.send_match_rpc(op, data)
##   await GameHostBridge.current.exit()
## 说明：
##   - 子游戏不得直接访问 Global.Online* / Global.OnlineMatch / Global.SceneMgr / Global.WindowPopup；
##   - 需要新能力时在这里加方法，而不是把 Global 服务名透传出去。

## 当前运行中的子游戏桥（同一时间只有一个子游戏，故用静态引用）。
static var current: GameHostBridge = null

## 准备状态变化（set_ready_status 触发）。
signal ready_status_changed(is_ready: bool)
## 收到对局数据（子游戏可连接，代替直接订阅网络层）。
signal match_data_received(op_code: int, payload: Variant)

var context: GameContext = null
var key: String = ""
var _is_ready := false

func _init(p_context: GameContext = null) -> void:
	context = p_context
	if context != null:
		key = context.key

## 创建一个桥并设为当前桥。
static func create(p_context: GameContext) -> GameHostBridge:
	var bridge := GameHostBridge.new(p_context)
	current = bridge
	return bridge

## 清空当前桥（GameLauncher 退出游戏时调用）。
static func clear() -> void:
	current = null

# ---------------------------------------------------------------------
# 上下文
# ---------------------------------------------------------------------

func option(name: String, default_value: Variant = null) -> Variant:
	return context.get_option(name, default_value) if context != null else default_value

func is_online() -> bool:
	return context != null and context.is_online()

func has_match() -> bool:
	return context != null and not context.match_id.is_empty()

func match_id() -> String:
	return context.match_id if context != null else ""

# ---------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------

## 飘字提示（原 Global.WindowPopup.show_dynamic）。
func toast(message1: String, speed: float = 100.0) -> void:
	if Global.has_global("WindowPopup"):
		Global.WindowPopup.show_dynamic(message1, speed)

## 消息框（原 Global.WindowPopup.show_message）。
func message(text: String, title: String = "提示", auto_close: bool = true) -> void:
	if Global.has_global("WindowPopup"):
		Global.WindowPopup.show_message(text, title, auto_close)

## 确认框（原 Global.WindowPopup.show_confirm）。
func confirm(text: String, callback: Callable, title: String = "确认") -> void:
	if Global.has_global("WindowPopup"):
		Global.WindowPopup.show_confirm(text, callback, title)

func close_popup(popup_id: String) -> void:
	if Global.has_global("WindowPopup"):
		Global.WindowPopup.close_popup(popup_id)

func open_settings(state: int = 0) -> void:
	if Global.has_global("SettingsMgr"):
		Global.SettingsMgr.show_settings(state)

# ---------------------------------------------------------------------
# 生命周期
# ---------------------------------------------------------------------

## 退出游戏：走 SceneRouter，按进入来源回到房间列表/游戏列表。
func exit(result: GameResult = null) -> void:
	if Global.has_global("SceneRouter"):
		await Global.SceneRouter.exit_game(result)
	elif Global.has_global("GameLauncher"):
		await Global.GameLauncher.exit_game(result)

## 子游戏请求退出（PROMPT_REFACTOR 2.3 ③）。
func request_exit_game() -> void:
	await exit()

## 获取本局房间/对局信息（只读副本）。
func room_info() -> Dictionary:
	if context == null:
		return {}
	return context.options.duplicate(true)

## 用当前上下文重开一局。
func restart() -> bool:
	return Global.GameLauncher.restart_game() if Global.has_global("GameLauncher") else false

## 上报结算，不退出。
func finish(result: GameResult) -> void:
	if Global.has_global("GameLauncher"):
		Global.GameLauncher.finish_game(result)

func is_running() -> bool:
	return Global.has_global("GameLauncher") and Global.GameLauncher.is_game_running()

# ---------------------------------------------------------------------
# 账号 / 网络
# ---------------------------------------------------------------------

func get_my_id() -> String:
	return str(Global.OnlineLogin.get_my_id()) if Global.has_global("OnlineLogin") else ""

func is_logged_in() -> bool:
	return Global.has_global("Online") and Global.Online.nakama_session != null

## Nakama 会话/客户端/socket：子游戏只需要“能发对局消息”，不要在这里做业务判断。
var nakama_session: NakamaSession:
	get:
		return Global.Online.nakama_session if Global.has_global("Online") else null
	set(value):
		if Global.has_global("Online"):
			Global.Online.nakama_session = value

var nakama_client: NakamaClient:
	get:
		return Global.Online.nakama_client if Global.has_global("Online") else null

var nakama_socket: NakamaSocket:
	get:
		return Global.Online.nakama_socket if Global.has_global("Online") else null

func get_session() -> NakamaSession:
	return nakama_session

func get_client() -> NakamaClient:
	return nakama_client

func get_socket() -> NakamaSocket:
	return nakama_socket

func is_nakama_socket_connected() -> bool:
	return Global.has_global("Online") and bool(Global.Online.is_socket_connected)

func connect_nakama_socket() -> void:
	if Global.has_global("Online"):
		Global.Online.connect_nakama_socket()

## 兼容 `await Global.Online.session_changed` 的写法：底层没有该信号时立即返回。
func wait_session_changed() -> void:
	if Global.has_global("Online") and Global.Online.has_signal("session_changed"):
		await Global.Online.session_changed

func wait_session_connected() -> void:
	if Global.has_global("Online") and Global.Online.has_signal("session_connected"):
		await Global.Online.session_connected

func wait_socket_connected() -> void:
	if Global.has_global("Online") and Global.Online.has_signal("socket_connected"):
		await Global.Online.socket_connected

# ---------------------------------------------------------------------
# 游戏状态（原 Global.OnlineGame）
# ---------------------------------------------------------------------

## 是否联机对局（可读写，游戏内可临时关闭网络同步）。
var online_play: bool:
	get:
		return bool(Global.OnlineGame.online_play) if Global.has_global("OnlineGame") else false
	set(value):
		if Global.has_global("OnlineGame"):
			Global.OnlineGame.online_play = value

## 发送文本对局状态（原 OnlineGame.sendToMatch）。
func send_match_state(op_code: int, data: String, presences = null):
	return await Global.OnlineGame.sendToMatch(op_code, data, presences)

## 发送二进制对局 RPC（原 OnlineGame.sendToMatchRpc）。
func send_match_rpc(op_code: int, data: PackedByteArray, presences = null):
	return await Global.OnlineGame.sendToMatchRpc(op_code, data, presences)

## 统一发送对局数据（PROMPT_REFACTOR 2.3 ③）：
## String 原样、PackedByteArray 走 raw RPC、其余（字典/数组）自动 JSON。
func send_match_data(op_code: int, payload: Variant) -> void:
	if payload is PackedByteArray:
		await send_match_rpc(op_code, payload)
	elif payload is String:
		await send_match_state(op_code, payload)
	else:
		await send_match_state(op_code, JSON.stringify(payload))

## 上报准备状态（PROMPT_REFACTOR 2.3 ③）。
## 本地立即生效并广播 ready_status_changed；联机时附带一条 ready 状态包。
func set_ready_status(is_ready_1: bool) -> void:
	if _is_ready == is_ready_1:
		return
	_is_ready = is_ready_1
	ready_status_changed.emit(is_ready_1)
	if is_online():
		send_match_data(GameProtocol.MatchOpCode.CUSTOM_RPC, {"t": "ready", "v": is_ready})

func is_ready() -> bool:
	return _is_ready

func get_game_max_people(game_id: int) -> int:
	return int(Global.OnlineGame.getGameMaxPeople(game_id))

# ---------------------------------------------------------------------
# 对局（原 Global.OnlineMatch）
# ---------------------------------------------------------------------

var my_peer_id: int:
	get:
		return int(Global.OnlineMatch.my_peer_id)
	set(value):
		Global.OnlineMatch.my_peer_id = value

var match_state: int:
	get:
		return int(Global.OnlineMatch.match_state)

var players: Dictionary:
	get:
		return Global.OnlineMatch.players

func create_match() -> void:
	Global.OnlineMatch.create_match(Global.Online.nakama_socket)

func join_match(p_match_id: String, metadata = null) -> void:
	Global.OnlineMatch.join_match(Global.Online.nakama_socket, p_match_id, metadata)

func join_matchmaker(data = {}) -> void:
	Global.OnlineMatch.joinMatchmaker(data)

func start_matchmaking(data: Dictionary = {}) -> void:
	Global.OnlineMatch.start_matchmaking(Global.Online.nakama_socket, data)

func leave(close_socket: bool = false) -> void:
	Global.OnlineMatch.leave(close_socket)

func start_playing() -> void:
	Global.OnlineMatch.start_playing()

func is_server() -> bool:
	return Global.OnlineMatch.is_server()

func get_my_session_id() -> String:
	return Global.OnlineMatch.get_my_session_id()

func get_match_id() -> String:
	return Global.OnlineMatch.get_match_id()

func get_unique_id() -> int:
	return int(Global.OnlineMatch.get_unique_id())

func get_player_names_by_peer_id() -> Dictionary:
	return Global.OnlineMatch.get_player_names_by_peer_id()

func custom_rpc(node: Node, method: String, args: Array = []) -> void:
	Global.OnlineMatch.custom_rpc(node, method, args)

func custom_rpc_id(node: Node, id: int, method: String, args: Array = []) -> void:
	Global.OnlineMatch.custom_rpc_id(node, id, method, args)

func custom_rpc_sync(node: Node, method: String, args: Array = []) -> void:
	Global.OnlineMatch.custom_rpc_sync(node, method, args)

func custom_rpc_id_sync(node: Node, id: int, method: String, args: Array = []) -> void:
	Global.OnlineMatch.custom_rpc_id_sync(node, id, method, args)

## 订阅“收到对局状态”事件（原 Global.SignalMgr.MatchStateEventSIG）。
func connect_match_state(callable: Callable) -> void:
	if Global.has_global("SignalMgr"):
		Global.SignalMgr.MatchStateEventSIG.connect(callable)

## 订阅对局信号（原 Global.OnlineMatch.connect(name, callable)）。
func connect_match_signal(signal_name: StringName, callable: Callable) -> void:
	Global.OnlineMatch.connect(signal_name, callable)
