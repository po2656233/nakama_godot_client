extends ItemList

@export var custom_color: Color = Color(0.157, 0.655, 0.427,0.5)
@export_group("列表属性配置")
@export_enum("聊天", "俱乐部", "房间", "其他") var listType: int

@export_subgroup("子项弹窗配置") # 创建子组
@export var Add: bool = false
@export var AllowMoreAdd: bool = false # 允许添加重复项
@export var Del: bool = false
@export var Modify: bool = false
@export var Select: bool = false
@export var Agree: bool = false
@export var Refuse: bool = false
@export var Block: bool = false
 
signal addItemData(info)
signal delItemData(info)
signal modifyItemData(info)
signal findItemData(info)

var addname: String = "新增"
var delname: String = "删除"
var modifyname: String = "修改"
var findName: String = "查询"
var agreeName: String = "同意"
var refuseName: String = "拒绝"
var blockName: String = "拉黑"

var popup_menu: PopupMenu
var selected_index: int = -1 # 用于存储当前选中的项目索引

# var tween: Tween 
var original_color: Color = Color(0.02, 0.388, 0.576)
var is_active: bool = false

# 长按后弹出菜单
var long_press_time = 1.0  # 长按时间（秒）
var press_start_time = 0
var is_long_press = false


func _ready():
	# 取消窗口拖动
	WindowDrag.unregister_drag_zone(self)
	# 创建弹出菜单
	popup_menu = PopupMenu.new()
	add_child(popup_menu)
	
	# 添加"删除"选项到弹出菜单
	popup_menu.size = Vector2(200, 120)
	if Add:
		popup_menu.add_item(addname)
	if Del:
		popup_menu.add_item(delname)
	if Modify:
		popup_menu.add_item(modifyname)
	if Select:
		popup_menu.add_item(findName)
	if Agree:
		popup_menu.add_item(agreeName)
	if Refuse:
		popup_menu.add_item(refuseName)
	if Block:
		popup_menu.add_item(blockName)

	# 连接信号
	popup_menu.id_pressed.connect(_on_popup_menu_item_selected)
	addItemData.connect(_on_add_item_data)
	delItemData.connect(_on_del_item_data)
	modifyItemData.connect(_on_modify_item_data)
	findItemData.connect(_on_find_item_data)
	SignalManager.OpenLightSIG.connect(open_color)
	SignalManager.CloseLightSIG.connect(close_color)
	self.connect("gui_input", Callable(self, "_on_item_list_gui_input"))
	pass


func _on_add_item_data(friend):
	print("新增好友---", friend)
	# 遍历所有项目
	var isExist = false
	for i in range(self.item_count):
		var item_meta = self.get_item_metadata(i)  # 获取项目元数据
		if item_meta and item_meta.user.username == friend.user.username:
			self.set_item_metadata(i,friend)
			self.set_item_text(i, friend.user.username)
			isExist = true
			if friend.user.avatar_url:
				var ret = await Util.load_texture_async(friend.user.avatar_url)
				if ret:
					self.set_item_icon(i, ret)
			break
	if not isExist:
		var index = self.add_item(friend.user.username)
		if friend.user.avatar_url:
			var ret = await Util.load_texture_async(friend.user.avatar_url)
			if ret:
				self.set_item_icon(index, ret)
		self.set_item_metadata(index, friend)
	pass
func _on_del_item_data(friend):
	# 遍历所有项目
	for i in range(self.item_count):
		var item_meta = self.get_item_metadata(i)  # 获取项目元数据
		if item_meta and item_meta.user.username == friend.user.username:
			self.remove_item(i)
			break
	pass

func _on_modify_item_data(friend):
	# 遍历所有项目
	for i in range(self.item_count):
		var item_meta = self.get_item_metadata(i)  # 获取项目元数据
		if item_meta and item_meta.user.username == friend.user.username:
			self.set_item_metadata(i,friend)
			self.set_item_text(i, friend.user.username)
			if friend.user.avatar_url:
				var ret = await Util.load_texture_async(friend.user.avatar_url)
				if ret:
					self.set_item_icon(i, ret)
			break
	pass
func _on_find_item_data(friend):
	for i in range(self.item_count):
		var item_meta = self.get_item_metadata(i)  # 获取项目元数据
		if item_meta and item_meta.user.username == friend.user.username:
			break
	pass



#################
func _on_item_selected(index: int):
	# 保存选中项的索引
	selected_index = index

	var friend = self.get_item_metadata(selected_index)
	if friend:
		print("选中项索引：", index,"-->", friend.user)
		await OnlineChat.set_current_channel(friend.channel, true) 
	pass
 
func _on_item_list_gui_input(event: InputEvent):
	if event is InputEventMouseButton and selected_index != -1:
		# 确保有项目被选中
		if event.double_click:
			showPopup(selected_index)
		# if event.pressed  and selected_index != -1:
		# 	if  event.button_index == MOUSE_BUTTON_RIGHT:
		# 		showPopup(selected_index)
		# 	else:
		# 		press_start_time = Time.get_ticks_msec()
		# else:
		# 	var press_duration = (Time.get_ticks_msec() - press_start_time) / 1000.0
		# 	if press_duration >= long_press_time and selected_index != -1:
		# 		showPopup(selected_index)
	pass

func showPopup(index:int):
	var friend = self.get_item_metadata(index)
	if not friend:
		return
	checkState(friend.state)
	# 显示弹出菜单在鼠标位置
	popup_menu.position = get_viewport().get_mouse_position()
	popup_menu.popup()	

