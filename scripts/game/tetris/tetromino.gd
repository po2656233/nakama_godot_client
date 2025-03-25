extends Node2D

class_name Tetromino

signal lock_tetromino(tetromino: Tetromino)

var bounds = {
	"min_x": -216,
	"max_x": 216,
	"max_y": 457
}

var rotation_index = 0
var wall_kicks
var tetromino_data
var is_next_piece
var pieces = []
var other_tetrominoes_pieces = [] 
var ghost_tetromino

@onready var timer = $Timer
@onready var piece_scene = preload("res://scenes/game/tetris/piece.tscn")
@onready var ghost_tetromino_scene = preload("res://scenes/game/tetris/ghost_tetromino.tscn")

var tetromino_cells

# 定义滑动的阈值
const SWIPE_THRESHOLD = 10.0
# 记录触摸开始的位置
var touch_start_position: Vector2
# 上一次触摸的位置
var touch_last_position: Vector2
# 定义双击的时间间隔（毫秒）
const DOUBLE_CLICK_TIME = 300
# 记录上一次触摸的时间
var last_touch_time: float = 0.0

# 记录触摸路径的点 检测是否画了半弧形
var touch_path: Array = []
var is_drawing: bool = false

# 
var rate_speed: float = 1.0

func _ready():
	tetromino_cells = Shared.cells[tetromino_data.tetromino_type]
	touch_start_position = Vector2(get_viewport().size.x / 2, 0)
	touch_last_position = Vector2.ZERO
	for cell in tetromino_cells:
		var piece = piece_scene.instantiate() as Piece
		pieces.append(piece)
		add_child(piece)
		piece.set_texture(tetromino_data.piece_texture)
		piece.position = cell * piece.get_size()
	
	if is_next_piece == false:
		position = tetromino_data.spawn_position	
		wall_kicks = Shared.wall_kicks_i if tetromino_data.tetromino_type == Shared.Tetromino.I else Shared.wall_kicks_jlostz
		ghost_tetromino = ghost_tetromino_scene.instantiate() as GhostTetromino
		ghost_tetromino.tetromino_data = tetromino_data
		get_tree().root.add_child.call_deferred(ghost_tetromino)
		hard_drop_ghost.call_deferred()
	else: 
		timer.stop()
		set_process_input(false)


func on_change_score(score: int):
	if score < 1000:
		rate_speed = 1.0
	elif score < 2000 :
		rate_speed = 0.8
	elif score < 4000:
		rate_speed = 0.6
	elif score < 6000:
		rate_speed = 0.4
	elif score < 8000:
		rate_speed = 0.2
	else:
		rate_speed = 0.1
	timer.set_wait_time(rate_speed)
	
func hard_drop_ghost():
	var final_hard_drop_position
	var ghost_position_update = calculate_global_position(Vector2.DOWN, global_position)
	
	while ghost_position_update != null:
		ghost_position_update = calculate_global_position(Vector2.DOWN, ghost_position_update)
		if ghost_position_update != null:
			final_hard_drop_position = ghost_position_update
	
	if final_hard_drop_position != null:
		var children = get_children().filter(func (c): return c is Piece)
		
		var pieces_position = []
		
		for i in children.size():
			var piece_position = children[i].position
			pieces_position.append(piece_position)
		
		ghost_tetromino.set_ghost_tetromino(final_hard_drop_position, pieces_position)
	
	return final_hard_drop_position

func _draw() -> void:
	# 绘制触摸路径
	if touch_path.size() > 1:
		for i in range(touch_path.size() - 1):
			draw_line(touch_path[i], touch_path[i + 1], Color(1, 0, 0), 2)

func _input(event):
	 # 检测触摸事件
	var left = false
	var right = false
	var up = false
	var down = false
	if event is InputEventScreenTouch:
		if event.is_pressed():
		# 当触屏开始时，记录触点位置
			touch_start_position = event.position
			timer.set_wait_time(0.1)
			#return
		elif event.is_released():
			timer.set_wait_time(rate_speed)
			#是否双击
			var current_time = Time.get_ticks_msec() / 1000.0 # 获取当前时间（秒）
			if current_time - last_touch_time <= DOUBLE_CLICK_TIME / 1000.0 and touch_start_position == event.position:
				hard_drop()
				print('双击完成')
				return
			last_touch_time = current_time # 更新上一次触摸时间
			# 当触屏结束时，计算移动方向
			var touch_end_position = event.position
			var direction = touch_end_position - touch_start_position
			if direction.y < -60  :
				up = true
			#elif direction.y > 0:
				#down = true
			elif direction.x < 0:
				# 如果触屏从右向左移动
				#move_left()
				left = true
			elif direction.x > 0:
				right = true
		#return
	#elif event is InputEventScreenDrag and not event.is_pressed():
		# 当触屏结束时，计算移动方向
		#var touch_end_position = event.position
		#var direction = touch_end_position - touch_start_position
		#if direction.x < 0:
				## 如果触屏从右向左移动
				##move_left()
			#left = true
		#elif direction.x > 0:
			#right = true
		#elif direction.y < 0:
			#up = true
		#elif direction.y > 0:
			#down = true
		#else:
			#return
				# 如果触屏从左向右移动
				#move_right()
	if Input.is_action_just_pressed("ui_left") or left:
		move(Vector2.LEFT)
	elif Input.is_action_just_pressed("ui_right")or right:
		move(Vector2.RIGHT)
	elif Input.is_action_just_pressed("ui_down") :
		move(Vector2.DOWN)
	elif Input.is_action_just_pressed("hard_drop"):
		hard_drop()
	elif Input.is_action_just_pressed("ui_up")or down:
		rotate_tetromino(-1)
	elif up:
		rotate_tetromino(1)

