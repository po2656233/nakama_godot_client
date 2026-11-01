extends GameBase

## 模块：俄罗斯方块插件入口（PROMPT_REFACTOR 阶段 4 验收）
## 职责：把本游戏接入 GameBase 生命周期契约，作为插件的生命周期落点。
## 说明：具体玩法仍在 Board / PieceSpawner / UI 等子节点；本脚本只做契约适配。

var started := false
var destroyed := false

func on_game_init(p_room_info: Dictionary, p_bridge: GameHostBridge) -> void:
	super.on_game_init(p_room_info, p_bridge)
	# 本局参数（房间/模式等）由框架注入，子游戏按需读取。
	set_meta("room_id", p_room_info.get("room_id", ""))

func on_game_start() -> void:
	started = true

func on_game_destroy() -> void:
	if destroyed:
		return
	destroyed = true
	# 切断本局私有逻辑：tetris 没有长驻 Timer/Tween，仅停止处理。
	set_process(false)
	super.on_game_destroy()