func _on_popup_menu_item_selected(id: int):
	# 处理"删除"选项
	var itemname = popup_menu.get_item_text(id)
	match itemname:
		addname:
			# 处理"新增"选项
			# 在这里添加你的代码来处理新增选项
			PopupManager.show_confirm("确定新增吗？", _add_item, "确认")
			print("新增")
		delname:
			# 处理"删除"选项
			# 在这里添加你的代码来处理删除选项
			print("删除")
			PopupManager.show_confirm("确定删除吗？", _delete_item, "确认")
		modifyname:
			# 处理"修改"选项
			# 在这里添加你的代码来处理修改选项
			print("修改")
		findName:
			# 处理"查询"选项
			# 在这里添加你的代码来处理查询选项
			print("查询")
		agreeName:
			# 处理"同意"选项
			# 在这里添加你的代码来处理同意选项
			print("同意")
			PopupManager.show_confirm("确定同意吗？", _add_item, "确认")
		refuseName:
			# 处理"拒绝"选项
			# 在这里添加你的代码来处理拒绝选项
			print("拒绝")
			PopupManager.show_confirm("确定拒绝吗？", _refuse_item, "确认")
		blockName:
			# 处理"拉黑"选项
			# 在这里添加你的代码来处理拉黑选项
			print("拉黑")
			PopupManager.show_confirm("确定要拉黑该用户吗？", _block_item, "确认")
			# _refuse_item()
		
	if id == 0 and selected_index != -1: # 第一个菜单项且有选中的项目
		# 如果你使用 Nakama，这里可以添加删除好友的网络请求
		# await nakama_client.remove_friend(friend_id)
		pass
	pass

func _add_item():
	match listType:
		0:
			var friend = self.get_item_metadata(selected_index)
			print("新增好友", friend)
			if friend:
				var ret = await Online.nakama_client.add_friends_async(Online.nakama_session,[friend.user.id])
				if ret:
					_on_add_item_data(friend)
				else:
					print("失败")
			print("新增好友")
		1:
			print("新增俱乐部")
		2:
			print("新增组员")
		3:
			print("新增房间")
	pass	

# 拒绝或拉黑好友	
func _refuse_item():
	var ret: bool = false
	match listType:
		0:
			var friend = self.get_item_metadata(selected_index)
			print("拒绝好友", friend)
			if friend: 
				ret = await Online.nakama_client.refuse_friends_async(friend.user.id)
				SignalManager.FreshFriendListSIG.emit()
		1:
			print("拒绝俱乐部")
			var group = self.get_item_metadata(selected_index)
			if group:
				ret = await Online.nakama_client.remove_group(group.id)
				SignalManager.FreshClubListSIG.emit()
		2:
			print("拒绝组员")
		3:
			print("拒绝房间")
		# 从列表中移除项目
	if ret:
		self.remove_item(selected_index)
		PopupManager.show_message("已拒绝")
		selected_index = -1 # 重置选中索引
	pass

# 拉黑好友	
func _block_item():
	var ret: bool = false
	match listType:
		0:
			var friend = self.get_item_metadata(selected_index)
			print("拉黑好友", friend)
			if friend: 
				ret = await Online.nakama_client.refuse_friends_async(friend.user.id)
				SignalManager.FreshFriendListSIG.emit()
		1:
			print("拉黑俱乐部")
			var group = self.get_item_metadata(selected_index)
			if group:
				ret = await Online.nakama_client.remove_group(group.id)
				SignalManager.FreshClubListSIG.emit()
		2:
			print("拉黑组员")
		3:
			print("拉黑房间")
		# 从列表中移除项目
	if ret:
		self.remove_item(selected_index)
		PopupManager.show_message("已拉黑")
		selected_index = -1 # 重置选中索引
	pass


func _delete_item():
	var ret: bool = false
	match listType:
		0:
			var friend = self.get_item_metadata(selected_index)
			print("删除好友", friend)
			if friend:
				ret = await Online.nakama_client.remove_friend(friend.user.id)
		1:
			print("删除俱乐部")
			var group = self.get_item_metadata(selected_index)
			if group:
				ret = await Online.nakama_client.remove_group(group.id)
		2:
			print("删除组员")
		3:
			print("删除房间")
		# 从列表中移除项目
	if ret:
		self.remove_item(selected_index)
		PopupManager.show_message("删除成功")
		selected_index = -1 # 重置选中索引
	pass


func checkState(state: int):
	popup_menu.clear()
	match state:
		0:
			popup_menu.add_item(blockName)
		1:
			popup_menu.add_item(delname)
		2:
			popup_menu.add_item(agreeName)
			popup_menu.add_item(refuseName)
		3:
			popup_menu.add_item(delname)
	pass

func GetCurrentItemData():
	if selected_index != -1:
		return self.get_item_metadata(selected_index)
	return null


func close_color():
	is_active = false
	toggle_color()

func open_color():
	is_active = true
	toggle_color()

func toggle_color():
	# 如果已有正在进行的动画，先停止它
	# if tween and tween.is_valid():
	# 	tween.kill()
	
		# 设置面板样式
	var style = StyleBoxFlat.new()
	style.bg_color = custom_color if is_active else original_color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	add_theme_stylebox_override("panel", style)
	# # 创建新的颜色过渡动画
	# tween = create_tween()
	# if is_active:
	# 	tween.tween_property(self, "modulate", original_color, 0.3)
	# else:
	# 	tween.tween_property(self, "modulate", custom_color, 0.3)
	pass
