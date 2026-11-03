extends GameBase2D

@onready var b_chessposition: Node2D = $b_chessposition
@onready var player_move: Sprite2D = $b_chessposition/player_move

@onready var luozi: AudioStreamPlayer = $luozi
@onready var chi: AudioStreamPlayer = $chi
@onready var cuowu: AudioStreamPlayer = $cuowu
@onready var chessposition: Node2D = $chessposition
@onready var jiangjun_play: AudioStreamPlayer = $jiangjun

@onready var over: CanvasLayer = %over
@onready var label: Label = $over/Label
const proto = preload("res://gdprotobuf/chineseChess.gd")

const chess_qizi = preload("res://games/chinesechess/scenes/move/chess_position.tscn")

const PLAYER_CHESS_C = preload("res://games/chinesechess/scenes/item/chess/chess_c.tscn")
const PLAYER_CHESS_J = preload("res://games/chinesechess/scenes/item/chess/chess_j.tscn")
const PLAYER_CHESS_M = preload("res://games/chinesechess/scenes/item/chess/chess_m.tscn")
const PLAYER_CHESS_P = preload("res://games/chinesechess/scenes/item/chess/chess_p.tscn")
const PLAYER_CHESS_S = preload("res://games/chinesechess/scenes/item/chess/chess_s.tscn")
const PLAYER_CHESS_X = preload("res://games/chinesechess/scenes/item/chess/chess_x.tscn")
const PLAYER_CHESS_Z = preload("res://games/chinesechess/scenes/item/chess/chess_z.tscn")

enum OpCode {
	OpXiangqiGameStart = 2000,               # 象棋游戏开始
	OpXiangqiSelect,				# 选中某个棋子
	OpXiangqiMove,  				# 象棋移动
	OpXiangqiGameEnd,                 # 象棋游戏结束
	OpXiangqiSurrender,               # 象棋投降
	OpXiangqiDraw,                   # 象棋求和
	OpXiangqiDrawAccept,            # 象棋同意求和
	OpXiangqiDrawReject,               # 象棋拒绝求和
	OpXiangqiUndo,                 # 象棋悔棋
	OpXiangqiUndoAccept,            # 象棋同意悔棋
	OpXiangqiUndoReject,             # 象棋拒绝悔棋
	OpXiangqiMoveError,              # 象棋移动错误
}

enum ChessType {
	NONE,
	CHESS_C,  # 车
	CHESS_J,  # 将/帅
	CHESS_M,  # 马
	CHESS_P,  # 炮
	CHESS_S,  # 士
	CHESS_X,  # 象
	CHESS_Z   # 兵/卒
}

var y0 = [1, 3, 6, 5, 2, 5, 6, 3, 1]
var y1 = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var y2 = [0, 4, 0, 0, 0, 0, 0, 4, 0]
var y3 = [7, 0, 7, 0, 7, 0, 7, 0, 7]
var y4 = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var y5 = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var y6 = [7, 0, 7, 0, 7, 0, 7, 0, 7]
var y7 = [0, 4, 0, 0, 0, 0, 0, 4, 0]
var y8 = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var y9 = [1, 3, 6, 5, 2, 5, 6, 3, 1]

var size1: int = 58

var start_player: int = 1
var my_clolor: int = 1 # 0黑 1红
var V_chess: chess_position
var is_waiting_for_opponent: bool = false
var game_ended: bool = false # 游戏是否已结束（绝杀或困毙）

var start_x: int = 0
var start_y: int = 0

var V_CHESS_QIZI: chess_position

var chess_position_array = []
var pre_chess_black: chess_position
var pre_chess_red: chess_position

func _enter_tree():
	if GameHostBridge.current != null:
		GameHostBridge.current.connect_match_state(_on_received_match_state)
	pass

func _ready() -> void:
	add_position()
	add_player_chess()
	jump_to_best_piece_for_player_move()
	_build_hud()
	_hotseat = GameHostBridge.current == null or not GameHostBridge.current.is_online()
	if _hotseat:
		my_clolor = -1
	pass
	

func _on_received_match_state(data: NakamaRTAPI.MatchData) -> void:
	print("象棋游戏接收数据: ", data)
	match data.op_code:
		OpCode.OpXiangqiGameStart:
			gameStart(data.data)	
			return
		OpCode.OpXiangqiSelect:
			gameSelect(data.binary_data)
			return
		OpCode.OpXiangqiMove:
			gameMove(data.binary_data)
			return
	pass
###############################################################################################
func gameStart(data) -> void:
	if data == null:
		return
	var json_conv = JSON.new()
	var error_code = json_conv.parse(data,true)
	if error_code != OK:
		print("Error parsing JSON: " + json_conv.get_error_message(), " --- ", data)
		return
	# GameHostBridge.current.open_settings() 

	# 黑方先走，动画初始在黑方最优棋子上
	var result = json_conv.get_data()
	start_player = result.gameState.current_turn
	var uid = _my_id()
	if uid == result.redPlayer:
		my_clolor = 1
		_message("我方执 黑子, 开启您的征程吧","开局提示",false)
	else:
		my_clolor = 0
		_message("我方执 红子, 请等待黑方先走","开局提示",false)
		
	print("象棋游戏开始 ", result," uid:",uid," my_clolor:",my_clolor)
	pass

