extends Control

@onready var progress_bar = $ProgressBar
@onready var percentage_label = $PercentageLabel
@onready var status_label = $StatusLabel
@onready var water_sound = $WaterSound

var progress_speed = 0.5
var target_value = 100.0
var current_status = ""
var is_animating = false

var status_messages = [
	"注入能量中...",
	"填充系统资源...",
	"准备完成！"
]

func _ready():
	# 初始化垂直进度条
	progress_bar.value = 0
	progress_bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	percentage_label.text = "0%"
	status_label.text = ""
	
	# 动画效果
	$AnimationPlayer.play("idle")
	
	# 开始模拟加载过程
	start_loading_simulation()

func _process(delta):
	# 平滑更新进度条值
	if progress_bar.value <= target_value:
		progress_bar.value = min(progress_bar.value + progress_speed * delta, target_value)
		update_percentage_label()
		
		# 检查是否需要更新状态消息
		update_status_based_on_progress()
		
		# 根据进度调整水声音效大小
		if water_sound.playing:
			water_sound.volume_db = lerp(-20.0, -10.0, progress_bar.value)

func update_percentage_label():
	var percentage = int(progress_bar.value)
	percentage_label.text = str(percentage) + "%"
	
	# 根据进度调整标签位置
	var bar_height = progress_bar.size.y
	var fill_height = bar_height * progress_bar.value
	var min_y = progress_bar.position.y + 20
	var max_y = progress_bar.position.y + bar_height - 40
	
	# 使标签位置跟随液面高度
	var label_y = max_y - fill_height
	label_y = clamp(label_y, min_y, max_y)
	percentage_label.position.y = label_y
	
func update_status_based_on_progress():
	var new_status = ""
	
	if progress_bar.value < 40:
		new_status = status_messages[0]
	elif progress_bar.value < 80:
		new_status = status_messages[1]
	else:
		new_status = status_messages[2]
		
	if new_status != current_status:
		current_status = new_status
		status_label.text = current_status
		# 播放状态变化的动画
		$StatusAnimation.play("status_change")

func start_loading_simulation():
	# 开始播放水流声
	water_sound.play()
	
	# 模拟多阶段加载过程
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", 30, 1.5)
	tween.tween_interval(0.5)
	tween.tween_property(progress_bar, "value", 60, 1.8)
	tween.tween_interval(0.3)
	tween.tween_property(progress_bar, "value", 90, 1.2)
	tween.tween_interval(0.4)
	tween.tween_property(progress_bar, "value", 100.0, 0.8)
	tween.tween_interval(0.5)
	tween.tween_callback(Callable(self, "loading_complete"))

func loading_complete():
	# 停止水流声
	var sound_fade = create_tween()
	sound_fade.tween_property(water_sound, "volume_db", -30.0, 1.0)
	sound_fade.tween_callback(Callable(water_sound, "stop"))
	
	# 加载完成，播放完成动画
	$AnimationPlayer.play("complete")
	progress_bar.value = target_value
	
	# 3秒后切换到主场景（示例）
	await get_tree().create_timer(3.0).timeout

	print("加载完成，可以切换到主场景了")
	
	# 实际项目中，这里会切换到主场景
	# get_tree().change_scene_to_file("res://scenes/main_game.tscn") 
