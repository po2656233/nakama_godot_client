extends SceneTree

## 开发辅助：校验子游戏框架（注册表、清单、路由、上下文、结果）。
## 用法：godot --headless --path . --script res://tools/validate_game_framework.gd

const EXPECTED_KEYS := ["chinesechess", "tetris", "mahjong_matching", "fishgame"]
const EXPECTED_ALIASES := {
	"xiangqi": "chinesechess",
	"mahjong": "mahjong_matching",
	"fish": "fishgame",
}
const CONTEXT_SCRIPT := "res://core/framework/game_context.gd"
const RESULT_SCRIPT := "res://core/framework/game_result.gd"

var _failed := 0
var _passed := 0
var _done := false

func _init() -> void:
	_run.call_deferred()
	_guard.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	var global = root.get_node_or_null("Global")
	_check(global != null, "Global autoload 存在")
	if global == null:
		_finish()
		return

	_check(global.has_global("GameRegistry"), "GameRegistry 已注册")
	_check(global.has_global("GameLauncher"), "GameLauncher 已注册")
	_check(global.has_global("SceneMgr"), "SceneMgr 已注册")

	var registry = global.GameRegistry
	for key in EXPECTED_KEYS:
		_check(registry.has(key), "注册表包含 %s" % key)
		var descriptor = registry.find(key)
		_check(descriptor != null, "%s 可解析为 GameDescriptor" % key)
		if descriptor != null:
			_check(descriptor.scene_exists(), "%s 场景存在: %s" % [key, descriptor.scene_path])
			_check(ResourceLoader.load(descriptor.scene_path) is PackedScene, "%s 场景可加载" % key)

	for alias in EXPECTED_ALIASES:
		var descriptor = registry.find(alias)
		_check(descriptor != null and descriptor.key == EXPECTED_ALIASES[alias], "别名 %s -> %s" % [alias, EXPECTED_ALIASES[alias]])

	_check(registry.find("not_a_real_game") == null, "未知游戏返回 null")
	_check(registry.validate().is_empty(), "内置游戏清单校验通过: %s" % str(registry.validate()))

	var scene_mgr = global.SceneMgr
	for key in EXPECTED_KEYS:
		_check(not scene_mgr.get_scene_path(key).is_empty(), "SceneMgr 能兜底查询子游戏 %s" % key)

	var descriptor = registry.find("tetris")
	var context_script = load(CONTEXT_SCRIPT)
	var result_script = load(RESULT_SCRIPT)
	_check(context_script != null and result_script != null, "GameContext / GameResult 脚本可加载")
	if context_script != null:
		var context = context_script.create(descriptor, {"mode": 2, "room_id": 42})
		_check(context.key == "tetris", "GameContext 记录 key")
		_check(context.mode == 2 and context.room_id == 42, "GameContext 记录启动参数")
		_check(not context.is_online(), "tetris 为单机上下文")
	if result_script != null:
		var result = result_script.win(88, {"combo": 3})
		_check(result.is_win() and result.is_finished() and result.score == 88, "GameResult.win 正常")

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
	print("\n===== 子游戏框架校验：通过 %d 项，失败 %d 项 =====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

## 防止脚本异常导致进程不退出。
func _guard() -> void:
	await create_timer(20.0).timeout
	if _done:
		return
	_done = true
	print("FAIL: 框架校验超时（20s）")
	quit(1)
