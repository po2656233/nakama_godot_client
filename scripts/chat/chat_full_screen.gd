extends Control


signal fullscreenSIG(is_fullscreen: bool)


@export var animate_transition: bool = true
@export var transition_duration: float = 0.3

var is_fullscreen := false
var is_rotated = false

var tween: Tween


var original_state := {
	"parent": null,
	"position": Vector2.ZERO,
	"size": Vector2.ZERO,
	"anchors": {},
	"margins": {}
}
#########################################################

###############################################################
func _on_fullscreen_toggle():

	if !is_fullscreen:
		WindowDrag.stopMove = true
		enter_fullscreen()
	else:
		WindowDrag.stopMove = false
		exit_fullscreen()
	# await get_tree().create_timer(1).timeout
	# Network.get_chat_history()
	pass



########################################################
func enter_fullscreen():
	if is_fullscreen:
		return

	# 保存当前状态
	save_current_state()
	
	# 准备全屏状态
	var viewport = get_viewport()
	if viewport:
		var target_size = viewport.get_visible_rect().size
		var target_position = Vector2.ZERO
		
		if animate_transition:
			animate_to_fullscreen(target_position, target_size)
		else:
			apply_fullscreen(target_position, target_size)

	pass

func exit_fullscreen():
	if !is_fullscreen:
		return
	
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
	if !viewport:
		return
		
	# 保存当前父节点引用
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
		
		# 设置全屏属性
		viewport.add_child(self)
		position = target_position
		size = target_size
		anchors_preset = Control.PRESET_FULL_RECT
		
		# 确保显示在最上层
		top_level = true
		
		# 更新状态
		is_fullscreen = true
		fullscreenSIG.emit(true)

func animate_to_fullscreen(target_position: Vector2, target_size: Vector2):
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 先设置top_level确保在最上层
	top_level = true
	
	# 动画过渡到全屏
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
	if !original_state.parent:
		return
	WindowDrag.unregister_drag_zone(original_state.parent)
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 动画过渡到原始状态
	tween.tween_property(self, "position", original_state.position, transition_duration)
	tween.parallel().tween_property(self, "size", original_state.size, transition_duration)
	
	tween.tween_callback(func():
		restore_original_state()
	)
	pass

func restore_original_state():
	if !original_state.parent:
		return
		
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	
	# 恢复到原始父节点
	original_state.parent.add_child(self)
	WindowDrag.unregister_drag_zone(original_state.parent)
	
	# 恢复原始属性
	position = original_state.position
	size = original_state.size
	anchor_left = original_state.anchors.left
	anchor_right = original_state.anchors.right
	anchor_top = original_state.anchors.top
	anchor_bottom = original_state.anchors.bottom
	offset_left = original_state.margins.left
	offset_right = original_state.margins.right
	offset_top = original_state.margins.top
	offset_bottom = original_state.margins.bottom
	
	
	# 重置顶层显示
	top_level = false
	
	is_fullscreen = false
	fullscreenSIG.emit(false)
	pass
