extends Node
const loginProto = preload("res://gdprotobuf/login.gd")
const homeProto = preload("res://gdprotobuf/home.gd")
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
	# print(" RPC反馈: ",funcName,"->",result)
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
##################################################################################

func sendToMatch(p_match_id, p_op_code : int, p_data : String, p_presences = null):
	if Online.nakama_socket and p_match_id != "":
		print("发送至比赛%s 操作码:%d 数据:%s"%[p_match_id, p_op_code, p_data])
		var result = await Online.nakama_socket.send_match_state_async(p_match_id, p_op_code, p_data, p_presences)
		if result.is_exception():
			PopupManager.show_dynamic("数据异常 " + result.get_exception().message)
			return null
		return result
	return null

#########################RPC###########################################################
func favoriteTable(payload):
	var result = await self.RpcData("favorite_table",payload)
	return result

func joinTable(payload):
	var result = await self.RpcData("join_table",payload)
	return result

func leaveTable(payload):
	var result = await self.RpcData("leave_table",payload)
	return result

###########################################################################
func joinMatch(mid,payload=null):
	if Online.nakama_socket:
		var result = await Online.nakama_socket.join_match_async(mid,payload)
		if result.is_exception():
			PopupManager.show_dynamic("加入匹配失败 "+result.get_exception().message)
			return false
		return true
	return false

func LeaveMatch(mid):
	if Online.nakama_socket:
		var result = await Online.nakama_socket.leave_match_async(mid)
		if result.is_exception():
			print("退出匹配失败 ",result.get_exception().message)
			PopupManager.show_dynamic("退出匹配失败 "+result.get_exception().message)
			return false
		return true
	return false
########################################################################################
# 获取游戏列表
func getGameList(kind:int=-1):
	if games_data.size() > 0:
		return games_data
	var result = await RpcListData("list_games",{"kid":kind}, "id")
	if result.size() > 0:
		games_data = result
	return result

# 获取收藏列表
func getFavoriteList():
	var result = await RpcData("favorite_list")
	return result


# 获取牌桌列表
func getTabelList(payload:Dictionary):
	var request = homeProto.GetTableListReq.new()
	request.set_creatorId(payload.get("creatorId",""))
	request.set_order(payload.get("order",""))
	request.set_name(payload.get("name",""))
	request.set_isDesc(payload.get("isDesc",false))
	request.set_pageNum(payload.get("pageNum",1))
	request.set_pageSize(payload.get("pageSize",20))
	var result = await RpcData("table_list",payload)
	# print("牌桌列表 反馈:",result)
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
