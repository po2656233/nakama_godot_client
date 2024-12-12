extends Node

# 邮件数据结构
signal mail_claimed(mail_id: int)
@warning_ignore("unused_signal")
signal mail_selected(mail_data: Dictionary) #无需理会,已全局有使用
var mail_list = [
	{
		"id": 1,
		"title": "欢迎来到游戏",
		"content": "亲爱的玩家，欢迎来到我们的游戏！这是您的新手礼包，请查收。",
		"reward": {"gold": 1000, "gems": 50},
		"is_claimed": false,
		"send_time": "2023-12-25 10:00:00"
	},
	{
		"id": 2,
		"title": "每日登录奖励",
		"content": "感谢您今日登录游戏，这是您的奖励！",
		"reward": {"gold": 500, "gems": 20},
		"is_claimed": false,
		"send_time": "2023-12-26 10:00:00"
	},
	{
		"id": 3,
		"title": "活动公告",
		"content": "新年活动即将开始，敬请期待！",
		"reward": {"gold": 2000, "gems": 100},
		"is_claimed": false,
		"send_time": "2023-12-27 10:00:00"
	}
]
var _mail_list_node = null

func set_mail_list_node(node):
	_mail_list_node = node

func get_mail_list_node():
	return _mail_list_node

func clear():
	mail_list = []

# 获取已领取邮件列表
func clear_claimed_mails() -> bool:
	var had_claimed = false
	# 从后向前遍历，这样删除元素时不会影响索引
	for i in range(mail_list.size() - 1, -1, -1):
		if mail_list[i]["is_claimed"]:
			mail_list.remove_at(i)
			had_claimed = true
	return had_claimed

func sort():
	mail_list = get_mail_list()

func get_mail_list() -> Array:
	# 创建邮件列表的副本
	var sorted_list = mail_list.duplicate()
	# 根据是否领取进行排序，未领取的排在前面
	sorted_list.sort_custom(func(a, b): return not a["is_claimed"] and b["is_claimed"])
	return sorted_list

func get_mail_by_id(id: int) -> Dictionary:
	for mail in mail_list:
		if mail["id"] == id:
			return mail
	return {}

func claim_mail_reward(mail_id: int) -> bool: 
	for mail in mail_list:
		if mail["id"] == mail_id and not mail["is_claimed"]:
			mail["is_claimed"] = true
			mail_claimed.emit(mail_id)
			# sort()
			return true
	return false


