extends SceneTree

## DragonBones -> Godot 原生骨骼动画转换器（v2，阶段 1 修复版）
##
## 修复要点（对应真机“碎裂/错位/动作失真”）：
##   1. 图集裁剪补偿：SubTexture 的 frameX/frameY/frameWidth/frameHeight 体现在
##      Sprite2D.offset 上（并支持 pivot），否则贴图会相对骨骼产生像素级位移；
##   2. 插槽（slot）局部 Transform：bone -> slot(Node2D) -> Sprite2D 三层，
##      插槽自身 x/y/skX/skY/scX/scY 正确继承；
##   3. 绘制顺序：按 DragonBones slot 顺序给 slot 节点设置绝对 z_index
##      （z_as_relative=false），修复按骨骼树递归顺序绘制导致的图层错乱；
##   4. 关键帧语义：缺失 x/y/aM/display 的帧继承上一帧（不再回落 rest/0/1）；
##   5. 缓动：frame.curve（三次贝塞尔）与 tweenEasing 烘焙成中间关键帧，
##      无缓动段按 DragonBones 语义做 step（保序），不再一律线性；
##   6. 骨骼/插槽 skX/skY 不同时用 rotation+skew 还原剪切矩阵。
##
## 用法：
##   godot --headless --path . --script res://tools/dragonbones_converter.gd -- \
##       --ske=res://sprites/daojishi/daojishitongyong_ske.json \
##       --tex=res://sprites/daojishi/daojishitongyong_tex.json \
##       --out=res://sprites/daojishi/daojishitongyong_avatar.tscn
##
## 可选：--armature=名称/索引  --animation=名称  --scale=数值

const DB_FPS_DEFAULT := 24.0
const CURVE_SAMPLES_PER_SEC := 24.0
const STEP_EPSILON := 0.001

var _ske_path := ""
var _tex_path := ""
var _out_path := ""
var _armature_filter := ""
var _animation_filter := ""
var _global_scale := 1.0
var _warnings: Array[String] = []
var _trimmed_sprites := 0

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

	var avatar_root := Node2D.new()
	avatar_root.name = "AvatarRoot"
	if not is_equal_approx(_global_scale, 1.0):
		avatar_root.scale = Vector2(_global_scale, _global_scale)
	var skeleton := Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	avatar_root.add_child(skeleton)

	var bone_nodes := _build_bones(armature, skeleton)
	var slot_nodes := _build_slots(armature, bone_nodes, atlas, tex, skeleton)
	var player := _build_animations(armature, bone_nodes, slot_nodes, frame_rate, avatar_root)
	if player != null:
		avatar_root.add_child(player)

	_set_owner_recursive(avatar_root, avatar_root)
	var packed := PackedScene.new()
	if packed.pack(avatar_root) != OK:
		push_error("[converter] PackedScene.pack 失败")
		avatar_root.free()
		return false
	var err := ResourceSaver.save(packed, _out_path)
	avatar_root.free()
	if err != OK:
		push_error("[converter] 保存失败 %s: %s" % [_out_path, err])
		return false

	print("[converter] 生成 %s（bones=%d, slots=%d, animations=%d, trimmed=%d）" % [
		_out_path, bone_nodes.size(), slot_nodes.size(),
		armature.get("animation", []).size(), _trimmed_sprites])
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
	var dir := _tex_path.get_base_dir()
	var atlas_path := dir.path_join(image_path)
	if not ResourceLoader.exists(atlas_path):
		# 容错：贴图可能被改名（例如 start_game_tex.png -> startgame_tex.png）
		var fallback := _find_atlas_fallback(dir)
		if fallback.is_empty():
			push_error("[converter] 图集不存在: %s" % atlas_path)
			return null
		_warnings.append("图集路径失配，改用同目录贴图: %s" % fallback)
		atlas_path = fallback
	return load(atlas_path) as Texture2D

