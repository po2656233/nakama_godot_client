extends SceneTree

## DragonBones -> Godot 原生骨骼动画转换器（PROMPT_REFACTOR 阶段 2）
##
## 输入：DragonBones 5.x 的 `_ske.json` + `_tex.json` + 图集 png
## 输出：包含 Skeleton2D + Bone2D + Sprite2D + AnimationPlayer 的 `.tscn`
##
## 用法：
##   godot --headless --path . --script res://tools/dragonbones_converter.gd -- \
##       --ske=res://sprites/daojishi/daojishitongyong_ske.json \
##       --tex=res://sprites/daojishi/daojishitongyong_tex.json \
##       --out=res://sprites/daojishi/daojishi_avatar.tscn
##
## 可选参数：--armature=名称/索引  --animation=名称  --scale=数值
##
## 说明 / 限制：
##   - 骨骼平移/缩放/旋转按关键帧数值线性插值（DragonBones 贝塞尔曲线暂按线性近似）；
##   - 插槽按 displayFrame 切换可见 Sprite，colorFrame 的 aM 转为 modulate alpha；
##   - blendMode=add 的插槽使用 CanvasItemMaterial 叠加混合；
##   - 暂不支持网格变形（mesh/deform）与换装 skin 动画，遇到会跳过并告警。

const DB_FPS_DEFAULT := 24.0

var _ske_path := ""
var _tex_path := ""
var _out_path := ""
var _armature_filter := ""
var _animation_filter := ""
var _global_scale := 1.0
var _warnings: Array[String] = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ske="): _ske_path = arg.substr(6)
		elif arg.begins_with("--tex="): _tex_path = arg.substr(6)
		elif arg.begins_with("--out="): _out_path = arg.substr(6)
		elif arg.begins_with("--armature="): _armature_filter = arg.substr(11)
		elif arg.begins_with("--animation="): _animation_filter = arg.substr(12)
		elif arg.begins_with("--scale="): _global_scale = float(arg.substr(8))

	if _ske_path.is_empty() or _tex_path.is_empty() or _out_path.is_empty():
		push_error("[converter] 缺少 --ske / --tex / --out 参数")
		quit(2)
		return

	var ok := _convert()
	for message in _warnings:
		print("[converter] WARN ", message)
	quit(0 if ok else 1)

# ---------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------

func _convert() -> bool:
	var ske := _read_json(_ske_path)
	var tex := _read_json(_tex_path)
	if ske.is_empty() or tex.is_empty():
		return false

	var armatures: Array = ske.get("armature", [])
	if armatures.is_empty():
		push_error("[converter] ske 中没有 armature")
		return false
	var armature: Dictionary = _pick_armature(armatures)
	var frame_rate := float(armature.get("frameRate", ske.get("frameRate", DB_FPS_DEFAULT)))
	var atlas: Texture2D = _load_atlas(tex)
	if atlas == null:
		return false

	var root := Node2D.new()
	root.name = "AvatarRoot"
	if not is_equal_approx(_global_scale, 1.0):
		root.scale = Vector2(_global_scale, _global_scale)
	var skeleton := Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	root.add_child(skeleton)

	var bone_nodes := _build_bones(armature, skeleton)
	var slot_nodes := _build_slots(armature, bone_nodes, atlas, tex, skeleton)
	var player := _build_animations(armature, bone_nodes, slot_nodes, frame_rate, root)
	if player != null:
		root.add_child(player)

	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("[converter] PackedScene.pack 失败")
		root.free()
		return false
	var err := ResourceSaver.save(packed, _out_path)
	root.free()
	if err != OK:
		push_error("[converter] 保存失败 %s: %s" % [_out_path, err])
		return false
	print("[converter] 生成 %s（bones=%d, slots=%d, animations=%d）" % [
		_out_path, bone_nodes.size(), slot_nodes.size(), armature.get("animation", []).size()])
	return true

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[converter] 文件不存在: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("[converter] JSON 解析失败: %s" % path)
		return {}
	return parsed

