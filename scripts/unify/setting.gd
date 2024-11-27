extends Control

@onready var menuBtn = $HBoxContainerRightTop/MB_setting
var login_scene = load("res://scenes/login.tscn")

# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	var popup_menu = menuBtn.get_popup()
	popup_menu.index_pressed.connect(on_setting_pressed)
	WindowDrag.unregister_drag_zone(self)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func on_setting_pressed(index: int) -> void:
	var popup_menu = menuBtn.get_popup()
	var check:bool = popup_menu.is_item_checked(index)
	var new_check:bool = not check
	popup_menu.set_item_checked(index, new_check)
	match index:
		0:
			print("Setting 0")
			pass
		1:
			print("Setting 1")
			pass
		2:
			print("Setting 2")
			pass
		3:
			print("Setting 3")
			WindowDrag.dragging = false
			FancyFade.wipe_left(login_scene.instantiate(),0.5)
			pass
		5:
			get_tree().quit()
			pass
		_:
			print("Setting error")
			pass
	pass

func _on_btn_full_pressed() -> void:
	if Window.MODE_FULLSCREEN == get_window().mode:
		restore_window()
	else:
		maximize_window()
	pass # Replace with function body.


# 最大化窗口
func maximize_window():
	get_window().mode = Window.MODE_FULLSCREEN 
    
# 最小化窗口
func minimize_window():
	get_window().mode = Window.MODE_MINIMIZED
    
# 恢复窗口(恢复到普通窗口模式)
func restore_window():
	get_window().mode = Window.MODE_WINDOWED

