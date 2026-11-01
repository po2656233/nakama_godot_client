extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_quit_button_pressed():
	# 从游戏内退出统一走启动器：处理离开对局、返回上一页。
	if GameBridge.current != null and GameBridge.current.is_running():
		await GameBridge.current.exit()
	else:
		get_tree().quit()

func _on_again_button_pressed():
	self.visible = false
	if GameBridge.current != null and GameBridge.current.is_running():
		if GameBridge.current.restart():
			return
	get_tree().reload_current_scene()