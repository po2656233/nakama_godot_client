extends Control

@onready var progress_bar = $Panel/MarginContainer/HBoxContainer/VBoxContainerInfo/ProgressBar
@onready var experience = $Panel/MarginContainer/HBoxContainer/VBoxContainerInfo/ProgressBar/experience
@onready var headIcon = $Panel/MarginContainer/HBoxContainer/TR_HEAD
@onready var username = $Panel/MarginContainer/HBoxContainer/VBoxContainerInfo/account
@onready var nickname = $Panel/MarginContainer/HBoxContainer/VBoxContainerInfo/HBoxContainer/nickname
# 导出变量，方便在编辑器中调整
@export_group("Experience Settings")
@export var exp_max := 100
@export var exp_current := 0.0
@export var exp_step := 10  # 每次增加的经验值
@export var text_prefix := "经验值"  # 可自定义前缀文本
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print('当前玩家信息',Network.player_data)
	nickname.text = ''
	if Network.player_data:
		username.text = Network.player_data.username
		if Network.player_data.avatar_url:
			headIcon.texture = await Network.load_texture_async(Network.player_data.avatar_url)
		if Network.player_data.display_name:
			nickname.text = Network.player_data.display_name
	 # 初始化进度条
	init_progress_bar()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



func init_progress_bar():
	# 初始化进度条
	progress_bar.max_value = exp_max
	progress_bar.value = exp_current
	# 连接信号
	progress_bar.value_changed.connect(update_progress_text)
	# 初始化显示
	update_progress_text(exp_current)

# 更新经验值
func update_exp(new_exp: float) -> void:
	exp_current = clampf(new_exp, 0, exp_max)  # 确保值在有效范围内
	progress_bar.value = exp_current

# 更新进度条文本
func update_progress_text(_value: float) -> void:
	experience.text = "%s %d/%d" % [text_prefix, progress_bar.value, progress_bar.max_value]

# 增加经验值（可绑定到按钮）
func add_exp() -> void:
	update_exp(exp_current + exp_step)

# 减少经验值（可选）
func reduce_exp() -> void:
	update_exp(exp_current - exp_step)
