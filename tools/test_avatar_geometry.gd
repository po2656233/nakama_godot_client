extends SceneTree

## 阶段 1 几何一致性测试（不是“节点存在”式假测试）。
##
## 对每个转换产物独立重算 DragonBones 矩阵，并与 Godot 场景逐项比对：
##   1. 每根骨骼的局部矩阵 = T(x,y) * [skX/skY 剪切] * S(scX,scY)，且 rest == transform；
##   2. 全局矩阵 = 父链矩阵连乘（验证层级/继承没有错位）；
##   3. 每个插槽的局部矩阵、绝对 z_index（绘制顺序）；
##   4. 每个 display 的 Sprite2D：局部矩阵、裁剪补偿 offset、初始可见性；
##   5. 动画采样：任意时刻每个插槽最多 1 个可见 Sprite（防止多贴图重叠成“碎裂”）。
##
## 用法：godot --headless --path . --script res://tools/test_avatar_geometry.gd

const TOL := 0.01
const ASSETS := [
	{"name": "daojishi", "ske": "res://sprites/daojishi/daojishitongyong_ske.json", "tex": "res://sprites/daojishi/daojishitongyong_tex.json", "scene": "res://sprites/daojishi/daojishitongyong_avatar.tscn", "bones": 6, "slots": 4},
	{"name": "dibeichang", "ske": "res://sprites/dibeichang/dibeichang_ske.json", "tex": "res://sprites/dibeichang/dibeichang_tex.json", "scene": "res://sprites/dibeichang/dibeichang_avatar.tscn", "bones": 7, "slots": 6},
	{"name": "jiangbei", "ske": "res://sprites/jiangbei/jiangbei_ske.json", "tex": "res://sprites/jiangbei/jiangbei_tex.json", "scene": "res://sprites/jiangbei/jiangbei_avatar.tscn", "bones": 28, "slots": 18},
	{"name": "puke", "ske": "res://sprites/puke/puke_ske.json", "tex": "res://sprites/puke/puke_tex.json", "scene": "res://sprites/puke/puke_avatar.tscn", "bones": 70, "slots": 54},
	{"name": "baoxiang1", "ske": "res://sprites/baoxiang1/lhdb_chujichang_ske.json", "tex": "res://sprites/baoxiang1/lhdb_chujichang_tex.json", "scene": "res://sprites/baoxiang1/baoxiang1_avatar.tscn", "bones": 25, "slots": 12},
	{"name": "baoxiang2", "ske": "res://sprites/baoxiang2/lhdb_gaojichang_1_ske.json", "tex": "res://sprites/baoxiang2/lhdb_gaojichang_1_tex.json", "scene": "res://sprites/baoxiang2/baoxiang2_avatar.tscn", "bones": 33, "slots": 27},
	{"name": "baoxiang3", "ske": "res://sprites/baoxiang3/lhdb_zhizunchang_ske.json", "tex": "res://sprites/baoxiang3/lhdb_zhizunchang_tex.json", "scene": "res://sprites/baoxiang3/baoxiang3_avatar.tscn", "bones": 56, "slots": 42},
	{"name": "baoxiang4", "ske": "res://sprites/baoxiang4/lhdb_zhongjichang_ske.json", "tex": "res://sprites/baoxiang4/lhdb_zhongjichang_tex.json", "scene": "res://sprites/baoxiang4/baoxiang4_avatar.tscn", "bones": 35, "slots": 19},
	{"name": "shaibao", "ske": "res://sprites/shaibao/shaibao_ske.json", "tex": "res://sprites/shaibao/shaibao_tex.json", "scene": "res://sprites/shaibao/shaibao_avatar.tscn", "bones": 101, "slots": 27},
	{"name": "startgame", "ske": "res://sprites/startgame/startgame_ske.json", "tex": "res://sprites/startgame/startgame_tex.json", "scene": "res://sprites/startgame/startgame_avatar.tscn", "bones": 6, "slots": 5},
]

var _passed := 0
var _failed := 0
var _done := false

func _init() -> void:
	_run.call_deferred()
	_guard.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	for asset in ASSETS:
		await _check_asset(asset)
	_finish()

