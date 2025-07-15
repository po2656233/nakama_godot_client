extends Node
var online_play = false
const loginProto = preload("res://gdprotobuf/login.gd")
const homeProto = preload("res://gdprotobuf/home.gd")
var local_match_id = ""
var games_data = []
var favorite_list = []
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
func initGameList():
	games_data = []
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
func favoriteTable(payload,obj:Object=null,work_cb:String="_on_work",error_cb:String="_on_err"):
	var result = await Online.sendDataRPC("favorite_table",payload,obj,work_cb,error_cb)
	return result

func joinTable(payload,obj:Object=null,work_cb:String="_on_work",error_cb:String="_on_err"):
	var result = await Online.sendDataRPC("join_table",payload,obj,work_cb,error_cb)
	return result

func leaveTable(payload,obj:Object=null,work_cb:String="_on_work",error_cb:String="_on_err"):
	var result = await Online.sendDataRPC("leave_table",payload,obj,work_cb,error_cb)
	return result

func createTable(payload,obj:Object=null,work_cb:String="_on_work",error_cb:String="_on_err"):
	var result = await Online.sendDataRPC("create_table",payload,obj,work_cb,error_cb)
	return result

func removeTable(payload,obj:Object=null,work_cb:String="_on_work",error_cb:String="_on_err"):
	var result = await Online.sendDataRPC("remove_table",payload,obj,work_cb,error_cb)
	return result


# 获取游戏列表
func getGameList(kind:int=-1,obj:Object=null,work_cb:String="_on_work"):
	# 每次都加载最新的
	var result = await Online.sendDataRPC("list_games",{"kid":kind},obj,work_cb)
	if result and result.size() > 0:
		games_data = Util.sort_by_filed(result,"id")
		SignalManager.GameListSIG.emit(games_data)
	else:
		result = [] 
	return result



# 获取收藏列表
func getFavoriteList(payload=null,obj:Object=null,work_cb:String="_on_work"):
	if favorite_list.size() == 0:
		var result = await Online.sendDataRPC("favorite_list",payload,obj,work_cb)
		favorite_list = result if result else []
	return favorite_list


# 获取牌桌列表
func getTabelList(payload:Dictionary,obj:Object=null,work_cb:String="_on_work"):
	#var request = homeProto.GetTableListReq.new()
	#request.set_creatorId(payload.get("creatorId",""))
	#request.set_order(payload.get("order",""))
	#request.set_name(payload.get("name",""))
	#request.set_isDesc(payload.get("isDesc",false))
	#request.set_pageNum(payload.get("pageNum",1))
	#request.set_pageSize(payload.get("pageSize",20))
	var result = await Online.sendDataRPC("table_list",payload,obj,work_cb)
	return result

########################################################################################
func getGameListOld():
	return games_data 
	
# 获取游戏名称
func getGameName(game_id:int):
	for game in games_data:
		if int(game.id) == game_id:
			return game.name
	return ""

# 获取游戏名称
func getGameEnName(game_id:int):
	for game in games_data:
		if int(game.id) == game_id:
			return game.en_name
	return ""

# 获取游戏名称
func getGameEnName_by(gamename:String):
	for game in games_data:
		if game.name == gamename:
			return game.en_name
	return ""

func getGameMaxPeople(game_id:int)->int:
	for game in games_data:
		if int(game.id) == game_id:
			return game.max_player
	return 0
	
# 获取游戏名称
func getGameID(enName:String):
	for game in games_data:
		if game.en_name == enName:
			return game.id
	return -1

# 获取游戏类型信息
func getKindName(kind):
	return kind_names.get(kind, "其他")

# 获取游戏类型英文名
func getKindEnName(kind):
	return kind_en_names.get(kind, "other")