func gameSelect(data)->void:
	var resp = proto.ChineseChessSelectResp.new()
	resp.from_bytes(data)
	print("象棋游戏 选中棋子 解析后 ", resp)
	var uid = _my_id()
	print("象棋游戏 选中棋子 当前用户id ", uid, " 移动用户id ", resp.get_userID())
	if uid == resp.get_userID():
		return
	var cell = resp.get_cell()
	var orginX = cell.get_pos().get_row()
	var orginY = cell.get_pos().get_col()
	var orgin = chess_position_array[orginX][orginY]
	# 同步玩家的位置
	player_move.position = orgin.position
	pass

func gameMove(data) -> void:
	#print("象棋游戏移动 ", data)
	var resp = proto.ChineseChessMoveResp.new()
	resp.from_bytes(data)
	print("象棋游戏移动 解析后 ", resp)
	var uid = _my_id()
	print("象棋游戏移动 当前用户id ", uid, " 移动用户id ", resp.get_userID())
	if uid == resp.get_userID():
		return
	var cell = resp.get_cell()
	var orginX = cell.get_pos().get_row()
	var orginY = cell.get_pos().get_col()
	var orgin = chess_position_array[orginX][orginY]
	
	V_chess = orgin
	var toPos = resp.get_toPos()
	var desX = toPos.get_row()
	var desY = toPos.get_col()
	var des = chess_position_array[desX][desY]
	otherMove(des)
	pass



###############################################################################################
func add_position() -> void:
	for x in 9:
		var chess_position_array_ = []
		for y in 10:
			V_CHESS_QIZI = chess_qizi.instantiate()
			chessposition.add_child(V_CHESS_QIZI)
			V_CHESS_QIZI.position = Vector2(x * size1, y * size1)
			V_CHESS_QIZI.V_position = Vector2(x, y)
			V_CHESS_QIZI.connect("move", _on_move)
			
			V_CHESS_QIZI.chess_color = 0
			if y >= 5:
				V_CHESS_QIZI.chess_color = 1
				
			chess_position_array_.append(V_CHESS_QIZI)
		chess_position_array.append(chess_position_array_)
	pass

func add_player_chess() -> void:
	add_player_chess_array(y0)
	add_player_chess_array(y1)
	add_player_chess_array(y2)
	add_player_chess_array(y3)
	add_player_chess_array(y4)
	add_player_chess_array(y5)
	add_player_chess_array(y6)
	add_player_chess_array(y7)
	add_player_chess_array(y8)
	add_player_chess_array(y9)
	pass

func add_player_chess_array(chess: Array) -> void:
	start_x = 0
	for i in chess:
		if i >= 1 and i < 8:
			var results = reture_chess(i)
			b_chessposition.add_child(results)
			results.position = Vector2(start_x * size1, start_y * size1)
			results.change(chess_position_array[start_x][start_y].chess_color)
			chess_position_array[start_x][start_y].play = results
		start_x += 1
	start_y += 1
	pass

# 添加获取棋子类型的方法
func get_chess_type(chess_instance) -> ChessType:
	if chess_instance == null:
		return ChessType.NONE
	if chess_instance is player_chess_c:
		return ChessType.CHESS_C
	elif chess_instance is player_chess_j:
		return ChessType.CHESS_J
	elif chess_instance is player_chess_m:
		return ChessType.CHESS_M
	elif chess_instance is player_chess_p:
		return ChessType.CHESS_P
	elif chess_instance is player_chess_s:
		return ChessType.CHESS_S
	elif chess_instance is player_chess_x:
		return ChessType.CHESS_X
	elif chess_instance is player_chess_z:
		return ChessType.CHESS_Z
	else:
		return ChessType.NONE

# 添加获取棋子名称的方法
func get_chess_name(chess_instance) -> String:
	match get_chess_type(chess_instance):
		ChessType.CHESS_C:
			return "车"
		ChessType.CHESS_J:
			return "将/帅"
		ChessType.CHESS_M:
			return "马"
		ChessType.CHESS_P:
			return "炮"
		ChessType.CHESS_S:
			return "士"
		ChessType.CHESS_X:
			return "象"
		ChessType.CHESS_Z:
			return "兵/卒"
		_:
			return "未知"

func reture_chess(chess: int):
	match chess:
		1:
			return PLAYER_CHESS_C.instantiate()
		2:
			return PLAYER_CHESS_J.instantiate()
		3:
			return PLAYER_CHESS_M.instantiate()
		4:
			return PLAYER_CHESS_P.instantiate()
		5:
			return PLAYER_CHESS_S.instantiate()
		6:
			return PLAYER_CHESS_X.instantiate()
		7:
			return PLAYER_CHESS_Z.instantiate()
	pass

	
