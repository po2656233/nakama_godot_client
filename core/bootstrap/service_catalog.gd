class_name ServiceCatalog
extends RefCounted

## 模块：全局服务清单（Global 拆解 ①）
## 职责：只负责“服务名 -> 脚本路径”的读取、校验与内置兜底。
## 说明：不实例化服务、不碰场景树；Global 只持有本类产出的路径表。

const CONFIG_PATH := "res://core/bootstrap/global_config.cfg"

## 配置缺项时的内置兜底（保证旧配置也能启动）。
const DEFAULT_SERVICES := {
	# 网络
	"Online": "res://core/network/Online.gd",
	"OnlineLogin": "res://core/network/OnlineLogin.gd",
	"OnlineChat": "res://core/network/OnlineChat.gd",
	"OnlineGame": "res://core/network/OnlineGame.gd",
	"OnlineMatch": "res://core/network/OnlineMatch.gd",
	# 导航 / 管理器
	"SceneRouter": "res://core/navigation/scene_router.gd",
	"SignalMgr": "res://core/services/signal_manager.gd",
	"SceneMgr": "res://core/scene/scene_manager.gd",
	"SettingsMgr": "res://core/services/settings_manager.gd",
	"DataMgr": "res://core/services/data_manager.gd",
	"MailMgr": "res://core/services/mail_manager.gd",
	# 窗口
	"WindowDrag": "res://core/window/drag.gd",
	"WindowPopup": "res://core/window/popup.gd",
	# 转场插件
	"Transitions": "res://addons/transitions/Transitions.gd",
	"FancyFade": "res://addons/transitions/FancyFade.gd",
	"FadeScene": "res://addons/transitions/FadeScene.gd",
	# 子游戏框架
	"GameRegistry": "res://core/framework/game_registry.gd",
	"GameLauncher": "res://core/framework/game_launcher.gd",
	# RTC 音视频
	"RtcSignaling": "res://core/rtc/rtc_signaling.gd",
	"RtcMedia": "res://core/rtc/rtc_media.gd",
}

## 读取配置表并合并内置兜底，返回“服务名 -> 路径”。
func load_paths() -> Dictionary:
	var paths: Dictionary = {}
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		for section in config.get_sections():
			for raw_key in config.get_section_keys(section):
				# 兼容 key 后写 # 注释的旧配置
				var service_name := str(raw_key).split("#")[0].strip_edges()
				var path := str(config.get_value(section, raw_key, "")).strip_edges().replace("\\", "/")
				if service_name.is_empty() or path.is_empty():
					continue
				if not ResourceLoader.exists(path):
					push_warning("[ServiceCatalog] 忽略不存在的服务脚本: %s -> %s" % [service_name, path])
					continue
				paths[service_name] = path
	else:
		push_warning("[ServiceCatalog] 无法读取 %s，使用内置服务表" % CONFIG_PATH)

	for service_name in DEFAULT_SERVICES:
		if paths.has(service_name):
			continue
		var default_path: String = DEFAULT_SERVICES[service_name]
		if ResourceLoader.exists(default_path):
			paths[service_name] = default_path
	return paths
