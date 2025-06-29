extends Node

# 测试断线重连功能的脚本
# 使用方法：将此脚本添加到场景中，然后调用相应的测试函数

func _ready():
	print("断线重连测试脚本已加载")
	# 监听连接状态变化
	Online.connect_state.connect(_on_connect_state_changed)

func _on_connect_state_changed(state: String):
	print("连接状态变化:", state)

# 测试发送RPC请求
func test_send_rpc():
	print("=== 测试发送RPC请求 ===")
	var result = await Online.sendDataRPC("test_function", {"data": "test"})
	print("RPC结果:", result)

# 测试检查连接状态
func test_connection_status():
	print("=== 测试连接状态 ===")
	var status = Online.get_connection_status()
	print("连接状态:", status)
	print("待处理请求数量:", Online.get_pending_requests_count())

# 测试手动重连
func test_manual_reconnect():
	print("=== 测试手动重连 ===")
	Online.manual_reconnect()

# 测试模拟断线
func test_simulate_disconnect():
	print("=== 测试模拟断线 ===")
	# 模拟断线情况
	if Online.nakama_socket:
		Online.nakama_socket.close()
		print("已模拟断开连接")

# 测试发送多个请求（模拟断线情况）
func test_multiple_requests():
	print("=== 测试发送多个请求 ===")
	
	# 发送多个请求
	for i in range(5):
		print("发送请求", i + 1)
		await Online.sendDataRPC("test_function_" + str(i), {"index": i})
		await get_tree().create_timer(0.5).timeout
	
	print("所有请求发送完成")

# 测试重试次数限制
func test_retry_limit():
	print("=== 测试重试次数限制 ===")
	
	# 发送一个会失败的请求多次
	for i in range(5):
		print("发送可能失败的请求", i + 1)
		await Online.sendDataRPC("invalid_function", {"test": "data"})
		await get_tree().create_timer(1.0).timeout

# 运行所有测试
func run_all_tests():
	print("开始运行所有测试...")
	
	# 等待一段时间确保连接稳定
	await get_tree().create_timer(2.0).timeout
	
	# 测试连接状态
	test_connection_status()
	
	# 测试发送RPC
	await test_send_rpc()
	
	# 测试发送多个请求
	await test_multiple_requests()
	
	# 测试重试次数限制
	await test_retry_limit()
	
	print("所有测试完成")

# 监控函数（可在_ready中调用）
func start_monitoring():
	print("开始监控连接状态...")
	
	# 每10秒检查一次状态
	var timer = Timer.new()
	timer.timeout.connect(_monitor_status)
	add_child(timer)
	timer.start(10.0)

func _monitor_status():
	var status = Online.get_connection_status()
	print("监控状态:", status)
	
	if status.pending_requests > 0:
		print("有待处理请求:", status.pending_requests) 