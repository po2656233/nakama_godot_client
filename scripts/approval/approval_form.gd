extends Control


# 预加载请求项场景
var RequestItemScene = preload("res://scenes/approval/request_item.tscn")
@onready var request_list = %RequestList

func _ready():
	if Global.OnlineLogin.player_data:
		var approvals = Global.DataMgr.get_instance().get_uid_approval(Global.OnlineLogin.get_my_id())
		import_requests(approvals)
	
func _exit_tree() -> void:
	Global.DataMgr.get_instance().save_data()
	clear_requests()
	pass

# 添加新的请求项到列表
func add_request_item(type: String,uid:String, name1: String, time: String,gid:String="-", gname1: String="-", level: int = 0, update_time: String="-", status = null) -> void:
	var request_item = RequestItemScene.instantiate()
	request_list.add_child(request_item)
	if status != null:
		request_item.setup(type,uid, name1, time, gid, gname1,level, update_time, status)
	else:
		request_item.setup(type,uid, name1, time)
	request_item.approved.connect(_on_request_approved.bind(request_item))
	request_item.rejected.connect(_on_request_rejected.bind(request_item))


# 导入请求数据
func import_requests(requests: Array) -> void:
	# 清除现有项目
	for child in request_list.get_children():
		child.queue_free()
	
	# 添加新项目
	for request in requests:
		if "status" in request:
			add_request_item(request.type,request.uid, request.name, request.time, request.group_id, request.group_name,request.level, request.update_time, request.status)
		else:
			add_request_item(request.type,request.uid, request.name,  request.time)
	reorder_requests()

# 重新排序请求列表
func reorder_requests() -> void:
	var items = request_list.get_children()
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
		request_list.remove_child(item)
	
	# 按顺序重新添加：未审批的在前，等待对方的在中间，已处理的在后
	for item in pending_items:
		request_list.add_child(item)
	for item in waiting_other_items:
		request_list.add_child(item)
	for item in processed_items:
		request_list.add_child(item)



# 当请求被批准时
func _on_request_approved(request_item: Control) -> void:
	print("请求已批准: ", request_item.get_request_info())
	# 更新状态为等待对方通过
	request_item.update_other_status(request_item.Status.APPROVED)
	reorder_requests()

# 当请求被拒绝时
func _on_request_rejected(request_item: Control) -> void:
	print("请求已拒绝: ", request_item.get_request_info())
	reorder_requests()



# 模拟更新对方状态（实际应用中这个方法应该由网络请求触发）
func update_other_party_status(request_item: Control, approved: bool) -> void:
	if approved:
		request_item.update_other_status(request_item.Status.APPROVED)
	else:
		request_item.update_other_status(request_item.Status.OTHER_REJECTED)
	reorder_requests()

# 公共方法：清空所有请求
func clear_requests() -> void:
	for child in request_list.get_children():
		child.queue_free()

# 公共方法：获取所有请求
func get_all_requests() -> Array:
	var requests = []
	for child in request_list.get_children():
		requests.append({
			"type": child.type,
			"uid": child.uid,
			"name": child.name,
			"status": child.status,
			"apply_time": child.apply_time,
			"approval_time": child.approval_time,
		})
	return requests
	
func _on_close_button_pressed() -> void:
	var parent_node = get_parent()
	if parent_node:
		parent_node.queue_free()
	else:
		self.queue_free()
	pass # Replace with function body.