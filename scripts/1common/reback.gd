extends Control

func _ready():
	pass


func _on_button_pressed():
	queue_free()
	SceneMgr.go_back()
	pass
