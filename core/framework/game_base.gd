class_name GameBase
extends Node

## 模块：子游戏生命周期契约（PROMPT_REFACTOR 2.3 ②）
## 职责：所有子游戏根节点必须实现下列钩子；SceneRouter / GameLauncher 只认这些钩子。
## 说明：
##   - 严禁在子游戏内直接访问大厅单例（Global.Online* / Global.SceneMgr ...），
##     一律通过注入的 GameHostBridge；
##   - Node2D / Control 根节点无法直接继承本类（单继承），请改用同一契约的
##     GameBase2D / GameBaseControl，钩子签名完全一致；
##   - on_game_destroy() 必须彻底切断本局信号、停止私有 Timer/Tween，避免内存泄漏。

## 宿主桥（由 GameLauncher 注入）。
var bridge: GameHostBridge = null
## 本局房间/对局信息（由 SceneRouter -> GameContext.options 传入）。
var room_info: Dictionary = {}
var _destroyed := false

## 由 GameLauncher 在实例化后、场景进入树前调用。
func on_game_init(p_room_info: Dictionary, p_bridge: GameHostBridge) -> void:
	room_info = p_room_info.duplicate(true)
	bridge = p_bridge

## 场景进入树、HUD 就绪后调用；此时可以开始第一局。
func on_game_start() -> void:
	pass

## 收到本局网络包（op_code 见 GameProtocol）。
func on_network_packet(_op_code: int, _payload: Variant) -> void:
	pass

## 切后台 / 暂停。
func on_game_pause() -> void:
	pass

## 恢复前台。
func on_game_resume() -> void:
	pass

## 退出前调用：断信号、停 Timer/Tween、释放私有资源。只会被调用一次。
func on_game_destroy() -> void:
	_destroyed = true

func is_destroyed() -> bool:
	return _destroyed

## 便捷：请求宿主执行上下文感知退出。
func request_exit() -> void:
	if bridge != null:
		bridge.request_exit_game()
