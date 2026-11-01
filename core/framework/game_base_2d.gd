class_name GameBase2D
extends Node2D

## 模块：2D 子游戏基类（推荐新游戏继承）
## 职责：实现 PROMPT_REFACTOR 2.3 的生命周期契约，并把重开/退出/结算转发给框架。
## 说明：
##   - GameBase（Node）与 GameBase2D / GameBaseControl 钩子签名完全一致，按根节点类型选择；
##   - 不重写 _ready()/_enter_tree()，避免和子类生命周期冲突；
##   - 子类扩展钩子时记得调用 super()（尤其是 on_game_destroy）。

var game_context: GameContext = null
## 宿主桥：子游戏唯一允许的框架入口（GameLauncher 注入）。
var bridge: GameHostBridge = null
## 本局房间/对局信息。
var room_info: Dictionary = {}
var _destroyed := false

# ---------------------------------------------------------------------
# 框架注入
# ---------------------------------------------------------------------

## 由 GameLauncher 在实例化后调用（旧契约，保留兼容）。
func on_game_bridge(p_bridge: GameHostBridge) -> void:
	bridge = p_bridge

## 由 GameLauncher 在实例化后调用（旧契约，保留兼容）。
func on_game_context(context: GameContext) -> void:
	game_context = context

## 由 GameLauncher 在实例化后调用（新契约）。
func on_game_init(p_room_info: Dictionary, p_bridge: GameHostBridge) -> void:
	room_info = p_room_info.duplicate(true)
	if p_bridge != null:
		bridge = p_bridge

# ---------------------------------------------------------------------
# 生命周期契约
# ---------------------------------------------------------------------

## 场景进入树、HUD 就绪后调用。
func on_game_start() -> void:
	pass

## 兼容旧钩子：默认转发到 on_game_start()。
func on_game_launched(_context: GameContext) -> void:
	on_game_start()

## 收到本局网络包（op_code 见 GameProtocol）。
func on_network_packet(_op_code: int, _payload: Variant) -> void:
	pass

func on_game_pause() -> void:
	pass

func on_game_resume() -> void:
	pass

## 退出前释放资源：断信号、停 Timer/Tween。只会被调用一次。
func on_game_destroy() -> void:
	if _destroyed:
		return
	_destroyed = true

func is_destroyed() -> bool:
	return _destroyed

## 收到结算结果时调用（可用来弹结算面板）。
func on_game_result(_result: GameResult) -> void:
	pass

## 即将退出时调用，适合停音效/断开本地计时器。
func on_game_exit(_result: GameResult) -> void:
	pass

# ---------------------------------------------------------------------
# 便捷方法
# ---------------------------------------------------------------------

## 上报结算结果，不退出游戏。
func finish_game(result: GameResult) -> void:
	if Global.has_global("GameLauncher"):
		Global.GameLauncher.finish_game(result)

## 上下文感知退出：回到进入时的房间列表 / 游戏列表。
func exit_game(result: GameResult = null) -> void:
	if Global.has_global("SceneRouter"):
		await Global.SceneRouter.exit_game(result)
	elif Global.has_global("GameLauncher"):
		await Global.GameLauncher.exit_game(result)
	elif Global.has_global("SceneMgr"):
		Global.SceneMgr.go_back()

## 便捷：请求宿主执行上下文感知退出。
func request_exit() -> void:
	if bridge != null:
		bridge.request_exit_game()

## 重开一局（保留当前对局/房间上下文）。
func restart_game() -> bool:
	return Global.GameLauncher.restart_game() if Global.has_global("GameLauncher") else false

## 联机对局发送自定义状态；非联机场景直接忽略。
func send_game_state(op_code: int, payload: Variant) -> void:
	if bridge != null:
		bridge.send_match_data(op_code, payload)

func is_online() -> bool:
	return game_context != null and game_context.is_online()

func get_game_option(name1: String, default_value: Variant = null) -> Variant:
	return game_context.get_option(name1, default_value) if game_context != null else default_value
