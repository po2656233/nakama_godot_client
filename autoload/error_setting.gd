extends Node

# 定义一个映射字典，将函数名称映射为中文
var FuncMapping = {
	"leave_table": "离开房间",
	"join_table": "加入房间",
	"remove_table": "",
	"favorite_table": "收藏房间",
	"send_message": "发送消息",
	# 添加更多映射...
}
var ResponeMapping = {
	"RPC function not found": "服务器未处理",
	"Request cancelled.":"网络断开",
}


var NetworkErrors = [
		"网络断开",
		"连接失败", 
		"连接超时",
		"HTTPRequest failed!",
		"Invalid session.",
		"Session expired.",
		"Request cancelled.",
		"RPC function not found",
	]