func _on_move(chess: chess_position):
	if not _hotseat and start_player != my_clolor:
		_toast("等待对方操作")
		cuowu.play()
		return	
	# 检查游戏是否已结束（绝杀或困毙）
	if game_ended:
		_toast("游戏已结束，请重新开始！")
		cuowu.play()
		return
	
	# 只有当前方才能操作
	if V_chess == null:
		if chess.play != null:
			if chess.play.chess_color == start_player:
				V_chess = chess
				player_move.visible = true
				player_move.position = V_chess.position
				_select_chess(chess)
	elif chess == V_chess:
		pass
	else:
		if chess.play != null:
			if chess.play.chess_color == start_player:
				V_chess = chess
				player_move.visible = true
				player_move.position = V_chess.position
				_select_chess(chess)
			else:
				if V_chess.play == null or not V_chess.play.has_method("move"):
					cuowu.play()
					print("移动---1")
					return
				if is_only_blocker_and_leaving_x(V_chess, chess):
					_toast("该棋子不能横向离开将帅之间的纵线！")
					cuowu.play()
					return
				if is_facing_kings(V_chess, chess):
					_toast("将帅不能面对面！")
					cuowu.play()
					return
				# 先检查移动是否合法
				if V_chess.play.move(V_chess, chess, chess_position_array):
					# 检查移动后是否会导致自己被将军
					if will_cause_self_check(V_chess, chess):
						_toast("被将军!!")
						cuowu.play()
						return
					if chess.play and chess.play.has_method("game_over") and chess.play.game_over():
						game_over()
					_pending_capture_type = int(get_chess_type(chess.play))
					_pending_capture_color = int(chess.play.chess_color)
					chess.play.queue_free()
					_move_end(chess)
					chi.play()
					if is_kings_facing():
						_undo_last_move()
						_toast("将帅面对面了！")
						cuowu.play()
						return
					check_xiangqi_status()
				else:
					cuowu.play()
		else:
			if V_chess.play == null or not V_chess.play.has_method("move"):
				return
			if is_only_blocker_and_leaving_x(V_chess, chess):
				_toast("将帅不能见面！")
				cuowu.play()
				return
			if is_facing_kings(V_chess, chess):
				_toast("将帅不能见面！")
				cuowu.play()
				return
			# 先检查移动是否合法
			if V_chess.play.move(V_chess, chess, chess_position_array):
				# 检查移动后是否会导致自己被将军
				if will_cause_self_check(V_chess, chess):
					_toast("被将军！")
					cuowu.play()
					return
				_move_end(chess)
				luozi.play()
				if is_kings_facing():
					_undo_last_move()
					_toast("将帅不能面对面！")
					cuowu.play()
					return
				check_xiangqi_status()
			else:
				cuowu.play()
	pass



func otherMove(chess: chess_position):
	# 检查游戏是否已结束（绝杀或困毙）
	if game_ended:
		_toast("游戏已结束，请重新开始！")
		cuowu.play()
		return
	

	# 只有当前方才能操作
	if V_chess == null:
		if chess.play != null:
			if chess.play.chess_color == start_player:
				V_chess = chess
				player_move.visible = true
				player_move.position = V_chess.position
	elif chess == V_chess:
		pass
	else:
		if chess.play != null:
			if chess.play.chess_color == start_player:
				V_chess = chess
				player_move.visible = true
				player_move.position = V_chess.position
			else:
				if V_chess.play == null or not V_chess.play.has_method("move"):
					cuowu.play()
					print("移动---1")
					return
				if is_only_blocker_and_leaving_x(V_chess, chess):
					_toast("该棋子不能横向离开将帅之间的纵线！")
					cuowu.play()
					return
				if is_facing_kings(V_chess, chess):
					_toast("将帅不能面对面！")
					cuowu.play()
					return
				# 先检查移动是否合法
				if V_chess.play.move(V_chess, chess, chess_position_array):
					# 检查移动后是否会导致自己被将军
					if will_cause_self_check(V_chess, chess):
						_toast("被将军!!")
						cuowu.play()
						return
					if chess.play and chess.play.has_method("game_over") and chess.play.game_over():
						game_over()
					_pending_capture_type = int(get_chess_type(chess.play))
					_pending_capture_color = int(chess.play.chess_color)
					chess.play.queue_free()
					_move_end(chess)
					chi.play()
					if is_kings_facing():
						_undo_last_move()
						_toast("将帅面对面了！")
						cuowu.play()
						return
					check_xiangqi_status()
				else:
					cuowu.play()
		else:
			if V_chess.play == null or not V_chess.play.has_method("move"):
				return
			if is_only_blocker_and_leaving_x(V_chess, chess):
				_toast("将帅不能见面！")
				cuowu.play()
				return
			if is_facing_kings(V_chess, chess):
				_toast("将帅不能见面！")
				cuowu.play()
				return
			# 先检查移动是否合法
			if V_chess.play.move(V_chess, chess, chess_position_array):
				# 检查移动后是否会导致自己被将军
				if will_cause_self_check(V_chess, chess):
					_toast("被将军！")
					cuowu.play()
					return
				_move_end(chess)
				luozi.play()
				if is_kings_facing():
					_undo_last_move()
					_toast("将帅不能面对面！")
					cuowu.play()
					return
				check_xiangqi_status()
			else:
				cuowu.play()
	pass