func _check_asset(asset: Dictionary) -> void:
	var asset_name: String = asset["name"]
	var ske := _read_json(asset["ske"])
	var tex := _read_json(asset["tex"])
	var packed := ResourceLoader.load(asset["scene"]) as PackedScene
	_check(packed != null, "%s: 场景可加载" % asset_name)
	if ske.is_empty() or tex.is_empty() or packed == null:
		return
	var armature: Dictionary = ske["armature"][0]
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	var avatar_root := _find_first(instance, "AvatarRoot") as Node2D
	var skeleton := _find_first(instance, "Skeleton2D") as Skeleton2D
	_check(avatar_root != null and skeleton != null, "%s: AvatarRoot/Skeleton2D 存在" % asset_name)
	if avatar_root == null or skeleton == null:
		instance.queue_free()
		return

	# --- 骨骼局部/全局矩阵 ---
	var bone_nodes: Dictionary = {}
	var bone_globals: Dictionary = {}
	var bone_matrix: Dictionary = {}
	for data in armature.get("bone", []):
		var bone_name := str(data["name"])
		var expected_local := _db_matrix(data.get("transform", {}))
		var node := _find_named(skeleton, _safe_name(bone_name)) as Node2D
		_check(node != null, "%s: 骨骼 %s 存在" % [asset_name, bone_name])
		if node == null:
			continue
		bone_nodes[bone_name] = node
		bone_matrix[bone_name] = expected_local
		_check(_matrix_close(node.transform, expected_local), "%s: 骨骼 %s 局部矩阵" % [asset_name, bone_name])
		var bone2d := node as Bone2D
		if bone2d != null:
			_check(_matrix_close(bone2d.rest, node.transform), "%s: 骨骼 %s rest == transform" % [asset_name, bone_name])
	var global_count := 0
	for data in armature.get("bone", []):
		var bone_name := str(data["name"])
		if not bone_nodes.has(bone_name):
			continue
		var global: Transform2D = bone_matrix[bone_name]
		var parent_name := str(data.get("parent", ""))
		while not parent_name.is_empty() and bone_matrix.has(parent_name):
			global = bone_matrix[parent_name] * global
			parent_name = str(_bone_parent(armature, parent_name))
		bone_globals[bone_name] = global
		var node: Node2D = bone_nodes[bone_name]
		var actual := avatar_root.global_transform.affine_inverse() * node.global_transform
		_check(_matrix_close(actual, global), "%s: 骨骼 %s 全局矩阵" % [asset_name, bone_name])
		global_count += 1

	# --- 插槽 / display ---
	var sub_textures: Dictionary = {}
	for sub in tex.get("SubTexture", []):
		sub_textures[str(sub["name"])] = sub
	var skin_slots: Dictionary = {}
	for slot_data in armature.get("skin", [])[0].get("slot", []):
		skin_slots[str(slot_data["name"])] = slot_data.get("display", [])
	var slot_index := 0
	for slot_data in armature.get("slot", []):
		var slot_name := str(slot_data["name"])
		var parent_name := str(slot_data.get("parent", ""))
		var parent_node: Node2D = bone_nodes.get(parent_name, skeleton)
		var slot_node := _find_named(parent_node, "slot_" + _safe_name(slot_name)) as Node2D
		var displays: Array = skin_slots.get(slot_name, [])
		if displays.is_empty():
			slot_index += 1
			continue
		_check(slot_node != null, "%s: 插槽 %s 存在" % [asset_name, slot_name])
		if slot_node == null:
			slot_index += 1
			continue
		var expected_slot := _db_matrix(slot_data.get("transform", {}))
		_check(_matrix_close(slot_node.transform, expected_slot), "%s: 插槽 %s 局部矩阵" % [asset_name, slot_name])
		_check(slot_node.z_index == slot_index and not slot_node.z_as_relative, "%s: 插槽 %s 绝对 z_index == %d" % [asset_name, slot_name, slot_index])
		var initial_display := int(slot_data.get("displayIndex", 0))
		for display_index in displays.size():
			var display: Dictionary = displays[display_index]
			var display_name := str(display.get("name", ""))
			if not sub_textures.has(display_name):
				continue
			var sprite := slot_node.get_node_or_null("d%d" % display_index) as Sprite2D
			_check(sprite != null, "%s: display %s/%d 存在" % [asset_name, slot_name, display_index])
			if sprite == null:
				continue
			_check(_matrix_close(sprite.transform, _db_matrix(display.get("transform", {}))), "%s: display %s/%d 局部矩阵" % [asset_name, slot_name, display_index])
			_check(_vec_close(sprite.offset, _expected_offset(sub_textures[display_name], display)), "%s: display %s/%d 裁剪 offset" % [asset_name, slot_name, display_index])
			_check(sprite.visible == (display_index == initial_display), "%s: display %s/%d 初始可见性" % [asset_name, slot_name, display_index])
		slot_index += 1

	# --- 动画采样：每个插槽最多一个可见显示 ---
	var player := _find_first(instance, "AnimationPlayer") as AnimationPlayer
	_check(player != null, "%s: AnimationPlayer 存在" % asset_name)
	if player != null:
		var any_visible := false
		for anim_name in player.get_animation_list():
			var animation := player.get_animation(anim_name)
			for sample_index in range(5):
				var time := animation.length * float(sample_index) / 5.0
				player.play(anim_name)
				player.seek(time, true)
				player.pause()
				await process_frame
				if _count_visible_sprites(skeleton) > 0:
					any_visible = true
				_check(_count_slot_overlaps(skeleton) == 0, "%s/%s@%.2fs: 每插槽至多 1 个可见 Sprites" % [asset_name, anim_name, time])
		_check(any_visible, "%s: 动画任意采样有可见内容" % asset_name)
	player.stop()
	instance.queue_free()
	await process_frame