func _find_atlas_fallback(dir: String) -> String:
	var dir_access := DirAccess.open(dir)
	if dir_access == null:
		return ""
	var candidates: Array[String] = []
	dir_access.list_dir_begin()
	var entry := dir_access.get_next()
	while entry != "":
		if not entry.begins_with(".") and entry.to_lower().ends_with(".png"):
			candidates.append(dir.path_join(entry))
		entry = dir_access.get_next()
	dir_access.list_dir_end()
	if candidates.size() == 1:
		return candidates[0]
	for candidate in candidates:
		if candidate.get_file().to_lower().ends_with("_tex.png"):
			return candidate
	return ""

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

## 裁剪补偿：把“原始帧”的 pivot 对齐到 Sprite2D 原点。
## DragonBones 约定 frameX = -leftTrim、frameY = -topTrim（daojishi/startgame 数据可验证），
## 因此 offset = regionCenter - pivotPointInTrimmed。
func _sprite_offset(sub_texture: Dictionary, display: Dictionary) -> Vector2:
	if not (sub_texture.has("frameX") or sub_texture.has("frameY")):
		return Vector2.ZERO
	var width := float(sub_texture.get("width", 1.0))
	var height := float(sub_texture.get("height", 1.0))
	var frame_width := float(sub_texture.get("frameWidth", width))
	var frame_height := float(sub_texture.get("frameHeight", height))
	var frame_x := float(sub_texture.get("frameX", 0.0))
	var frame_y := float(sub_texture.get("frameY", 0.0))
	var pivot: Dictionary = display.get("pivot", {})
	var pivot_x := float(pivot.get("x", 0.5))
	var pivot_y := float(pivot.get("y", 0.5))
	_trimmed_sprites += 1
	return Vector2(
		width * 0.5 - frame_x - pivot_x * frame_width,
		height * 0.5 - frame_y - pivot_y * frame_height
	)

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
	var slot_index := 0
	for slot_data in armature.get("slot", []):
		var slot_name := str(slot_data.get("name", ""))
		var parent: Node = bone_nodes.get(str(slot_data.get("parent", "")), skeleton)
		var displays: Array = skin_slots.get(slot_name, [])
		if displays.is_empty():
			_warnings.append("插槽 %s 没有 display，跳过" % slot_name)
			slot_index += 1
			continue

		# slot 自身变换单独一层，保证 display 变换相对 slot 而不是相对 bone。
		var slot_node := Node2D.new()
		# slot 名与 bone 名可能重复（puke 有 21 处），统一加前缀，避免场景内重名与查找歧义。
		slot_node.name = "slot_" + _safe_name(slot_name)
		slot_node.z_as_relative = false
		slot_node.z_index = slot_index
		_apply_transform(slot_node, slot_data.get("transform", {}))
		parent.add_child(slot_node)

		var initial_display := int(slot_data.get("displayIndex", 0))
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
			sprite.name = "d%d" % display_index
			sprite.texture = _make_atlas_texture(atlas, sub_textures[display_name])
			sprite.centered = true
			sprite.offset = _sprite_offset(sub_textures[display_name], display)
			if str(slot_data.get("blendMode", "normal")) == "add":
				var material := CanvasItemMaterial.new()
				material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				sprite.material = material
			_apply_transform(sprite, display.get("transform", {}))
			sprite.visible = display_index == initial_display
			slot_node.add_child(sprite)
			entries.append({"node": sprite, "display": display_index})
		if entries.is_empty():
			slot_node.free()
			slot_index += 1
			continue
		result[slot_name] = {"node": slot_node, "entries": entries, "initial": initial_display}
		slot_index += 1
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
		var translate_segments := _vector_segments(bone_frame.get("translateFrame", []), bone.position, frame_rate, false)
		_add_numeric_track(animation, path + ":position", translate_segments, bone.position)
		var scale_segments := _vector_segments(bone_frame.get("scaleFrame", []), bone.scale, frame_rate, true)
		_add_numeric_track(animation, path + ":scale", scale_segments, bone.scale)
		var rotate_segments := _rotation_segments(bone_frame.get("rotateFrame", []), bone.rotation, frame_rate)
		_add_numeric_track(animation, path + ":rotation", rotate_segments, bone.rotation)

	for slot_frame in anim_data.get("slot", []):
		if not slot_frame is Dictionary:
			continue
		var slot: Dictionary = slot_nodes.get(str(slot_frame.get("name", "")), {})
		if slot.is_empty():
			continue
		_track_display(animation, slot, slot_frame.get("displayFrame", []), frame_rate, avatar_root)
		_track_color(animation, slot, slot_frame.get("colorFrame", []), frame_rate, avatar_root)

	if anim_data.has("zOrder"):
		_track_zorder(animation, slot_nodes, anim_data.get("zOrder", []), frame_rate, avatar_root)

	if animation.get_track_count() == 0:
		return null
	return animation

