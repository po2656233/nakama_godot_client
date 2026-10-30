extends GameBase2D

var board_size = Vector2(17,8)
var piece_types = 34
var per_piece_count = 4
var pieceSize = Vector2(50, 65)

var show_board_size = Vector2(8,17)

var total_count = board_size.x * board_size.y
var achieve_count = 0
var remain_count = total_count

var achieve_list = []

var prefab_mahjong = preload("res://scenes/game/mahjong_matching/prefabs/prefab_mahjong.tscn")
var prefab_mahjong_show = preload("res://scenes/game/mahjong_matching/prefabs/prefab_resultmahjong.tscn")
var last_clicked_piece = null

#棋盘的二维数组
var board = []
var boardNodes = []

# match一次之后才能继续平移
var hasMatched = true
var lastMoveDir

# Called when the node enters the scene tree for 	the first time.
func _ready():
	$BgmPlayer.play()

	start_new_game()
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func start_new_game():
	#初始化棋盘
	#把棋盘上的所有牌都清除掉
	for child in $UI.get_node("achieveBoxContainer").get_children():
		child.queue_free()
	for child in $Board.get_children():
		child.queue_free()
	initialize_board()
	refresh_achieve_info()
	hasMatched = true #默认状态可以移动

func refresh_achieve_info():
	$UI.get_node("achieveCount").text = str(achieve_count)
	$UI.get_node("remainCount").text = str(remain_count)
	# 更新已收集的牌
	for i in range(achieve_list.size()):
		var piece = achieve_list[i]
		var piece_node = $UI.get_node("achieveBoxContainer").get_node(str(i))
		if piece_node == null:
			piece_node = prefab_mahjong_show.instantiate()
			piece_node.name = str(i)
			$UI.get_node("achieveBoxContainer").add_child(piece_node)
			#从下往上，从左往右排列
			piece_node.position = Vector2(i % int(show_board_size.x) * 50, floor(show_board_size.y - (i+1) / show_board_size.x) * 65)
			piece_node.set_piece(piece)

	if remain_count == 0:
		$UI.get_node("GameEnd").visible = true

func initialize_board():
	achieve_count = 0
	remain_count = total_count
	achieve_list = []
	board = []
	boardNodes = []
	last_clicked_piece = null

	var pieces = []
	for i in range(piece_types):
		for j in range(per_piece_count):
			pieces.append(i+1)
	#打乱牌的顺序
	for i in range(pieces.size()):
		var random = randi() % pieces.size()
		var temp = pieces[i]
		pieces[i] = pieces[random]
		pieces[random] = temp

	for i in range(board_size.x):
		var row = []
		for j in range(board_size.y):
			var piece = pieces[i * board_size.y + j]
			row.append(piece)
		board.append(row)
	# 打印棋盘，用于调试
	print_board()
	# 更新棋盘
	for xIndex in range(board_size.x):
		var colNodes = []
		for yIndex in range(0, board_size.y):
			var piece = board[xIndex][yIndex]
			var piece_node = prefab_mahjong.instantiate()
			var strName = str(xIndex) + "_" + str(yIndex)
			piece_node.name = strName
			#放到最下面，不然会被覆盖
			$Board.add_child(piece_node)
			piece_node.set_piece(piece)
			piece_node.set_cur_pos(xIndex, yIndex)
			piece_node.reset_moving(pieceSize)
			piece_node.piece_clicked.connect(_on_piece_click)
			
			colNodes.append(piece_node)
		boardNodes.append(colNodes)
	
	reset_all_z_index()
	pass

func print_board():
	for i in range(board_size.x):
		var row = ""
		for j in range(board_size.y):
			row += str(board[i][j]) + " "
		print(row)
	pass

func _remove_piece_from_board(piece):
	boardNodes[piece.xIndex][piece.yIndex] = null

func _on_piece_click(piece):
	if piece == last_clicked_piece:
		last_clicked_piece.set_selected(false)
		last_clicked_piece = null
		return
	if last_clicked_piece != null and are_adjacent(last_clicked_piece, piece):
		# 如果两个PieceNode相邻，检查数值是否相等
		if last_clicked_piece.piece == piece.piece:
			achieve_list.append(last_clicked_piece.piece)
			achieve_list.append(piece.piece)
			
			_remove_piece_from_board(last_clicked_piece)
			_remove_piece_from_board(piece)
			
			achieve_count += 2
			remain_count -= 2
			# 如果数值相等，消除两个PieceNode
			last_clicked_piece.queue_free()
			piece.queue_free()
			refresh_achieve_info()
			$SE.get_node("MergePlayer").play()
			
			hasMatched = true
	if last_clicked_piece != null:
		last_clicked_piece.set_selected(false)
	piece.set_selected(true)
	last_clicked_piece = piece
	var random = randi() % 6 + 1
	$SE.get_node("ClickPlayer1").play()

