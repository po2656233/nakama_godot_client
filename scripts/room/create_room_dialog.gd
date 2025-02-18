extends Window

@onready var room_name_option = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/RoomNameOption
@onready var room_psw_option = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/RoomPasswordOption
@onready var game_type_option = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/GameTypeOption
@onready var players_spin_box = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/PlayersOption/PlayersSpinBox
@onready var spectator_check = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/PlayersOption/SpectatorCheck
@onready var base_score_spin_box = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/ScoreOption/BaseScoreSpinBox
@onready var entry_score_spin_box = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/ScoreOption/EntryScoreSpinBox
@onready var tax_check = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/TaxCheck
@onready var tax_container = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/TaxContainer
@onready var tax_slider = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/TaxContainer/TaxSlider
@onready var tax_value_label = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/TaxContainer/TaxValue
@onready var game_mode_option = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/GameModeOption
@onready var game_section = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/GameSectionOption

@onready var cancel_button = $MarginContainer/Panel/VBoxContainer/ButtonSection/CancelButton
@onready var create_button = $MarginContainer/Panel/VBoxContainer/ButtonSection/CreateButton

signal room_created(room_data)

func _ready():
	# 设置窗口为模态
	exclusive = true
	# 连接信号
	tax_check.toggled.connect(_on_tax_toggled)
	tax_slider.value_changed.connect(_on_tax_value_changed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	create_button.pressed.connect(_on_create_pressed)
	
	# # 初始化UI状态
	tax_container.visible = false
	var games = await OnlineGame.getGameList()
	for game in games:
		game_type_option.add_item(game.name,game.id)
		game_type_option.set_item_metadata(game_type_option.get_item_count() - 1, game) 
	_on_game_type_selected(0)
	# # 设置窗口在屏幕中央
	# var screen_size = DisplayServer.screen_get_size()
	# position = (screen_size - size) / 2


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER:
			if create_button:
				create_button.pressed.emit()
				get_viewport().set_input_as_handled()  # 阻止事件继续传递
		elif event.keycode == KEY_ESCAPE:
			if cancel_button:
				cancel_button.pressed.emit()
				get_viewport().set_input_as_handled()  # 阻止事件继续传递


func _on_tax_toggled(button_pressed: bool):
	tax_container.visible = button_pressed

func _on_tax_value_changed(value: float):
	tax_value_label.text = "%.1f%%" % value


func _on_game_type_selected(index: int):
	if game_type_option.item_count == 0:
		return
	var game = game_type_option.get_item_metadata(index)
	if game:
		if game.max_player != -1:
			players_spin_box.max_value = game.max_player
			players_spin_box.value = game.max_player
			players_spin_box.editable = false
			print("max_player: ", game.max_player)
		else:
			players_spin_box.value = game.max_player
			players_spin_box.editable = true


func _on_cancel_pressed():
	hide()

func _on_create_pressed():
	hide()
	# 模拟创建房间回包
	if not await _validate_room_data():
		return
	PopupManager.show_confirm("确定创建吗？", _create_room, "确认")
	pass

func _create_room():
	if Online.nakama_socket:
		# 匹配创建参数
		# var match_maker_ticket = await Online.nakama_socket.add_matchmaker_async()
		# print("匹配创建成功，票据: ", match_maker_ticket)

		# 服务端创建牌桌
		var res = await Online.nakama_socket.rpc_async("create_table",{
			"id": -1,
			"gid": game_type_option.get_selected_id(),
			"name": room_name_option.text,
			"key": room_psw_option.text,
			"mode": game_mode_option.get_selected_id(),
			"section":game_section.get_selected_id(),
			"enterScore": entry_score_spin_box.value,
			"baseScore": base_score_spin_box.value,
			"allowLookOn": spectator_check.button_pressed,
			"commission": tax_slider.value if tax_check.button_pressed else 0,
			"maxSitter": players_spin_box.value,
			"maxRound": -1,
			"openTime": 0,
			"closeTime": 0,
		})
		if res.is_exception():
			print("创建房间失败:",res.get_exception().message)
			PopupManager.show_dynamic("创建房间失败")
			return
		print("创建服务端托管成功",res)
		room_created.emit({})
	pass


# 添加验证方法
func _validate_room_data() -> bool:
	var gametype = game_type_option.get_selected_id()
	if gametype == -1:
		PopupManager.show_message("请选择游戏类型")
		await get_tree().create_timer(1.5).timeout
		show()
		return false
	if room_name_option.text == "":
		PopupManager.show_message("请输入房间名称")
		await get_tree().create_timer(1.5).timeout
		show()
		return false
	if entry_score_spin_box.value <= 0:
		_show_error("请设置有效的入场分")
		return false
	if players_spin_box.value < 1:
		_show_error("最少需要1名玩家")
		return false
	if base_score_spin_box.value < 0:
		_show_error("底分不能为负数")
		return false
	if tax_check.button_pressed and tax_slider.value < 0:
		_show_error("税率不能为负数")
		return false
	return true

func _show_error(message: String):
	var dialog = AcceptDialog.new()
	add_child(dialog)
	dialog.dialog_text = message
	dialog.popup_centered()



func _on_close_requested() -> void:
	hide()
	pass # Replace with function body.


func _on_text_edit_focus_entered() -> void:
	# 获取目标编辑控件的全局位置和大小
	if Util.isMobile():
		DisplayServer.virtual_keyboard_show("中文输入法") 
	pass # Replace with function body.
 
func _on_text_edit_focus_exited() -> void:
	if Util.isMobile():
		DisplayServer.virtual_keyboard_hide()
	pass # Replace with function body.
