class_name NativeCharacterAvatar
extends Node2D

## 模块：原生骨骼动画统一门面（PROMPT_REFACTOR 阶段 2）
## 职责：用一个稳定的 API 播放 `Skeleton2D + AnimationPlayer` 骨骼动画，
##       取代对 gddragonbones（DragonBones GDExtension）的直接依赖。
## 用法：
##   avatar.play_animation("idle", true, 0.2)
##   avatar.stop_animation()
##   if avatar.has_animation("attack"): ...
## 说明：
##   - `avatar_scene` 指向 `tools/dragonbones_converter.gd` 生成的原生场景；
##   - 场景内约定包含 `AnimationPlayer`（任意深度）与 `Skeleton2D`；
##   - 多套皮肤由转换器在根节点写入 meta `dragonbones_skins` 后生效；
##     未提供皮肤映射时 `set_skin()` 返回 false（单皮动画属正常情况）。

## 由转换器生成的原生骨骼场景。
@export var avatar_scene: PackedScene = null
## 进入树后自动播放的动画名（空表示不自动播放）。
@export var autoplay_animation: StringName = &""
## 自动播放是否循环。
@export var autoplay_loop: bool = true

var _avatar: Node2D = null
var _player: AnimationPlayer = null
var _skins: Dictionary = {}
var _current_skin := ""

func _ready() -> void:
	if _ensure_avatar() and not autoplay_animation.is_empty():
		play_animation(String(autoplay_animation), autoplay_loop)

# ---------------------------------------------------------------------
# 对外 API（PROMPT_REFACTOR 3.1）
# ---------------------------------------------------------------------

## 播放动画；返回是否成功（动画不存在或场景未就绪时返回 false）。
func play_animation(anim_name: String, loop: bool = true, blend_time: float = 0.2) -> bool:
	if anim_name.is_empty() or not _ensure_avatar() or _player == null:
		return false
	if not _player.has_animation(anim_name):
		push_warning("[NativeCharacterAvatar] 动画不存在: %s" % anim_name)
		return false
	var animation := _player.get_animation(anim_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_player.play(anim_name, maxf(blend_time, 0.0))
	return true

func stop_animation() -> void:
	if _player != null:
		_player.stop()

## 是否存在指定动画。
func has_animation(anim_name: String) -> bool:
	if not _ensure_avatar() or _player == null:
		return false
	return _player.has_animation(anim_name)

## 全部动画名（调试/自检用）。
func animation_names() -> PackedStringArray:
	if not _ensure_avatar() or _player == null:
		return PackedStringArray()
	var result := PackedStringArray()
	for name1 in _player.get_animation_list():
		result.append(str(name1))
	result.sort()
	return result

## 切换皮肤；转换器未写入皮肤映射时返回 false。
func set_skin(skin_name: String) -> bool:
	if not _ensure_avatar() or _skins.is_empty():
		return false
	if not _skins.has(skin_name):
		push_warning("[NativeCharacterAvatar] 皮肤不存在: %s" % skin_name)
		return false
	_current_skin = skin_name
	var mapping: Dictionary = _skins[skin_name]
	for node_name in mapping.keys():
		var node := _avatar.get_node_or_null(str(node_name))
		if node is CanvasItem:
			(node as CanvasItem).visible = bool(mapping[node_name])
	return true

func current_skin() -> String:
	return _current_skin

# ---------------------------------------------------------------------
# 查询 / 内部
# ---------------------------------------------------------------------

## 当前动画名（未播放返回空）。
func current_animation() -> StringName:
	return _player.current_animation if _player != null else &""

func is_playing() -> bool:
	return _player != null and _player.is_playing()

func get_animation_player() -> AnimationPlayer:
	_ensure_avatar()
	return _player

func get_avatar_root() -> Node2D:
	_ensure_avatar()
	return _avatar

func get_skeleton() -> Skeleton2D:
	if not _ensure_avatar():
		return null
	return _find_first(_avatar, "Skeleton2D") as Skeleton2D

func _ensure_avatar() -> bool:
	if _avatar != null and is_instance_valid(_avatar):
		return true
	if avatar_scene == null:
		return false
	_avatar = avatar_scene.instantiate() as Node2D
	if _avatar == null:
		push_error("[NativeCharacterAvatar] avatar_scene 根节点不是 Node2D")
		return false
	add_child(_avatar)
	_player = _find_first(_avatar, "AnimationPlayer") as AnimationPlayer
	if _player == null:
		push_warning("[NativeCharacterAvatar] 场景中缺少 AnimationPlayer: %s" % avatar_scene.resource_path)
	_skins = _avatar.get_meta("dragonbones_skins", {})
	return true

func _find_first(node: Node, target_name: String) -> Node:
	if str(node.name) == target_name:
		return node
	for child in node.get_children():
		var found := _find_first(child, target_name)
		if found != null:
			return found
	return null
