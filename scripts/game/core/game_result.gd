class_name GameResult
extends RefCounted

## 模块：子游戏结果
## 职责：统一表达一局游戏的输赢、分数、名次与附加数据，供平台层结算/展示。
## 用法：子游戏结束时调用 Global.GameLauncher.finish_game(GameResult.win(score)).

enum Outcome {
	NONE = 0,
	WIN = 1,
	LOSE = 2,
	DRAW = 3,
	ABORTED = 4,
}

var outcome: Outcome = Outcome.NONE
var score: int = 0
var rank: int = 0
var winner_peer_id: int = 0
var details: Dictionary = {}

static func win(p_score: int = 0, p_details: Dictionary = {}) -> GameResult:
	return _make(Outcome.WIN, p_score, p_details)

static func lose(p_score: int = 0, p_details: Dictionary = {}) -> GameResult:
	return _make(Outcome.LOSE, p_score, p_details)

static func draw(p_score: int = 0, p_details: Dictionary = {}) -> GameResult:
	return _make(Outcome.DRAW, p_score, p_details)

static func aborted(p_details: Dictionary = {}) -> GameResult:
	return _make(Outcome.ABORTED, 0, p_details)

static func _make(p_outcome: Outcome, p_score: int, p_details: Dictionary) -> GameResult:
	var result := GameResult.new()
	result.outcome = p_outcome
	result.score = p_score
	result.details = p_details.duplicate(true)
	return result

func is_finished() -> bool:
	return outcome != Outcome.NONE and outcome != Outcome.ABORTED

func is_win() -> bool:
	return outcome == Outcome.WIN

func outcome_name() -> String:
	match outcome:
		Outcome.WIN:
			return "win"
		Outcome.LOSE:
			return "lose"
		Outcome.DRAW:
			return "draw"
		Outcome.ABORTED:
			return "aborted"
		_:
			return "none"

func to_dict() -> Dictionary:
	return {
		"outcome": outcome,
		"outcome_name": outcome_name(),
		"score": score,
		"rank": rank,
		"winner_peer_id": winner_peer_id,
		"details": details.duplicate(true),
	}
