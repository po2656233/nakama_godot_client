extends player_chess

func move(_start:chess_position,_end:chess_position,_chess_array:Array)->bool:
	if chess_color==1:
		if _start.V_position.y<_end.V_position.y:
			return false
	else :
		if _start.V_position.y>_end.V_position.y:
			return false
	var distance_=distance(_start.V_position,_end.V_position)
	if chess_color!=_start.chess_color:
		if distance_.x+distance_.y==1:
			return true
	else :
		if distance_.x==0 and distance_.y==1:
			return true
	return false
		
		
	
	
