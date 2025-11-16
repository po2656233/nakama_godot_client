extends Control

func _ready():
	pass


func _on_button_pressed():
	queue_free()
	Global.SceneMgr.go_back()
	pass
