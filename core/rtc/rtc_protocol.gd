class_name RtcProtocol
extends RefCounted

## 模块：RTC 信令协议（PROMPT_REFACTOR 阶段 3）
## 职责：定义 Nakama 对局/频道上的音视频信令操作码与 JSON 载荷编解码。
## 传输：沿用 Nakama match state（`OnlineGame.sendToMatch`），op_code = OP_BASE + Kind。
## 说明：
##   - 载荷统一为 `{"k": kind, "p": {from, ...}}` 的 JSON 字符串；
##   - 音频/视频帧用 base64（`Marshalls.raw_to_base64`）内联，单帧体积需调用方控制。

## 信令类型。
enum Kind {
	CALL_INVITE = 1,
	CALL_ACCEPT = 2,
	CALL_REJECT = 3,
	CALL_HANGUP = 4,
	OFFER = 5,
	ANSWER = 6,
	ICE = 7,
	AUDIO = 8,
	VIDEO = 9,
}

## 通话状态。
enum CallState {
	IDLE = 0,
	OUTGOING = 1,
	INCOMING = 2,
	IN_CALL = 3,
}

## Nakama 自定义 op_code 基址（避开框架已有的 9001/9999 等）。
const OP_BASE := 7300

static func op_code(kind: int) -> int:
	return OP_BASE + kind

static func kind_from_op(op_code_value: int) -> int:
	return op_code_value - OP_BASE

static func is_rtc_op(op_code_value: int) -> bool:
	return op_code_value > OP_BASE and op_code_value <= OP_BASE + Kind.VIDEO

static func encode(kind: int, payload: Dictionary = {}) -> String:
	return JSON.stringify({"k": kind, "p": payload})

## 解析载荷；非法数据返回空字典。
static func decode(text: String) -> Dictionary:
	if text.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var parsed: Dictionary = json.data
	if not parsed.has("k") or not parsed.has("p"):
		return {}
	return {
		"k": int(parsed["k"]),
		"p": parsed["p"] if parsed["p"] is Dictionary else {},
	}

static func encode_bytes(data: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(data)

static func decode_bytes(text: String) -> PackedByteArray:
	return Marshalls.base64_to_raw(text)
