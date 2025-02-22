extends Control

const CHESS_POSITION = preload("res://scenes/game/xiangqi/M/chess_position.tscn")

var V_CHESS_POSITION:chess_position


@onready var chessposition: Node2D = $chessposition

var chess_position_array=[]
var pre_chess:chess_position
var size1:int=58
func _ready() -> void:
	# SettingsManager.show_settings() 
	add_position()
	add_player_chess()
	
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

	
var start_x:int=0
var start_y:int=0


@onready var b_chessposition: Node2D = $b_chessposition

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
	

@onready var player_move: Sprite2D = $b_chessposition/player_move

@onready var luozi: AudioStreamPlayer = $luozi
@onready var chi: AudioStreamPlayer = $chi
@onready var cuowu: AudioStreamPlayer = $cuowu



var start_player:int=1
var V_chess:chess_position
func move(chess:chess_position):
	if V_chess==null:
		if chess.play!=null:
			if chess.play.chess_color==start_player:
				V_chess=chess
				player_move.visible=true
				player_move.position=V_chess.position
	elif chess==V_chess:
		pass
	else :
		if chess.play!=null:
			if chess.play.chess_color==start_player:
				V_chess=chess
				player_move.visible=true
				player_move.position=V_chess.position
			else:
				if V_chess.play.move(V_chess,chess,chess_position_array):
					if chess.play.game_over():
						game_over()
					chess.play.queue_free()
					_move_end(chess)
					chi.play()
				else :
					cuowu.play()
		else :
			if V_chess.play == null:
				return
			if V_chess.play.move(V_chess,chess,chess_position_array):
				_move_end(chess)
				luozi.play()
			else :
				cuowu.play()
	
func _move_end(chess:chess_position)->void:
	chess.play=V_chess.play
	V_chess.play=null
	chess.play.position=chess.position
	V_chess=null
	if pre_chess:
		V_chess = pre_chess
		player_move.position=pre_chess.position
	pre_chess = chess
	# player_move.visible=false
	change_player()
	player_move._change_color()
func change_player()->void:
	if start_player==0:
		start_player=1
	else :
		start_player=0
	

@onready var over: CanvasLayer = %over
@onready var label: Label = $over/Label

func game_over()->void:
	over.visible=true
	if start_player==1:
		label.text="黑方获胜"
	else :
		label.text="红方获胜"


func _on_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/game/xiangqi/S/xiangqi.tscn")


func _on_reback_btn_pressed() -> void:
	SceneManager.change_scene("home")
	pass # Replace with function body.
