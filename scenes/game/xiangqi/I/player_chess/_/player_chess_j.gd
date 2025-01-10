extends player_chess



func move(_start:chess_position,_end:chess_position,_chess_array:Array)->bool:
	if _end.V_position.x<3 or _end.V_position.x>5:
		return false
	if chess_color==1:
		if _end.V_position.y<7:
			return false
	elif  chess_color==0:
		if _end.V_position.y>2:
			return false
	var distance_=distance(_start.V_position,_end.V_position)
	if distance_.x+distance_.y==1:
		return true
	return false

func game_over()->bool:
	return true
