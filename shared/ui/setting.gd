extends Control

@onready var menuBtn = $HBoxContainerRightTop/MB_setting
@onready var notifyBtn = $btn_what
@onready var emailBtn = $HBoxContainerRightTop/btn_email
@onready var fullBtn = $HBoxContainerRightTop/btn_full


var mail_scene = load("res://lobby/email/mail.tscn")
var novolume = preload("res://assets/currency/novolume.png")
var volume = preload("res://assets/currency/volume.png")


# 存储所有菜单项的信息
var menu_items = []
var hidden_indices = []  # 存储需要隐藏的索引

# Called when the node enters the scene tree for the first time.
func _ready() -> void: 
	var isMute = Global.DataMgr.get_instance().get_isMute()
	print("当前是否禁音:",isMute)
	Global.SignalMgr.MuteSIG.emit(isMute)
	Global.SignalMgr.BackgroundMusicSIG.emit(isMute)
	
	var popup_menu = menuBtn.get_popup()
	popup_menu.index_pressed.connect(on_setting_pressed)
	for i in popup_menu.item_count:
		popup_menu.set_item_icon_max_width(i, 80)
		var icon = popup_menu.get_item_icon(i)
		menu_items.append({
			"text": popup_menu.get_item_text(i),
			"id": popup_menu.get_item_id(i),
			"icon": icon,
			"submenu": popup_menu.get_item_submenu(i),
			"metadata": popup_menu.get_item_metadata(i)
			})
	# 连接菜单打开信号
	_rebuild_menu()
	popup_menu.about_to_popup.connect(_rebuild_menu)

	notifyBtn.lookSIG.connect(_on_look_notify)
	emailBtn.lookSIG.connect(_on_look_email)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(_delta: float) -> void:
	#pass



# 隐藏指定索引的菜单项
func hide_menu_item(index: int):
	if index not in hidden_indices:
		hidden_indices.append(index)
	_rebuild_menu()

# 显示指定索引的菜单项
func show_menu_item(index: int):
	hidden_indices.erase(index)
	_rebuild_menu()

# 重建菜单
func _rebuild_menu():
	if not menuBtn:
		return
	var popup = menuBtn.get_popup()
	var isMute = Global.DataMgr.get_instance().get_isMute()
	var icon = volume if isMute else novolume
	var text = "打开音量" if isMute else "关闭音量"
	popup.clear()

	
	# 重新添加未隐藏的菜单项
	for i in range(menu_items.size()):
		if i == 0:
			popup.add_item(text, 0)
			popup.set_item_icon(0,icon) 
			popup.set_item_icon_max_width(0, 80)
		elif i not in hidden_indices:
			var item = menu_items[i]
			if item.submenu.is_empty():
				popup.add_item(item.text, item.id)
				var idx = popup.item_count - 1
				if item.icon:
					popup.set_item_icon(idx, item.icon)
				if item.metadata != null:
					popup.set_item_metadata(idx, item.metadata)
				popup.set_item_icon_max_width(idx, 80)
			else:
				popup.add_submenu_item(item.text, item.submenu, item.id)
	pass
##############################################################################

# 显示邮件系统
func show_mail():
	if mail_scene and not mail_scene.visible:
		mail_scene.show()  # 或者 mail_scene.visible = true

# 隐藏邮件系统
func hide_mail():
	if mail_scene:
		mail_scene.hide()  # 或者 mail_scene.visible = false

# 切换显示/隐藏状态
func toggle_mail():
	if mail_scene:
		mail_scene.visible = !mail_scene.visible

# 禁用返回主页
func noReback():
	# showNotify(false)
	hide_menu_item(4)
	pass


# 没有返回主页
func noHome():
	print("没有返回主页")
	hide_menu_item(3)
	pass

# 登录
func simple():
	hide_menu_item(2)
	hide_menu_item(4)
	showNotify(false)
	pass

func on_setting_pressed(index: int) -> void:
	var popup_menu = menuBtn.get_popup()
	var check:bool = popup_menu.is_item_checked(index)
	var new_check:bool = not check
	popup_menu.set_item_checked(index, new_check)
	Global.WindowDrag.dragging = false
	print("Setting pressed ",index)
	var id = popup_menu.get_item_id(index)
	match id:
		0:
			var isMute = Global.DataMgr.get_instance().get_isMute()
			isMute = !isMute
			print("是否禁音: ",isMute)
			Global.DataMgr.get_instance().set_isMute(isMute)
			Global.SignalMgr.BackgroundMusicSIG.emit(isMute)
			Global.SignalMgr.MuteSIG.emit(isMute)
			_rebuild_menu()
			# var hints = "打开音量" if isMute else "关闭音量"
			# popup_menu.set_item_text(index, hints)
			# popup_menu.set_item_icon(index, volume if isMute else novolume)
			pass
		2:#返回登录页
			Global.OnlineLogin.logout() 
			Global.SceneMgr.switch_to_scene("login",Global.SceneMgr.get_transition_key("WIPE_LEFT"),0.5)
		# 	pass
		3:# 退出
			get_tree().quit()
			print("退出游戏")
			pass
		4:#返回主页
			Global.SceneMgr.switch_to_scene("home",Global.SceneMgr.get_transition_key("WIPE_LEFT"),0.5)
		_:
			print("Setting error",index)
			pass
	pass

func _on_btn_full_pressed() -> void:
	if Window.MODE_FULLSCREEN == get_window().mode:
		restore_window()
	else:
		maximize_window()
	pass # Replace with function body.


# 最大化窗口
func maximize_window():
	get_window().mode = Window.MODE_FULLSCREEN 
	
# 最小化窗口
func minimize_window():
	get_window().mode = Window.MODE_MINIMIZED
	
# 恢复窗口(恢复到普通窗口模式)
func restore_window():
	get_window().mode = Window.MODE_WINDOWED

##########################################


#############################
func _on_btn_notify_pressed() -> void:
	#铃铛停止播放
	Global.SignalMgr.NewNotifySIG.emit(false)
	pass # Replace with function body.


func _on_btn_email_pressed() -> void:
	pass # Replace with function body.

func _on_look_notify()->void:
	Global.SceneMgr.show_scene_in_center("approval",0.9)
	pass

func _on_look_email()->void:
	Global.SceneMgr.show_scene_in_center("email")
	# Global.FancyFade.wipe_left(mail_scene.instantiate(),0.5)
	pass
#######################################
func showNotify(isShow:bool):
	if notifyBtn:
		notifyBtn.visible = isShow
	if emailBtn:
		emailBtn.visible = isShow
	# fullBtn.visible = isShow
	pass
