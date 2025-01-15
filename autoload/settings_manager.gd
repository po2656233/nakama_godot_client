extends Node

@warning_ignore("unused_signal")
signal settings_changed

var settings_ui: Control = null
var settings_scene = preload("res://scenes/element/setting.tscn")
var music_scene = preload("res://scenes/element/music.tscn")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # 让设置在游戏暂停时也能工作
	add_child(music_scene.instantiate())
	settings_changed.connect(_on_scene_changed)

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
	if state == 0:
		settings_ui.noHome()
	elif state == 1:
		# print("noReback")
		settings_ui.noReback()
	elif state == 2:
		settings_ui.simple()
	settings_ui.show()
	pass

func hide_settings():
	if settings_ui != null:
		settings_ui.hide()
	pass


func showNotify(isMute: bool = false):
	if settings_ui != null:
		settings_ui.showNotify(isMute)

func toggle_settings():
	if settings_ui != null and settings_ui.visible:
		hide_settings()
	else:
		show_settings()

# 当场景改变时，确保设置UI被正确处理
func _on_scene_changed():
	if settings_ui != null:
		settings_ui.queue_free()
		settings_ui = null
