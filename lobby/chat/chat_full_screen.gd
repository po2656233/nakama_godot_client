extends Control

signal fullscreenSIG(is_fullscreen: bool)

@export var animate_transition: bool = true
@export var transition_duration: float = 0.1

var is_fullscreen := false
var is_rotated = false
var tween: Tween

# 在类成员变量中添加（用于保存原始矩形在视口坐标系中的位置）
var _original_global_rect := Rect2()

var original_state := {
	"parent": null,
	"position": Vector2.ZERO,
	"size": Vector2.ZERO,
	"anchors": {},
	"margins": {}
}


func _on_fullscreen_toggle():
	Global.WindowDrag.stopMove = !is_fullscreen
	if is_fullscreen:
		exit_fullscreen()
	else:
		enter_fullscreen()

func enter_fullscreen():
	if is_fullscreen: return

	save_current_state()
	
	# 保存原始矩形在视口坐标系中的位置（用于退出动画的终点）
	if original_state.parent:
		# 计算控件在视口坐标系中的全局矩形
		var global_pos = original_state.parent.global_position + original_state.position
		_original_global_rect = Rect2(global_pos, original_state.size)
	else:
		_original_global_rect = Rect2(original_state.position, original_state.size)
	
	var viewport = get_viewport()
	if viewport:
		var target_size = viewport.get_visible_rect().size
		var target_position = Vector2.ZERO
		if animate_transition:
			animate_to_fullscreen(target_position, target_size)
		else:
			apply_fullscreen(target_position, target_size)


func exit_fullscreen():
	if !is_fullscreen: return
	if animate_transition:
		animate_to_normal()
	else:
		restore_original_state()
	pass

func save_current_state():
	var parent = get_parent()
	if parent:
		original_state.parent = parent
		original_state.position = position
		original_state.size = size
		original_state.anchors = {
			"left": anchor_left,
			"right": anchor_right,
			"top": anchor_top,
			"bottom": anchor_bottom
		}
		original_state.margins = {
			"left": offset_left,
			"right": offset_right,
			"top": offset_top,
			"bottom": offset_bottom
		}
	pass

func apply_fullscreen(target_position: Vector2, target_size: Vector2):
	var viewport = get_viewport()
	if !viewport: return

	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
		viewport.add_child(self)
		position = target_position
		size = target_size
		anchors_preset = Control.PRESET_FULL_RECT
		top_level = true
		is_fullscreen = true
		fullscreenSIG.emit(true)
	pass

func animate_to_fullscreen(target_position: Vector2, target_size: Vector2):
	if tween: tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	top_level = true
	tween.tween_property(self, "position", target_position, transition_duration)
	tween.parallel().tween_property(self, "size", target_size, transition_duration)
	tween.tween_callback(func():
		var viewport=get_viewport()
		if viewport and original_state.parent:
			if get_parent() != viewport:
				original_state.parent.remove_child(self)
				viewport.add_child(self)
			anchors_preset=Control.PRESET_FULL_RECT
			is_fullscreen=true
			fullscreenSIG.emit(true)
	)
	pass



func animate_to_normal():
	if !original_state.parent: return
	Global.WindowDrag.unregister_drag_zone(original_state.parent)
	
	if tween: tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	var viewport = get_viewport()
	if !viewport: return
	
	var viewport_size = viewport.get_visible_rect().size
	
	# 终点矩形（原始状态在视口坐标系中的位置）
	var end_rect = _original_global_rect
	
	# 起点矩形（全屏状态，视口坐标系中）
	var start_rect = Rect2(Vector2.ZERO, viewport_size)
	
	# 自定义插值：固定右边界和下边界
	var update_rect = func(t: float):
		# 宽度和高度线性变化
		var w = lerpf(start_rect.size.x, end_rect.size.x, t)
		var h = lerpf(start_rect.size.y, end_rect.size.y, t)
		
		# 右边界和下边界线性变化（保持右/下边缘连续）
		var right = lerpf(start_rect.end.x, end_rect.end.x, t)
		var bottom = lerpf(start_rect.end.y, end_rect.end.y, t)
		
		# 反推左上角位置
		var left = right - w
		var top = bottom - h
		
		position = Vector2(left, top)
		size = Vector2(w, h)
	
	tween.tween_method(update_rect, 0.0, 1.0, transition_duration)
	
	# 动画完成后恢复父节点、锚点等
	tween.tween_callback(restore_original_state)
	pass

func restore_original_state():
	if !original_state.parent: return
	
	# 将节点移回原始父节点
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
		original_state.parent.add_child(self)
		top_level = false
	
	# 恢复保存的锚点和边距
	anchor_left   = original_state.anchors.left
	anchor_right  = original_state.anchors.right
	anchor_top    = original_state.anchors.top
	anchor_bottom = original_state.anchors.bottom
	offset_left   = original_state.margins.left
	offset_right  = original_state.margins.right
	offset_top    = original_state.margins.top
	offset_bottom = original_state.margins.bottom
	
	# 由于锚点恢复可能改变位置/尺寸，强制设为原始值
	position = original_state.position
	size = original_state.size
	
	is_fullscreen = false
	fullscreenSIG.emit(false)
	pass