# 判断移动是否会导致自己被将军
func will_cause_self_check(from_pos: chess_position, to_pos: chess_position) -> bool:
	if to_pos.play == null:
		return false
	# 保存目标位置的原始棋子
	var original_piece = to_pos.play
	
	# 模拟移动：将棋子从起始位置移动到目标位置
	to_pos.play = from_pos.play
	from_pos.play = null
	
	# 检查移动后是否将帅面对面
	if is_kings_facing():
		# 恢复原始状态
		from_pos.play = to_pos.play
		to_pos.play = original_piece
		return true
	
	# 找到当前玩家的将/帅位置
	var king_pos = find_king_pos(start_player)
	var in_check = false
	
	# 检查对方是否有任何棋子可以攻击到我方将/帅
	if king_pos:
		for x in range(9):
			for y in range(10):
				var pos = chess_position_array[x][y]
				# 如果是对方的棋子
				if pos.play and pos.play.chess_color != start_player:
					# 检查该棋子是否可以攻击到我方将/帅
					if pos.play.move(pos, king_pos, chess_position_array):
						in_check = true
						break
			if in_check:
				break
	
	# 恢复原始状态
	from_pos.play = to_pos.play
	to_pos.play = original_piece
	
	return in_check

func set_pre_move(pre_chess, new_chess):
	if pre_chess:
		V_chess = pre_chess
		player_move.position = pre_chess.position
	pre_chess = new_chess
	pass

func _select_chess(chess:chess_position):
	# 选中棋子协议
	var select_position = chess.V_position
	var select_req = proto.ChineseChessSelectReq.new()
	# 创建并填充 cell（起始格）
	var cell = select_req.new_cell()
	cell.set_piece(get_chess_type(chess.play))
	var select_pos = cell.new_pos() if cell.has_method("new_pos") else cell.get_pos()
	select_pos.set_row(select_position.x)
	select_pos.set_col(select_position.y)
	# 序列化为字节
	var resp = select_req.to_bytes()
	_send_op(OpCode.OpXiangqiSelect, {"from": [select_position.x, select_position.y]})
	pass

func _move_end(chess:chess_position) -> void:
	_push_history_raw(V_chess.V_position, chess.V_position, int(V_chess.play.chess_color), _pending_capture_type, _pending_capture_color)
	_pending_capture_type = 0
	_pending_capture_color = -1
	var to_position = chess.V_position
	var from_position = V_chess.V_position
		
	chess.play = V_chess.play
	V_chess.play = null
	chess.play.position = chess.position
	V_chess = null
	var pre_chess = pre_chess_black if start_player == 0 else pre_chess_red
	if pre_chess:
		V_chess = pre_chess
		player_move.position = pre_chess.position
	pre_chess = chess
	if start_player == 0:
		pre_chess_black = pre_chess
		if pre_chess_red and pre_chess_black.position == pre_chess_red.position:
			pre_chess_red = null
	else:
		pre_chess_red = pre_chess
		if pre_chess_black and pre_chess_black.position == pre_chess_red.position:
			pre_chess_black = null
	if not check_xiangqi_status():
		return
	
	# 发生移动协议
	var move_req = proto.ChineseChessMoveReq.new()
	# 创建并填充 cell（起始格）
	var cell = move_req.new_cell()
	var pos_from = cell.new_pos() if cell.has_method("new_pos") else cell.get_pos()
	cell.set_piece(get_chess_type(chess.play))
	pos_from.set_row(from_position.x)
	pos_from.set_col(from_position.y)
 	# 填充目标位置
	var topos = move_req.new_toPos()
	if topos:
		topos.set_row(to_position.x)
		topos.set_col(to_position.y)
	# 序列化为字节
	var resp = move_req.to_bytes()

	var strChess = JSON.stringify({
		"color": chess.play.chess_color,
		"play": get_chess_type(chess.play),
		"form": from_position,
		"to": to_position,
	})
	print("MOVE  ", strChess," chess_color:", chess.play.chess_color, " my_clolor:", my_clolor)
	if not _hotseat and chess.play.chess_color != my_clolor:
		_toast("请布阵我方棋子！")
		pass
		
	_send_move(from_position, to_position)
	change_player()
	player_move._change_color()
	is_waiting_for_opponent = false
	pass


func change_player() -> void:
	if start_player == 0:
		start_player = 1
	else:
		start_player = 0
	# 始终显示player_move，跳到当前方最优棋子
	jump_to_best_piece_for_player_move()

# player_move动画始终显示，优先上次操作、将/帅、中线兵/卒、再第一个己方棋子
func jump_to_best_piece_for_player_move():
	# 优先跳到上一次操作过的己方棋子
	if start_player == 0 and pre_chess_black and pre_chess_black.play:
		V_chess = pre_chess_black
		player_move.visible = true
		player_move.position = pre_chess_black.position
		return
	if start_player == 1 and pre_chess_red and pre_chess_red.play:
		V_chess = pre_chess_red
		player_move.visible = true
		player_move.position = pre_chess_red.position
		return
	# 跳到中线兵/卒
	var center_x = 4
	for y in range(10):
		var pos = chess_position_array[center_x][y]
		if get_chess_type(pos.play) == ChessType.CHESS_Z and pos.play and pos.play.chess_color == start_player:
			V_chess = pos
			player_move.visible = true
			player_move.position = pos.position
			return
	# 跳到将/帅
	for x in range(9):
		for y in range(10):
			var pos = chess_position_array[x][y]
			if get_chess_type(pos.play) == ChessType.CHESS_J and pos.play and pos.play.chess_color == start_player:
				V_chess = pos
				player_move.visible = true
				player_move.position = pos.position
				return
	
	# 跳到第一个己方棋子
	for x in range(9):
		for y in range(10):
			var pos = chess_position_array[x][y]
			if pos.play and pos.play.chess_color == start_player:
				V_chess = pos
				player_move.visible = true
				player_move.position = pos.position
				return
	# 没有己方棋子
	player_move.visible = false
	V_chess = null
	_toast("已决出胜负")

