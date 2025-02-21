extends PanelContainer

signal game_selected(itemNode)

@onready var gameTitle = $Front/GameFront/GameTitle
@onready var gameImage = $Front/GameFront/GameImage
@onready var gameBack = $Back
@onready var gameFrontImage = $Front/GameFront
@onready var gameBackImage = $Back/GameBack


@onready var gameFront = $Front
@onready var introduceTitle = $Back/GameBack/Introduce
@onready var description = $Back/GameBack/MarginContainer/Description
@onready var animation = $AnimationPlayer
# @onready var dragonBonesDibeichang = $Front/MarginContainer/DragonBonesDibeichang
# @onready var dragonBonesJiangbei = $Front/MarginContainer/DragonBonesJiangbei
# @onready var dragonBonesPuke = $Front/MarginContainer/DragonBonesPuke
@onready var version = $Version
@onready var dragonBones1 = $Front/GameFront/DragonBonesDibeichang
@onready var dragonBones2 = 	$Front/GameFront/DragonBonesJiangbei
@onready var dragonBones3 = 	$Front/GameFront/DragonBonesPuke
@onready var dragonBones4 = 	$Front/GameFront/DragonBonesBaoX1
@onready var dragonBones5 = 	$Front/GameFront/DragonBonesBaoX2
@onready var dragonBones6 = 	$Front/GameFront/DragonBonesBaoX3
@onready var dragonBones7 = 	$Front/GameFront/DragonBonesBaoX4

var gameLogos = []
var game_data = {}
var is_flipped = true
var is_hovering = false
var is_animating = false

# 滑动相关变量
var drag_start_position = Vector2.ZERO
var is_dragging = false
var min_swipe_distance = 200  # 最小滑动距离
#
func _ready():
	gameLogos = [ dragonBones1, dragonBones2, dragonBones3, dragonBones4, dragonBones5, dragonBones6, dragonBones7]
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	gameFrontImage.texture = load("res://assets/game/flagItem/%d.png"%[randi() % 5])

func setup(data):
	game_data = data
	gameTitle.text = data.title
	introduceTitle.text = data.name
	description.text = data.description
	var img = load("res://assets/game/flagItem/%d.png"%[randi() % 5])
	gameBackImage.texture = img
	if data.image:
		for dragonBones in gameLogos:
			DataManager.safe_free_node(dragonBones)
		gameImage.texture = await Util.load_texture_async(data.image,300,300)
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
				DataManager.safe_free_node(dragonBones)
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
