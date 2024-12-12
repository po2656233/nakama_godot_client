extends Button

@export var shake_amount := 5.0  # 抖动幅度
@export var shake_duration := 2  # 抖动持续时间
@export var shake_speed := 20.0  # 抖动速度
@export var normal_texture: Texture2D
@export var shake_texture: Texture2D

# @onready var normal_texture = preload("res://asset/currency/notify.svg")  # 替换成你的默认按钮图片路径
# @onready var shake_texture = preload("res://asset/currency/notification.svg")  # 替换成你的按下状态图片路径

signal shakeSIG() #抖动信号
signal lookSIG() #查看信号
signal newMsgSIG() #查看信号
# 是否抖动中
var _is_shaking := false
var _shake_time := 0.0
@export var _initial_position: Vector2
var _rng := RandomNumberGenerator.new()
var iconX:Texture2D


func _ready():
	if normal_texture:  # 如果在编辑器中选择了图片
		self.icon = normal_texture    # 设置按钮图标
	position = _initial_position
	pressed.connect(_on_button_pressed)
	shakeSIG.connect(_on_shaked)
	newMsgSIG.connect(_on_newMsg)

func _process(delta):
	if _is_shaking:
		_shake_time += delta * shake_speed
		# 使用正弦函数创造平滑的抖动效果
		var offset := Vector2(
 			_rng.randf_range(-shake_amount, shake_amount),
			_rng.randf_range(-shake_amount, shake_amount)
		)
		position = _initial_position + offset

func _on_button_pressed():
	if not _is_shaking:
		icon = normal_texture
		# 弹窗当前通知列表
		lookSIG.emit()
	_is_shaking = false
	position = _initial_position
	_is_shaking = false
	_shake_time = 0.0

func _on_shaked():
	print("震动")
	icon = shake_texture
	if not _is_shaking:
		_is_shaking = true
		_shake_time = 0.0
		if shake_texture:  # 如果在编辑器中选择了图片
			self.icon = shake_texture    # 设置按钮图标

func _on_newMsg():
	self.icon = shake_texture    # 设置按钮图标