func _pick_armature(armatures: Array) -> Dictionary:
	if _armature_filter.is_empty():
		return armatures[0]
	if _armature_filter.is_valid_int():
		var index := _armature_filter.to_int()
		if index >= 0 and index < armatures.size():
			return armatures[index]
	for armature in armatures:
		if armature is Dictionary and str(armature.get("name", "")) == _armature_filter:
			return armature
	_warnings.append("armature 未找到，回退到第一个: %s" % _armature_filter)
	return armatures[0]

# ---------------------------------------------------------------------
# 图集
# ---------------------------------------------------------------------

func _load_atlas(tex: Dictionary) -> Texture2D:
	var image_path := str(tex.get("imagePath", ""))
	if image_path.is_empty():
		push_error("[converter] tex 缺少 imagePath")
		return null
	var atlas_path := _tex_path.get_base_dir().path_join(image_path)
	if not ResourceLoader.exists(atlas_path):
		push_error("[converter] 图集不存在: %s" % atlas_path)
		return null
	return load(atlas_path) as Texture2D

func _make_atlas_texture(atlas: Texture2D, sub_texture: Dictionary) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(
		float(sub_texture.get("x", 0.0)),
		float(sub_texture.get("y", 0.0)),
		float(sub_texture.get("width", 1.0)),
		float(sub_texture.get("height", 1.0))
	)
	texture.filter_clip = true
	return texture

# ---------------------------------------------------------------------
# 骨骼 / 插槽
# ---------------------------------------------------------------------

func _build_bones(armature: Dictionary, skeleton: Skeleton2D) -> Dictionary:
	var bones: Dictionary = {}
	var pending: Array = armature.get("bone", []).duplicate()
	var guard := 0
	while not pending.is_empty() and guard < 64:
		guard += 1
		var still: Array = []
		for data in pending:
			if not data is Dictionary:
				continue
			var bone_name := str(data.get("name", "bone"))
			var parent_name := str(data.get("parent", ""))
			var parent: Node = skeleton
			if not parent_name.is_empty():
				if not bones.has(parent_name):
					still.append(data)
					continue
				parent = bones[parent_name]
			var bone := Bone2D.new()
			bone.name = _safe_name(bone_name)
			bone.auto_calculate_length_and_angle = false
			_apply_transform(bone, data.get("transform", {}))
			# Bone2D 的 rest 默认是零矩阵，不设置会让 Skeleton2D 反演失败（det == 0）。
			bone.rest = bone.transform
			parent.add_child(bone)
			bones[bone_name] = bone
		pending = still
	if not pending.is_empty():
		_warnings.append("有 %d 根骨骼找不到父节点，已忽略" % pending.size())
	return bones

func _build_slots(armature: Dictionary, bone_nodes: Dictionary, atlas: Texture2D, tex: Dictionary, skeleton: Skeleton2D) -> Dictionary:
	var sub_textures: Dictionary = {}
	for sub in tex.get("SubTexture", []):
		sub_textures[str(sub.get("name", ""))] = sub

	var skin_slots: Dictionary = {}
	var skins: Array = armature.get("skin", [])
	if not skins.is_empty() and skins[0] is Dictionary:
		for slot_data in skins[0].get("slot", []):
			skin_slots[str(slot_data.get("name", ""))] = slot_data.get("display", [])

	var result: Dictionary = {}
	for slot_data in armature.get("slot", []):
		var slot_name := str(slot_data.get("name", ""))
		var parent: Node = bone_nodes.get(str(slot_data.get("parent", "")), skeleton)
		var displays: Array = skin_slots.get(slot_name, [])
		if displays.is_empty():
			_warnings.append("插槽 %s 没有 display，跳过" % slot_name)
			continue
		var entries: Array = []
		for display_index in displays.size():
			var display: Dictionary = displays[display_index]
			var display_name := str(display.get("name", ""))
			if not sub_textures.has(display_name):
				_warnings.append("插槽 %s 的 display %s 不在图集中" % [slot_name, display_name])
				continue
			if display.has("mesh") or display.has("deform"):
				_warnings.append("插槽 %s 的 display %s 是网格，暂不支持" % [slot_name, display_name])
			var sprite := Sprite2D.new()
			sprite.name = _safe_name(slot_name) + "_d%d" % display_index
			sprite.texture = _make_atlas_texture(atlas, sub_textures[display_name])
			sprite.centered = true
			if str(slot_data.get("blendMode", "normal")) == "add":
				var material := CanvasItemMaterial.new()
				material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				sprite.material = material
			_apply_transform(sprite, display.get("transform", {}))
			sprite.visible = display_index == 0
			parent.add_child(sprite)
			entries.append({"node": sprite, "display": display_index})
		if entries.is_empty():
			continue
		result[slot_name] = {"entries": entries, "data": slot_data}
	return result

