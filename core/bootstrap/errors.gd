extends Node

# 定义一个映射字典，将函数名称映射为中文
var FuncMapping = {
	"leave_table": "离开房间",
	"join_table": "加入房间",
	"remove_table": "删除房间",
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
	# 通用网络错误
	"RPC function not found": "服务器未处理",
	"Request cancelled.": "网络断开",
	"Connection failed": "连接失败",
	"Connection timeout": "连接超时",
	"Invalid session": "会话无效",
	"Session expired": "会话已过期",
	"WebSocket connection failed": "网络连接失败",
	"Network unreachable": "网络不可达",
	"Host unreachable": "主机不可达",
	"Connection refused": "连接被拒绝",
	"TLS handshake failed": "TLS握手失败",
	"Certificate verification failed": "证书验证失败",
	"Failed to decode JSON response": "连接失败,服务器网络异常",
	"ERR_CANT_CONNECT": "连接失败,服务器网络异常",
	"ERR_TIMEOUT": "连接超时,请检查网络",
	"ERR_FILE_EOF": "连接断开,请检查网络",
	"ERR_CONNECTION_ERROR": "连接出错,请检查网络",
	"HTTPRequest failed!": "网络连接失败，请检查您的网络设置",


	#账密失效
	"Invalid session.": "会话无效",
	"Session expired.": "会话已过期",
	"Invalid credentials.": "账号或密码错误，请检查后重试",
	"User account not found.": "该账号未注册",
	"Device ID is required.": "缺少设备ID"

}

## 可重试的网络类错误特征（小写匹配）。业务错误不在此列。
const NETWORK_ERROR_MARKERS: Array = [
	"cancelled",
	"connection",
	"timeout",
	"network",
	"socket",
	"websocket",
	"tls",
	"certificate",
	"eof",
	"unreachable",
	"refused",
	"failed to decode",
	"httprequest",
]

## 把服务端/插件错误文本转成中文；找不到映射就原样返回。
func humanize(message: String) -> String:
	var text := message.strip_edges()
	if text.is_empty():
		return "操作失败，请稍后重试"
	if ResponeMapping.has(text):
		return ResponeMapping[text]
	for key in ResponeMapping:
		if text.contains(str(key)):
			return str(ResponeMapping[key])
	return text

## 是否属于“可以等重连后重试”的网络错误。
func is_network_error(message: String) -> bool:
	var lower := message.to_lower()
	for marker in NETWORK_ERROR_MARKERS:
		if lower.contains(marker):
			return true
	return false