func game_over() -> void:
	over.visible = true
	_send_op(OpCode.OpXiangqiGameEnd, {"winner": 1 - start_player, "reason": "将死"})
	if start_player == 1:
		label.text = "黑方获胜"
	else:
		label.text = "红方获胜"


func _on_button_button_down() -> void:
	if not restart_game():
		get_tree().reload_current_scene()


func _on_reback_btn_pressed() -> void:
	if GameHostBridge.current != null:
		GameHostBridge.current.request_exit_game()
	else:
		await exit_game()

# 检查"将军""绝杀""困毙"状态
func check_xiangqi_status():
	if is_checkmate(1 - start_player):
		game_ended = true # 设置游戏结束状态
		_toast("绝杀！游戏结束")
		game_over()
		return false
	elif is_check(1 - start_player):
		jiangjun_play.play()
		_toast("将军！", 300)
	elif is_stalemate(1 - start_player):
		game_ended = true # 设置游戏结束状态
		_toast("困毙！游戏结束")
		game_over()
		return false
	return true

# 判断"将帅不能相见"
func is_facing_kings(start_pos, end_pos) -> bool:
	# 找到两个“将/帅”所在列
	var j1 = null
	var j2 = null
	
	for y in range(10):
		for x in range(9):
			var pos = chess_position_array[x][y]
			if get_chess_type(pos.play) == ChessType.CHESS_J:
				if j1 == null:
					j1 = pos
				else:
					j2 = pos
	if j1 and j2 and j1.V_position.x == j2.V_position.x:
		var miny = min(j1.V_position.y, j2.V_position.y)
		var maxy = max(j1.V_position.y, j2.V_position.y)
		var blockers = []
		for y in range(miny + 1, maxy):
			var mid = chess_position_array[j1.V_position.x][y]
			if mid.play:
				blockers.append(mid)
		# 如果只有一个棋子挡在中间，且本次移动是要让它离开该纵轴，则禁止
		if blockers.size() == 1 and blockers[0] == start_pos:
			if end_pos.V_position.x != start_pos.V_position.x:
				return true
		# 其它情况同原逻辑
		if blockers.size() == 0:
			if (start_pos.V_position.x == j1.V_position.x and end_pos.V_position.x == j1.V_position.x and
				((start_pos.V_position.y > miny and start_pos.V_position.y < maxy) or (end_pos.V_position.y > miny and end_pos.V_position.y < maxy))):
				return true
			if (start_pos.V_position.x == j1.V_position.x and start_pos.play and end_pos == j2):
				return true
	return false

# 判断"将军"
func is_check(enemy_color: int) -> bool:
	var king_pos = find_king_pos(enemy_color)
	if not king_pos:
		return false
	# 检查对方棋子是否能攻击到己方将/帅
	var attacker_color = 1 - enemy_color # 攻击方颜色
	for x in range(9):
		for y in range(10):
			var pos = chess_position_array[x][y]
			if pos.play and pos.play.chess_color == attacker_color:
				if pos.play.move(pos, king_pos, chess_position_array):
					return true
	return false

# 判断"绝杀"
func is_checkmate(enemy_color: int) -> bool:
	if not is_check(enemy_color):
		return false

	print("检测绝杀：被将军方颜色=", enemy_color)
	# 检查被将军方是否能通过任何移动解将
	for x in range(9):
		for y in range(10):
			var piece_pos = chess_position_array[x][y]
			if piece_pos.play and piece_pos.play.chess_color == enemy_color:
				for tx in range(9):
					for ty in range(10):
						var target_pos = chess_position_array[tx][ty]
						if piece_pos == target_pos:
							continue # 跳过原地不动

						# 保存原始状态
						var original_piece = piece_pos.play
						var original_target = target_pos.play

						# 检查移动是否合法（不能吃自己的棋子）
						if target_pos.play and target_pos.play.chess_color == enemy_color:
							continue # 不能吃自己的棋子
						
						if not piece_pos.play.move(piece_pos, target_pos, chess_position_array):
							continue # 移动不合法，跳过

						# 模拟移动
						target_pos.play = original_piece
						piece_pos.play = null

						# 检查移动后是否仍然被将军
						var still_in_check = is_check(enemy_color)
						
						# 检查是否造成将帅面对面（这也是不合法的）
						if not still_in_check:
							still_in_check = is_kings_facing()

						# 恢复原始状态
						piece_pos.play = original_piece
						target_pos.play = original_target

						# 如果存在一个移动可以解将，则不是绝杀
						if not still_in_check:
							print("找到解将移动：", piece_pos.V_position, " -> ", target_pos.V_position)
							return false

	# 如果所有可能的移动都不能解将，则为绝杀
	print("绝杀确认：所有移动都无法解将")
	return true

