extends Node

# 邮件数据结构

signal mail_claimed(mail_id: int)
signal mail_selected(mail_data: Dictionary)

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

func get_mail_list() -> Array:
	return mail_list

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
			return true
	return false
