extends PanelContainer

signal game_selected(itemNode)

@onready var description = $Back/MarginContainer/Description
@onready var gameTitle = $Front/GameTitle
@onready var gameImge = $Front/MarginContainer/GameImage
@onready var gameFront = $Front
@onready var gameBack = $Back
@onready var animation = $AnimationPlayer
@onready var dragonBonesDibeichang = $Front/MarginContainer/DragonBonesDibeichang
@onready var dragonBonesJiangbei = $Front/MarginContainer/DragonBonesJiangbei
@onready var dragonBonesPuke = $Front/MarginContainer/DragonBonesPuke

var game_data = {}
var is_flipped = true
var is_hovering = false
var is_animating = false

# 滑动相关变量
var drag_start_position = Vector2.ZERO
var is_dragging = false
var min_swipe_distance = 80  # 最小滑动距离

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func setup(data):
	game_data = data
	gameTitle.text = data.title
	description.text = data.description
	if data.image:
		gameImge.texture = data.image
		dragonBonesDibeichang.visible = false
		dragonBonesJiangbei.visible = false
		dragonBonesPuke.visible = false
	else:
		gameImge.visible = false
		var index = randi() % 3
		if index == 0:
			dragonBonesDibeichang.visible = true
			dragonBonesJiangbei.visible = false
			dragonBonesPuke.visible = false
		elif index == 1:
			dragonBonesJiangbei.visible = true
			dragonBonesDibeichang.visible = false
			dragonBonesPuke.visible = false
		else:
			dragonBonesPuke.visible = true
			dragonBonesJiangbei.visible = false
			dragonBonesDibeichang.visible = false

	pass

func flip():
	if is_animating:
		return
		
	is_animating = true
	animation.play("flip")
	
	# 在动画中间点切换正反面
	await get_tree().create_timer(0.4).timeout
	gameFront.visible = !is_flipped
	gameBack.visible = is_flipped
	is_flipped = !is_flipped
	
	await animation.animation_finished
	is_animating = false

func _on_gui_input(event):
	# 处理滚轮事件
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			# 如果卡片是翻转状态且描述文本有滚动条
			if description.get_v_scroll_bar().max_value > 0:
				get_viewport().set_input_as_handled()
				return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			 # 如果没有明显的拖动，则视为点击，且双击
			if event.double_click and  (event.position - drag_start_position).length() < min_swipe_distance:
				game_selected.emit(self)
				print("即将进入游戏", game_data["title"])
				return
			if event.pressed:
				# 开始拖动
				drag_start_position = event.position
				is_dragging = true
			else:
				# 结束拖动
				is_dragging = false
	
	elif event is InputEventMouseMotion and is_dragging:
		# 计算水平滑动距离
		var drag_distance = event.position.x - drag_start_position.x
		
		# 如果滑动距离超过阈值，触发翻转
		if abs(drag_distance) > min_swipe_distance:
			is_dragging = false  # 防止多次触发
			flip()

func _on_mouse_entered():
	if not is_hovering and not animation.is_playing():
		is_hovering = true
		animation.play("hover")

func _on_mouse_exited():
	if is_hovering:
		is_hovering = false
		scale = Vector2(1, 1)  # 直接重置缩放，不使用动画
	pass
