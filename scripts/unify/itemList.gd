extends ItemList

@export var custom_color: Color = Color(0.8, 0.8, 1.0, 1.0)
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

var tween: Tween
var original_color: Color
var is_active: bool = false

func _ready():
	# 保存原始颜色
	original_color = modulate
	# 取消窗口拖动
	WindowDrag.unregister_drag_zone(self)
	# 创建弹出菜单
	popup_menu = PopupMenu.new()
	add_child(popup_menu)
	
	# 添加"删除"选项到弹出菜单
	popup_menu.size = Vector2(20, 10)
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
				var ret = await Network.load_texture_async(friend.user.avatar_url)
				if ret:
					self.set_item_icon(i, ret)
			break
	if not isExist:
		var index = self.add_item(friend.user.username)
		if friend.user.avatar_url:
			var ret = await Network.load_texture_async(friend.user.avatar_url)
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
				var ret = await Network.load_texture_async(friend.user.avatar_url)
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
		print("选中项索引：", index,"-->", friend.user.username)
		await Network.set_current_channel(friend.channel, true) 
	pass
 
func _on_item_list_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		# 确保有项目被选中
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and selected_index != -1:
			var friend = self.get_item_metadata(selected_index)
			if not friend:
				return
			checkState(friend.state)
			# 显示弹出菜单在鼠标位置
			popup_menu.position = get_viewport().get_mouse_position()
			popup_menu.popup()	
		pass
	pass

func _on_gui_input(event:InputEvent) -> void:
	_on_item_list_gui_input(event)
	# if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
	# 	toggle_color()
	# 	pass
	pass # Replace with function body.

func _on_popup_menu_item_selected(id: int):
	# 处理"删除"选项
	var itemname = popup_menu.get_item_text(id)
	match itemname:
		addname:
			# 处理"新增"选项
			# 在这里添加你的代码来处理新增选项
			_add_item()
			print("新增")
		delname:
			# 处理"删除"选项
			# 在这里添加你的代码来处理删除选项
			_delete_item()
			print("删除")
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
			_add_item()
		refuseName:
			# 处理"拒绝"选项
			# 在这里添加你的代码来处理拒绝选项
			print("拒绝")
			_refuse_item()
		blockName:
			# 处理"拉黑"选项
			# 在这里添加你的代码来处理拉黑选项
			print("拉黑")
			_refuse_item()
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
				var ret = await Network.add_friends_async(friend.user.id)
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
				ret = await Network.refuse_friends_async(friend.user.id)
		1:
			print("拒绝俱乐部")
			var group = self.get_item_metadata(selected_index)
			if group:
				ret = await Network.remove_group(group.id)
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



func _delete_item():
	var ret: bool = false
	match listType:
		0:
			var friend = self.get_item_metadata(selected_index)
			print("删除好友", friend)
			if friend:
				ret = await Network.remove_friend(friend.user.id)
		1:
			print("删除俱乐部")
			var group = self.get_item_metadata(selected_index)
			if group:
				ret = await Network.remove_group(group.id)
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




func toggle_color():
	is_active = !is_active
	# 如果已有正在进行的动画，先停止它
	if tween and tween.is_valid():
		tween.kill()
	
	# 创建新的颜色过渡动画
	tween = create_tween()
	if is_active:
		tween.tween_property(self, "modulate", original_color, 0.3)
	else:
		tween.tween_property(self, "modulate", custom_color, 0.3)
	pass

