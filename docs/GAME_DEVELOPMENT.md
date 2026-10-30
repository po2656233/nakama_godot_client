# 子游戏接入指南

> 目标：新增一个子游戏只需要 **一个目录 + 一个场景 + 一条清单**，退出/重开/结算/返回按钮全部复用框架。

## 1. 命名约定

| 项 | 规则 | 示例 |
| --- | --- | --- |
| `key` | 与服务端游戏列表的 `en_name` 一致，小写 | `space_run` |
| 场景目录 | `scenes/game/<key>/` | `scenes/game/space_run/` |
| 主场景 | `scenes/game/<key>/<key>.tscn` | `space_run.tscn` |
| 脚本目录 | `scripts/game/<key>/` | `scripts/game/space_run/` |
| 资源目录 | `assets/game/<key>/` | `assets/game/space_run/` |

场景文件名与目录名一致时，下载/外部游戏会被 `GameRegistry` 自动发现；否则必须在
`loading_screen` 注册时显式指定路径。

## 2. 最小接入：继承基类（推荐）

### 2.1 创建脚本

复制 `scripts/game/template/template_game.gd` 到 `scripts/game/<key>/<key>.gd`：

```gdscript
extends GameBase2D
## 我的新游戏

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

如果游戏根节点是 UI 类，改用 `extends GameBaseControl`。

### 2.2 创建场景

- 新建 `scenes/game/<key>/<key>.tscn`；
- 根节点类型保持 `Node2D`（配 `GameBase2D`）或 `Control`（配 `GameBaseControl`）；
- 根节点挂上 `2.1` 的脚本；
- 不要自己写“返回大厅”按钮，`GameLauncher` 默认会挂 `__GameHUD`。

### 2.3 注册清单

编辑 `scripts/game/core/game_catalog.gd`，加一条：

```gdscript
{
    "key": "space_run",
    "title": "太空跑酷",
    "scene": "res://scenes/game/space_run/space_run.tscn",
    "max_players": 1,
    "online": false,
    "aliases": [],
    "tags": ["休闲"],
    "order": 50,
},
```

字段说明：

- `online=false`：单机，`exit_game` 不会调用 `LeaveMatch`；
- `online=true`：联机，需要服务端对局 `match_id`；
- `show_back_button=false`：场景内已有返回按钮时使用；
- `aliases`：兼容旧 key / 服务端不同拼写，例如 `xiangqi -> chinesechess`。

### 2.4 启动

在页面/房间流程里用：

```gdscript
Global.GameLauncher.start_game("space_run", {
    "mode": 1,
    "room_id": 0,
    "transition": "tile_reveal",
    "transition_time": 1.0,
})
```

不要再用 `get_tree().change_scene_to_file()` 或 `SceneMgr.switch_to_scene("space_run")`
直接切游戏，否则不会注入上下文、不会挂返回按钮、也不会通知对局服务。

## 3. 生命周期

```
GameLauncher.start_game()
  ├─ GameRegistry.find(key) -> GameDescriptor
  ├─ 实例化场景
  ├─ on_game_context(context)       # 保存上下文（基类已实现）
  ├─ SceneMgr 切换场景
  ├─ 挂 __GameHUD（可配置）
  ├─ on_game_launched(context)      # 正式开始
  └─ sendToMatch(LOADING_MAP_FINISH) # 联机时
```

退出：

```
GameLauncher.exit_game(result?)
  ├─ on_game_result(result?)   # 有结算时
  ├─ on_game_exit(result?)
  ├─ game_finished 信号
  ├─ LeaveMatch（联机时）
  └─ SceneMgr.go_back()
```

重开：

```gdscript
restart_game()   # 基类方法；保留 match/room 上下文，重新实例化场景
```

结算：

```gdscript
finish_game(GameResult.win(score))
finish_game(GameResult.lose(score))
finish_game(GameResult.draw(score))
finish_game(GameResult.aborted({"reason": "对方掉线"}))
```

## 4. GameContext 字段

| 字段 | 说明 |
| --- | --- |
| `key` | 注册 key |
| `title` | 展示名 |
| `game_id` | 服务端游戏 ID（联机时） |
| `mode` | 玩法/模式，由调用方传入 |
| `room_id` | 房间 ID，由调用方传入 |
| `match_id` | Nakama 对局 ID |
| `online` | 是否联机游戏 |
| `previous_scene` | 进入游戏前的页面，`go_back` 使用 |
| `options` | 调用方自定义参数 |

读取：

```gdscript
var difficulty = context.get_option("difficulty", 1)
```

## 5. 联机对局

- 发自定义状态：`send_game_state(op_code, payload)`（基类已封装 `OnlineGame.sendToMatch`）；
- 收状态：沿用现有 `SignalMgr.MatchStateEventSIG` 或 `OnlineMatch` 的事件；
- 不要在游戏里直接 `change_scene_to_file()`，统一由 `GameLauncher` 管理场景；
- 退出时框架会调用 `OnlineMatch.LeaveMatch(match_id)`，游戏内不要重复调用。

## 6. 外部/下载游戏

`loading_screen.gd` 按以下约定下载并解压：

```
https://<resource_host>/<key>.zip
  ├─ scenes/game/<key>/<key>.tscn
  ├─ scripts/game/<key>/...
  └─ assets/game/<key>/...
```

解压后：

1. 找到 `<key>.tscn` 主场景；
2. `GameRegistry.register_external(key, path)`；
3. `GameLauncher.start_game(key)`。

解压路径已做绝对路径/`..` 校验。注意：当前仍解压到 `res://`，导出包中该目录只读，
正式发布前需要迁移到 `user://`（或预打包 PCK）。

## 7. 自检清单

- [ ] key 与服务端 `en_name` 一致；
- [ ] `scenes/game/<key>/<key>.tscn` 可 `ResourceLoader.load()`；
- [ ] 根脚本 `extends GameBase2D` 或 `GameBaseControl`；
- [ ] `game_catalog.gd` 已登记；
- [ ] 没有自己写 `change_scene_to_file()` / `reload_current_scene()`；
- [ ] 退出/重开走 `exit_game()` / `restart_game()`；
- [ ] 结算走 `finish_game()`；
- [ ] 跑 `tools/validate_game_framework.gd` 通过。
