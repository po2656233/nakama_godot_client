class_name ReliableMessageQueue
extends Node

# 消息重试配置
const MAX_RETRY_ATTEMPTS = 10
const INITIAL_RETRY_DELAY = 1.0  # 初始重试延迟（秒）
const RETRY_BACKOFF_FACTOR = 2.0  # 指数退避因子
const MAX_RETRY_DELAY = 5.0     # 最大重试延迟（秒）
# 这些接口不会在断线重连后自动恢复
const NON_RETRY_API: Array = [
	"authenticate_email_async",
	"authenticate_device_async",
	"register_account",
	"login",
	"do_login",
	"do_device_login"
]
# 消息数据结构
class QueuedMessage:
	var id: String 
	var caller: Object = Online.nakama_socket  # 默认使用在线的nakama_socket
	var func_name: String
	var payload: Variant
	var create_time: float
	var last_send_time: float
	var retry_count: int
	var next_retry_time: float
	var do_success: Callable
	var do_failure: Callable
	
	func _init(msg_id: String,msg_name: String, data: Variant, obj:Object=Online.nakama_socket ,on_success: Callable = Util.EMPTY_CALLABLE, on_failure: Callable = Util.EMPTY_CALLABLE) -> void:
		id = msg_id
		func_name = msg_name
		payload = data
		create_time = Time.get_unix_time_from_system()
		last_send_time = 0.0
		retry_count = 0
		next_retry_time = 0.0
		caller = obj
		do_success = on_success
		do_failure = on_failure
	
	func should_retry() -> bool:
		return retry_count < MAX_RETRY_ATTEMPTS
	
	func calculate_next_retry() -> void:
		retry_count += 1
		# 指数退避算法
		var delay = INITIAL_RETRY_DELAY * pow(RETRY_BACKOFF_FACTOR, retry_count - 1)
		delay = min(delay, MAX_RETRY_DELAY)
		next_retry_time = Time.get_unix_time_from_system() + delay

var _message_queue: Array[QueuedMessage] = []
var _in_progress: Dictionary = {}  # 正在发送中的消息 (id: QueuedMessage)
var _mutex: Mutex = Mutex.new()
var _message_counter: int = 0
var _processing_active: bool = false

# 添加消息到队列
func EnqueueMessage(funcName: String,payload: Variant,obj:Object=Online.nakama_socket ,success_cb: Callable = Util.EMPTY_CALLABLE, failure_cb: Callable = Util.EMPTY_CALLABLE) -> String:
	# 重试的API不加入队列
	if NON_RETRY_API.has(funcName) or obj == null:
		print("警告！！！添加消息到队列失败 funcName:", funcName, " payload:", payload, " obj is null")
		return ""
	
	# 确保线程安全
	_mutex.lock()
	var msg_id = "msg_%d_%d" % [Time.get_unix_time_from_system(), _message_counter]
	_message_counter += 1
	
	var message = QueuedMessage.new(msg_id,funcName,payload,obj,success_cb,failure_cb)
	_message_queue.append(message)
	_mutex.unlock()
	
	# 确保处理循环已启动
	_ensure_processing_active()
	
	return msg_id

# 获取队列状态
func get_queue_status() -> Dictionary:
	_mutex.lock()
	var status = {
		"total_messages": _message_queue.size() + _in_progress.size(),
		"pending": _message_queue.size(),
		"in_progress": _in_progress.size(),
		"oldest_message": 0.0,
		"retry_stats": {}
	}
	
	if not _message_queue.is_empty():
		status["oldest_message"] = Time.get_unix_time_from_system() - _message_queue[0].create_time
	
	# 统计重试次数分布
	for msg in _message_queue:
		var count = msg.retry_count
		if not status["retry_stats"].has(count):
			status["retry_stats"][count] = 0
		status["retry_stats"][count] += 1
	
	_mutex.unlock()
	return status

# 确保处理循环已启动
func _ensure_processing_active() -> void:
	if _processing_active:
		return
	
	_processing_active = true
	_process_queue()

# 处理队列的核心方法
func _process_queue() -> void:
	while true:
		# 获取当前时间
		var current_time = Time.get_unix_time_from_system()
		
		_mutex.lock()
		
		# 1. 检查超时的进行中消息
		var timed_out_messages = []
		for msg_id in _in_progress:
			var msg = _in_progress[msg_id]
			# 假设超过30秒没有更新为超时
			if current_time - msg.last_send_time > 30.0:
				timed_out_messages.append(msg_id)
		
		# 将超时消息移回队列
		for msg_id in timed_out_messages:
			var msg = _in_progress[msg_id]
			_in_progress.erase(msg_id)
			_message_queue.append(msg)
			print("消息超时移回队列: ", msg_id)
		
		# 2. 查找可重试的消息
		var messages_to_send = []
		for i in range(_message_queue.size() - 1, -1, -1):
			var msg = _message_queue[i]
			
			# 检查是否应该重试
			if current_time >= msg.next_retry_time:
				messages_to_send.append(msg)
				_message_queue.remove_at(i)
				_in_progress[msg.id] = msg
		
		_mutex.unlock()
		
		# 3. 发送消息
		for msg in messages_to_send:
			msg.last_send_time = current_time
			await _send_message_with_retry(msg)
		
		# 4. 检查队列是否为空
		_mutex.lock()
		var queue_empty = _message_queue.is_empty()
		var in_progress_empty = _in_progress.is_empty()
		_mutex.unlock()
		
		if queue_empty and in_progress_empty:
			_processing_active = false
			return
		
		# 等待下一帧再继续处理
		await get_tree().create_timer(0.1).timeout

# 发送消息并处理重试逻辑
func _send_message_with_retry(msg: QueuedMessage) -> void:
	var success = false
	var should_retry = true
	var socket = null
	
	# 尝试发送消息
	while not success and should_retry:
		# 使用 await 确保异步发送完成
		socket = msg.caller
		if msg.caller == null:
			socket = Online.nakama_socket
		success = await Util.Asyn_Call(socket, msg.func_name, msg.payload, msg.do_success, msg.do_failure,false)
		if success:
			# 发送成功，从进行中移除
			_mutex.lock()
			_in_progress.erase(msg.id)
			_mutex.unlock()
			print("消息发送成功: ", msg.id)
			return
		# 发送失败，计算下次重试时间
		msg.calculate_next_retry()
		should_retry = msg.should_retry()
		if should_retry:
			# 等待重试时间到达
			var cur_time = Time.get_unix_time_from_system()
			var wait_time = msg.next_retry_time - cur_time
			print("发送失败，[%d] %d秒后重试消息 %s (尝试 %d/%d) " % [
				cur_time,
				wait_time,
				msg.id,
				msg.retry_count,
				MAX_RETRY_ATTEMPTS,
			])
			if wait_time > 0:
				await get_tree().create_timer(wait_time).timeout
	# 达到最大重试次数仍失败
	_mutex.lock()
	_in_progress.erase(msg.id)
	_mutex.unlock()
	var now_time = Time.get_unix_time_from_system()
	print("消息 %s 发送失败，[%d]达到最大重试次数 %d" % [msg.id,now_time, MAX_RETRY_ATTEMPTS])
	# 这里可以添加回调通知发送失败


# 清理资源
func clear_queue():
	_mutex.lock()
	_message_queue.clear()
	_in_progress.clear()
	_mutex.unlock()
