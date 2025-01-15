extends Node2D

signal timeout


@onready var progress_circle = $ProgressCircle
@onready var time_label = $TimeLabel
@onready var animation_player = $AnimationPlayer
@onready var tick_sound = $TickSound
@onready var timeout_sound = $TimeoutSound
@onready var timerover_sound = $TimeoverSound
@onready var timer = $Timer

var time_left: float = 20.0
var is_running: bool = false

func _ready():
	# start()
	pass
	
func _process(_delta):
	if time_left <= 10.0 and is_running:
		var intensity = (10.0 - time_left) / 10.0
		animation_player.speed_scale = 1.0 + intensity  # 减小动画速度变化范围
		if not animation_player.is_playing():
			animation_player.play("pulse")
	


func update_time_label():
	var minutes = floor(time_left / 60)
	var seconds = int(time_left) % 60

	
	# 根据剩余时间更新颜色 - 使用更暖的颜色
	if time_left <= 10.0:
		time_label.label_settings.font_color = Color.RED
		time_label.label_settings.font_size = 50
		time_label.text = "%2d" % [seconds]
	else:
		time_label.text = "%02d:%02d" % [minutes, seconds]
	pass

func start(total_time:float = 20.0):
	is_running = true
	time_left = total_time
	timer.start()
	update_time_label()
	pass
	
func stop():
	is_running = false
	timer.stop()
	animation_player.stop()
	update_time_label()
	pass

func _on_timer_timeout():
	print("计时器超时")
	time_left -= 1.0
	update_time_label()
	
	# 在最后10秒开始视觉和听觉反馈
	animation_player.stop()
	if time_left <= 10.0:
		if time_left == 0.0:
			timerover_sound.play()
			timeout.emit()
			stop()
		else:
			timeout_sound.play()  # 播放滴答声
	else:
		tick_sound.play()
	pass 

