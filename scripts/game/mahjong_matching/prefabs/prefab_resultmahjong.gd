extends Node2D

var piece = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func set_piece(piece1):
	#先把数字补到两位的汉字
	var piece_str = str(piece1)
	while piece_str.length() < 2:
		piece_str = "0" + piece_str
	#设置图片
	var piece_texture = load("res://assets/game/mahjong_matching/texture/" + piece_str + ".svg")
	$Sprite.texture = piece_texture
	self.piece = piece1
