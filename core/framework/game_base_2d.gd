class_name GameBase2D
extends Node2D

## 模块：2D 子游戏基类（推荐新游戏继承）
## 职责：接收 GameContext，并把重开/退出/结算/对局消息转发给 GameLauncher。
## 说明：
##   - 不重写 _ready()/_enter_tree()，避免和子类生命周期冲突；
##   - 子类如需扩展 on_game_context()/on_game_launched() 等钩子，记得调用 super()。

var game_context: GameContext = null

## 由 GameLauncher 在实例化后调用。
func on_game_context(context: GameContext) -> void:
	game_context = context

## 场景进入树并挂好 HUD 后调用，适合做“对局正式开始”的初始化。
func on_game_launched(_context: GameContext) -> void:
	pass

## 收到结算结果时调用（可用来弹结算面板）。
func on_game_result(_result: GameResult) -> void:
	pass

## 即将退出时调用，适合停音效/断开本地计时器。
func on_game_exit(_result: GameResult) -> void:
	pass

## 上报结算结果，不退出游戏。
func finish_game(result: GameResult) -> void:
	if Global.has_global("GameLauncher"):
		Global.GameLauncher.finish_game(result)

## 退出游戏并回到上一页。
func exit_game(result: GameResult = null) -> void:
	if Global.has_global("GameLauncher"):
		await Global.GameLauncher.exit_game(result)
	else:
		Global.SceneMgr.go_back()

## 重开一局（保留当前对局/房间上下文）。
func restart_game() -> bool:
	return Global.GameLauncher.restart_game() if Global.has_global("GameLauncher") else false

## 联机对局发送自定义状态；非联机场景直接忽略。
func send_game_state(op_code: int, payload: Variant) -> void:
	if game_context == null or not game_context.is_online():
		return
	var data: String = payload if payload is String else JSON.stringify(payload)
	await Global.OnlineGame.sendToMatch(op_code, data)

func is_online() -> bool:
	return game_context != null and game_context.is_online()

func get_game_option(name: String, default_value: Variant = null) -> Variant:
	return game_context.get_option(name, default_value) if game_context != null else default_value
