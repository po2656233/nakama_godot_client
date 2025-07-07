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

# 这些接口不会在断线重连后自动恢复
const Non_Retry_API: Array = [
	"authenticate_email_async",
	"authenticate_device_async",
	"register_account",
	"login",
	"do_login",
	"do_device_login"
]

# 定义一个映射字典，将错误消息映射为中文
var ResponeMapping = {
	"RPC function not found": "服务器未处理",
	"Request cancelled.":"网络断开",
	"Connection failed": "连接失败",
	"Connection timeout": "连接超时",
	"Invalid session": "会话无效",
	"Session expired": "会话已过期",
	"WebSocket connection failed": "WebSocket连接失败",
	"Network unreachable": "网络不可达",
	"Host unreachable": "主机不可达",
	"Connection refused": "连接被拒绝",
	"TLS handshake failed": "TLS握手失败",
	"Certificate verification failed": "证书验证失败",
}

# 网络错误
var NetworkErrors = [
		# "网络断开",
		# "连接失败", 
		# "连接超时",
		"HTTPRequest failed!",
		"Invalid session.",
		"Session expired.",
		"Request cancelled.",
		"RPC function not found",
		"Connection failed",
		"Connection timeout",
		"WebSocket connection failed",
		"Network unreachable",
		"Host unreachable",
		"Connection refused",
		"TLS handshake failed",
		"Certificate verification failed",
		"ERR_CANT_CONNECT",
		"ERR_TIMEOUT",
		"ERR_FILE_EOF",
		"ERR_CONNECTION_ERROR",
	]
