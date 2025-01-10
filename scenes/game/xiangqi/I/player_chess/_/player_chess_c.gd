extends player_chess

func move(_start:chess_position,_end:chess_position,_chess_array:Array)->bool:
	var distance_=distance(_start.V_position,_end.V_position)
	if distance_.x!=0 and distance_.y==0:	
		if _end.V_position.x>_start.V_position.x:
			for x1 in range(1,_end.V_position.x-_start.V_position.x):
				if  _chess_array[_start.V_position.x+x1][_start.V_position.y].play!=null:
					return false
			return true
		else :
			for x1 in range(1,_start.V_position.x-_end.V_position.x):
				if  _chess_array[_end.V_position.x+x1][_end.V_position.y].play!=null:
					return false
			return true

	elif distance_.x==0 and distance_.y!=0:
		if _end.V_position.y>_start.V_position.y:
			for y1 in range(1,_end.V_position.y-_start.V_position.y):
				if  _chess_array[_start.V_position.x][_start.V_position.y+y1].play!=null:
					return false
			return true
		else :
			for y1 in range(1,_start.V_position.y-_end.V_position.y):
				if  _chess_array[_end.V_position.x][_end.V_position.y+y1].play!=null:
					return false
			return true
	return false
