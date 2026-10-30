class_name GameContext
extends RefCounted

## 模块：子游戏启动上下文
## 职责：把“从哪个入口、以什么玩法、哪个房间/对局”启动游戏的信息集中传递。
## 说明：子游戏只读这份上下文，不要在游戏内部再去拼装房间/对局信息。

var key: String = ""
var title: String = ""
var game_id: int = -1
var mode: int = 0
var room_id: Variant = -1
var match_id: String = ""
var online: bool = false
var previous_scene: String = ""
var options: Dictionary = {}

## 由 GameLauncher 调用：从 GameDescriptor 和调用方参数生成上下文。
static func create(descriptor: GameDescriptor, p_options: Dictionary = {}) -> GameContext:
	var context := GameContext.new()
	if descriptor == null:
		return context

	context.key = descriptor.key
	context.title = descriptor.title
	context.online = descriptor.online
	context.options = p_options.duplicate(true)
	context.mode = int(p_options.get("mode", 0))
	context.room_id = p_options.get("room_id", -1)

	if Global.has_global("SceneMgr"):
		context.previous_scene = Global.SceneMgr.get_previous_scene_name()

	if Global.has_global("OnlineMatch"):
		context.match_id = str(Global.OnlineMatch.get_match_id())
	if p_options.has("match_id"):
		context.match_id = str(p_options.get("match_id"))

	if p_options.has("game_id"):
		context.game_id = int(p_options.get("game_id"))
	elif descriptor.online and Global.has_global("OnlineGame"):
		context.game_id = int(Global.OnlineGame.getGameID(descriptor.key))

	return context

func get_option(name: String, default_value: Variant = null) -> Variant:
	return options.get(name, default_value)

func has_match() -> bool:
	return not match_id.is_empty()

func is_online() -> bool:
	return online and not match_id.is_empty()

func to_dict() -> Dictionary:
	return {
		"key": key,
		"title": title,
		"game_id": game_id,
		"mode": mode,
		"room_id": room_id,
		"match_id": match_id,
		"online": online,
		"previous_scene": previous_scene,
		"options": options.duplicate(true),
	}
