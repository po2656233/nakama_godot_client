class_name GameDescriptor
extends RefCounted

## 模块：子游戏描述
## 职责：描述一个可启动的子游戏（键名、场景、人数、是否联机等）。
## 用途：GameCatalog 声明数据，GameRegistry 建立索引，GameLauncher 按它启动场景。
## 说明：key 必须与服务端游戏列表的 en_name 一致（大小写不敏感）。

var key: String = ""
var title: String = ""
var scene_path: String = ""
var max_players: int = 1
var online: bool = false
var show_back_button: bool = true
var order: int = 0
var aliases: PackedStringArray = PackedStringArray()
var tags: PackedStringArray = PackedStringArray()
## 来源：builtin（内置）/ external（下载或外部注册）
var source: String = "builtin"

func _init(data: Dictionary = {}) -> void:
	key = _normalize_token(str(data.get("key", "")))
	title = str(data.get("title", key))
	scene_path = str(data.get("scene", data.get("scene_path", ""))).strip_edges()
	max_players = maxi(1, int(data.get("max_players", 1)))
	online = bool(data.get("online", false))
	show_back_button = bool(data.get("show_back_button", true))
	order = int(data.get("order", 0))
	aliases = _to_tokens(data.get("aliases", []))
	tags = _to_tokens(data.get("tags", []))
	source = str(data.get("source", "builtin"))

## 键名/别名是否匹配（全部按小写比较）。
func matches(name: String) -> bool:
	var token := _normalize_token(name)
	if token.is_empty():
		return false
	if token == key:
		return true
	return aliases.has(token)

## 场景路径是否真的存在（下载游戏的场景可能刚落盘，ResourceLoader 尚未扫描）。
func scene_exists() -> bool:
	if scene_path.is_empty():
		return false
	return FileAccess.file_exists(scene_path) or ResourceLoader.exists(scene_path)

func is_valid() -> bool:
	return not key.is_empty() and not title.is_empty() and not scene_path.is_empty()

func to_dict() -> Dictionary:
	return {
		"key": key,
		"title": title,
		"scene": scene_path,
		"max_players": max_players,
		"online": online,
		"show_back_button": show_back_button,
		"order": order,
		"aliases": Array(aliases),
		"tags": Array(tags),
		"source": source,
	}

func _to_string() -> String:
	return "GameDescriptor(%s -> %s)" % [key, scene_path]

static func _normalize_token(value: String) -> String:
	return value.strip_edges().to_lower()

static func _to_tokens(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if value is Array or value is PackedStringArray:
		for item in value:
			var token := _normalize_token(str(item))
			if not token.is_empty() and not result.has(token):
				result.append(token)
	return result
