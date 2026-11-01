extends Node

## 模块：场景导航（Global.SceneMgr）
## 职责：
##   1. 应用页面路由（登录、主页、聊天、房间……）；
##   2. 场景切换/返回与转场；
##   3. 叠加页（邮件、审批）入口。
## 边界：
##   - 子游戏路由由 GameRegistry 负责，本类只做兜底查询；
##   - 不处理网络（离开对局由 GameLauncher 负责）；
##   - 不负责场景内 UI，不扫描整个 res:// 目录。
## 依赖：SceneRegistry / SceneTransition / SceneOverlay + Global.FancyFade。

const SceneRegistry = preload("res://core/scene/scene_registry.gd")
const SceneTransition = preload("res://core/scene/scene_transition.gd")
const SceneOverlay = preload("res://core/scene/scene_overlay.gd")

const HOME_NODE := "home"

var registry = SceneRegistry.new()
var current_scene_name := ""
var previous_name := ""

func _ready() -> void:
	Global.SignalMgr.ChangeSceneSIG.connect(switch_to_scene)

######################################################################
# 路由查询
######################################################################

## 注册/更新一个应用页面路由，返回是否写入成功。
func add_scene(scene_name: String, scene_path: String, overwrite: bool = false) -> bool:
	return registry.register(scene_name, scene_path, overwrite)

func has_scene(scene_name: String) -> bool:
	return not get_scene_path(scene_name).is_empty()

## 场景文件是否真实存在（下载中的游戏会先注册、后落盘）。
func check_scene(scene_name: String) -> bool:
	var scene_path := get_scene_path(scene_name)
	return not scene_path.is_empty() and FileAccess.file_exists(scene_path)

## 先查应用路由，再查子游戏注册表。
func get_scene_path(scene_name: String) -> String:
	var path := registry.get_path(scene_name)
	if not path.is_empty():
		return path
	if Global.has_global("GameRegistry"):
		return Global.GameRegistry.get_scene_path(scene_name)
	return ""

func get_scene_name_from_path(scene_path: String) -> String:
	return scene_path.get_file().get_basename()

func get_all_scenes() -> Dictionary:
	var result := registry.all()
	if Global.has_global("GameRegistry"):
		for descriptor in Global.GameRegistry.all():
			if not result.has(descriptor.key):
				result[descriptor.key] = descriptor.scene_path
	return result

func get_ordered_scene_names() -> Array:
	var names: Array = registry.names()
	if Global.has_global("GameRegistry"):
		for descriptor in Global.GameRegistry.all():
			if not names.has(descriptor.key):
				names.append(descriptor.key)
	return names

## 记录当前页面名，供调试和返回逻辑使用。
func set_current_scene(scene_name: String) -> void:
	current_scene_name = scene_name.strip_edges()

func get_current_scene_name() -> String:
	return current_scene_name

## 记录“从哪个页面进入子游戏/弹窗”，go_back() 会回到这里。
func set_previous_name(scene_name: String) -> void:
	previous_name = scene_name.strip_edges()

func get_previous_scene_name() -> String:
	return previous_name

func get_current_scene_path() -> String:
	return get_scene_path(current_scene_name)

func get_running_scene_path() -> String:
	var scene := get_tree().current_scene if get_tree() != null else null
	return scene.scene_file_path if scene != null else ""

## 当前运行场景名：子游戏返回注册 key，应用页面返回场景文件名。
func get_running_scene_name() -> String:
	var scene_path := get_running_scene_path()
	if Global.has_global("GameRegistry"):
		var game_key: String = Global.GameRegistry.get_key_by_scene(scene_path)
		if not game_key.is_empty():
			return game_key
	return get_scene_name_from_path(scene_path)

######################################################################
# 转场
######################################################################

func get_transition_key(transition_type: String) -> String:
	return SceneTransition.get_key(transition_type)

func get_transition_description(transition_type: String) -> String:
	return SceneTransition.get_description(transition_type)

## 切换到应用页面（按路由名）。
func switch_to_scene(
	scene_name: String,
	transition_way: String = "cross",
	dissolve_time: float = 1.0,
	dissolve_image: Texture2D = null
) -> void:
	if scene_name.is_empty():
		return

	var scene_path := get_scene_path(scene_name)
	if scene_path.is_empty():
		Global.WindowPopup.show_dynamic("场景不存在：%s" % scene_name)
		push_error("[SceneMgr] 未注册的场景: %s" % scene_name)
		return

	var instance := _instantiate_scene(scene_path)
	if instance == null:
		return

	_present(instance, transition_way, dissolve_time, dissolve_image)