# 判断"困毙"
func is_stalemate(enemy_color: int) -> bool:
	# 困毙：未被将军但无法进行任何合法移动
	if is_check(enemy_color):
		return false
	
	# 检查是否能进行任何合法移动
	for x in range(9):
		for y in range(10):
			var piece_pos = chess_position_array[x][y]
			# 遍历所有当前玩家的棋子
			if piece_pos.play and piece_pos.play.chess_color == enemy_color:
				# 尝试这个棋子的所有可能移动
				for tx in range(9):
					for ty in range(10):
						var target_pos = chess_position_array[tx][ty]
						# 检查是否可以移动到目标位置
						if piece_pos.play.move(piece_pos, target_pos, chess_position_array):
							# 模拟移动
							var original_target = target_pos.play
							target_pos.play = piece_pos.play
							var original_piece = piece_pos.play
							piece_pos.play = null
							
							# 检查移动后是否被将军
							var would_be_in_check = is_check(enemy_color) or is_kings_facing()
							
							# 恢复原状
							piece_pos.play = original_piece
							target_pos.play = original_target
							
							# 如果存在一个合法移动（不会被将军），则不是困毙
							if not would_be_in_check:
								return false
								
	# 如果无法进行任何合法移动，则为困毙
	return true

# 查找“将/帅”位置
func find_king_pos(color: int):
	for x in range(9):
		for y in range(10):
			var pos = chess_position_array[x][y]
			if get_chess_type(pos.play) == ChessType.CHESS_J and pos.play.chess_color == color:
				return pos
	return null

# 检查走子后将帅是否同竖线且中间无子
func is_kings_facing() -> bool:
	var j1 = null
	var j2 = null
	for y in range(10):
		for x in range(9):
			var pos = chess_position_array[x][y]
			if pos.play and get_chess_type(pos.play) == ChessType.CHESS_J:
				if j1 == null:
					j1 = pos
				else:
					j2 = pos
	if j1 and j2 and j1.V_position.x == j2.V_position.x:
		var miny = min(j1.V_position.y, j2.V_position.y)
		var maxy = max(j1.V_position.y, j2.V_position.y)
		var count = 0
		for y in range(miny + 1, maxy):
			if chess_position_array[j1.V_position.x][y].play:
				count += 1
		if count == 0:
			return true
	return false

# 判断是否为将帅之间唯一阻挡棋子且本次移动要离开该纵轴
func is_only_blocker_and_leaving_x(start_pos, end_pos) -> bool:
	var j1 = null
	var j2 = null
	for y in range(10):
		for x in range(9):
			var pos = chess_position_array[x][y]
			if pos.play and get_chess_type(pos.play) == ChessType.CHESS_J:
				if j1 == null:
					j1 = pos
				else:
					j2 = pos
	if j1 and j2 and j1.V_position.x == j2.V_position.x:
		var miny = min(j1.V_position.y, j2.V_position.y)
		var maxy = max(j1.V_position.y, j2.V_position.y)
		var blockers = []
		for y in range(miny + 1, maxy):
			var mid = chess_position_array[j1.V_position.x][y]
			if mid.play:
				blockers.append(mid)
		if blockers.size() == 1 and blockers[0] == start_pos:
			# 本次移动要离开该纵轴
			if end_pos.V_position.x != start_pos.V_position.x:
				return true
	return false

# 撤销上一步（简单实现：只禁止本次走子，实际可扩展为完整悔棋）
func _undo_last_move():
	# 这里只做提示和不切换玩家，实际悔棋可记录历史状态
	change_player()
	is_waiting_for_opponent = false

# 设置player_move到当前方中线兵/卒
func set_player_move_to_center_pawn(color: int):
	var center_x = 4
	var found = false
	# 优先找中线兵/卒
	for y in range(10):
		var pos = chess_position_array[center_x][y]
		if pos.play and pos.play.chess_color == color and get_chess_type(pos.play) == ChessType.CHESS_Z:
			V_chess = pos
			player_move.visible = true
			player_move.position = pos.position
			found = true
			break
	# 若没有中线兵/卒，找第一个己方兵/卒
	if not found:
		for x in range(9):
			for y in range(10):
				var pos = chess_position_array[x][y]
				if pos.play and pos.play.chess_color == color and get_chess_type(pos.play) == ChessType.CHESS_Z:
					V_chess = pos
					player_move.visible = true
					player_move.position = pos.position
					return
	# 若没有兵/卒，找第一个己方棋子
	if not found:
		for x in range(9):
			for y in range(10):
				var pos = chess_position_array[x][y]
				if pos.play and pos.play.chess_color == color:
					V_chess = pos
					player_move.visible = true
					player_move.position = pos.position
					return
	pass


# =====================================================================
# PROMPT_REFACTOR 阶段 3：GameBase2D 生命周期 / 网络 JSON / 结算闭环
# =====================================================================

var _started := false
var _hotseat := false
var _remote_applying := false
var _hud_built := false
var _move_history: Array[Dictionary] = []
var _pending_capture_type := 0
var _pending_capture_color := -1
var _turn_time_left := 60.0
var _timer_label: Label = null
var _pending_dialog: ConfirmationDialog = null

