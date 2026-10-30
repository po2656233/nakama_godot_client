class_name GameCatalog
extends RefCounted

## 模块：内置子游戏清单
## 职责：项目内置子游戏的唯一声明处。新增子游戏 = 新增一条数据 + 一个场景。
## 字段：
##   key          与服务端游戏 en_name 一致（小写），也是 GameLauncher.start_game() 的入参
##   title        展示名（服务端未返回时使用）
##   scene        场景入口
##   max_players  最大人数（仅作本地兜底，实际以服务端为准）
##   online       是否需要 Nakama 对局（房间/匹配）
##   aliases      兼容旧场景名/别名，例如 xiangqi -> chinesechess
##   order        列表排序
##   show_back_button 是否自动挂载右上角返回按钮（默认 true）

const BUILTIN := [
	{
		"key": "chinesechess",
		"title": "中国象棋",
		"scene": "res://scenes/game/xiangqi/xiangqi.tscn",
		"max_players": 2,
		"online": true,
		"aliases": ["xiangqi"],
		# 场景内自带 RebackBtn，避免重复挂返回按钮
		"show_back_button": false,
		"tags": ["棋类", "对战"],
		"order": 10,
	},
	{
		"key": "tetris",
		"title": "俄罗斯方块",
		"scene": "res://scenes/game/tetris/tetris.tscn",
		"max_players": 1,
		"online": false,
		"aliases": ["tetris_game"],
		"tags": ["休闲", "单机"],
		"order": 20,
	},
	{
		"key": "mahjong_matching",
		"title": "麻将连连看",
		"scene": "res://scenes/game/mahjong_matching/level/main_game.tscn",
		"max_players": 1,
		"online": false,
		"aliases": ["mahjong"],
		"tags": ["益智", "单机"],
		"order": 30,
	},
	{
		"key": "fishgame",
		"title": "捕鱼大作战",
		"scene": "res://scenes/game/fishgame/Game.tscn",
		"max_players": 4,
		"online": true,
		"aliases": ["fish"],
		"tags": ["动作", "对战"],
		"order": 40,
	},
]
