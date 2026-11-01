extends RefCounted

## 模块：场景转场
## 职责：集中维护转场类型表，并把「转场类型 -> FancyFade 调用」收敛到一处。
## 依赖：Global.FancyFade（addons/transitions）。
## 说明：SceneMgr 只调用 play()，不再关心具体动画实现。

const DEFAULT_IMAGE := preload("res://addons/transitions/images/blurry-noise.png")

const TYPES := {
	# 擦除
	"WIPE_LEFT": {"key": "wipe-left", "description": "从右向左擦除"},
	"WIPE_RIGHT": {"key": "wipe-right", "description": "从左向右擦除"},
	"WIPE_UP": {"key": "wipe-up", "description": "从下向上擦除"},
	"WIPE_DOWN": {"key": "wipe-down", "description": "从上向下擦除"},
	"WIPE_SQUARE": {"key": "square", "description": "方形擦除"},
	"WIPE_CONICAL": {"key": "conical", "description": "锥形擦除"},
	# 圆形
	"CIRCLE_IN": {"key": "circle-in", "description": "圆形向内收缩"},
	"CIRCLE_OUT": {"key": "circle-out", "description": "圆形向外扩展"},
	# 噪点
	"NOISE": {"key": "noise", "description": "随机噪点过渡"},
	"NOISE_PIXELATED": {"key": "noise-pixelated", "description": "像素化噪点过渡"},
	"NOISE_BLURRY": {"key": "blurry-noise", "description": "模糊噪点过渡"},
	"NOISE_CELL": {"key": "cell-noise", "description": "蜂窝状噪点过渡"},
	# 艺术效果
	"PAINT_BRUSH_HORIZONTAL": {"key": "horizontal-paint-brush", "description": "水平画笔"},
	"PAINT_BRUSH_VERTICAL": {"key": "vertical-paint-brush", "description": "垂直画笔"},
	"SWIRL": {"key": "swirl", "description": "旋涡"},
	"TILE_REVEAL": {"key": "tile_reveal", "description": "瓦片揭示"},
	# 基础
	"custom": {"key": "custom", "description": "自定义过渡"},
	"cross": {"key": "cross", "description": "交叉淡入淡出"},
	"instant": {"key": "instant", "description": "立即切换"},
}

## 把大写枚举名/小写 key 统一成 TYPES 的键；未知类型回退到 cross。
static func normalize(type_name: String) -> String:
	if TYPES.has(type_name):
		return type_name
	var lower := type_name.to_lower()
	for type_key in TYPES:
		if type_key.to_lower() == lower or str(TYPES[type_key]["key"]).to_lower() == lower:
			return type_key
	return "cross"

static func get_key(type_name: String) -> String:
	if not TYPES.has(type_name):
		return ""
	return str(TYPES[type_name]["key"])

static func get_description(type_name: String) -> String:
	if not TYPES.has(type_name):
		return ""
	return str(TYPES[type_name]["description"])

## 播放转场。调用方不需要 await（FancyFade 内部自己完成动画）。
static func play(scene: Node, transition_way: String = "cross", seconds: float = 1.0, custom_image: Texture2D = null) -> void:
	if scene == null:
		return

	var type_key := normalize(transition_way)
	var fade_key := str(TYPES[type_key]["key"])

	# headless（CI/脚本校验）没有可截图的视口；instant 也不需要截图，直接替换。
	if fade_key == "instant" or DisplayServer.get_name() == "headless":
		Global.SceneMgr.replace_current_scene(scene)
		return

	match fade_key:
		"cross":
			Global.FancyFade.cross_fade(scene, seconds)
		"custom":
			Global.FancyFade.custom_fade(scene, seconds, custom_image if custom_image != null else DEFAULT_IMAGE)
		_:
			Global.FancyFade._fade(fade_key, scene, seconds)
