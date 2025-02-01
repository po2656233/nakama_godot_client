extends Window

@onready var room_name_option = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/RoomNameOption
@onready var game_type_option = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/GameTypeOption
@onready var players_spin_box = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/PlayersOption/PlayersSpinBox
@onready var spectator_check = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/PlayersOption/SpectatorCheck
@onready var entry_fee_check = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/EntryFeeCheck
@onready var entry_fee_container = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/EntryFeeContainer
@onready var entry_fee_spin_box = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/EntryFeeContainer/EntryFeeSpinBox
@onready var tax_check = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/TaxCheck
@onready var tax_container = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/TaxContainer
@onready var tax_slider = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/TaxContainer/TaxSlider
@onready var tax_value_label = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/TaxContainer/TaxValue
@onready var game_mode_option = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/GameModeOption
@onready var game_section = $MarginContainer/Panel/VBoxContainer/ScrollContainer/GridContainer/GameSectionOption

@onready var cancel_button = $MarginContainer/Panel/VBoxContainer/ButtonSection/CancelButton
@onready var create_button = $MarginContainer/Panel/VBoxContainer/ButtonSection/CreateButton

signal room_created(room_data: Dictionary)

func _ready():
	# 设置窗口为模态
	exclusive = true
	# 连接信号
	# entry_fee_check.toggled.connect(_on_entry_fee_toggled)
	tax_check.toggled.connect(_on_tax_toggled)
	tax_slider.value_changed.connect(_on_tax_value_changed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	create_button.pressed.connect(_on_create_pressed)
	
	# # 初始化UI状态
	# entry_fee_container.visible = false
	tax_container.visible = false
	
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

# func _on_entry_fee_toggled(button_pressed: bool):
# 	entry_fee_container.visible = button_pressed
# 	pass

func _on_tax_toggled(button_pressed: bool):
	tax_container.visible = button_pressed

func _on_tax_value_changed(value: float):
	tax_value_label.text = "%.1f%%" % value

func _on_cancel_pressed():
	hide()
	# queue_free()

func _on_create_pressed():
	hide()
	# 模拟创建房间回包
	var creator_id = "0"
	if OnlineChat.player_data:
		creator_id = OnlineChat.player_data.id
	var gametype = game_type_option.get_selected_id()
	if gametype == -1:
		PopupManager.show_message("请选择游戏类型")
		await get_tree().create_timer(2.0).timeout
		show()
		return

	var room_data = {
		"room_id": "0000xxxx",
		"room_name": room_name_option.text,
		"game_type": game_type_option.get_selected_id(),
		"game_name": game_type_option.get_item_text(game_type_option.selected),
		"max_players": players_spin_box.value,
		"allow_spectators": spectator_check.button_pressed,
		"has_entry_fee": entry_fee_check.button_pressed,
		"entry_score": entry_fee_spin_box.value if entry_fee_check.button_pressed else 0,
		"base_score": 0,
		"has_tax": tax_check.button_pressed,
		"tax_rate": tax_slider.value if tax_check.button_pressed else 0,
		"game_mode": game_mode_option.get_selected_id(),
		"game_mode_text": game_mode_option.get_item_text(game_mode_option.selected),
		"match_rule":game_section.get_selected_id(),
		"match_rule_text": game_section.get_item_text(game_section.selected),

		"creator_id": creator_id,
		"current_round": 0,
		"player_count": 0,
		"status": "等待中",
		"create_time": "2024-01-08 10:45:00",
		"description": "适合新手的21点游戏房间",
		"rules": ["基础规则", "新手教学"],
		"players": ["新手A", "新手B"],
		"favorite": false,
	}
	print("创建房间数据: ", room_data)
	room_created.emit(room_data)
	hide()
	# queue_free()

# 添加验证方法
func _validate_room_data() -> bool:
	if entry_fee_check.button_pressed and entry_fee_spin_box.value <= 0:
		_show_error("请设置有效的入场分")
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
