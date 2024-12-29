extends Window

@onready var game_type_option = $MarginContainer/ScrollContainer/VBoxContainer/GameTypeSection/GameTypeOption
@onready var players_spin_box = $MarginContainer/ScrollContainer/VBoxContainer/PlayersSection/PlayersSpinBox
@onready var spectator_check = $MarginContainer/ScrollContainer/VBoxContainer/SpectatorSection/SpectatorCheck
@onready var entry_fee_check = $MarginContainer/ScrollContainer/VBoxContainer/EntryFeeSection/EntryFeeCheck
@onready var entry_fee_container = $MarginContainer/ScrollContainer/VBoxContainer/EntryFeeSection/EntryFeeContainer
@onready var entry_fee_spin_box = $MarginContainer/ScrollContainer/VBoxContainer/EntryFeeSection/EntryFeeContainer/EntryFeeSpinBox
@onready var tax_check = $MarginContainer/ScrollContainer/VBoxContainer/TaxSection/TaxCheck
@onready var tax_container = $MarginContainer/ScrollContainer/VBoxContainer/TaxSection/TaxContainer
@onready var tax_slider = $MarginContainer/ScrollContainer/VBoxContainer/TaxSection/TaxContainer/TaxSlider
@onready var tax_value_label = $MarginContainer/ScrollContainer/VBoxContainer/TaxSection/TaxContainer/TaxValue
@onready var game_mode_option = $MarginContainer/ScrollContainer/VBoxContainer/GameModeSection/GameModeOption
@onready var game_section = $MarginContainer/ScrollContainer/VBoxContainer/GameSection/GameSectionOption

@onready var cancel_button = $MarginContainer/ScrollContainer/VBoxContainer/ButtonSection/CancelButton
@onready var create_button = $MarginContainer/ScrollContainer/VBoxContainer/ButtonSection/CreateButton

signal room_created(room_data: Dictionary)

func _ready():
	# 设置窗口为模态
	self.exclusive = true
	
	# 连接信号
	entry_fee_check.toggled.connect(_on_entry_fee_toggled)
	tax_check.toggled.connect(_on_tax_toggled)
	tax_slider.value_changed.connect(_on_tax_value_changed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	create_button.pressed.connect(_on_create_pressed)
	
	# 初始化UI状态
	entry_fee_container.visible = false
	tax_container.visible = false
	
	# 设置窗口在屏幕中央
	var screen_size = DisplayServer.screen_get_size()
	position = (screen_size - size) / 2

func _on_entry_fee_toggled(button_pressed: bool):
	entry_fee_container.visible = button_pressed

func _on_tax_toggled(button_pressed: bool):
	tax_container.visible = button_pressed

func _on_tax_value_changed(value: float):
	tax_value_label.text = "%.1f%%" % value

func _on_cancel_pressed():
	hide()
	# queue_free()

func _on_create_pressed():
	var room_data = {
		"game_type": game_type_option.get_selected_id(),
		"game_type_text": game_type_option.get_item_text(game_type_option.selected),
		"players": players_spin_box.value,
		"allow_spectators": spectator_check.button_pressed,
		"has_entry_fee": entry_fee_check.button_pressed,
		"entry_fee": entry_fee_spin_box.value if entry_fee_check.button_pressed else 0,
		"has_tax": tax_check.button_pressed,
		"tax_rate": tax_slider.value if tax_check.button_pressed else 0,
		"game_mode": game_mode_option.get_selected_id(),
		"game_mode_text": game_mode_option.get_item_text(game_mode_option.selected),
		"match_rule":game_section.get_selected_id(),
		"match_rule_text": game_section.get_item_text(game_section.selected),
	}
	
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
