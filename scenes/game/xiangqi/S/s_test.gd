extends Node2D

@onready var b_chessposition: Node2D = $b_chessposition
@onready var player_move: Sprite2D = $b_chessposition/player_move

@onready var luozi: AudioStreamPlayer = $luozi
@onready var chi: AudioStreamPlayer = $chi
@onready var cuowu: AudioStreamPlayer = $cuowu
@onready var chessposition: Node2D = $chessposition
@onready var jiangjun_play: AudioStreamPlayer = $jiangjun

@onready var over: CanvasLayer = %over
@onready var label: Label = $over/Label

const CHESS_POSITION = preload("res://scenes/game/xiangqi/M/chess_position.tscn")

const PLAYER_CHESS_C = preload("res://scenes/game/xiangqi/I/player_chess/_/player_chess_c.tscn")
const PLAYER_CHESS_J = preload("res://scenes/game/xiangqi/I/player_chess/_/player_chess_j.tscn")
const PLAYER_CHESS_M = preload("res://scenes/game/xiangqi/I/player_chess/_/player_chess_m.tscn")
const PLAYER_CHESS_P = preload("res://scenes/game/xiangqi/I/player_chess/_/player_chess_p.tscn")
const PLAYER_CHESS_S = preload("res://scenes/game/xiangqi/I/player_chess/_/player_chess_s.tscn")
const PLAYER_CHESS_X = preload("res://scenes/game/xiangqi/I/player_chess/_/player_chess_x.tscn")
const PLAYER_CHESS_Z = preload("res://scenes/game/xiangqi/I/player_chess/_/player_chess_z.tscn")

var y0=[1,3,6,5,2,5,6,3,1]
var y1=[0,0,0,0,0,0,0,0,0]
var y2=[0,4,0,0,0,0,0,4,0]
var y3=[7,0,7,0,7,0,7,0,7]
var y4=[0,0,0,0,0,0,0,0,0]
var y5=[0,0,0,0,0,0,0,0,0]
var y6=[7,0,7,0,7,0,7,0,7]
var y7=[0,4,0,0,0,0,0,4,0]
var y8=[0,0,0,0,0,0,0,0,0]
var y9=[1,3,6,5,2,5,6,3,1]

var size1:int=58

var start_player:int=1
var V_chess:chess_position
var is_waiting_for_opponent: bool = false
var game_ended: bool = false  # 游戏是否已结束（绝杀或困毙）

var start_x:int=0
var start_y:int=0

var V_CHESS_POSITION:chess_position

var chess_position_array=[]
var pre_chess_black:chess_position
var pre_chess_red:chess_position




func _ready() -> void:
	# SettingsManager.show_settings() 
	add_position()
	add_player_chess()
	# 黑方先走，动画初始在黑方最优棋子上
	start_player = 1
	jump_to_best_piece_for_player_move()
	
func add_position()->void:
	for x in 9:
		var chess_position_array_=[]
		for y in 10:
			V_CHESS_POSITION=CHESS_POSITION.instantiate()
			chessposition.add_child(V_CHESS_POSITION)
			V_CHESS_POSITION.position=Vector2(x*size1,y*size1)
			V_CHESS_POSITION.V_position=Vector2(x,y)
			V_CHESS_POSITION.connect("move",move)
			if y>=5:
				V_CHESS_POSITION.chess_color=1
			chess_position_array_.append(V_CHESS_POSITION)
		chess_position_array.append(chess_position_array_)
	pass

func add_player_chess()->void:
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

func add_player_chess_array(chess:Array)->void:
	start_x=0
	for i in chess:
		if i>=1 and i<8:
			var results=reture_chess(i-1)
			b_chessposition.add_child(results)
			results.position=Vector2(start_x*size1,start_y*size1)
			results.change(chess_position_array[start_x][start_y].chess_color)
			chess_position_array[start_x][start_y].play=results
		start_x+=1
	start_y+=1
	pass

func reture_chess(chess:int):
	match chess:
		0:
			return PLAYER_CHESS_C.instantiate()
		1:
			return PLAYER_CHESS_J.instantiate()
		2:
			return PLAYER_CHESS_M.instantiate()
		3:
			return PLAYER_CHESS_P.instantiate()
		4:
			return PLAYER_CHESS_S.instantiate()
		5:
			return PLAYER_CHESS_X.instantiate()
		6:
			return PLAYER_CHESS_Z.instantiate()
	pass


func move(chess:chess_position):
	# 检查游戏是否已结束（绝杀或困毙）
	if game_ended:
		PopupManager.show_dynamic("游戏已结束，请重新开始！")
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
					PopupManager.show_dynamic("该棋子不能横向离开将帅之间的纵线！")
					cuowu.play()
					return
				if is_facing_kings(V_chess, chess):
					PopupManager.show_dynamic("将帅不能面对面！")
					cuowu.play()
					return
				# 先检查移动是否合法
				if V_chess.play.move(V_chess, chess, chess_position_array):
					# 检查移动后是否会导致自己被将军
					if will_cause_self_check(V_chess, chess):
						PopupManager.show_dynamic("被将军!!")
						cuowu.play()
						return
					if chess.play and chess.play.has_method("game_over") and chess.play.game_over():
						game_over()
					chess.play.queue_free()
					_move_end(chess)
					chi.play()
					if is_kings_facing():
						_undo_last_move()
						PopupManager.show_dynamic("将帅面对面了！")
						cuowu.play()
						return
					check_xiangqi_status()
				else:
					cuowu.play()
		else:
			if V_chess.play == null or not V_chess.play.has_method("move"):
				return
			if is_only_blocker_and_leaving_x(V_chess, chess):
				PopupManager.show_dynamic("将帅不能见面！")
				cuowu.play()
				return
			if is_facing_kings(V_chess, chess):
				PopupManager.show_dynamic("将帅不能见面！")
				cuowu.play()
				return
			# 先检查移动是否合法
			if V_chess.play.move(V_chess, chess, chess_position_array):
				# 检查移动后是否会导致自己被将军
				if will_cause_self_check(V_chess, chess):
					PopupManager.show_dynamic("被将军！")
					cuowu.play()
					return
				_move_end(chess)
				luozi.play()
				if is_kings_facing():
					_undo_last_move()
					PopupManager.show_dynamic("将帅不能面对面！")
					cuowu.play()
					return
				check_xiangqi_status()
			else:
				cuowu.play()
	pass


