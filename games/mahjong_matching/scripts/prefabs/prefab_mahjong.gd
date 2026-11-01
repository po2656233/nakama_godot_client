extends Node2D

signal piece_clicked

var bMouseOver = false
var piece = 0
var dragging = false
var drag_start_position = Vector2()
var dragMinDistance = 30
var moving = false

var xIndex = 0
var yIndex = 0

enum Direction{
	UP = 0,
	DOWN = 1,
	LEFT = 2,
	RIGHT = 3
}
# Called when the node enters the scene tree for the first time.
func _ready():
	$board.visible = false
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if self.dragging:
		# 先确定是横向移动还是纵向移动
		var drag_distance = get_viewport().get_mouse_position() - drag_start_position
		var main_game = _get_main_game()
		if main_game:
			if drag_distance.length() > dragMinDistance:
				var realDistance = Vector2(drag_distance.x / get_parent().scale.x, drag_distance.y / get_parent().scale.y)
				main_game.update_move_pos(xIndex, yIndex, realDistance)
			else:
				main_game.reset_all_moving()

func set_piece(piece):
	#先把数字补到两位的字符
	var piece_str = str(piece)
	while piece_str.length() < 2:
		piece_str = "0" + piece_str
	#设置图片
	var piece_texture = load("res://games/mahjong_matching/assets/image/texture/" + piece_str + ".svg")
	$Sprite.texture = piece_texture
	self.piece = piece

func set_cur_pos(x, y):
	xIndex = x
	yIndex = y

func set_offset(pieceSize, offset):
	position = Vector2(pieceSize.x * xIndex + offset.x, pieceSize.y * yIndex + offset.y)

func reset_moving(pieceSize):
	moving = false
	position = Vector2(pieceSize.x * xIndex, pieceSize.y * yIndex)

func set_cur_z_index(pieceSize, boardSize, bHorizonMove):
	var curX = 1+floor(position.x/pieceSize.x)
	var curY = 1+floor(position.y/pieceSize.y)
	if bHorizonMove:
		z_index = curX + (boardSize.y - curY) * boardSize.x
	else:
		z_index = curX * boardSize.y + (boardSize.y - curY)

func _input(event):
	if event is InputEventMouseButton and not event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if dragging:
			var game_main = _get_main_game()
			game_main.set_afterdrag_pos()
		dragging = false
		if bMouseOver:
			piece_clicked.emit(self)
	# drag and drop
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and bMouseOver:
		dragging = true
		drag_start_position = event.position

func _on_area_2d_mouse_entered():
	bMouseOver = true
	pass # Replace with function body.

func _on_area_2d_mouse_exited():
	bMouseOver = false
	pass # Replace with function body.

func set_selected(bSelected):
	if bSelected:
		$board.visible = true
	else:
		$board.visible = false

func _get_main_game():
	var parent = self.get_parent()
	if not parent:
		return null
	return parent.get_parent()
