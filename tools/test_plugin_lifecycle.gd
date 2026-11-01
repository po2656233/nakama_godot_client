extends SceneTree

## 子游戏生命周期冒烟：验证 GameLauncher + GameHostBridge + 插件场景能真正跑起来。
##
## 流程：start_game("tetris") -> 上下文/桥注入 -> 场景进入树 -> exit_game -> 状态清空
## 用法：godot --headless --path . --script res://tools/test_plugin_lifecycle.gd
## 退出码：0 通过；1 失败。
##
## 注意：本脚本不能静态引用 GameHostBridge / GameContext 等全局类，
##       否则会在 autoload 就绪前触发编译（Global 标识符不可见）。

var _passed := 0
var _failed := 0
var _done := false

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

	_check(global.has_global("GameLauncher"), "GameLauncher 已注册")
	_check(global.has_global("GameRegistry"), "GameRegistry 已注册")
	var launcher = global.GameLauncher

	_check(not launcher.is_game_running(), "启动前没有运行中的游戏")
	var started: bool = launcher.start_game("tetris")
	_check(started, "start_game(\"tetris\") 返回 true")
	await process_frame
	await process_frame
	await process_frame

	var context = launcher.get_context()
	_check(context != null, "启动后上下文已创建")
	if context != null:
		_check(context.key == "tetris", "上下文 key == tetris")
		_check(not context.is_online(), "tetris 是单机上下文")
		_check(context.get_option("probe", 42) == 42, "上下文可携带启动参数")

	_check(launcher.is_game_running(), "launcher.is_game_running() 为 true")
	var game: Node = launcher.get_game()
	_check(game != null, "游戏实例存在")
	if game != null:
		_check(game.is_inside_tree(), "游戏场景已进入场景树")
		_check(game.get_meta("game_bridge", null) != null, "根节点携带 game_bridge meta")
		_check(game.get_meta("game_context", null) == context, "根节点携带 game_context meta")

	await launcher.exit_game()
	await process_frame
	await process_frame
	_check(launcher.get_context() == null, "退出后上下文已清空")
	_check(not launcher.is_game_running(), "退出后 is_game_running() 为 false")
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
	print("\n===== 插件生命周期冒烟：通过 %d 项，失败 %d 项 =====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _guard() -> void:
	await create_timer(30.0).timeout
	if _done:
		return
	_done = true
	print("FAIL: 生命周期冒烟超时（30s）")
	quit(1)