# ---------------------------------------------------------------------
# 数值时间线（继承 + 缓动烘焙）
# ---------------------------------------------------------------------

## 位移/缩放时间线。
## 实测（与原 gddragonbones 参考渲染对照）：这些资产的帧值是相对 base pose 的增量——
##   位移：absolute = base + frame(x, y)（缺省 0）
##   缩放：absolute = base * frame(x, y)（缺省 1）
## 缺省值按 DragonBones 文档取 0/1，而不是继承上一帧。
func _vector_segments(frames: Array, base: Vector2, frame_rate: float, is_scale: bool) -> Array:
	var segments: Array = []
	var time := 0.0
	for frame in frames:
		if not frame is Dictionary:
			continue
		var delta := Vector2(
			float(frame.get("x", 1.0 if is_scale else 0.0)),
			float(frame.get("y", 1.0 if is_scale else 0.0))
		)
		var value := base * delta if is_scale else base + delta
		var duration := float(frame.get("duration", 0.0)) / maxf(frame_rate, 1.0)
		segments.append({
			"time": time,
			"duration": duration,
			"value": value,
			"curve": frame.get("curve", null),
			"easing": frame.get("tweenEasing", null),
			"has_easing": frame.has("tweenEasing"),
		})
		time += duration
	return segments

## 旋转时间线：absolute = base_rotation + frame(rotate)（单位：度，缺省 0）。
func _rotation_segments(frames: Array, base_rotation: float, frame_rate: float) -> Array:
	var segments: Array = []
	var time := 0.0
	for frame in frames:
		if not frame is Dictionary:
			continue
		var delta_deg := float(frame.get("rotate", frame.get("rot", 0.0)))
		var value := base_rotation + deg_to_rad(delta_deg)
		var duration := float(frame.get("duration", 0.0)) / maxf(frame_rate, 1.0)
		segments.append({
			"time": time,
			"duration": duration,
			"value": value,
			"curve": frame.get("curve", null),
			"easing": frame.get("tweenEasing", null),
			"has_easing": frame.has("tweenEasing"),
		})
		time += duration
	return segments

func _alpha_segments(frames: Array, frame_rate: float) -> Array:
	var segments: Array = []
	var current := 1.0
	var time := 0.0
	for frame in frames:
		if not frame is Dictionary:
			continue
		# DragonBones colorFrame 的 value 是“绝对颜色变换”，缺省即默认（aM=100），不是继承上一帧。
		var value: Variant = frame.get("value", null)
		current = 1.0
		if value is Dictionary and value.has("aM"):
			current = clampf(float(value["aM"]) / 100.0, 0.0, 1.0)
		var duration := float(frame.get("duration", 0.0)) / maxf(frame_rate, 1.0)
		segments.append({
			"time": time,
			"duration": duration,
			"value": current,
			"curve": frame.get("curve", null),
			"easing": frame.get("tweenEasing", null),
			"has_easing": frame.has("tweenEasing"),
		})
		time += duration
	return segments

