extends GameBase2D

## 模块：子游戏模板（复制 games/template 整个目录后改名）
## 职责：演示如何接入 GameContext、上报结算、退出与重开。
## 使用：
##   1. 复制 games/template 为 games/<key>/；
##   2. entry.tscn 根节点挂本脚本；
##   3. game_meta.tres 填 key/title/entry_scene（入口固定 entry.tscn）；
##   4. 在游戏列表/房间流程里用 GameBridge.current.restart("<key>") 启动。

func on_game_launched(context: GameContext) -> void:
	print("[TemplateGame] 启动: %s, 人数上限: %s, 联机: %s" % [
		context.key,
		context.get_option("max_players", 1),
		context.is_online(),
	])
	# TODO: 在这里开始第一局、播放 BGM、初始化棋盘等。

func on_game_result(result: GameResult) -> void:
	print("[TemplateGame] 结算: %s, 得分: %d" % [result.outcome_name(), result.score])
	# TODO: 展示结算面板；需要回大厅时调用 await exit_game(result)。

func on_game_exit(_result: GameResult) -> void:
	# TODO: 停止音效、计时器、网络监听。
	pass

## 示例：本地一局结束
func _on_local_game_over(score: int) -> void:
	finish_game(GameResult.win(score))

## 示例：重开
func _on_restart_pressed() -> void:
	restart_game()

## 示例：返回
func _on_exit_pressed() -> void:
	await exit_game()
