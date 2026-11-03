extends SceneTree

## 阶段 2 验收测试：DragonBones -> 原生骨骼动画（Skeleton2D + AnimationPlayer）。
##
## 覆盖：
##   1. 转换产物结构（骨骼数 / 插槽 Sprite / 动画名 / 时长 / 轨道数）；
##   2. NativeCharacterAvatar 门面 API（has_animation / play / stop / set_skin）；
##   3. countdown_timer.tscn 已替换为原生 Avatar，且不再包含 DragonBones 节点。
##
## 用法：godot --headless --path . --script res://tools/test_avatar.gd
## 退出码：0 通过；1 失败。

const AVATAR_SCENE := "res://sprites/daojishi/daojishitongyong_avatar.tscn"
const COUNTDOWN_SCENE := "res://shared/ui/countdown_timer.tscn"

var _passed := 0
var _failed := 0
var _done := false

func _init() -> void:
	_run.call_deferred()
	_guard.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	# 1) 转换产物结构
	var packed := ResourceLoader.load(AVATAR_SCENE) as PackedScene
	_check(packed != null, "原生骨骼场景可加载")
	if packed != null:
		var avatar_root := packed.instantiate()
		var player := _find_first(avatar_root, "AnimationPlayer") as AnimationPlayer
		var skeleton := _find_first(avatar_root, "Skeleton2D") as Skeleton2D
		_check(player != null, "包含 AnimationPlayer")
		_check(skeleton != null, "包含 Skeleton2D")
		_check(skeleton != null and _count_type(skeleton, "Bone2D") == 6, "骨骼数量 == 6")
		_check(_count_type(avatar_root, "Sprite2D") == 4, "插槽 Sprite 数量 == 4")
		if player != null:
			_check(player.has_animation("animation"), "包含动画 animation")
			var animation := player.get_animation("animation")
			if animation != null:
				_check(absf(animation.length - 1.0) < 0.01, "动画时长 == 1.0s（实际 %.3f）" % animation.length)
				_check(animation.get_track_count() == 14, "轨道数量 == 14（实际 %d）" % animation.get_track_count())
		avatar_root.free()

	# 2) 门面 API
	var avatar := NativeCharacterAvatar.new()
	avatar.avatar_scene = packed
	avatar.autoplay_animation = &""
	root.add_child(avatar)
	await process_frame
	await process_frame
	_check(avatar.has_animation("animation"), "门面 has_animation(animation)")
	_check(not avatar.has_animation("nope"), "门面拒绝未知动画")
	_check(avatar.play_animation("animation", true, 0.1), "门面 play_animation 成功")
	await process_frame
	_check(avatar.current_animation() == &"animation", "当前动画 == animation")
	_check(avatar.is_playing(), "动画正在播放")
	_check(avatar.play_animation("animation", false, 0.0), "非循环播放成功")
	avatar.stop_animation()
	await process_frame
	_check(not avatar.is_playing(), "stop_animation 后停止")
	_check(not avatar.set_skin("default"), "单皮动画 set_skin 返回 false")
	_check(avatar.get_animation_player() != null and avatar.get_skeleton() != null, "可获取 AnimationPlayer/Skeleton2D")
	avatar.queue_free()
	await process_frame

	# 3) countdown_timer 已替换
	var countdown := ResourceLoader.load(COUNTDOWN_SCENE) as PackedScene
	_check(countdown != null, "countdown_timer.tscn 可加载")
	if countdown != null:
		var instance := countdown.instantiate()
		var avatar_node := instance.get_node_or_null("Avatar")
		_check(avatar_node != null, "含 Avatar 节点")
		_check(avatar_node is NativeCharacterAvatar, "Avatar 节点是 NativeCharacterAvatar")
		_check(_find_first(instance, "DragonBones") == null, "不再包含 DragonBones 节点")
		if avatar_node is NativeCharacterAvatar:
			_check(String(avatar_node.autoplay_animation) == "animation", "Avatar 自动播放 animation")
		instance.free()

	_finish()

func _find_first(node: Node, target_name: String) -> Node:
	if str(node.name) == target_name:
		return node
	for child in node.get_children():
		var found := _find_first(child, target_name)
		if found != null:
			return found
	return null

func _count_type(node: Node, type_name: String) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		count += _count_type(child, type_name)
	return count

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", label)

func _finish() -> void:
	if _done:
		return
	_done = true
	print("\n===== 原生骨骼动画测试：通过 %d 项，失败 %d 项 =====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _guard() -> void:
	await create_timer(20.0).timeout
	if _done:
		return
	_done = true
	print("FAIL: 原生骨骼动画测试超时（20s）")
	quit(1)