## 把 segment 序列烘焙成关键帧：曲线/缓动插值，缺省缓动按 step 保持。
func _bake_segments(segments: Array) -> Array:
	var keys: Array = []
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		keys.append({"time": float(segment["time"]), "value": segment["value"]})
		if index + 1 >= segments.size():
			continue
		var next: Dictionary = segments[index + 1]
		var duration := float(next["time"]) - float(segment["time"])
		if duration <= 0.0001:
			continue
		var curve: Variant = segment["curve"]
		if curve is Array and curve.size() == 4:
			var samples := clampi(int(ceil(duration * CURVE_SAMPLES_PER_SEC)), 2, 12)
			for sample_index in range(1, samples):
				var progress := float(sample_index) / float(samples)
				var eased := _bezier_ease(progress, curve)
				keys.append({
					"time": float(segment["time"]) + duration * progress,
					"value": _lerp_variant(segment["value"], next["value"], eased),
				})
		elif not bool(segment["has_easing"]):
			# DragonBones 语义：没有 tweenEasing / curve 的段是阶跃（保持当前值到段末）。
			keys.append({
				"time": float(segment["time"]) + duration - STEP_EPSILON,
				"value": segment["value"],
			})
		elif absf(float(segment["easing"])) > 0.0001:
			var samples2 := clampi(int(ceil(duration * CURVE_SAMPLES_PER_SEC)), 2, 12)
			for sample_index2 in range(1, samples2):
				var progress2 := float(sample_index2) / float(samples2)
				var eased2 := progress2 * progress2 if float(segment["easing"]) > 0.0 else 1.0 - (1.0 - progress2) * (1.0 - progress2)
				keys.append({
					"time": float(segment["time"]) + duration * progress2,
					"value": _lerp_variant(segment["value"], next["value"], eased2),
				})
	return keys

func _add_numeric_track(animation: Animation, path: String, segments: Array, rest_value: Variant) -> void:
	if segments.is_empty():
		return
	var keys := _bake_segments(segments)
	if keys.is_empty():
		return
	var has_change := false
	for key in keys:
		if not _values_equal(key["value"], rest_value):
			has_change = true
			break
	if not has_change:
		return
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	for key in keys:
		animation.track_insert_key(track, key["time"], key["value"])

# ---------------------------------------------------------------------
# 插槽显隐 / 透明度 / zOrder
# ---------------------------------------------------------------------

func _track_display(animation: Animation, slot: Dictionary, frames: Array, frame_rate: float, avatar_root: Node2D) -> void:
	if frames.is_empty():
		return
	var keys: Array = []
	var time := 0.0
	for frame in frames:
		if not frame is Dictionary:
			continue
		# displayFrame 缺省 value 即 display 0（绝对索引），不是继承上一帧。
		var display_value := int(frame.get("value", 0))
		keys.append({"time": time, "value": display_value})
		time += float(frame.get("duration", 0.0)) / maxf(frame_rate, 1.0)
	for entry in slot.get("entries", []):
		var sprite: Sprite2D = entry["node"]
		var display_index := int(entry["display"])
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(_rel_path(sprite, avatar_root) + ":visible"))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
		for key in keys:
			animation.track_insert_key(track, float(key["time"]), int(key["value"]) == display_index)

func _track_color(animation: Animation, slot: Dictionary, frames: Array, frame_rate: float, avatar_root: Node2D) -> void:
	if frames.is_empty():
		return
	var segments := _alpha_segments(frames, frame_rate)
	var keys := _bake_segments(segments)
	if keys.is_empty():
		return
	var has_change := false
	for key in keys:
		if absf(float(key["value"]) - 1.0) > 0.0001:
			has_change = true
			break
	if not has_change:
		return
	for entry in slot.get("entries", []):
		var sprite: Sprite2D = entry["node"]
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(_rel_path(sprite, avatar_root) + ":modulate"))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		for key in keys:
			animation.track_insert_key(track, float(key["time"]), Color(1.0, 1.0, 1.0, float(key["value"])))

