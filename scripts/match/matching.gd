extends Control

# 匹配状态
enum MatchState { IDLE, MATCHING, SUCCESS, FAILED }
var current_state: MatchState = MatchState.IDLE

# 计时相关变量
var elapsed_time: float = 0
var is_matching: bool = false

# 动画相关变量
var progress_rotation: float = 0
var progress_speed: float = 1.2
var progress_value: float = 0.0

# 节点引用
@onready var timer_label = $CenterContainer/VBoxContainer/TimerLabel
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var progress_circle = $CenterContainer/VBoxContainer/ProgressCircle
@onready var cancel_button = $CenterContainer/VBoxContainer/CancelButton
@onready var start_button = $CenterContainer/VBoxContainer/StartButton
@onready var animation_player = $AnimationPlayer
@onready var match_sound = $MatchSound
@onready var success_sound = $SuccessSound
@onready var fail_sound = $FailSound

func _ready():
    SettingsManager.show_settings(1)
    # 初始化UI状态
    reset_ui()
    # 连接信号
    cancel_button.pressed.connect(_on_cancel_button_pressed)
    start_button.pressed.connect(_on_start_button_pressed)
    
    # 测试模式：5-15秒后随机匹配成功或失败
    if OS.has_feature("editor"):
        await get_tree().create_timer(randf_range(5, 15)).timeout
        if randf() > 0.5:
            _on_match_success()
        else:
            _on_match_failed()

func _process(delta):
    if is_matching:
        elapsed_time += delta
        update_timer_display()
        
        # 更新进度圈
        progress_rotation += delta * progress_speed
        progress_value = fmod(progress_rotation, 1.0)
        progress_circle.material.set_shader_parameter("progress", progress_value)

func start_matching():
    current_state = MatchState.MATCHING
    is_matching = true
    status_label.text = "正在匹配中..."
    elapsed_time = 0
    cancel_button.visible = true
    start_button.visible = false
    animation_player.play("matching_pulse")
    match_sound.play()
    
    # 显示进度动画
    progress_circle.visible = true
    progress_rotation = 0
    progress_value = 0

func stop_matching():
    is_matching = false
    current_state = MatchState.IDLE
    reset_ui()
    animation_player.stop()
    match_sound.stop()

func reset_ui():
    status_label.text = "等待开始匹配..."
    timer_label.text = "00:00"
    cancel_button.visible = false
    start_button.visible = true
    progress_circle.visible = false
    progress_circle.material.set_shader_parameter("progress", 0.0)

func update_timer_display():
    var minutes = floor(elapsed_time / 60)
    var seconds = fmod(elapsed_time, 60)
    timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_cancel_button_pressed():
    stop_matching()
    
func _on_start_button_pressed():
    start_matching()

func _on_match_success():
    current_state = MatchState.SUCCESS
    is_matching = false
    status_label.text = "匹配成功！"
    cancel_button.visible = false
    animation_player.play("success_flash")
    progress_circle.visible = false
    match_sound.stop()
    success_sound.play()
    
    # 2秒后切换场景或显示其他UI
    await get_tree().create_timer(2.0).timeout

    # 这里添加切换到游戏场景的代码
    SceneManager.switch_to_scene("match_success","swirl",0.5) 
    print("切换到游戏场景")

func _on_match_failed():
    current_state = MatchState.FAILED
    is_matching = false
    status_label.text = "匹配失败，请重试"
    cancel_button.visible = false
    start_button.visible = true
    animation_player.play("failed_shake")
    progress_circle.visible = false
    match_sound.stop()
    fail_sound.play()