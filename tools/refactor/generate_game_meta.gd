extends SceneTree

## 一次性工具：为内置子游戏生成 game_meta.tres（GameMeta 自描述清单）。
## 用法：godot --headless --path . --script res://tools/refactor/generate_game_meta.gd [-- --force]
##
## 生成后 GameRegistry 只扫描 games/<key>/game_meta.tres，不再需要 game_catalog.gd。

const META_SCRIPT := "res://core/framework/game_meta.gd"

const BUILTIN := [
	{
		"key": "chinesechess",
		"title": "中国象棋",
		"entry": "res://games/chinesechess/entry.tscn",
		"max_players": 2,
		"online": true,
		"show_back_button": false,
		"order": 10,
		"aliases": ["xiangqi"],
		"tags": ["棋类", "对战"],
		"description": "双人实时对战的经典中国象棋。",
	},
	{
		"key": "tetris",
		"title": "俄罗斯方块",
		"entry": "res://games/tetris/entry.tscn",
		"max_players": 1,
		"online": false,
		"show_back_button": true,
		"order": 20,
		"aliases": ["tetris_game"],
		"tags": ["休闲", "单机"],
		"description": "经典俄罗斯方块，支持消行与分数结算。",
	},
	{
		"key": "mahjong_matching",
		"title": "麻将连连看",
		"entry": "res://games/mahjong_matching/entry.tscn",
		"max_players": 1,
		"online": false,
		"show_back_button": true,
		"order": 30,
		"aliases": ["mahjong"],
		"tags": ["益智", "单机"],
		"description": "消除配对玩法，逐关挑战。",
	},
	{
		"key": "fishgame",
		"title": "捕鱼大作战",
		"entry": "res://games/fishgame/entry.tscn",
		"max_players": 4,
		"online": true,
		"show_back_button": true,
		"order": 40,
		"aliases": ["fish"],
		"tags": ["动作", "对战"],
		"description": "多人同屏射击捕鱼，联机对战。",
	},
]

func _init() -> void:
	var force := OS.get_cmdline_user_args().has("--force")
	var meta_script: Script = load(META_SCRIPT)
	if meta_script == null:
		push_error("[generate_game_meta] 无法加载 %s" % META_SCRIPT)
		quit(1)
		return

	var created := 0
	for entry in BUILTIN:
		var key: String = entry["key"]
		var path := "res://games/%s/game_meta.tres" % key
		if FileAccess.file_exists(path) and not force:
			print("  SKIP ", path)
			continue
		if not FileAccess.file_exists(entry["entry"]):
			push_error("[generate_game_meta] 入口场景不存在: %s" % entry["entry"])
			continue

		var meta: Resource = meta_script.new()
		meta.set("key", key)
		meta.set("title", entry["title"])
		meta.set("entry_scene", entry["entry"])
		meta.set("max_players", entry["max_players"])
		meta.set("online", entry["online"])
		meta.set("show_back_button", entry["show_back_button"])
		meta.set("order", entry["order"])
		meta.set("aliases", PackedStringArray(entry["aliases"]))
		meta.set("tags", PackedStringArray(entry["tags"]))
		meta.set("description", entry["description"])

		var err := ResourceSaver.save(meta, path)
		if err != OK:
			push_error("[generate_game_meta] 保存失败 %s: %s" % [path, err])
			continue
		print("  SAVE ", path)
		created += 1

	print("[generate_game_meta] 生成 %d 个 game_meta.tres" % created)
	quit(0)
