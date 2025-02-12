extends Node
var games_data = []
var kind_names = {
    1: "对战类",
    2: "百人类",
    3: "房卡类",
    4: "竞猜类",
    5: "电玩城",
    6: "电竞类",
    7: "体育类",
    8: "益智类",
    9: "RPG类",
    10: "PK类",
    11: "麻将类"
}
var kind_en_names = {
    1: "fight",
    2: "multiplayer",
    3: "sameTable",
    4: "guess",
    5: "gamesCity",
    6: "esports",
    7: "sport",
    8: "education",
    9: "RolePlayingGame",
    10: "PlayerKilling",
    11: "mahjong"
}
#####################################################################
# 有效的RPC函数
# var rpc_funcs = [
# 	"list_games",
# 	"match_list"
# ]
#####################################################################

# 获取数据
func RpcData(funcName, payload:Dictionary={}):
	# if not rpc_funcs.has(funcName):
	# 	print("无效的RPC函数名:",funcName)
	# 	return []
	var result = await Online.sendDataRPC(funcName,payload)
	if result and result.id == funcName:
		return JSON.parse_string(result.payload)
	return null

# 获取列表数据
func RpcListData(funcName, payload:Dictionary={}, sort_field:String=""):
	# if not rpc_funcs.has(funcName):
	# 	print("无效的RPC函数名:",funcName)
	# 	return []
	var result = await Online.sendDataRPC(funcName,payload)
	if result and result.id == funcName:
		var sorted = JSON.parse_string(result.payload)
		sorted = sorted.duplicate() 
		if sort_field != "":
			sorted.sort_custom(func(a, b):
				if a.has(sort_field) and b.has(sort_field):
					return a[sort_field] < b[sort_field]
				else:
					return false
			)
		return sorted
	return []

# 获取游戏列表
func getGameList(kind:int=-1):
	if games_data.size() > 0:
		return games_data
	var result = await RpcListData("list_games",{"kid":kind}, "id")
	if result.size() > 0:
		games_data = result
	return result

# 获取匹配列表
func getMatchList(payload:Dictionary={"limit":100,"authoritative":true,"minSize":0,"maxSize":100,"query":"*"}):
	var result = await RpcListData("match_list",payload)
	return result

# 获取游戏名称
func getGameName(game_id:int):
	for game in games_data:
		if game.id == game_id:
			return game.name
	return ""

# 获取游戏类型信息
func getKindName(kind:int):
	return kind_names.get(kind, "其他")

# 获取游戏类型英文名
func getKindEnName(kind:int):
	return kind_en_names.get(kind, "other")

