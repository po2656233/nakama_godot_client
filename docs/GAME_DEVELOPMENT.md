# 子游戏插件接入指南

> 目标：新增一个子游戏 = **复制一个目录 + 填一份 `game_meta.tres`**。
> 大厅代码零改动；退出/重开/结算/返回按钮/联机上报全部复用框架。
> 子游戏只能通过 `GameBridge` 访问框架，不能出现任何 `Global.*` 调用。

## 1. 插件目录结构

```text
games/<key>/
├── game_meta.tres      # 插件自描述（GameMeta）
├── entry.tscn          # 唯一入口场景（框架只实例化它）
├── scripts/            # 游戏私有逻辑（可带子目录）
├── scenes/             # 游戏内部子场景（可选）
└── assets/             # 私有贴图/音频/主题（可选）
```

`<key>` 必须与服务端游戏列表的 `en_name` 一致（小写），例如 `chinesechess`、`fishgame`。
现有游戏：`chinesechess`、`tetris`、`mahjong_matching`、`fishgame`；`template/` 是复制用模板，
注册表扫描时会跳过。

## 2. game_meta.tres 字段

资源类型 `GameMeta`（`core/framework/game_meta.gd`）：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `key` | String | 唯一键，必须等于目录名，也与服务端 `en_name` 一致 |
| `title` | String | 展示名（服务端未返回时使用） |
| `entry_scene` | String | 入口场景，固定写 `res://games/<key>/entry.tscn` |
| `max_players` | int | 最大人数（本地兜底，实际以服务端为准） |
| `online` | bool | 是否需要 Nakama 对局（联机游戏退出时会 `LeaveMatch`） |
| `show_back_button` | bool | 是否自动挂右上角返回按钮（场景自带返回按钮时设 false） |
| `order` | int | 游戏列表排序 |
| `aliases` | PackedStringArray | 兼容旧 key / 服务端别名，例如 `xiangqi` |
| `tags` | PackedStringArray | 分类标签 |
| `version` | String | 插件版本（独立打包/热更时使用） |
| `min_client` | String | 最低客户端版本 |
| `description` | String | 一句话简介 |

示例：

```ini
[gd_resource type="Resource" script_class="GameMeta" format=3]

[ext_resource type="Script" path="res://core/framework/game_meta.gd" id="1"]

[resource]
script = ExtResource("1")
key = "space_run"
title = "太空跑酷"
entry_scene = "res://games/space_run/entry.tscn"
max_players = 1
online = false
order = 50
aliases = PackedStringArray()
tags = PackedStringArray("休闲")
description = "单机跑酷。"
```

## 3. 五步接入

1. **复制模板**：`games/template/` → `games/<key>/`；
2. **改入口场景**：`entry.tscn` 根节点挂本游戏脚本（`Node2D`/`Control` 均可），
   引用私有资源时只用 `res://games/<key>/...` 路径；
3. **改元数据**：`game_meta.tres` 填 `key/title/entry_scene` 等字段（key 必须等于目录名）；
4. **实现生命周期钩子**（可选，推荐继承基类）：

```gdscript
extends GameBase2D     # UI 类游戏用 GameBaseControl

func on_game_launched(context: GameContext) -> void:
    # 场景已进入树、HUD 已挂好，可以开始第一局
    print("start ", context.key, " online=", context.is_online())

func on_game_result(result: GameResult) -> void:
    # 收到结算：展示自己的结算面板
    print(result.outcome_name(), " score=", result.score)

func on_game_exit(_result: GameResult) -> void:
    # 停音效、计时器、网络监听
    pass
```

5. **启动**（大厅/房间流程里）：

```gdscript
Global.GameLauncher.start_game("space_run", {
    "mode": 1,
    "room_id": 0,
    "transition": "tile_reveal",
    "transition_time": 1.0,
})
```

不要用 `get_tree().change_scene_to_file()` 或 `SceneMgr.switch_to_scene()` 直接切游戏，
否则不会注入上下文/桥、不会挂返回按钮、也不会通知对局服务。

## 4. GameBridge：子游戏唯一对外通道

`GameBridge.current` 由 `GameLauncher` 在启动时创建、退出时清空。基类里还可以直接用
成员 `bridge`（推荐，可读性更好）。

