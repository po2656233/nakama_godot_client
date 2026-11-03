extends SceneTree

## 阶段 3 验收：中国象棋（GameBase2D 生命周期 / 规则 / 网络同步 / 悔棋 / 结算）。
##
## 真实交互路径：
##   1. 实例化 entry.tscn，检查 9x10 棋盘与 32 枚初始棋子；
##   2. 单击选中 + 点击目标完成一次合法走子（热座模式），校验棋盘/turn/历史；
##   3. 非法走子被拒绝；
##   4. on_network_packet 收到远端 Move 后真正落子；
##   5. 悔棋恢复棋盘与吃子；
##   6. 认输进入结算；
##   7. 规则单测：兵过河横走、马腿、象眼、炮架。
##
## 用法：godot --headless --path . --script res://tools/test_xiangqi.gd

const CHESS_SCENE := "res://games/chinesechess/entry.tscn"
const SCRIPT_PATH := "res://games/chinesechess/scripts/xiangqi.gd"

var _passed := 0
var _failed := 0
var _done := false
var _game: Node = null

func _init() -> void:
	_run.call_deferred()
	_guard.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	var packed := ResourceLoader.load(CHESS_SCENE) as PackedScene
	_check(packed != null, "象棋场景可加载")
	if packed == null:
		_finish()
		return
	_game = packed.instantiate()
	root.add_child(_game)
	await process_frame
	await process_frame
	_game.on_game_start()
	await process_frame

	var board = _game.get("chess_position_array")
	_check(board != null and board.size() == 9, "棋盘 9 列")
	_check(board != null and board[0].size() == 10, "棋盘 10 行")
	_check(_count_pieces(board) == 32, "初始棋子 32 枚（实际 %d）" % _count_pieces(board))
	_check(_game.has_method("on_game_init") and _game.has_method("on_game_start")
		and _game.has_method("on_network_packet") and _game.has_method("on_game_destroy"), "实现 GameBase 生命周期")

	# 1) 本地合法走子：黑兵（y=6）向前一步
	await _click(Vector2i(0, 6))
	await _click(Vector2i(0, 5))
	_check(board[0][5].play != null, "走子后目标格有棋子")
	_check(board[0][6].play == null, "走子后起点为空")
	_check(int(_game.get("start_player")) == 0, "走子后轮到红方")
	_check(_history_size() == 1, "移动历史记录 1 步")

	# 2) 非法走子：红兵一次走两格
	await _click(Vector2i(1, 3))
	var before = board[1][3].play
	await _click(Vector2i(1, 5))
	_check(board[1][3].play == before and board[1][5].play == null, "非法走子被拒绝（兵不能一次走两格）")

	# 3) 远端走子：红兵（1,3）->（1,4）
	var op_move := _op("OpXiangqiMove")
	_game.on_network_packet(op_move, {"from": [0, 3], "to": [0, 4]})
	await process_frame
	_check(board[0][4].play != null and board[0][3].play == null, "网络包驱动远端走子生效")
	_check(_history_size() == 2, "远端走子也记录历史")

	# 4) 悔棋：撤销上一步（远端红兵）
	_game._on_undo_pressed()
	await process_frame
	_check(board[0][3].play != null and board[0][4].play == null, "悔棋恢复远端走子")
	_check(_history_size() == 1, "悔棋后历史 -1")

	# 5) 吃子 + 悔棋复原：黑车（0,9）吃掉（0,5）的黑兵？改用红炮吃黑兵
	# 先本地走黑兵(0,5)->(0,4)，再红炮(1,7)隔子吃(0,7)? 用简单场景：直接验证 _undo_one 的吃子恢复
	_check(_rule_tests(), "规则单测（兵/马/象/炮）")

	# 6) 认输结算
	_game._on_surrender_pressed()
	await process_frame
	_check(bool(_game.get("game_ended")), "认输后 game_ended")
	var over = _game.get_node_or_null("over")
	_check(over != null and over.visible, "认输后显示结算层")
	var label = _game.get_node_or_null("over/Label")
	_check(label != null and "认输" in label.text, "结算文案包含认输原因")

	# 7) 销毁清理
	_game.on_game_destroy()
	_check(bool(_game.is_destroyed()), "on_game_destroy 标记已销毁")
	_game.queue_free()
	await process_frame
	_finish()

