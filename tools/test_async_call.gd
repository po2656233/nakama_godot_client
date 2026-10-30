extends SceneTree

## 开发辅助：验证 Util.Asyn_Call 在 Godot 4.7 下的异步行为。
## 用法：godot --headless --path . --script res://tools/test_async_call.gd
## 注意：--script 主脚本在 autoload 之前编译，因此这里通过节点路径访问 Util。

class Dummy extends Node:
	func add_one(value: int):
		await get_tree().process_frame
		return value + 1

	func fail_with(message: String):
		await get_tree().process_frame
		return NakamaAsyncResult.new(NakamaException.new(message))

var _success_value = null
var _failure_value := ""
var _failed := 0
var _util: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_util = root.get_node_or_null("Util")
	if _util == null:
		print("FAIL: Util 自动加载未就绪")
		quit(1)
		return

	var dummy := Dummy.new()
	root.add_child(dummy)

	var ok: bool = await _util.Asyn_Call(dummy, "add_one", [41], func(value): _success_value = value, func(_msg): _failed += 1)
	_check("成功调用返回 true", ok)
	_check("成功回调拿到结果 42", _success_value == 42)

	ok = await _util.Asyn_Call(dummy, "fail_with", ["Invalid credentials."], func(_v): _failed += 1, func(msg): _failure_value = msg)
	_check("业务异常返回 false", not ok)
	_check("业务异常已中文化", _failure_value == "账号或密码错误，请检查后重试")

	ok = await _util.Asyn_Call(dummy, "fail_with", ["Request cancelled."], Callable(), func(msg): _failure_value = msg)
	_check("网络异常返回 false", not ok)
	_check("网络异常已中文化", _failure_value == "网络断开")
	_check("网络异常已入重试队列", _util.reliable_queue.get_queue_status().total_messages > 0)

	print("\n===== 异步封装测试结束：失败 %d 项 =====" % _failed)
	dummy.queue_free()
	quit(1 if _failed > 0 else 0)

func _check(name: String, passed: bool) -> void:
	if passed:
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)