## 切换到一个已经实例化的场景（GameLauncher 使用，避免二次 load）。
func switch_to_scene_instance(
	instance: Node,
	transition_way: String = "cross",
	dissolve_time: float = 1.0,
	dissolve_image: Texture2D = null
) -> void:
	if instance == null or not is_instance_valid(instance):
		push_error("[SceneMgr] 无效的场景实例")
		return
	_present(instance, transition_way, dissolve_time, dissolve_image)

## 返回到记录的上一个页面；没有记录则回主页。
## 注意：离开联机对局由 GameLauncher.exit_game() 处理，本方法只负责页面跳转。
func go_back(transition_way: String = "cross", dissolve_time: float = 1.0) -> void:
	var target := previous_name
	if target.is_empty() or not has_scene(target):
		target = HOME_NODE
	switch_to_scene(target, transition_way, dissolve_time)

## 兼容旧调用名；内部委托给 GameLauncher。
func ToGameScene(game_name: String) -> bool:
	return to_game_scene(game_name)

## 启动子游戏（推荐的新入口）。
func to_game_scene(game_name: String) -> bool:
	var key := game_name.strip_edges()
	if key.is_empty():
		return false
	if Global.has_global("SceneRouter"):
		return Global.SceneRouter.enter_game(key)
	if not Global.has_global("GameLauncher"):
		Global.WindowPopup.show_dynamic("游戏启动器未就绪")
		push_error("[SceneMgr] GameLauncher 未注册")
		return false
	return Global.GameLauncher.start_game(key)

## 直接替换当前场景（无转场）。供 instant 转场和无渲染环境（headless）使用。
func replace_current_scene(instance: Node) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	var tree := get_tree()
	if tree == null:
		return
	var old_scene := tree.current_scene
	if old_scene != null and old_scene != instance:
		old_scene.queue_free()
	if instance.get_parent() == null:
		tree.root.add_child(instance)
	tree.current_scene = instance

## 在当前场景上层按比例打开一个页面（邮件、审批等）。
func show_scene_in_center(scene_name: String, scale_ratio: float = 0.8) -> Node:
	return SceneOverlay.show_in_center(self, get_scene_path(scene_name), scale_ratio)

######################################################################
# 内部实现
######################################################################

func _instantiate_scene(scene_path: String) -> Node:
	if not ResourceLoader.exists(scene_path):
		Global.WindowPopup.show_dynamic("场景文件缺失：%s" % scene_path)
		push_error("[SceneMgr] 场景文件不存在: %s" % scene_path)
		return null

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("[SceneMgr] 不是有效的 PackedScene: %s" % scene_path)
		return null

	var instance := packed.instantiate()
	if instance == null:
		push_error("[SceneMgr] 场景实例化失败: %s" % scene_path)
	return instance

func _present(instance: Node, transition_way: String, dissolve_time: float, dissolve_image: Texture2D) -> void:
	# 切页前清掉挂在旧场景上的设置面板，避免被一起释放后残留引用。
	if Global.has_global("SettingsMgr"):
		Global.SettingsMgr.settings_changed.emit()

	if Global.has_global("FancyFade"):
		SceneTransition.play(instance, transition_way, dissolve_time, dissolve_image)
		return

	# 转场插件不可用时的兜底：直接替换当前场景。
	var tree := get_tree()
	if tree == null:
		return
	var old_scene := tree.current_scene
	if old_scene != null:
		old_scene.queue_free()
	tree.root.add_child(instance)
	tree.current_scene = instance

## 打印路由与子游戏清单，排查“场景找不到”时使用。
func print_all_scenes() -> void:
	print("\n=== 应用页面路由 (%d) ===" % registry.size())
	for key in registry.names():
		print("  %-16s %s" % [key, registry.get_path(key)])

	if not Global.has_global("GameRegistry"):
		return
	print("\n=== 子游戏 (%d) ===" % Global.GameRegistry.count())
	for descriptor in Global.GameRegistry.all():
		print("  %-16s %-8s %s" % [descriptor.key, "[联机]" if descriptor.online else "[单机]", descriptor.scene_path])
	print("")
