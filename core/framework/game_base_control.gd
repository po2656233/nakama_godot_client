class_name GameBaseControl
extends Control

## 模块：Control 子游戏基类（UI 类小游戏继承）
## 职责与 GameBase2D 完全一致，只是根节点类型不同。
## 说明：子类扩展钩子方法时记得调用 super()。

var game_context: GameContext = null
## 框架桥：子游戏唯一允许的框架入口（GameLauncher 注入）。
var bridge: GameBridge = null

## 由 GameLauncher 在实例化后调用：注入框架桥。
func on_game_bridge(p_bridge: GameBridge) -> void:
	bridge = p_bridge

func on_game_context(context: GameContext) -> void:
	game_context = context

func on_game_launched(_context: GameContext) -> void:
	pass

func on_game_result(_result: GameResult) -> void:
	pass

func on_game_exit(_result: GameResult) -> void:
	pass

func finish_game(result: GameResult) -> void:
	if Global.has_global("GameLauncher"):
		Global.GameLauncher.finish_game(result)

func exit_game(result: GameResult = null) -> void:
	if Global.has_global("GameLauncher"):
		await Global.GameLauncher.exit_game(result)
	else:
		Global.SceneMgr.go_back()

func restart_game() -> bool:
	return Global.GameLauncher.restart_game() if Global.has_global("GameLauncher") else false

func send_game_state(op_code: int, payload: Variant) -> void:
	if game_context == null or not game_context.is_online():
		return
	var data: String = payload if payload is String else JSON.stringify(payload)
	await Global.OnlineGame.sendToMatch(op_code, data)

func is_online() -> bool:
	return game_context != null and game_context.is_online()

func get_game_option(name: String, default_value: Variant = null) -> Variant:
	return game_context.get_option(name, default_value) if game_context != null else default_value