func on_game_init(p_room_info: Dictionary, p_bridge: GameHostBridge) -> void:
	super.on_game_init(p_room_info, p_bridge)
	if p_bridge != null:
		p_bridge.connect_match_state(_on_received_match_state)
	if p_bridge != null and p_bridge.is_online():
		_hotseat = false
		my_clolor = int(p_room_info.get("my_color", my_clolor))
	else:
		_hotseat = true
		my_clolor = -1

func on_game_start() -> void:
	_started = true
	_build_hud()
	_turn_time_left = 60.0
	_update_timer_label()

func on_network_packet(op_code: int, payload: Variant) -> void:
	_handle_network(op_code, payload)

func on_game_destroy() -> void:
	_move_history.clear()
	game_ended = true
	for sound in [luozi, chi, cuowu, jiangjun_play]:
		if sound != null:
			sound.stop()
	super.on_game_destroy()

func _handle_network(op_code: int, payload: Variant) -> void:
	match op_code:
		OpCode.OpXiangqiMove:
			if payload is Dictionary:
				var from = payload.get("from", [])
				var to = payload.get("to", [])
				if from is Array and to is Array and from.size() >= 2 and to.size() >= 2:
					_apply_remote_move(Vector2i(int(from[0]), int(from[1])), Vector2i(int(to[0]), int(to[1])))
			else:
				gameMove(payload)
		OpCode.OpXiangqiSelect:
			if payload is Dictionary:
				var pos = payload.get("from", [])
				if pos is Array and pos.size() >= 2:
					_sync_remote_select(Vector2i(int(pos[0]), int(pos[1])))
		OpCode.OpXiangqiSurrender:
			var color := int(payload.get("color", start_player)) if payload is Dictionary else start_player
			_end_game(1 - color, "对方认输")
		OpCode.OpXiangqiDraw:
			_ask_draw()
		OpCode.OpXiangqiDrawAccept:
			_end_game(-1, "双方和棋")
		OpCode.OpXiangqiDrawReject:
			_toast("对方拒绝和棋")
		OpCode.OpXiangqiUndo:
			_ask_undo()
		OpCode.OpXiangqiUndoAccept:
			_undo_one()
			_toast("对方同意悔棋")
		OpCode.OpXiangqiUndoReject:
			_toast("对方拒绝悔棋")
		OpCode.OpXiangqiGameStart:
			gameStart(payload if payload is String else JSON.stringify(payload))
		_:
			pass

