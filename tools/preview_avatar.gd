extends SceneTree

## 阶段 1 视觉校验工具：加载原生骨骼场景并截图（需要真实渲染，不能 --headless）。
##
## 用法：
##   godot --path . --script res://tools/preview_avatar.gd -- \
##       --scene=res://sprites/daojishi/daojishitongyong_avatar.tscn \
##       --out=user://preview_daojishi.png --time=0.0 --scale=1.0
##
## 参数：
##   --scene  要预览的场景（默认 daojishi）
##   --out    截图输出路径（默认 user://preview_avatar.png）
##   --anim   动画名（默认 animation）
##   --time   截图前把动画 seek 到的时间（秒，默认 0）
##   --scale  预览缩放（默认 1）
##   --bg     背景色 0xRRGGBB（默认深灰）

var _scene_path := "res://sprites/daojishi/daojishitongyong_avatar.tscn"
var _out_path := "user://preview_avatar.png"
var _anim_name := "animation"
var _seek_time := 0.0
var _preview_scale := 1.0
var _bg := Color(0.12, 0.12, 0.14, 1.0)
var _delay := 0.0

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="): _scene_path = arg.substr(8)
		elif arg.begins_with("--out="): _out_path = arg.substr(6)
		elif arg.begins_with("--anim="): _anim_name = arg.substr(7)
		elif arg.begins_with("--time="): _seek_time = float(arg.substr(7))
		elif arg.begins_with("--scale="): _preview_scale = float(arg.substr(8))
		elif arg.begins_with("--bg="): _bg = Color.html(arg.substr(5))
		elif arg.begins_with("--delay="): _delay = float(arg.substr(8))
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	var background := ColorRect.new()
	background.color = _bg
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var packed: PackedScene = load(_scene_path)
	if packed == null:
		push_error("[preview] 无法加载场景: %s" % _scene_path)
		quit(1)
		return
	var avatar := packed.instantiate()
	root.add_child(avatar)
	if avatar is Node2D:
		(avatar as Node2D).position = Vector2(root.size.x * 0.5, root.size.y * 0.5)
		(avatar as Node2D).scale = Vector2(_preview_scale, _preview_scale)

	var player := _find_first(avatar, "AnimationPlayer") as AnimationPlayer
	if player != null and player.has_animation(_anim_name):
		player.play(_anim_name)
		player.seek(_seek_time, true)
		player.pause()
	elif player != null:
		push_warning("[preview] 动画不存在: %s（可用: %s）" % [_anim_name, str(player.get_animation_list())])

	# 等渲染若干帧，确保纹理/骨骼更新完成；--delay 用于 DragonBones 参考实现（按真实时间播放）
	for _i in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	if _delay > 0.0:
		await create_timer(_delay).timeout
		await RenderingServer.frame_post_draw

	var image: Image = root.get_texture().get_image()
	var err := image.save_png(_out_path)
	if err != OK:
		push_error("[preview] 截图保存失败 %s: %s" % [_out_path, err])
		quit(1)
		return
	print("[preview] saved %s (%dx%d) scene=%s time=%.2f" % [_out_path, image.get_width(), image.get_height(), _scene_path, _seek_time])
	quit(0)

func _find_first(node: Node, target_name: String) -> Node:
	if str(node.name) == target_name:
		return node
	for child in node.get_children():
		var found := _find_first(child, target_name)
		if found != null:
			return found
	return null
