extends Control

## 模块：来电/呼叫面板（PROMPT_REFACTOR 阶段 3，shared/ui/rtc/）
## 职责：展示来电/呼叫状态，并把接听/拒接/挂断转发给 Global.RtcSignaling。
## 用法：实例化后默认隐藏；收到 RtcSignaling.call_invited 自动显示。

var _panel: PanelContainer
var _title: Label
var _info: Label
var _accept_button: Button
var _reject_button: Button
var _hangup_button: Button

func _ready() -> void:
	_build_ui()
	visible = false
	if Global.has_global("RtcSignaling"):
		var signaling = Global.RtcSignaling
		signaling.call_invited.connect(_on_call_invited)
		signaling.call_accepted.connect(_on_call_accepted)
		signaling.call_rejected.connect(_on_call_rejected)
		signaling.call_ended.connect(_on_call_ended)
		signaling.state_changed.connect(_on_state_changed)

# ---------------------------------------------------------------------
# 对外
# ---------------------------------------------------------------------

## 主动呼叫某人（会立即发起 invite 并展示面板）。
func open_outgoing(peer_id: String, video: bool = false) -> void:
	if not Global.has_global("RtcSignaling"):
		return
	Global.RtcSignaling.invite(peer_id, video)
	visible = true
	_title.text = "正在呼叫…"
	_info.text = "对端：%s" % peer_id
	_set_buttons(false, true)

# ---------------------------------------------------------------------
# 信号回调
# ---------------------------------------------------------------------

func _on_call_invited(peer: String, video: bool) -> void:
	visible = true
	_title.text = "视频来电" if video else "语音来电"
	_info.text = "来自：%s" % peer
	_set_buttons(true, false)

func _on_call_accepted(peer: String) -> void:
	visible = true
	_title.text = "通话中"
	_info.text = "对端：%s" % peer
	_set_buttons(false, true)

func _on_call_rejected(_peer: String, _reason: String) -> void:
	visible = false

func _on_call_ended(_peer: String, _reason: String) -> void:
	visible = false

func _on_state_changed(state: int) -> void:
	if state == RtcProtocol.CallState.IDLE:
		visible = false

# ---------------------------------------------------------------------
# 按钮
# ---------------------------------------------------------------------

func _on_accept_pressed() -> void:
	if Global.has_global("RtcSignaling"):
		Global.RtcSignaling.accept()

func _on_reject_pressed() -> void:
	if Global.has_global("RtcSignaling"):
		Global.RtcSignaling.reject("declined")

func _on_hangup_pressed() -> void:
	if Global.has_global("RtcSignaling"):
		Global.RtcSignaling.hang_up()

func _set_buttons(incoming: bool, active: bool) -> void:
	_accept_button.visible = incoming
	_reject_button.visible = incoming or active
	_hangup_button.visible = active and not incoming
	_reject_button.text = "拒接" if incoming else "取消"

# ---------------------------------------------------------------------
# UI 构建（避免维护复杂 .tscn，占位组件用代码生成）
# ---------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(320, 160)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-160, -80)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	box.add_child(_title)

	_info = Label.new()
	_info.name = "Info"
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_info)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)

	_accept_button = _make_button("接听", buttons)
	_accept_button.pressed.connect(_on_accept_pressed)
	_reject_button = _make_button("拒接", buttons)
	_reject_button.pressed.connect(_on_reject_pressed)
	_hangup_button = _make_button("挂断", buttons)
	_hangup_button.pressed.connect(_on_hangup_pressed)

func _make_button(text: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(88, 36)
	parent.add_child(button)
	return button
