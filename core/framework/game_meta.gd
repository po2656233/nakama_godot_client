class_name GameMeta
extends Resource

## 模块：子游戏插件元数据（每个插件自描述）
## 用途：`games/<key>/game_meta.tres` 是该子游戏的唯一声明，GameRegistry 扫描它完成注册。
## 约定：
##   - key 与服务端游戏列表的 en_name 一致（小写）；
##   - entry_scene 默认同目录下的 entry.tscn；
##   - 插件目录结构：game_meta.tres + entry.tscn + scripts/ + assets/（可选 scenes/）。

## 唯一键（= 目录名，与服务端 en_name 一致）
@export var key: String = ""
## 展示名（服务端未返回时使用）
@export var title: String = ""
## 入口场景（唯一入口，框架只实例化它）
@export var entry_scene: String = ""
## 最大人数（本地兜底，实际以服务端为准）
@export var max_players: int = 1
## 是否需要 Nakama 对局
@export var online: bool = false
## 是否自动挂载右上角返回按钮
@export var show_back_button: bool = true
## 列表排序
@export var order: int = 0
## 兼容旧 key / 服务端别名的可检索名
@export var aliases: PackedStringArray = PackedStringArray()
## 分类标签
@export var tags: PackedStringArray = PackedStringArray()
## 插件版本（独立打包/热更时使用）
@export var version: String = "1.0.0"
## 最低客户端版本
@export var min_client: String = "1.0.0"
## 一句话简介
@export var description: String = ""

## 是否是一份可用的元数据。
func is_valid() -> bool:
	return not key.strip_edges().is_empty() and not entry_scene.strip_edges().is_empty()

## 入口场景是否真的存在。
func scene_exists() -> bool:
	return not entry_scene.is_empty() and (FileAccess.file_exists(entry_scene) or ResourceLoader.exists(entry_scene))

## 转换成 GameDescriptor 需要的字典（保持 registry 内部数据结构不变）。
func to_descriptor_dict(source: String = "builtin") -> Dictionary:
	return {
		"key": key,
		"title": title if not title.is_empty() else key,
		"scene": entry_scene,
		"max_players": max_players,
		"online": online,
		"show_back_button": show_back_button,
		"order": order,
		"aliases": Array(aliases),
		"tags": Array(tags),
		"source": source,
	}
