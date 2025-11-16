extends PanelContainer

signal game_selected(itemNode)

@onready var gameTitle = $Front/Control/GameFront/GameTitle
@onready var gameImage = $Front/Control/GameFront/GameImage
@onready var gameBack = $Back
@onready var gameFrontImage = $Front/Control/GameFront
@onready var gameBackImage = $Back/Control/GameBack


@onready var gameFront = $Front
@onready var introduceTitle = $Back/Control/GameBack/Introduce
@onready var description = $Back/Control/GameBack/MarginContainer/Description
@onready var animation = $AnimationPlayer
# @onready var dragonBonesDibeichang = $Front/Control/MarginContainer/DragonBonesDibeichang
# @onready var dragonBonesJiangbei = $Front/Control/MarginContainer/DragonBonesJiangbei
# @onready var dragonBonesPuke = $Front/Control/MarginContainer/DragonBonesPuke
@onready var version = $Version
@onready var dragonBones1 = $Front/Control/GameFront/DragonBonesDibeichang
@onready var dragonBones2 = 	$Front/Control/GameFront/DragonBonesJiangbei
@onready var dragonBones3 = 	$Front/Control/GameFront/DragonBonesPuke
@onready var dragonBones4 = 	$Front/Control/GameFront/DragonBonesBaoX1
@onready var dragonBones5 = 	$Front/Control/GameFront/DragonBonesBaoX2
@onready var dragonBones6 = 	$Front/Control/GameFront/DragonBonesBaoX3
@onready var dragonBones7 = 	$Front/Control/GameFront/DragonBonesBaoX4

var gameLogos = []
var game_data = {}
var is_flipped = true
var is_hovering = false
var is_animating = false

# 滑动相关变量
var drag_start_position = Vector2.ZERO
var is_dragging = false
var min_swipe_distance = 300  # 最小滑动距离
#
func _ready():
	gameLogos = [ dragonBones1, dragonBones2, dragonBones3, dragonBones4, dragonBones5, dragonBones6, dragonBones7]
	var index = randi() % 5
	if index == 1 and not Util.isFullScreen():
		index = 3
	_on_window_resized()
	gameFrontImage.texture = load("res://assets/game/flagItem/%d.png"%[randi() % 5])
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	 # 连接窗口大小改变信号
	get_viewport().connect("size_changed", _on_window_resized)
	

func _on_window_resized():
	# 当窗口大小改变时，重新设置最小尺寸
	set_custom_minimum_size(Vector2(get_viewport().size.x/3.5, get_viewport().size.y* 0.75))

func setup(data):
	game_data = data
	gameTitle.text = data.title
	introduceTitle.text = data.name
	description.text = data.description
	description.scroll_bar.value_changed.emit(0.0)
	var img = load("res://assets/game/flagItem/%d.png"%[randi() % 5])
	gameBackImage.texture = img
	# gameImage.texture = img
	if data.image:
		for dragonBones in gameLogos:
			Global.DataMgr.safe_free_node(dragonBones)
		gameImage.texture = await Util.load_texture_async(data.image,255,255)
	else:
		# gameImage.texture = img
		var logoLen = gameLogos.size()
		var index = randi() % logoLen
		for i in range(logoLen):#gameLogos:
			var dragonBones = gameLogos[i]
			if i == index:
				dragonBones.visible = true
				print(data.title,"-->", index)
			else:
				Global.DataMgr.safe_free_node(dragonBones)
	if data.version:
		version.text = "当前版本:"+data.version
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
				#accept_event()
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
