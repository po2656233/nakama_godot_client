extends RefCounted

## 模块：场景路由表
## 职责：只维护「场景名 -> 场景路径」映射，不加载场景、不转场、不访问网络。
## 说明：子游戏不在这里登记，统一由 GameRegistry 管理（SceneMgr 会做兜底查询）。

## 应用级页面路由（子游戏见 scripts/game/core/game_catalog.gd）。
const DEFAULT_ROUTES := {
	"loading": "res://scenes/1common/loading/loading_screen.tscn",
	"login": "res://scenes/login.tscn",
	"register": "res://scenes/register.tscn",
	"home": "res://scenes/home.tscn",
	"email": "res://scenes/email/mail.tscn",
	"approval": "res://scenes/approval/approval_form.tscn",
	"clublist": "res://scenes/clublist/ClubScene.tscn",
	"clubhome": "res://scenes/clublist/ClubDetailScene.tscn",
	"gamelist": "res://scenes/gamelist/game_list.tscn",
	"roomlist": "res://scenes/roomlist/room_list.tscn",
	"matching": "res://scenes/match/matching.tscn",
	"matchSuccess": "res://scenes/match/match_success.tscn",
	"leaderboard": "res://scenes/1common/leaderboard.tscn",
}

var _paths: Dictionary = {}
var _order: Array[String] = []

func _init() -> void:
	register_many(DEFAULT_ROUTES)

## 注册一个场景；overwrite=false 时同名不覆盖。
func register(name: String, path: String, overwrite: bool = false) -> bool:
	var key := name.strip_edges()
	var scene_path := path.strip_edges()
	if key.is_empty() or scene_path.is_empty():
		return false
	if _paths.has(key):
		if not overwrite:
			return false
		_paths[key] = scene_path
		return true

	_paths[key] = scene_path
	_order.append(key)
	return true

func register_many(routes: Dictionary, overwrite: bool = false) -> int:
	var added := 0
	for name in routes:
		if register(str(name), str(routes[name]), overwrite):
			added += 1
	return added

func has(name: String) -> bool:
	return _paths.has(name)

func get_path(name: String) -> String:
	return str(_paths.get(name, ""))

func names() -> Array[String]:
	return _order.duplicate()

func all() -> Dictionary:
	return _paths.duplicate()

func size() -> int:
	return _paths.size()
