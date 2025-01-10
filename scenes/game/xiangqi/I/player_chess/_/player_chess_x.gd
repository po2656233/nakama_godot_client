extends player_chess

func move(_start:chess_position,_end:chess_position,_chess_array:Array)->bool:
	if _end.chess_color!=chess_color:
		return false
	var distance_=distance(_start.V_position,_end.V_position)
	if distance_.x==2 and distance_.y==2:
		var x=(_start.V_position.x+_end.V_position.x)/2
		var y=(_start.V_position.y+_end.V_position.y)/2
		if _chess_array[x][y].play==null:
			return true
	return false
