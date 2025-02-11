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

func getGameName(game_id:int):
	for game in games_data:
		if game.id == game_id:
			return game.name
	return ""

func getKindName(kind:int):
	if kind == 1:
		return "对战类"
	elif kind == 2:
		return "百人类"
	elif kind == 3:
		return "房卡类"
	elif kind == 4:
		return "竞猜类"
	elif kind == 5:
		return "电玩城"
	elif kind == 6:
		return "电竞类"
	elif kind == 7:
		return "体育类"
	elif kind == 8:
		return "益智类"
	elif kind == 9:	
		return "RPG类"
	elif kind == 10:
		return "PK类"
	elif kind == 11:
		return "麻将类"
	else:
		return "其他"

func getKindEnName(kind:int):
	if kind == 1:
		return "fight"
	elif kind == 2:
		return "multiplayer"
	elif kind == 3:
		return "sameTable"
	elif kind == 4:
		return "guess"
	elif kind == 5:
		return "gamesCity"
	elif kind == 6:
		return "esports"
	elif kind == 7:
		return "sport"
	elif kind == 8:
		return "education"
	elif kind == 9:
		return "RolePlayingGame"
	elif kind == 10:
		return "PlayerKilling"
	elif kind == 11:
		return "mahjong"
	else:
		return "other"