func is_half_arc(points: Array) -> bool:
	if points.size() < 3:
		return false # 至少需要三个点来判断

	# 计算起始点和结束点的距离
	var start_point = points[0]
	var end_point = points[points.size() - 1]

	# 计算中间点的 Y 坐标
	var mid_point = points[floor(points.size()/2.0)]

	# 判断中间点是否在起始点和结束点的上方
	if mid_point.y < start_point.y and mid_point.y < end_point.y:
		return true
	return false
	

			
func move(direction: Vector2) -> bool:
	var new_position = calculate_global_position(direction, global_position)
	if new_position:
		global_position = new_position
		if direction != Vector2.DOWN:
			hard_drop_ghost.call_deferred()
		return true
	return false
	
func calculate_global_position(direction: Vector2, starting_global_position: Vector2):
	#TODO: check for collision with other tetrominos
	#print_debug(is_colliding_with_other_tetrominos(direction, starting_global_position))
	if is_colliding_with_other_tetrominos(direction, starting_global_position):
		return null
	#TODO: check for collision with game bounds
	if !is_within_game_bounds(direction, starting_global_position):
		return null
	return starting_global_position + direction * pieces[0].get_size().x

func is_within_game_bounds(direction: Vector2, starting_global_position: Vector2):
	for piece in pieces:
		var new_position = piece.position + starting_global_position + direction * piece.get_size()
		if new_position.x < bounds.get("min_x") || new_position.x > bounds.get("max_x") || new_position.y >= bounds.get("max_y"):
			return false
	return true

func is_colliding_with_other_tetrominos(direction: Vector2, starting_global_position: Vector2):
	for tetromino_piece in other_tetrominoes_pieces:
		for piece in pieces:
			if starting_global_position + piece.position + direction * piece.get_size() == tetromino_piece.global_position:
				return true
	return false

func rotate_tetromino(direction: int):
	var original_rotation_index = rotation_index
	if tetromino_data.tetromino_type == Shared.Tetromino.O:
		return
	apply_rotation(direction)
	
	rotation_index = wrap(rotation_index + direction, 0, 4)
	
	if !test_wall_kicks(rotation_index, direction):
		rotation_index = original_rotation_index
		apply_rotation(-direction)
	
	hard_drop_ghost.call_deferred()
	

func test_wall_kicks(current_rotation_index: int, rotation_direction: int):
	var wall_kick_index = get_wall_kick_index(current_rotation_index, rotation_direction)
	
	for i in wall_kicks[0].size():
		var translation = wall_kicks[wall_kick_index][i]
		if move(translation):
			return true
	return false

func get_wall_kick_index(current_rotation_index: int, rotation_direction):
	var wall_kick_index = current_rotation_index * 2
	if rotation_direction < 0:
		wall_kick_index -= 1
		
	return wrap(wall_kick_index, 0 , wall_kicks.size())

func apply_rotation(direction: int):
	var rotation_matrix = Shared.clockwise_rotation_matrix if direction == 1 else Shared.counter_clockwise_rotation_matrix
	
	tetromino_cells = Shared.cells[tetromino_data.tetromino_type]
	
	for i in tetromino_cells.size():
		var cell = tetromino_cells[i]

		var coordinates = rotation_matrix[0] * cell.x + rotation_matrix[1]* cell.y
		tetromino_cells[i] = coordinates
	
	for i in pieces.size():
		var piece = pieces[i]
		piece.position = tetromino_cells[i] * piece.get_size()
				
	

func hard_drop():
	while(move(Vector2.DOWN)):
		continue
	lock()

func lock():
	timer.stop()
	lock_tetromino.emit(self)
	set_process_input(false)
	ghost_tetromino.queue_free()
	

func _on_timer_timeout():
	var should_lock =  !move(Vector2.DOWN)
	if should_lock:
		lock()
