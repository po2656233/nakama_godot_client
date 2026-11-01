extends Node

class_name Board

signal tetromino_locked
signal game_over(int) 

@onready var panel_container = $"../PanelContainer"
@onready var line_scene = preload("res://games/tetris/scenes/line.tscn")

const ROW_COUNT = 20
const COLUMN_COUNT = 10
var score = 0
var next_tetromino
var tetrominos: Array[Tetromino] = []
@export var tetromino_scene: PackedScene

func spawn_tetromino(type: TetrisTypes.Tetromino, is_next_piece, spawn_position):
	var tetromino_data = TetrisShared.shared().data[type]
	var tetromino = tetromino_scene.instantiate() as Tetromino
	
	tetromino.tetromino_data = tetromino_data
	tetromino.is_next_piece = is_next_piece
	
	if is_next_piece == false:
		var other_pieces = get_all_pieces()
		tetromino.position = tetromino_data.spawn_position
		tetromino.other_tetrominoes_pieces = other_pieces
		add_child(tetromino)
		tetromino.lock_tetromino.connect(on_tetromino_locked)
	else: 
		tetromino.scale = Vector2(0.5, 0.5)
		panel_container.add_child(tetromino)
		tetromino.set_position(spawn_position)
		next_tetromino = tetromino
		next_tetromino.on_change_score(score)
		

func on_tetromino_locked(tetromino: Tetromino):
	next_tetromino.queue_free()
	tetrominos.append(tetromino)
	add_tetromino_to_lines(tetromino)
	remove_full_lines()
	tetromino_locked.emit()
	check_game_over()

	
func check_game_over():
		for piece in get_all_pieces():
			var y_location = piece.global_position.y
			if y_location == -456:
				game_over.emit(score)
	
func add_tetromino_to_lines(tetromino: Tetromino):
	var tetromino_pieces = tetromino.get_children().filter(func (c): return c is Piece)
	for piece in tetromino_pieces:
		var y_position = piece.global_position.y
		var does_line_for_piece_exists = false
		for line in get_lines():
			if line.global_position.y == y_position:
				piece.reparent(line)
				does_line_for_piece_exists = true
		if !does_line_for_piece_exists:
			var piece_line = line_scene.instantiate() as Line
			piece_line.global_position = Vector2(0, y_position)
			add_child(piece_line)
			piece.reparent(piece_line)

func get_lines():
	return get_children().filter(func (c): return c is Line)

func remove_full_lines():
	var row = 0
	var cell = 0
	for line in get_lines():
		if line.is_line_full(COLUMN_COUNT):
			move_lines_down(line.global_position.y)
			row+=1
			line.free()
	if row == 1:
		cell = 10
	elif row == 2:
		cell = 30
	elif row == 3:
		cell = 60
	elif row == 4:
		cell = 100
	score += cell
	if 0 < row:
		%ScoreLabel.set_text("SCORE:"+ String.num(score))
		pass
	
		
		
func move_lines_down(y_position):
	for line in get_lines():
		if line.global_position.y < y_position:
			line.global_position.y += 48

func get_all_pieces():
	var pieces = []
	for line in get_lines():
		pieces.append_array(line.get_children())
	return pieces
