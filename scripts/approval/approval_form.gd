extends Control

# 预加载请求项场景
var RequestItemScene = preload("res://scenes/approval/request_item.tscn")
@onready var addBtn = $Panel/MarginContainer/VBoxContainer/AddTestDataButton
func _ready():
	# 连接测试按钮信号
	addBtn.pressed.connect(_on_add_test_data_button_pressed)

# 添加新的请求项到列表
func add_request_item(type: String, name1: String, time: String, status = null) -> void:
	var request_item = RequestItemScene.instantiate()
	%RequestList.add_child(request_item)
	if status != null:
		request_item.setup(type, name1, time, status)
	else:
		request_item.setup(type, name1, time)
	request_item.approved.connect(_on_request_approved.bind(request_item))
	request_item.rejected.connect(_on_request_rejected.bind(request_item))

# 导入请求数据
func import_requests(requests: Array) -> void:
	# 清除现有项目
	for child in %RequestList.get_children():
		child.queue_free()
	
	# 添加新项目
	for request in requests:
		if "status" in request:
			add_request_item(request.type, request.name, request.time, request.status)
		else:
			add_request_item(request.type, request.name, request.time)

# 重新排序请求列表
func reorder_requests() -> void:
	var items = %RequestList.get_children()
	var pending_items = []
	var waiting_other_items = []
	var processed_items = []
	
	# 将项目按状态分类
	for item in items:
		var status = item.get_status()
		if status == item.Status.PENDING:
			pending_items.append(item)
		elif status == item.Status.WAITING_OTHER:
			waiting_other_items.append(item)
		else:
			processed_items.append(item)
	
	# 从父节点移除所有项目
	for item in items:
		%RequestList.remove_child(item)
	
	# 按顺序重新添加：未审批的在前，等待对方的在中间，已处理的在后
	for item in pending_items:
		%RequestList.add_child(item)
	for item in waiting_other_items:
		%RequestList.add_child(item)
	for item in processed_items:
		%RequestList.add_child(item)

# 当请求被批准时
func _on_request_approved(request_item: Control) -> void:
	print("请求已批准: ", request_item.get_request_info())
	# 更新状态为等待对方通过
	request_item.update_other_status(request_item.Status.WAITING_OTHER)
	reorder_requests()

# 当请求被拒绝时
func _on_request_rejected(request_item: Control) -> void:
	print("请求已拒绝: ", request_item.get_request_info())
	reorder_requests()

# 添加测试数据的按钮回调
func _on_add_test_data_button_pressed() -> void:
	var current_time = Time.get_datetime_string_from_system().split(".")[0]
	var test_data = [
		{"type": "用户", "name": "张三", "time": current_time},
		{"type": "俱乐部", "name": "篮球俱乐部", "time": current_time},
		{"type": "用户", "name": "李四", "time": current_time, "status": RequestItemScene.instantiate().Status.WAITING_OTHER},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "读书会", "time": current_time, "status": RequestItemScene.instantiate().Status.OTHER_APPROVED},
		{"type": "俱乐部", "name": "篮球俱乐部", "time": current_time},
		{"type": "俱乐部", "name": "篮球俱乐部", "time": current_time},
		{"type": "俱乐部", "name": "篮球俱乐部", "time": current_time},
		{"type": "俱乐部", "name": "篮球俱乐部", "time": current_time},
	]
	import_requests(test_data)

# 模拟更新对方状态（实际应用中这个方法应该由网络请求触发）
func update_other_party_status(request_item: Control, approved: bool) -> void:
	if approved:
		request_item.update_other_status(request_item.Status.OTHER_APPROVED)
	else:
		request_item.update_other_status(request_item.Status.OTHER_REJECTED)
	reorder_requests()


func _on_close_button_pressed() -> void:
	var parent_node = get_parent()
	if parent_node:
		parent_node.queue_free()
	else:
		self.queue_free()
	pass # Replace with function body.