func _track_zorder(animation: Animation, slot_nodes: Dictionary, frames: Array, frame_rate: float, avatar_root: Node2D) -> void:
	var time := 0.0
	var keyframes: Array = []
	for frame in frames:
		if not frame is Dictionary:
			continue
		keyframes.append({"time": time, "order": frame.get("zOrder", [])})
		time += float(frame.get("duration", 0.0)) / maxf(frame_rate, 1.0)
	for keyframe in keyframes:
		var order: Array = keyframe["order"]
		for index in order.size():
			var slot: Dictionary = slot_nodes.get(str(order[index]), {})
			if slot.is_empty():
				continue
			var slot_node: Node2D = slot["node"]
			var track_path := NodePath(_rel_path(slot_node, avatar_root) + ":z_index")
			var track := animation.find_track(track_path, Animation.TYPE_VALUE)
			if track == -1:
				track = animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track, track_path)
				animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
			animation.track_insert_key(track, float(keyframe["time"]), index)

# ---------------------------------------------------------------------
# 缓动数学
# ---------------------------------------------------------------------

## DragonBones curve = [x1, y1, x2, y2]（P0=(0,0), P3=(1,1)）。
func _bezier_ease(x: float, curve: Array) -> float:
	var x1 := clampf(float(curve[0]), 0.0, 1.0)
	var y1 := float(curve[1])
	var x2 := clampf(float(curve[2]), 0.0, 1.0)
	var y2 := float(curve[3])
	# 由 x 反解 t（牛顿迭代），再求 y。
	var t := x
	for _i in range(6):
		var mt := 1.0 - t
		var px := 3.0 * mt * mt * t * x1 + 3.0 * mt * t * t * x2 + t * t * t
		var dx := 3.0 * mt * mt * x1 + 6.0 * mt * t * (x2 - x1) + 3.0 * t * t * (1.0 - x2)
		if absf(dx) < 0.00001:
			break
		t = clampf(t - (px - x) / dx, 0.0, 1.0)
	var mt2 := 1.0 - t
	return 3.0 * mt2 * mt2 * t * y1 + 3.0 * mt2 * t * t * y2 + t * t * t

func _lerp_variant(from_value: Variant, to_value: Variant, weight: float) -> Variant:
	if from_value is Vector2:
		return (from_value as Vector2).lerp(to_value as Vector2, weight)
	return lerpf(float(from_value), float(to_value), weight)

func _values_equal(a: Variant, b: Variant) -> bool:
	if a is Vector2 and b is Vector2:
		return (a as Vector2).is_equal_approx(b as Vector2)
	return absf(float(a) - float(b)) < 0.0001

# ---------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------

func _rel_path(node: Node, root_node: Node) -> String:
	var parts: Array[String] = []
	var current: Node = node
	while current != null and current != root_node:
		parts.push_front(str(current.name))
		current = current.get_parent()
	return "/".join(parts)

## DragonBones 局部矩阵：x 轴角 = skY，y 轴角 = skX + 90°（skX != skY 时为剪切）。
## 用 Node2D 的 rotation(=skY) + skew(=skX-skY) + scale 还原。
func _apply_transform(node: Node2D, transform_data: Dictionary) -> void:
	node.position = Vector2(float(transform_data.get("x", 0.0)), float(transform_data.get("y", 0.0)))
	node.scale = Vector2(float(transform_data.get("scX", 1.0)), float(transform_data.get("scY", 1.0)))
	var rotation_x := float(transform_data.get("skX", transform_data.get("rot", 0.0)))
	var rotation_y := float(transform_data.get("skY", rotation_x))
	node.rotation = deg_to_rad(rotation_y)
	node.skew = deg_to_rad(rotation_x - rotation_y)

func _safe_name(raw: String) -> String:
	var result := raw.strip_edges().replace(".", "_").replace(":", "_").replace("@", "_").replace("/", "_").replace("\"", "_").replace("%", "_")
	if result.is_empty():
		result = "Node"
	return result

func _set_owner_recursive(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner = root_node
		_set_owner_recursive(child, root_node)
