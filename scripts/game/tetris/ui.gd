extends CanvasLayer

class_name UI

@onready var center_container = $CenterContainer
@onready var label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Label2
func show_game_over(score :int):
	var hint = "\n\n\t\t\t\tSCORE:\t"
	if score == 0:
		hint = hint + "得了个鸭蛋0"
	elif score < 800:
		hint = hint + " 小试牛刀 "+ String.num(score)
	elif  score < 1600:
		hint = hint + " 牛皮吹上天 "+ String.num(score)
	elif  score < 3200:
		hint = hint + String.num(score)+ " 这得分 必须横着走 "
	else:
		hint = hint + String.num(score)+ " 全人类都是小可爱 "
	label.text = hint+"\n\n\n"
	center_container.show()


func _on_button_pressed():
	if Global.has_global("GameLauncher") and Global.GameLauncher.is_game_running():
		if Global.GameLauncher.restart_game():
			return
	get_tree().reload_current_scene()
