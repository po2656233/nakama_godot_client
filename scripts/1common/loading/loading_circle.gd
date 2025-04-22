extends Control

@onready var sphere_progress = $SphereProgress
@onready var percentage_label = $PercentageLabel
@onready var status_label = $StatusLabel
@onready var water_sound = $WaterSound

var progress_speed = 0.3
var target_value = 0.0
var current_status = ""
var is_animating = false

var status_messages = [
	"注入能量中...",
	"填充系统资源...",
	"准备完成！"
]

func _ready():
	# 初始化球状进度条
	sphere_progress.material.set_shader_parameter("progress", 0.0)
	percentage_label.text = "0%"
	status_label.text = ""
	
	# 动画效果
	$AnimationPlayer.play("idle")
	
	# 开始模拟加载过程
	start_loading_simulation()

func _process(delta):
	# 平滑更新进度值
	if sphere_progress.material.get_shader_parameter("progress") < target_value:
		var current_progress = sphere_progress.material.get_shader_parameter("progress")
		var new_progress = min(current_progress + progress_speed * delta, target_value)
		sphere_progress.material.set_shader_parameter("progress", new_progress)
		
		# 更新百分比标签
		update_percentage_label()
		
		# 检查是否需要更新状态消息
		update_status_based_on_progress()
		
		# 根据进度调整水声音效大小
		if water_sound.playing:
			water_sound.volume_db = lerp(-20.0, -10.0, new_progress)

func update_percentage_label():
	var progress = sphere_progress.material.get_shader_parameter("progress")
	var percentage = int(progress * 100)
	percentage_label.text = str(percentage) + "%"
	
func update_status_based_on_progress():
	var progress = sphere_progress.material.get_shader_parameter("progress")
	var new_status = ""
	
	if progress < 0.4:
		new_status = status_messages[0]
	elif progress < 0.8:
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
	tween.tween_property(self, "target_value", 0.3, 1.5)
	tween.tween_interval(0.5)
	tween.tween_property(self, "target_value", 0.6, 1.8)
	tween.tween_interval(0.3)
	tween.tween_property(self, "target_value", 0.9, 1.2)
	tween.tween_interval(0.4)
	tween.tween_property(self, "target_value", 1.0, 0.8)
	tween.tween_interval(0.5)
	tween.tween_callback(Callable(self, "loading_complete"))

func loading_complete():
	# 停止水流声
	var sound_fade = create_tween()
	sound_fade.tween_property(water_sound, "volume_db", -30.0, 1.0)
	sound_fade.tween_callback(Callable(water_sound, "stop"))
	
	# 确保进度为满
	sphere_progress.material.set_shader_parameter("progress", 1.0)
	
	# 加载完成，播放完成动画
	$AnimationPlayer.play("complete")
	
	# 3秒后切换到主场景（示例）
	await get_tree().create_timer(3.0).timeout
	print("加载完成，可以切换到主场景了")
	
	# 实际项目中，这里会切换到主场景
	# get_tree().change_scene_to_file("res://scenes/main_game.tscn") 