| 分类 | API |
| --- | --- |
| 上下文 | `context`、`key`、`option(name, default)`、`is_online()`、`has_match()`、`match_id()` |
| UI | `toast(text, speed=100)`、`message(text, title, auto_close)`、`confirm(text, cb, title)`、`open_settings()` |
| 生命周期 | `exit(result?)`、`restart()`、`finish(result)`、`is_running()` |
| 账号/网络 | `get_my_id()`、`nakama_session`、`nakama_client`、`nakama_socket`、`is_nakama_socket_connected()` |
| 对局 | `send_match_state(op, text)`、`send_match_rpc(op, bytes)`、`my_peer_id`、`match_state`、`players`、`is_server()`、`create_match()`、`join_match(id)`、`leave()`、`start_playing()` |
| 自定义 RPC | `custom_rpc(node, method, args)`、`custom_rpc_sync(...)`、`custom_rpc_id(node, id, method, args)` |
| 事件 | `connect_match_state(cb)`、`connect_match_signal(name, cb)` |

示例：

```gdscript
GameBridge.current.toast("已加入房间")
await GameBridge.current.send_match_rpc(GameProtocol.MatchOpCode.CUSTOM_RPC, payload)
var peer := GameBridge.current.my_peer_id
```

协议枚举统一来自 `GameProtocol`（`core/framework/game_protocol.gd`）：

```gdscript
match state:
    GameProtocol.MatchState.PLAYING: ...
    GameProtocol.MatchMode.CREATE: ...
    GameProtocol.PlayerStatus.CONNECTED: ...
```

## 5. 生命周期

```text
GameLauncher.start_game(key)
  ├─ 读取 game_meta.tres -> GameDescriptor
  ├─ 实例化 entry.tscn
  ├─ 创建 GameBridge（GameBridge.current）
  ├─ on_game_bridge(bridge) / on_game_context(context)
  ├─ SceneMgr 切换场景（挂 __GameHUD）
  ├─ on_game_launched(context)
  └─ 联机时 sendToMatch(LOADING_MAP_FINISH)
```

退出：

```text
GameBridge.current.exit(result?)
  ├─ on_game_result(result?)
  ├─ on_game_exit(result?)
  ├─ game_finished 信号
  ├─ LeaveMatch（联机时）
  └─ SceneMgr.go_back()
```

重开 / 结算：

```gdscript
GameBridge.current.restart()
GameBridge.current.finish(GameResult.win(score))
GameBridge.current.finish(GameResult.lose(score))
GameBridge.current.finish(GameResult.draw(score))
GameBridge.current.finish(GameResult.aborted({"reason": "对方掉线"}))
```

## 6. 联机对局

- 状态发送：`send_match_state(op, text)`（文本）/ `send_match_rpc(op, bytes)`（二进制）；
- 接收：`GameBridge.current.connect_match_state(cb)`，或沿用 `SignalMgr.MatchStateEventSIG`；
- 对局 ID / 座位 / 玩家表：`match_id`、`my_peer_id`、`players`、`get_player_names_by_peer_id()`；
- 不要自己 `LeaveMatch`，退出时框架统一处理。

## 7. 沙盒规则（校验会拦截）

1. `games/**/*.gd` 不得出现任何 `Global.`（包括注释外的 `Global.Online*`、`Global.SceneMgr` 等）；
2. 不得跨插件引用 `res://games/<other>/`；
3. `entry_scene` 必须指向本目录 `entry.tscn`，且能加载/实例化；
4. `key` 必须等于目录名，且不能与其它插件重复；
5. 资源引用全部使用 `res://games/<key>/...`。

校验命令：

```powershell
$g = 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe'
& $g --headless --path . --script res://tools/validate_plugins.gd -- --strict-sandbox
```

## 8. 外部/下载游戏

`shared/ui/loading/loading_screen.gd` 按以下约定下载并解压：

```
https://<resource_host>/<key>.zip
  └── games/<key>/
        ├── game_meta.tres
        ├── entry.tscn
        ├── scripts/...
        └── assets/...
```

解压后：

1. 找到 `games/<key>/entry.tscn`（优先）或旧布局 `games/<key>/<key>.tscn`；
2. `GameRegistry.register_external(key, path)`；
3. `GameLauncher.start_game(key)`。

当前仍解压到 `res://games/`（导出包只读），正式发布前应改 `user://games/` + PCK；
`GameRegistry` 已经会扫描 `user://games/*/game_meta.tres`。

## 9. 自检清单

- [ ] 目录名 == `game_meta.key` == 服务端 `en_name`；
- [ ] `entry.tscn` 存在且可实例化；
- [ ] 没有任何 `Global.` 调用；
- [ ] 没有引用其它子游戏的文件；
- [ ] 退出/重开/结算走 `GameBridge`；
- [ ] `validate_plugins --strict-sandbox` 通过；
- [ ] `test_plugin_lifecycle` 通过。
