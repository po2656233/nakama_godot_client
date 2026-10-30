extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_quit_button_pressed():
	# 从游戏内退出统一走启动器：处理离开对局、返回上一页。
	if Global.has_global("GameLauncher") and Global.GameLauncher.is_game_running():
		await Global.GameLauncher.exit_game()
	else:
		get_tree().quit()

func _on_again_button_pressed():
	self.visible = false
	if Global.has_global("GameLauncher") and Global.GameLauncher.is_game_running():
		if Global.GameLauncher.restart_game():
			return
	get_tree().reload_current_scene()