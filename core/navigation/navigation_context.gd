class_name NavigationContext
extends RefCounted

## 模块：导航上下文（PROMPT_REFACTOR 2.2 ①）
## 职责：记录“玩家是从哪个入口进入子游戏”的信息，供 SceneRouter 退出时按来源精准回退。
## 说明：
##   - 只描述导航来源，不持有场景/网络对象；
##   - 可安全地放进 GameContext.options 或日志里（to_dict）。

## 进入来源枚举。
enum EntrySource {
	GAME_LIST,      # 从游戏列表/大厅直接快速匹配进入
	ROOM_LIST,      # 从具体游戏的房间列表进入
	CLUB_ROOM_LIST, # 从俱乐部房间列表进入
	CHAT_INVITE,    # 从聊天室/好友邀请卡片进入
}

var source: int = EntrySource.GAME_LIST
var game_id: String = ""
var room_id: String = ""
var extra_data: Dictionary = {}

func _init(
	p_source: int = EntrySource.GAME_LIST,
	p_game_id: String = "",
	p_room_id: String = "",
	p_extra_data: Dictionary = {}
) -> void:
	source = p_source
	game_id = p_game_id
	room_id = p_room_id
	extra_data = p_extra_data.duplicate(true)

## 来源的可读名（日志/调试）。
func source_name() -> String:
	match source:
		EntrySource.GAME_LIST:
			return "GAME_LIST"
		EntrySource.ROOM_LIST:
			return "ROOM_LIST"
		EntrySource.CLUB_ROOM_LIST:
			return "CLUB_ROOM_LIST"
		EntrySource.CHAT_INVITE:
			return "CHAT_INVITE"
		_:
			return "UNKNOWN"

## 序列化（可以放进 GameContext.options / 存档）。
func to_dict() -> Dictionary:
	return {
		"source": source,
		"source_name": source_name(),
		"game_id": game_id,
		"room_id": room_id,
		"extra_data": extra_data.duplicate(true),
	}

## 反序列化；非法数据回退到 GAME_LIST。
static func from_dict(data: Dictionary) -> NavigationContext:
	var source_value: int = int(data.get("source", EntrySource.GAME_LIST))
	if source_value < EntrySource.GAME_LIST or source_value > EntrySource.CHAT_INVITE:
		source_value = EntrySource.GAME_LIST
	var extra: Dictionary = {}
	if data.get("extra_data") is Dictionary:
		extra = data["extra_data"]
	return NavigationContext.new(
		source_value,
		str(data.get("game_id", "")),
		str(data.get("room_id", "")),
		extra
	)

# ---------------------------------------------------------------------
# 常用工厂
# ---------------------------------------------------------------------

static func for_game_list(p_game_id: String = "") -> NavigationContext:
	return NavigationContext.new(EntrySource.GAME_LIST, p_game_id)

static func for_room_list(p_game_id: String, p_room_id: String = "", p_extra: Dictionary = {}) -> NavigationContext:
	return NavigationContext.new(EntrySource.ROOM_LIST, p_game_id, p_room_id, p_extra)

static func for_club_room_list(p_game_id: String, p_room_id: String = "", p_extra: Dictionary = {}) -> NavigationContext:
	return NavigationContext.new(EntrySource.CLUB_ROOM_LIST, p_game_id, p_room_id, p_extra)

static func for_chat_invite(p_game_id: String, p_room_id: String = "", p_extra: Dictionary = {}) -> NavigationContext:
	return NavigationContext.new(EntrySource.CHAT_INVITE, p_game_id, p_room_id, p_extra)

func _to_string() -> String:
	return "NavigationContext(%s, game=%s, room=%s)" % [source_name(), game_id, room_id]