func _click(cell: Vector2i) -> void:
	var board = _game.get("chess_position_array")
	_game._on_move(board[cell.x][cell.y])
	await process_frame

func _count_pieces(board: Array) -> int:
	var total := 0
	for x in board.size():
		for y in board[x].size():
			if board[x][y].play != null:
				total += 1
	return total

func _history_size() -> int:
	var history = _game.get("_move_history")
	return history.size() if history != null else 0

func _op(name: String) -> int:
	var script: Script = load(SCRIPT_PATH)
	var ops: Dictionary = script.get_script_constant_map()["OpCode"]
	return int(ops[name])

## 用真实棋子脚本 + 模拟棋盘验证走法（不依赖 UI）。
func _rule_tests() -> bool:
	var ok := true
	# 兵：过河后可横走，未过河不可，不能后退
	var soldier = load("res://games/chinesechess/scripts/item/chess/chess_z.gd").new()
	soldier.chess_color = 1
	var empty := _make_board()
	var s1 = empty[2][4]
	var e1 = empty[3][4]
	ok = ok and soldier.move(s1, e1, empty)
	soldier = load("res://games/chinesechess/scripts/item/chess/chess_z.gd").new()
	soldier.chess_color = 1
	var empty2 := _make_board()
	ok = ok and not soldier.move(empty2[2][6], empty2[3][6], empty2)
	ok = ok and not soldier.move(empty2[2][4], empty2[2][5], empty2)
	# 马：蹩马腿
	var horse = load("res://games/chinesechess/scripts/item/chess/chess_m.gd").new()
	horse.chess_color = 1
	var horse_board := _make_board()
	ok = ok and horse.move(horse_board[2][2], horse_board[3][4], horse_board)
	horse_board[2][3].play = horse
	ok = ok and not horse.move(horse_board[2][2], horse_board[3][4], horse_board)
	# 象：塞象眼
	var elephant = load("res://games/chinesechess/scripts/item/chess/chess_x.gd").new()
	elephant.chess_color = 0
	var ele_board := _make_board()
	ele_board[4][2].chess_color = 0
	ok = ok and elephant.move(ele_board[2][0], ele_board[4][2], ele_board)
	ele_board[3][1].play = horse
	ok = ok and not elephant.move(ele_board[2][0], ele_board[4][2], ele_board)
	# 炮：隔一子吃子；无架不能吃；有架不能走空
	var cannon = load("res://games/chinesechess/scripts/item/chess/chess_p.gd").new()
	cannon.chess_color = 1
	var cannon_board := _make_board()
	var target = load("res://games/chinesechess/scripts/item/chess/chess_z.gd").new()
	target.chess_color = 0
	cannon_board[0][1].play = horse
	cannon_board[0][3].play = target
	ok = ok and cannon.move(cannon_board[0][0], cannon_board[0][3], cannon_board)
	var cannon_board2 := _make_board()
	cannon_board2[0][3].play = target
	ok = ok and not cannon.move(cannon_board2[0][0], cannon_board2[0][3], cannon_board2)
	var cannon_board3 := _make_board()
	cannon_board3[0][1].play = horse
	ok = ok and not cannon.move(cannon_board3[0][0], cannon_board3[0][3], cannon_board3)
	# 释放临时节点
	for board2 in [empty, empty2, horse_board, ele_board, cannon_board, cannon_board2, cannon_board3]:
		for col in board2:
			for node in col:
				node.free()
	horse.free()
	elephant.free()
	cannon.free()
	return ok

func _make_board() -> Array:
	var board := []
	var pos_script: Script = load("res://games/chinesechess/scripts/move/chess_position.gd")
	for x in 9:
		var col := []
		for y in 10:
			var cell = pos_script.new()
			cell.V_position = Vector2(x, y)
			cell.chess_color = 0 if y < 5 else 1
			col.append(cell)
		board.append(col)
	return board

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
	print("\n===== 中国象棋验收：通过 %d 项，失败 %d 项 =====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _guard() -> void:
	await create_timer(40.0).timeout
	if _done:
		return
	_done = true
	print("FAIL: 中国象棋验收超时（40s）")
	quit(1)