func _count_visible_sprites(node: Node) -> int:
	var total := 0
	if node is Sprite2D and (node as Sprite2D).visible:
		total += 1
	for child in node.get_children():
		total += _count_visible_sprites(child)
	return total
## 统计“同一插槽内可见 Sprite 数 > 1”的插槽个数（应为 0）。
func _count_slot_overlaps(node: Node) -> int:
	var overlaps := 0
	if node is Node2D and str(node.name).begins_with("d") and not (node is Bone2D):
		return 0
	for child in node.get_children():
		if child is Node2D and str(child.name).begins_with("d") and child.get_child_count() == 0:
			continue
		if child is Node2D and _is_slot_node(child):
			var visible := 0
			for sprite in child.get_children():
				if sprite is Sprite2D and (sprite as Sprite2D).visible:
					visible += 1
			if visible > 1:
				overlaps += 1
		overlaps += _count_slot_overlaps(child)
	return overlaps

func _is_slot_node(node: Node) -> bool:
	if node.get_child_count() == 0:
		return false
	for child in node.get_children():
		if child is Sprite2D:
			return true
	return false

func _bone_parent(armature: Dictionary, bone_name: String) -> String:
	for data in armature.get("bone", []):
		if str(data.get("name", "")) == bone_name:
			return str(data.get("parent", ""))
	return ""

func _db_matrix(transform_data: Dictionary) -> Transform2D:
	var skx := deg_to_rad(float(transform_data.get("skX", transform_data.get("rot", 0.0))))
	var sky := deg_to_rad(float(transform_data.get("skY", rad_to_deg(skx))))
	var sx := float(transform_data.get("scX", 1.0))
	var sy := float(transform_data.get("scY", 1.0))
	var x_axis := Vector2(cos(sky) * sx, sin(sky) * sx)
	var y_axis := Vector2(-sin(skx) * sy, cos(skx) * sy)
	var origin := Vector2(float(transform_data.get("x", 0.0)), float(transform_data.get("y", 0.0)))
	return Transform2D(x_axis, y_axis, origin)

func _expected_offset(sub_texture: Dictionary, display: Dictionary) -> Vector2:
	if not (sub_texture.has("frameX") or sub_texture.has("frameY")):
		return Vector2.ZERO
	var width := float(sub_texture.get("width", 1.0))
	var height := float(sub_texture.get("height", 1.0))
	var frame_width := float(sub_texture.get("frameWidth", width))
	var frame_height := float(sub_texture.get("frameHeight", height))
	var frame_x := float(sub_texture.get("frameX", 0.0))
	var frame_y := float(sub_texture.get("frameY", 0.0))
	var pivot: Dictionary = display.get("pivot", {})
	return Vector2(
		width * 0.5 - frame_x - float(pivot.get("x", 0.5)) * frame_width,
		height * 0.5 - frame_y - float(pivot.get("y", 0.5)) * frame_height
	)

func _matrix_close(a: Transform2D, b: Transform2D) -> bool:
	return (_vec_close(a.x, b.x) and _vec_close(a.y, b.y) and _vec_close(a.origin, b.origin))

func _vec_close(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= TOL and absf(a.y - b.y) <= TOL

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _safe_name(raw: String) -> String:
	var result := raw.strip_edges().replace(".", "_").replace(":", "_").replace("@", "_").replace("/", "_").replace("\"", "_").replace("%", "_")
	return result if not result.is_empty() else "Node"

func _find_first(node: Node, target_name: String) -> Node:
	if str(node.name) == target_name:
		return node
	for child in node.get_children():
		var found := _find_first(child, target_name)
		if found != null:
			return found
	return null

func _find_named(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if str(child.name) == target_name:
			return child
		var nested := _find_named(child, target_name)
		if nested != null:
			return nested
	return null

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		if _failed <= 40:
			print("FAIL: ", label)

func _finish() -> void:
	if _done:
		return
	_done = true
	print("\n===== 骨骼几何一致性：通过 %d 项，失败 %d 项 =====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _guard() -> void:
	await create_timer(60.0).timeout
	if _done:
		return
	_done = true
	print("FAIL: 骨骼几何一致性测试超时（60s）")
	quit(1)