func _apply_remote_move(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if game_ended:
		return
	if from_cell.x < 0 or from_cell.x > 8 or from_cell.y < 0 or from_cell.y > 9:
		return
	if to_cell.x < 0 or to_cell.x > 8 or to_cell.y < 0 or to_cell.y > 9:
		return
	var from_pos := chess_position_array[from_cell.x][from_cell.y] as chess_position
	var to_pos := chess_position_array[to_cell.x][to_cell.y] as chess_position
	if from_pos.play == null:
		return
	if from_pos.play.chess_color != start_player:
		return
	if not from_pos.play.move(from_pos, to_pos, chess_position_array):
		return
	V_chess = from_pos
	if to_pos.play != null:
		_pending_capture_type = int(get_chess_type(to_pos.play))
		_pending_capture_color = int(to_pos.play.chess_color)
		to_pos.play.queue_free()
	var moving_piece := from_pos.play
	var from_global := from_pos.global_position
	_remote_applying = true
	_move_end(to_pos)
	_remote_applying = false
	chi.play() if to_pos.play != null else luozi.play()
	if moving_piece != null and is_instance_valid(moving_piece):
		moving_piece.position = from_pos.position
		var tween := create_tween()
		tween.tween_property(moving_piece, "position", to_pos.position, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _sync_remote_select(cell: Vector2i) -> void:
	if cell.x < 0 or cell.x > 8 or cell.y < 0 or cell.y > 9:
		return
	var pos := chess_position_array[cell.x][cell.y] as chess_position
	if pos.play != null:
		player_move.visible = true
		player_move.position = pos.position

func _push_history_raw(from_cell: Vector2, to_cell: Vector2, color: int, captured_type: int, captured_color: int) -> void:
	_move_history.append({
		"from": from_cell,
		"to": to_cell,
		"color": color,
		"captured_type": captured_type,
		"captured_color": captured_color,
	})

func _undo_one() -> bool:
	if _move_history.is_empty():
		_toast("没有可悔的棋")
		return false
	var record: Dictionary = _move_history.pop_back()
	var from_cell: Vector2 = record["from"]
	var to_cell: Vector2 = record["to"]
	var from_pos := chess_position_array[int(from_cell.x)][int(from_cell.y)] as chess_position
	var to_pos := chess_position_array[int(to_cell.x)][int(to_cell.y)] as chess_position
	var piece = to_pos.play
	if piece == null:
		return false
	to_pos.play = null
	from_pos.play = piece
	piece.position = from_pos.position
	var captured_type := int(record["captured_type"])
	if captured_type != 0:
		var captured = reture_chess(captured_type)
		b_chessposition.add_child(captured)
		captured.position = to_pos.position
		captured.change(int(record["captured_color"]))
		to_pos.play = captured
	start_player = int(record["color"])
	V_chess = null
	game_ended = false
	over.visible = false
	player_move.visible = false
	kick_turn_timer()
	return true

func _on_surrender_pressed() -> void:
	if game_ended:
		return
	if _is_online():
		_send_op(OpCode.OpXiangqiSurrender, {"color": my_clolor})
	_end_game(1 - my_clolor if my_clolor >= 0 else 0, "认输")

func _on_draw_pressed() -> void:
	if game_ended:
		return
	if _is_online():
		_send_op(OpCode.OpXiangqiDraw, {})
		_toast("已向对方发送求和请求")
	else:
		_end_game(-1, "和棋")

func _on_undo_pressed() -> void:
	if game_ended:
		return
	if _is_online():
		_send_op(OpCode.OpXiangqiUndo, {})
		_toast("已向对方发送悔棋请求")
	else:
		_undo_one()

func _ask_draw() -> void:
	_show_confirm("对方请求和棋，是否同意？", func(accepted: bool):
		if accepted:
			if _is_online():
				_send_op(OpCode.OpXiangqiDrawAccept, {})
			_end_game(-1, "双方和棋")
		elif _is_online():
			_send_op(OpCode.OpXiangqiDrawReject, {}))

func _ask_undo() -> void:
	_show_confirm("对方请求悔棋，是否同意？", func(accepted: bool):
		if accepted:
			_undo_one()
			if _is_online():
				_send_op(OpCode.OpXiangqiUndoAccept, {})
		elif _is_online():
			_send_op(OpCode.OpXiangqiUndoReject, {}))

func _show_confirm(text: String, callback: Callable) -> void:
	if _pending_dialog != null and is_instance_valid(_pending_dialog):
		_pending_dialog.queue_free()
	_pending_dialog = ConfirmationDialog.new()
	_pending_dialog.dialog_text = text
	_pending_dialog.title = "对局确认"
	add_child(_pending_dialog)
	_pending_dialog.confirmed.connect(func():
		_pending_dialog.queue_free()
		callback.call(true))
	_pending_dialog.canceled.connect(func():
		_pending_dialog.queue_free()
		callback.call(false))
	_pending_dialog.popup_centered()

func _end_game(winner: int, reason: String) -> void:
	if game_ended:
		return
	game_ended = true
	over.visible = true
	if winner < 0:
		label.text = "和棋（%s）" % reason
	elif winner == 1:
		label.text = "黑方获胜（%s）" % reason
	else:
		label.text = "红方获胜（%s）" % reason
	if _is_online():
		_send_op(OpCode.OpXiangqiGameEnd, {"winner": winner, "reason": reason})

func _send_move(from_cell: Vector2, to_cell: Vector2) -> void:
	if _remote_applying:
		return
	_send_op(OpCode.OpXiangqiMove, {
		"from": [int(from_cell.x), int(from_cell.y)],
		"to": [int(to_cell.x), int(to_cell.y)],
	})

func _send_op(op_code: int, payload: Dictionary) -> void:
	if not _is_online():
		return
	if bridge != null:
		bridge.send_match_data(op_code, payload)

func _is_online() -> bool:
	return bridge != null and bridge.is_online()

func _my_id() -> String:
	if bridge != null:
		return bridge.get_my_id()
	return ""

func _toast(message1: String, speed: float = 100.0) -> void:
	if bridge != null:
		bridge.toast(message1, speed)
	else:
		print("[xiangqi] ", message1)

func _message(text: String, title: String = "提示", auto_close: bool = true) -> void:
	if bridge != null:
		bridge.message(text, title, auto_close)
	else:
		print("[xiangqi] ", title, ": ", text)

func _build_hud() -> void:
	if _hud_built:
		return
	_hud_built = true
	var bar := HBoxContainer.new()
	bar.name = "ChessHud"
	add_child(bar)
	bar.position = Vector2(24, 24)
	var surrender := Button.new()
	surrender.text = "认输"
	surrender.pressed.connect(_on_surrender_pressed)
	bar.add_child(surrender)
	var draw := Button.new()
	draw.text = "求和"
	draw.pressed.connect(_on_draw_pressed)
	bar.add_child(draw)
	var undo := Button.new()
	undo.text = "悔棋"
	undo.pressed.connect(_on_undo_pressed)
	bar.add_child(undo)
	_timer_label = Label.new()
	_timer_label.name = "TurnTimer"
	_timer_label.add_theme_font_size_override("font_size", 24)
	add_child(_timer_label)
	_timer_label.position = Vector2(24, 76)
	_update_timer_label()

func _process(delta: float) -> void:
	if not _started or game_ended:
		return
	_turn_time_left -= delta
	_update_timer_label()
	if _turn_time_left <= 0.0:
		kick_turn_timer()
		change_player()
		_toast("超时，换对方走棋")

func kick_turn_timer() -> void:
	_turn_time_left = 60.0
	_update_timer_label()

func _update_timer_label() -> void:
	if _timer_label == null:
		return
	_timer_label.text = "倒计时 %02d 秒" % int(maxf(0.0, _turn_time_left))