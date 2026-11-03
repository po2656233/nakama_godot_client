extends player_chess
class_name player_chess_z

## 兵/卒：过河前只能向前；过河后可以向前或左右横走，不能后退。
func move(_start: chess_position, _end: chess_position, _chess_array: Array) -> bool:
	var from := _start.V_position
	var to := _end.V_position
	var forward := -1.0 if chess_color == 1 else 1.0
	var crossed_river := (chess_color == 1 and from.y < 5) or (chess_color == 0 and from.y >= 5)
	var dx := absf(to.x - from.x)
	var dy := to.y - from.y
	if dy == forward and dx == 0:
		return true
	if crossed_river and dy == 0 and dx == 1:
		return true
	return false
