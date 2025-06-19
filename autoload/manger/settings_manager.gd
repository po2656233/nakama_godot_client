extends Node

signal settings_changed
signal settings_hide
signal settings_toggle

var settings_ui: Control = null
var settings_scene = preload("res://scenes/1common/setting.tscn")
var music_scene = preload("res://scenes/1common/music.tscn")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # 让设置在游戏暂停时也能工作
	add_child(music_scene.instantiate())
	
	settings_changed.connect(_on_scene_changed)
	settings_hide.connect(_on_hide_settings)
	settings_toggle.connect(_on_toggle_settings)

func show_settings(state: int = 0):
	if settings_ui == null:
		settings_ui = settings_scene.instantiate()
		if settings_ui == null:
			return

		# 添加到最上层场景
		var root = get_tree().root
		var current_scene = root.get_child(root.get_child_count() - 1)
		if current_scene:
			current_scene.add_child(settings_ui)
		pass
	if state == 0:
		settings_ui.noHome()
	elif state == 1:
		# print("noReback")
		settings_ui.noReback()
	elif state == 2:
		settings_ui.simple()
	else:
		settings_ui.hide()
		return
	settings_ui.show()
	# await get_tree().process_frame
	pass

func _on_hide_settings():
	if settings_ui != null:
		settings_ui.hide()
		print("隐藏设置按钮")
	pass


func showNotify(isMute: bool = false):
	if settings_ui != null:
		settings_ui.showNotify(isMute)

func _on_toggle_settings():
	if settings_ui != null and settings_ui.visible:
		_on_hide_settings()
	else:
		show_settings()

# 当场景改变时，确保设置UI被正确处理
func _on_scene_changed():
	if settings_ui != null:
		settings_ui.queue_free()
		settings_ui = null