func are_adjacent(piece1, piece2):
	if piece1.xIndex != piece2.xIndex and piece1.yIndex != piece2.yIndex:
		return false
	
	var count = 0
	#实际上只有一个循环有效
	for xInd in range(min(piece1.xIndex, piece2.xIndex), max(piece1.xIndex, piece2.xIndex)+1):
		for yInd in range(min(piece1.yIndex, piece2.yIndex), max(piece1.yIndex, piece2.yIndex)+1):
			if boardNodes[xInd][yInd] != null:
				count += 1
	
	return count <= 2

func reset_all_moving():
	for child in $Board.get_children():
		if child.moving:
			child.reset_moving(pieceSize)

func reset_all_z_index(bHorizon = true):
	for child in $Board.get_children():
		child.set_cur_z_index(pieceSize, board_size, bHorizon)

func get_move_list(xIndex, yIndex, direction):
	var ret = []
	for i in range(1, max(board_size.x, board_size.y)+1):
		var tmpX = xIndex - direction.x * i
		var tmpY = yIndex - direction.y * i
		if tmpX < 0 or tmpX >= board_size.x or tmpY < 0 or tmpY >= board_size.y:
			break
		
		if boardNodes[tmpX][tmpY] != null:
			ret.append(boardNodes[tmpX][tmpY])
		else:
			break
	ret.append(boardNodes[xIndex][yIndex])
	for i in range(1, max(board_size.x, board_size.y)+1):
		var tmpX = xIndex + direction.x * i
		var tmpY = yIndex + direction.y * i
		if tmpX < 0 or tmpX >= board_size.x or tmpY < 0 or tmpY >= board_size.y:
			break
		
		if boardNodes[tmpX][tmpY] != null:
			ret.append(boardNodes[tmpX][tmpY])
		else:
			break
	for piece in ret:
		piece.moving = true
	return ret

func get_move_range(piece, direction):
	var xIndex = piece.xIndex
	var yIndex = piece.yIndex
	
	for i in range(1, max(board_size.x, board_size.y)+1):
		var tmpX = xIndex + direction.x * i
		var tmpY = yIndex + direction.y * i
		
		if tmpX < 0 or tmpX >= board_size.x or tmpY < 0 or tmpY >= board_size.y or boardNodes[tmpX][tmpY] != null:
			var offset = (abs(tmpX - xIndex) + abs(tmpY - yIndex) - 1) * (pieceSize.x * direction.x + pieceSize.y * direction.y)
			return [min(0, offset), max(0, offset)]

func check_moveable(xIndex, yIndex, direction):
	if not hasMatched:
		return false
	return true	
#	xIndex = xIndex - direction.x
#	yIndex = yIndex - direction.y
#
#	if xIndex < 0 or xIndex >= board_size.x or yIndex < 0 or yIndex >= board_size.y or boardNodes[xIndex][yIndex] == null:
#		return true
#	return false

func update_move_pos(xIndex, yIndex, drag_distance):
	var normal_distance
	var direction
	if abs(drag_distance.x) > abs(drag_distance.y):
		normal_distance = Vector2(drag_distance.x, 0)
		direction = Vector2(1 if drag_distance.x > 0 else -1, 0)
	else:
		normal_distance = Vector2(0, drag_distance.y)
		direction = Vector2(0, 1 if drag_distance.y > 0 else -1)
	
	if direction != lastMoveDir:
		reset_all_moving()
	if !lastMoveDir or lastMoveDir.x * direction.x == 0:
		reset_all_z_index(direction.x != 0)
	lastMoveDir = direction
	
	if not check_moveable(xIndex, yIndex, direction):
		return
	
	var move_list = get_move_list(xIndex, yIndex, direction)
	var move_range = get_move_range(move_list[move_list.size()-1], direction)
	
	var clamp_offset
	if normal_distance.x != 0:
		clamp_offset = Vector2(clamp(normal_distance.x, move_range[0], move_range[1]), 0)
	else:
		clamp_offset = Vector2(0, clamp(normal_distance.y, move_range[0], move_range[1]))
	
	for piece in move_list:
		piece.set_offset(pieceSize, clamp_offset)
		piece.set_cur_z_index(pieceSize, board_size, direction.x != 0)

func set_afterdrag_pos():
	var move_list = []
	for piece in $Board.get_children():
		if piece.moving:
			move_list.append(piece)
			boardNodes[piece.xIndex][piece.yIndex] = null
	for piece in move_list:
		var newXIndex = floor((piece.position.x + pieceSize.x/2)/pieceSize.x)
		var newYIndex = floor((piece.position.y + pieceSize.y/2)/pieceSize.y)
		
		if newXIndex!=piece.xIndex or newYIndex!=piece.yIndex:
			#hasMatched = false
			pass
		
		piece.set_cur_pos(newXIndex, newYIndex)
		piece.reset_moving(pieceSize)
		boardNodes[piece.xIndex][piece.yIndex] = piece
	
	reset_all_z_index()
	lastMoveDir = null

