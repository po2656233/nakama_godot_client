extends player_chess


func move(_start:chess_position,_end:chess_position,_chess_array:Array)->bool:
	var distance_=distance(_start.V_position,_end.V_position)
	if distance_.x==1 and distance_.y==2:
		var y =(_start.V_position.y+_end.V_position.y)/2
		if _chess_array[_start.V_position.x][y].play==null:
			return true
	elif distance_.x==2 and distance_.y==1:
		var x =(_start.V_position.x+_end.V_position.x)/2
		if _chess_array[x][_start.V_position.y].play==null:
			return true
	return false
