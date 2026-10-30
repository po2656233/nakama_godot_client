extends RefCounted

## 模块：场景叠加层
## 职责：把“在当前场景上层按比例打开一个页面”的能力独立出来（邮件、审批等）。
## 说明：只做 UI 容器与复用，不负责路由和转场。

const CONTAINER_PREFIX := "__Overlay_"

## 在当前场景中央按比例显示一个场景；已打开则直接返回原实例。
static func show_in_center(host: Node, scene_path: String, scale_ratio: float = 0.8) -> Node:
	if host == null or scene_path.is_empty():
		return null
	var tree := host.get_tree()
	if tree == null:
		return null
	var current_scene := tree.current_scene
	if current_scene == null:
		push_warning("[SceneOverlay] 当前没有活动场景")
		return null

	var existing := _find_instance(current_scene, scene_path)
	if existing != null:
		existing.get_parent().visible = true
		return existing

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("[SceneOverlay] 无法加载场景: %s" % scene_path)
		return null
	var instance := packed.instantiate()
	if instance == null:
		push_error("[SceneOverlay] 无法实例化场景: %s" % scene_path)
		return null

	var ratio := clampf(scale_ratio, 0.1, 1.0)
	var margin := (1.0 - ratio) / 2.0
	var container := Control.new()
	container.name = CONTAINER_PREFIX + scene_path.get_file().get_basename()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.anchor_left = margin
	container.anchor_top = margin
	container.anchor_right = 1.0 - margin
	container.anchor_bottom = 1.0 - margin
	container.offset_left = 0.0
	container.offset_top = 0.0
	container.offset_right = 0.0
	container.offset_bottom = 0.0
	container.add_child(instance)
	current_scene.add_child(container)
	return instance

## 关闭某个叠加页（传 show_in_center 返回的场景实例）。
static func close(scene_instance: Node) -> void:
	if scene_instance == null or not is_instance_valid(scene_instance):
		return
	var parent := scene_instance.get_parent()
	if parent != null:
		parent.queue_free()

static func _find_instance(current_scene: Node, scene_path: String) -> Node:
	for child in current_scene.get_children():
		if not child is Control:
			continue
		if not str(child.name).begins_with(CONTAINER_PREFIX):
			continue
		for sub_child in child.get_children():
			if sub_child.scene_file_path == scene_path:
				return sub_child
	return null