# 判断移动是否会导致自己被将军
func will_cause_self_check(from_pos: chess_position, to_pos: chess_position) -> bool:
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

func set_pre_move(pre_chess,new_chess):
	if pre_chess:
		V_chess = pre_chess
		player_move.position = pre_chess.position
	pre_chess = new_chess
	pass


func _move_end(chess:chess_position)->void:
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
	change_player()
	player_move._change_color()
	is_waiting_for_opponent = false


func change_player()->void:
	if start_player==0:
		start_player=1
	else:
		start_player=0
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
		if pos.play and pos.play.chess_color == start_player and (pos.play is player_chess_z):
			V_chess = pos
			player_move.visible = true
			player_move.position = pos.position
			return
	# 跳到将/帅
	for x in range(9):
		for y in range(10):
			var pos = chess_position_array[x][y]
			if pos.play and (pos.play is player_chess_j) and pos.play.chess_color == start_player:
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
	PopupManager.show_dynamic("已决出胜负")

func game_over()->void:
	over.visible=true
	if start_player==1:
		label.text="黑方获胜"
	else :
		label.text="红方获胜"


func _on_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/game/xiangqi/S/s_test.tscn")


func _on_reback_btn_pressed() -> void:
	SceneManager.go_back()
	# queue_free()
	
	pass # Replace with function body.

# 检查"将军""绝杀""困毙"状态
func check_xiangqi_status():
	if is_checkmate(1-start_player):
		game_ended = true  # 设置游戏结束状态
		PopupManager.show_dynamic("绝杀！游戏结束")
		game_over()
		return false
	elif is_check(1-start_player):
		jiangjun_play.play()
		PopupManager.show_dynamic("将军！", 300)
	elif is_stalemate(1-start_player):
		game_ended = true  # 设置游戏结束状态
		PopupManager.show_dynamic("困毙！游戏结束")
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
			if pos.play and (pos.play is player_chess_j):
				if j1 == null:
					j1 = pos
				else:
					j2 = pos
	if j1 and j2 and j1.V_position.x == j2.V_position.x:
		var miny = min(j1.V_position.y, j2.V_position.y)
		var maxy = max(j1.V_position.y, j2.V_position.y)
		var blockers = []
		for y in range(miny+1, maxy):
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
func is_check(enemy_color:int) -> bool:
	var king_pos = find_king_pos(enemy_color)
	if not king_pos:
		return false
	# 检查对方棋子是否能攻击到己方将/帅
	var attacker_color = 1 - enemy_color  # 攻击方颜色
	for x in range(9):
		for y in range(10):
			var pos = chess_position_array[x][y]
			if pos.play and pos.play.chess_color == attacker_color:
				if pos.play.move(pos, king_pos, chess_position_array):
					return true
	return false

# 判断"绝杀"
func is_checkmate(enemy_color:int) -> bool:
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
							continue  # 跳过原地不动

						# 保存原始状态
						var original_piece = piece_pos.play
						var original_target = target_pos.play

						# 检查移动是否合法（不能吃自己的棋子）
						if target_pos.play and target_pos.play.chess_color == enemy_color:
							continue  # 不能吃自己的棋子
						
						if not piece_pos.play.move(piece_pos, target_pos, chess_position_array):
							continue  # 移动不合法，跳过

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
func is_stalemate(enemy_color:int) -> bool:
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
func find_king_pos(color:int):
	for x in range(9):
		for y in range(10):
			var pos = chess_position_array[x][y]
			if pos.play and (pos.play is player_chess_j) and pos.play.chess_color == color:
				return pos
	return null

# 检查走子后将帅是否同竖线且中间无子
func is_kings_facing() -> bool:
	var j1 = null
	var j2 = null
	for y in range(10):
		for x in range(9):
			var pos = chess_position_array[x][y]
			if pos.play and (pos.play is player_chess_j):
				if j1 == null:
					j1 = pos
				else:
					j2 = pos
	if j1 and j2 and j1.V_position.x == j2.V_position.x:
		var miny = min(j1.V_position.y, j2.V_position.y)
		var maxy = max(j1.V_position.y, j2.V_position.y)
		var count = 0
		for y in range(miny+1, maxy):
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
			if pos.play and (pos.play is player_chess_j):
				if j1 == null:
					j1 = pos
				else:
					j2 = pos
	if j1 and j2 and j1.V_position.x == j2.V_position.x:
		var miny = min(j1.V_position.y, j2.V_position.y)
		var maxy = max(j1.V_position.y, j2.V_position.y)
		var blockers = []
		for y in range(miny+1, maxy):
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
func set_player_move_to_center_pawn(color:int):
	var center_x = 4
	var found = false
	# 优先找中线兵/卒
	for y in range(10):
		var pos = chess_position_array[center_x][y]
		if pos.play and pos.play.chess_color == color and (pos.play is player_chess_z):
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
				if pos.play and pos.play.chess_color == color and (pos.play is player_chess_z):
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
