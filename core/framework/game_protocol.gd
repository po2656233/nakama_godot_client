class_name GameProtocol
extends RefCounted

## 模块：子游戏协议常量（唯一来源）
## 职责：集中定义与框架/服务端约定的枚举与操作码，供 core/network 与 games/* 共用。
## 说明：
##   - OnlineMatch / OnlineGame 里的枚举改为引用本文件，避免两处数值漂移；
##   - 子游戏只需要 `GameProtocol.MatchState.X` / `GameProtocol.MatchMode.X` 这类常量，
##     不需要（也禁止）直接访问 Global.Online*。

## 对局状态（GameLauncher 会在子游戏场景就绪后上报 LOADING_MAP_FINISH）。
enum MatchState {
	LOBBY = 0,
	MATCHING = 1,
	CONNECTING = 2,
	WAITING_FOR_ENOUGH_PLAYERS = 3,
	READY = 4,
	PLAYING = 5,
	LOADING_MAP_FINISH = 9999,
}

## 进入对局的方式。
enum MatchMode {
	NONE = 0,
	CREATE = 1,
	JOIN = 2,
	MATCHMAKER = 3,
}

## 玩家连接状态。
enum PlayerStatus {
	CONNECTING = 0,
	CONNECTED = 1,
}

## 对局内部自定义 RPC 的操作码。
enum MatchOpCode {
	CUSTOM_RPC = 9001,
	JOIN_SUCCESS = 9002,
	JOIN_ERROR = 9003,
}

## 房间/对局业务状态。
enum GameStatus {
	Waiting = 1,
	Loading = 2,
	Start = 3,
	Playing = 4,
	Opening = 5,
	Over = 6,
	Stop = 7,
}