# ---------------------------------------------------------------------
# 动画
# ---------------------------------------------------------------------

func _build_animations(armature: Dictionary, bone_nodes: Dictionary, slot_nodes: Dictionary, frame_rate: float, avatar_root: Node2D) -> AnimationPlayer:
	var animations: Array = armature.get("animation", [])
	if animations.is_empty():
		return null
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.root_node = NodePath("..")
	var library := AnimationLibrary.new()
	for anim_data in animations:
		if not anim_data is Dictionary:
			continue
		var anim_name := str(anim_data.get("name", "animation"))
		if not _animation_filter.is_empty() and anim_name != _animation_filter:
			continue
		var animation := _build_animation(anim_data, bone_nodes, slot_nodes, frame_rate, avatar_root)
		if animation != null:
			library.add_animation(anim_name, animation)
	if library.get_animation_list().is_empty():
		player.free()
		return null
	player.add_animation_library("", library)
	return player

func _build_animation(anim_data: Dictionary, bone_nodes: Dictionary, slot_nodes: Dictionary, frame_rate: float, avatar_root: Node2D) -> Animation:
	var length := float(anim_data.get("duration", 0.0)) / maxf(frame_rate, 1.0)
	if length <= 0.0:
		return null
	var animation := Animation.new()
	animation.length = maxf(length, 0.01)
	var play_times := int(anim_data.get("playTimes", 0))
	animation.loop_mode = Animation.LOOP_NONE if play_times == 1 else Animation.LOOP_LINEAR

	for bone_frame in anim_data.get("bone", []):
		if not bone_frame is Dictionary:
			continue
		var bone: Bone2D = bone_nodes.get(str(bone_frame.get("name", "")))
		if bone == null:
			continue
		var path := _rel_path(bone, avatar_root)
		_track_vector2(animation, path + ":position", bone_frame.get("translateFrame", []), bone.position, frame_rate)
		_track_vector2(animation, path + ":scale", bone_frame.get("scaleFrame", []), bone.scale, frame_rate)
		_track_rotation(animation, path + ":rotation", bone_frame.get("rotateFrame", []), bone.rotation, frame_rate)

	for slot_frame in anim_data.get("slot", []):
		if not slot_frame is Dictionary:
			continue
		var slot: Dictionary = slot_nodes.get(str(slot_frame.get("name", "")), {})
		if slot.is_empty():
			continue
		_track_display(animation, slot["entries"], slot_frame.get("displayFrame", []), frame_rate, avatar_root)
		_track_color(animation, slot["entries"], slot_frame.get("colorFrame", []), frame_rate, avatar_root)

	if anim_data.has("zOrder"):
		_track_zorder(animation, slot_nodes, anim_data.get("zOrder", []), frame_rate, avatar_root)

	if animation.get_track_count() == 0:
		return null
	return animation

func _track_vector2(animation: Animation, path: String, frames: Array, rest: Vector2, frame_rate: float) -> void:
	if frames.is_empty():
		return
	var keys: Array = []
	var time := 0.0
	for frame in frames:
		if not frame is Dictionary:
			continue
		var value := rest
		if frame.has("x") or frame.has("y"):
			value = Vector2(
				float(frame["x"]) if frame.has("x") else rest.x,
				float(frame["y"]) if frame.has("y") else rest.y
			)
		keys.append({"time": time, "value": value})
		time += float(frame.get("duration", 0.0)) / maxf(frame_rate, 1.0)
	if not _has_change(keys, rest):
		return
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	for key in keys:
		animation.track_insert_key(track, key["time"], key["value"])

