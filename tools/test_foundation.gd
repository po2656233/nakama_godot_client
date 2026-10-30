extends SceneTree

## 开发辅助：基础层运行时冒烟测试（不依赖服务器）。
## 用法：godot --headless --path . --script res://tools/test_foundation.gd

var _failed := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var util = root.get_node_or_null("Util")
	var errors = root.get_node_or_null("Errors")
	var global = root.get_node_or_null("Global")
	if util == null or errors == null or global == null:
		print("FAIL: autoload 未就绪")
		quit(1)
		return

	_test_errors(errors, util)
	_test_time(util)
	_test_legacy_message(global)
	_test_writable_match(global)
	_test_scene_registry(global)

	print("\n===== 基础层测试结束：失败 %d 项 =====" % _failed)
	quit(1 if _failed > 0 else 0)

func _test_errors(errors, util) -> void:
	_check("错误中文化", errors.humanize("Invalid credentials.") == "账号或密码错误，请检查后重试")
	_check("网络错误识别", errors.is_network_error("Request cancelled."))
	_check("业务错误不重试", not errors.is_network_error("Invalid credentials."))
	_check("空错误兜底", errors.humanize("") == "操作失败，请稍后重试")

func _test_time(util) -> void:
	var now := int(Time.get_unix_time_from_system())
	_check("今天时间格式", util.format_china_time(now).begins_with("今天 "))
	_check("消息 5 分钟内不显示", util.format_china_time_for_msg(now) == "")
	var yesterday := now - 24 * 3600
	_check("昨天时间格式", util.format_china_time(yesterday).begins_with("昨天 "))
	_check("日期分割线", not util.format_date_separator(now).is_empty())

func _test_legacy_message(global) -> void:
	var data_mgr = global.get_global("DataMgr")
	_check("DataManager 单例可用", data_mgr != null)
	if data_mgr == null:
		return
	var legacy := 'channel_id: abc, code: 0, content: {"type":1,"content":"hi, there"}, create_time: 1710484245, group_id: <null>, message_id: m1, persistent: true, room_name: <null>, sender_id: u1, update_time: 1710484245, user_id_one: u1, user_id_two: u2, username: tester'
	var parsed: Dictionary = data_mgr.parse_message(legacy)
	_check("旧消息 channel_id", parsed.get("channel_id") == "abc")
	_check("旧消息 content 为字典", parsed.get("content") is Dictionary)
	_check("旧消息 content 内容", (parsed.get("content", {}) as Dictionary).get("content") == "hi, there")
	_check("旧消息 message_id", parsed.get("message_id") == "m1")
	_check("旧消息 persistent", parsed.get("persistent") == true)
	_check("旧消息 <null> 归一化", parsed.get("group_id") == "")

func _test_writable_match(global) -> void:
	var match_mgr = global.get_global("OnlineMatch")
	_check("OnlineMatch 可用", match_mgr != null)
	if match_mgr == null:
		return
	# 这些属性以前是只读的，赋值会运行时报错；这里确保可写。
	match_mgr.my_session_id = "s1"
	match_mgr.matchmaker_ticket = "t1"
	match_mgr.match_state = match_mgr.MatchState.READY
	match_mgr.match_mode = match_mgr.MatchMode.JOIN
	_check("OnlineMatch 属性可写", match_mgr.get_my_session_id() == "s1" and match_mgr.get_match_state() == match_mgr.MatchState.READY)
	match_mgr.my_session_id = ""
	match_mgr.matchmaker_ticket = ""
	match_mgr.match_state = match_mgr.MatchState.LOBBY
	match_mgr.match_mode = match_mgr.MatchMode.NONE

func _test_scene_registry(global) -> void:
	var scene_mgr = global.get_global("SceneMgr")
	_check("加载场景路径已修正", scene_mgr.get_scene_path("loading").ends_with("loading/loading_screen.tscn"))
	_check("匹配成功场景路径已修正", scene_mgr.get_scene_path("matchSuccess").ends_with("match/match_success.tscn"))
	_check("注册场景可查询", scene_mgr.has_scene("login"))

func _check(name: String, passed: bool) -> void:
	if passed:
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)
