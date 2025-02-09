extends Node
var games_data = []

func getGameList(kind:int=-1):
	if games_data.size() > 0:
		return games_data
	var result = await Online.sendDataRPC("list_games",{"kid":kind})
	print("获取游戏列表",result)
	if result and result.id == "list_games":
		var sorted = JSON.parse_string(result.payload)
		sorted = sorted.duplicate()
		sorted.sort_custom(func(a, b): return a.id < b.id)
		games_data = sorted
		return games_data
	return []