func _track_rotation(animation: Animation, path: String, frames: Array, rest: float, frame_rate: float) -> void:
	if frames.is_empty():
		return
	var keys: Array = []
	var time := 0.0
	for frame in frames:
		if not frame is Dictionary:
			continue
		var value := rest
		if frame.has("rot"):
			value = deg_to_rad(float(frame["rot"]))
		elif frame.has("skX"):
			value = deg_to_rad(float(frame["skX"]))
		keys.append({"time": time, "value": value})
		time += float(frame.get("duration", 0.0)) / maxf(frame_rate, 1.0)
	if not _has_change(keys, rest):
		return
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	for key in keys:
		animation.track_insert_key(track, key["time"], key["value"])

func _track_display(animation: Animation, entries: Array, frames: Array, frame_rate: float, avatar_root: Node2D) -> void:
	if frames.is_empty() or entries.is_empty():
		return
	var tracks: Dictionary = {}
	for entry in entries:
		var sprite: Sprite2D = entry["node"]
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(_rel_path(sprite, avatar_root) + ":visible"))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
		tracks[int(entry["display"])] = track
	var time := 0.0
	for frame in frames:
		if not frame is Dictionary:
			continue
		var value := int(frame.get("value", 0))
		for display_index in tracks.keys():
			var visible := value >= 0 and int(value) == int(display_index)
			animation.track_insert_key(tracks[display_index], time, visible)
		time += float(frame.get("duration", 0.0)) / maxf(frame_rate, 1.0)

func _track_color(animation: Animation, entries: Array, frames: Array, frame_rate: float, avatar_root: Node2D) -> void:
	if frames.is_empty() or entries.is_empty():
		return
	var tracks: Array = []
	for entry in entries:
		var sprite: Sprite2D = entry["node"]
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(_rel_path(sprite, avatar_root) + ":modulate"))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		tracks.append(track)
	var time := 0.0
	for frame in frames:
		if not frame is Dictionary:
			continue
		var alpha := 1.0
		var value: Dictionary = frame.get("value", {})
		if value.has("aM"):
			alpha = clampf(float(value["aM"]) / 100.0, 0.0, 1.0)
		var color := Color(1.0, 1.0, 1.0, alpha)
		for track in tracks:
			animation.track_insert_key(track, time, color)
		time += float(frame.get("duration", 0.0)) / maxf(frame_rate, 1.0)

func _track_zorder(animation: Animation, slot_nodes: Dictionary, frames: Array, frame_rate: float, avatar_root: Node2D) -> void:
	var time := 0.0
	for frame in frames:
		if not frame is Dictionary:
			continue
		var order: Array = frame.get("zOrder", [])
		for index in order.size():
			var slot: Dictionary = slot_nodes.get(str(order[index]), {})
			for entry in slot.get("entries", []):
				var sprite: Sprite2D = entry["node"]
				var track := animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track, NodePath(_rel_path(sprite, avatar_root) + ":z_index"))
				animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
				animation.track_insert_key(track, 0.0, 0)
				animation.track_insert_key(track, time, index)
		time += float(frame.get("duration", 0.0)) / maxf(frame_rate, 1.0)

# ---------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------

func _has_change(keys: Array, rest: Variant) -> bool:
	for key in keys:
		var value: Variant = key["value"]
		if value is Vector2:
			if not (value as Vector2).is_equal_approx(rest as Vector2):
				return true
		elif absf(float(value) - float(rest)) > 0.0001:
			return true
	return false

func _rel_path(node: Node, root: Node) -> String:
	var parts: Array[String] = []
	var current: Node = node
	while current != null and current != root:
		parts.push_front(str(current.name))
		current = current.get_parent()
	return "/".join(parts)

func _apply_transform(node: Node2D, transform_data: Dictionary) -> void:
	node.position = Vector2(float(transform_data.get("x", 0.0)), float(transform_data.get("y", 0.0)))
	node.scale = Vector2(float(transform_data.get("scX", 1.0)), float(transform_data.get("scY", 1.0)))
	var rotation_deg := float(transform_data.get("rot", transform_data.get("skX", 0.0)))
	node.rotation = deg_to_rad(rotation_deg)

func _safe_name(raw: String) -> String:
	var result := raw.strip_edges().replace(".", "_").replace(":", "_").replace("@", "_").replace("/", "_").replace("\"", "_").replace("%", "_")
	if result.is_empty():
		result = "Node"
	return result

func _set_owner_recursive(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_owner_recursive(child, root)
