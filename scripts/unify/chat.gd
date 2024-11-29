extends Control

@onready var addfirendPanle = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/AddFirends
@onready var addclubPanle = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/AddClub
@onready var friendListItem = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/Panel_friends/VBoxContainer/ItemList
@onready var clubListItem = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/Panel_clubs/VBoxContainer/ItemList
@onready var findFriend = $MarginContainer/Panel/TabContainer/friends/HSplitContainerFriends/HSplitContainer/AddFirends
@onready var findClub = $MarginContainer/Panel/TabContainer/club/HSplitContainerClub/HSplitContainer/AddClub
signal fullscreen_changed(is_fullscreen: bool)

@export var toggle_button_path: NodePath
@export var animate_transition: bool = true
@export var transition_duration: float = 0.3

var original_state := {
	"parent": null,
	"position": Vector2.ZERO,
	"size": Vector2.ZERO,
	"anchors": {},
	"margins": {}
}
var is_fullscreen := false
var is_rotated = false
var tween: Tween
var button: Button


# 初始化
func _ready():
	# 取消窗口拖动
	WindowDrag.unregister_drag_zone(self)
	if toggle_button_path:
		button = get_node(toggle_button_path)
		if button:
			button.pressed.connect(_on_fullscreen_toggle)
	else:
		# 如果没有指定按钮，创建一个默认的
		button = Button.new()
		button.text = "全屏切换"
		button.pressed.connect(_on_fullscreen_toggle)
		add_child(button)
    # 设置旋转中心点
	set_rotation_pivot()
	# 获取好友列表
	get_friends_list()
	findFriend.addItemSig.connect(_on_add_friend)
	findClub.addItemSig.connect(_on_add_club)

func _on_add_friend(friend):
	print("聊天正在添加好友",friend)
	friendListItem.addItemData.emit(friend)
	pass

func _on_add_club(club):
	print(club)
	clubListItem.addItemData.emit(club)
	pass

func _on_fullscreen_toggle():
	if !is_fullscreen:
		enter_fullscreen()
	else:
		exit_fullscreen()

func enter_fullscreen():
	if is_fullscreen:
		return
		
	# 保存当前状态
	save_current_state()
	
	# 准备全屏状态
	var viewport = get_viewport()
	if viewport:
		var target_size = viewport.get_visible_rect().size
		var target_position = Vector2.ZERO
		
		if animate_transition:
			animate_to_fullscreen(target_position, target_size)
		else:
			apply_fullscreen(target_position, target_size)

func exit_fullscreen():
	if !is_fullscreen:
		return
		
	if animate_transition:
		animate_to_normal()
	else:
		restore_original_state()

func save_current_state():
	var parent = get_parent()
	if parent:
		original_state.parent = parent
		original_state.position = position
		original_state.size = size
		original_state.anchors = {
			"left": anchor_left,
			"right": anchor_right,
			"top": anchor_top,
			"bottom": anchor_bottom
		}
		original_state.margins = {
			"left": offset_left,
			"right": offset_right,
			"top": offset_top,
			"bottom": offset_bottom
		}

func apply_fullscreen(target_position: Vector2, target_size: Vector2):
	var viewport = get_viewport()
	if !viewport:
		return
		
	# 保存当前父节点引用
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
		
		# 设置全屏属性
		viewport.add_child(self)
		position = target_position
		size = target_size
		anchors_preset = Control.PRESET_FULL_RECT
		
		# 确保显示在最上层
		top_level = true
		
		# 更新状态
		is_fullscreen = true
		emit_signal("fullscreen_changed", true)

func animate_to_fullscreen(target_position: Vector2, target_size: Vector2):
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 先设置top_level确保在最上层
	top_level = true
	
	# 动画过渡到全屏
	tween.tween_property(self, "position", target_position, transition_duration)
	tween.parallel().tween_property(self, "size", target_size, transition_duration)
	
	tween.tween_callback(func():
		var viewport = get_viewport()
		if viewport and original_state.parent:
			if get_parent() != viewport:
				original_state.parent.remove_child(self)
				viewport.add_child(self)
			anchors_preset = Control.PRESET_FULL_RECT
			is_fullscreen = true
			emit_signal("fullscreen_changed", true)
	)

func animate_to_normal():
	if !original_state.parent:
		return
		
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 动画过渡到原始状态
	tween.tween_property(self, "position", original_state.position, transition_duration)
	tween.parallel().tween_property(self, "size", original_state.size, transition_duration)
	
	tween.tween_callback(func():
		restore_original_state()
	)

func restore_original_state():
	if !original_state.parent:
		return
		
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	
	# 恢复到原始父节点
	original_state.parent.add_child(self)
	
	# 恢复原始属性
	position = original_state.position
	size = original_state.size
	anchor_left = original_state.anchors.left
	anchor_right = original_state.anchors.right
	anchor_top = original_state.anchors.top
	anchor_bottom = original_state.anchors.bottom
	offset_left = original_state.margins.left
	offset_right = original_state.margins.right
	offset_top = original_state.margins.top
	offset_bottom = original_state.margins.bottom
	
	# 重置顶层显示
	top_level = false
	
	is_fullscreen = false
	emit_signal("fullscreen_changed", false)

###################################################
# 以下是按钮事件处理函数
func get_friends_list():
	var friendlist = await Network.get_friends_list()
	if friendlist:
		print(friendlist)
		friendListItem.clear()
		for friend in friendlist.friends:
			var user = friend.user
			var username = user.username
			var friend_status = "在线" if user.online else "离线"
			if user.display_name:
				username += '('+user.display_name+')'
			username += '['+friend_status+']'
			var index = friendListItem.add_item(username)
			if user.avatar_url:
				var texture = await Network.load_texture_async(user.avatar_url)
				if texture:
					friendListItem.set_item_icon(index,texture)
			friendListItem.set_item_metadata(index,user)
	print("获取好友列表")
	pass

###################################################
func _on_show_addfriend_pressed() -> void:
	if addfirendPanle.visible:
		addfirendPanle.hide()
	else:
		addfirendPanle.show()
	pass # Replace with function body.


func _on_show_addclub_pressed() -> void:
	if addclubPanle.visible:
		addclubPanle.hide()
	else:
		addclubPanle.show()
	pass # Replace with function body.


func _on_btn_popup_pressed() -> void:
	_on_fullscreen_toggle()
    # 来回旋转按钮
	button.rotation_degrees += 45
    
    # 如果要添加动画效果
	# tween = create_tween()
	# tween.tween_property(button, "rotation_degrees", 90, 0.5)
	pass # Replace with function body.


#######################弹窗按钮旋转###############################
# 设置旋转中心点
func set_rotation_pivot():
	# 设置旋转中心为按钮中心
	button.pivot_offset = button.size / 2