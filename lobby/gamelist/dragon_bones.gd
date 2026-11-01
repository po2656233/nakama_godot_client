extends NativeCharacterAvatar

## 模块：游戏卡片上的原生骨骼动画（DragonBones 平替）
## 职责：进入树后自动播放动画，并跟随父容器保持居中。
## 说明：由 `extends DragonBones` 迁移而来，API 与 NativeCharacterAvatar 一致；
##       `scaleX/scaleY` 仅用于居中换算（原实现如此），不改变节点缩放。

@export var scaleX: float = 2.0
@export var scaleY: float = 2.0

func _ready() -> void:
	super._ready()
	center_in_parent()
	var parent := get_parent()
	if parent is Control:
		(parent as Control).resized.connect(_on_parent_resized)

func center_in_parent() -> void:
	var parent := get_parent()
	if parent is Control:
		var parent_rect: Rect2 = (parent as Control).get_rect()
		position = Vector2(parent_rect.size.x / scaleX, parent_rect.size.y / scaleY)

func _on_parent_resized() -> void:
	center_in_parent()
