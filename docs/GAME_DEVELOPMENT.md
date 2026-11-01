# 子游戏插件接入指南

> 目标：新增一个子游戏 = **复制一个目录 + 填一份 `game_meta.tres`**。
> 大厅代码零改动；进入/退出走 `SceneRouter`（上下文感知回退），生命周期走 `GameBase` 契约，
> 子游戏只能通过 `GameHostBridge` 访问框架，不能出现任何 `Global.*` 调用。

## 1. 插件目录结构

```text
games/<key>/
├── game_meta.tres      # GameMetadata 自描述
├── entry.tscn          # 唯一入口场景（框架只实例化它）
├── scripts/            # 游戏私有逻辑（可带子目录）
├── scenes/             # 游戏内部子场景（可选）
└── assets/             # 私有贴图/音频/主题（可选）
```

`<key>` 必须与服务端游戏列表的 `en_name` 一致（小写），例如 `chinesechess`、`fishgame`。
现有游戏：`chinesechess`、`tetris`、`mahjong_matching`、`fishgame`；`template/` 是复制用模板，
注册表扫描时会跳过。

## 2. game_meta.tres 字段（GameMetadata）

资源类型 `GameMetadata`（`core/framework/game_metadata.gd`）：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `game_id` | String | 唯一 ID，必须等于目录名，也与服务端 `en_name` 一致 |
| `display_name` | String | 展示名（服务端未返回时使用） |
| `icon` | Texture2D | 列表/房间图标（可空） |
| `min_players` | int | 最少人数（本地兜底） |
| `max_players` | int | 最大人数（本地兜底，实际以服务端为准） |
| `entry_scene` | String | 入口场景，固定写 `res://games/<key>/entry.tscn` |
| `support_voice` | bool | 是否支持实时语音（RTC 阶段 3 生效） |
| `support_video` | bool | 是否支持实时视频（RTC 阶段 3 生效） |
| `online` | bool | 是否需要 Nakama 对局 |
| `show_back_button` | bool | 是否自动挂右上角返回按钮 |
| `order` | int | 游戏列表排序 |
| `aliases` | PackedStringArray | 兼容旧 key / 服务端别名，例如 `xiangqi` |
| `tags` | PackedStringArray | 分类标签 |
| `version` | String | 插件版本（独立打包/热更时使用） |
| `min_client` | String | 最低客户端版本 |
| `description` | String | 一句话简介 |

示例：

```ini
[gd_resource type="Resource" script_class="GameMetadata" format=3]

[ext_resource type="Script" path="res://core/framework/game_metadata.gd" id="1"]

[resource]
script = ExtResource("1")
game_id = "space_run"
display_name = "太空跑酷"
min_players = 1
max_players = 1
entry_scene = "res://games/space_run/entry.tscn"
support_voice = false
support_video = false
online = false
order = 50
aliases = PackedStringArray()
tags = PackedStringArray("休闲")
description = "单机跑酷。"
```

## 3. 五步接入

1. **复制模板**：`games/template/` → `games/<key>/`；
2. **改入口场景**：`entry.tscn` 根节点挂本游戏脚本（Node2D/Control/Node 均可），
   引用私有资源时只用 `res://games/<key>/...` 路径；
3. **改元数据**：`game_meta.tres` 填 `game_id/display_name/entry_scene` 等字段；
4. **实现生命周期钩子**（推荐继承基类）：

```gdscript
extends GameBase2D     # UI 类用 GameBaseControl，纯 Node 根用 GameBase

func on_game_init(room_info: Dictionary, bridge: GameHostBridge) -> void:
    # 注入房间信息与宿主桥（进入树之前调用）
    pass

func on_game_start() -> void:
    # 场景已进入树、HUD 已挂好，可以开始第一局
    pass

func on_network_packet(op_code: int, payload: Variant) -> void:
    # 收到本局网络包（op_code 见 GameProtocol）
    pass

func on_game_pause() -> void:
    pass

func on_game_resume() -> void:
    pass

func on_game_destroy() -> void:
    # 必须彻底切断本局信号、停止私有 Timer/Tween，释放内存
    super.on_game_destroy()
```

5. **启动**（只允许走 SceneRouter）：

```gdscript
# 从游戏列表进入
Global.SceneRouter.prepare_game_list("space_run")
Global.SceneRouter.enter_game("space_run")

# 从房间列表进入（room_info 会注入子游戏）
Global.SceneRouter.prepare_room_list("space_run", room_id)
Global.SceneRouter.enter_pending_game("space_run")   # loading_screen 内部已这样调用

# 俱乐部房间 / 聊天邀请同理：
Global.SceneRouter.prepare_club_room_list("space_run", room_id, {"club_id": club_id})
Global.SceneRouter.prepare_chat_invite("space_run", room_id)
```

不要用 `get_tree().change_scene_to_file()` 或 `GameLauncher.start_game()` 直接切游戏，
否则不会记录导航来源、不会注入桥、也不会按来源回退。

## 4. 生命周期与回退

```text
SceneRouter.enter_game(game_id, room_info, nav_context)
  ├─ 压入导航栈（NavigationContext）
  ├─ GameLauncher 实例化 entry.tscn
  ├─ 创建 GameHostBridge（GameHostBridge.current）
  ├─ on_game_init(room_info, bridge) / on_game_context(context)
  ├─ SceneMgr 切换场景（挂 __GameHUD）
  └─ on_game_launched → on_game_start；联机时 sendToMatch(LOADING_MAP_FINISH)

SceneRouter.exit_game(result?)
  ├─ on_game_destroy()（一次）
  ├─ leave_table（联机 + 房间来源，best-effort）
  ├─ GameLauncher.exit_game(result, navigate_back=false)
  │    ├─ on_game_result(result?) / on_game_exit(result?)
  │    ├─ game_finished 信号
  │    └─ LeaveMatch（联机时）
  ├─ 按 NavigationContext.source 回退：
  │    GAME_LIST → gamelist | ROOM_LIST → roomlist
  │    CLUB_ROOM_LIST → clubhome | CHAT_INVITE → home
  └─ SignalMgr.GameReturnedSIG(source, gameId, roomId) 供目标页面刷新
```

`NavigationContext`（`core/navigation/navigation_context.gd`）：

```gdscript
enum EntrySource { GAME_LIST, ROOM_LIST, CLUB_ROOM_LIST, CHAT_INVITE }
var source: int
var game_id: String
var room_id: String
var extra_data: Dictionary
```

子游戏内拿导航信息：`game_context.navigation()`；只读，不要修改来源。

## 5. GameHostBridge：子游戏唯一对外通道

`GameHostBridge.current` 由 `GameLauncher` 在启动时创建、退出时清空。基类里可以直接用
成员 `bridge`（推荐）。

| 分类 | API |
| --- | --- |
| 上下文 | `context`、`key`、`option(name, default)`、`is_online()`、`has_match()`、`match_id()`、`room_info()` |
| UI | `toast(text, speed=100)`、`message(text, title, auto_close)`、`confirm(text, cb, title)`、`open_settings()` |
| 生命周期 | `exit(result?)`、`request_exit_game()`、`restart()`、`finish(result)`、`is_running()` |
| 对局数据 | `send_match_data(op_code, payload)`、`send_match_state(op, text)`、`send_match_rpc(op, bytes)`、`set_ready_status(bool)`、`is_ready()` |
| 账号/网络 | `get_my_id()`、`nakama_session`、`nakama_client`、`nakama_socket`、`is_nakama_socket_connected()` |
| 对局 | `my_peer_id`、`match_state`、`players`、`is_server()`、`create_match()`、`join_match(id)`、`leave()`、`start_playing()` |
| 自定义 RPC | `custom_rpc(node, method, args)`、`custom_rpc_sync(...)`、`custom_rpc_id(node, id, method, args)` |
| 事件 | `connect_match_state(cb)`、`connect_match_signal(name, cb)`、`ready_status_changed` 信号 |

示例：

```gdscript
bridge.toast("已加入房间")
bridge.send_match_data(GameProtocol.MatchOpCode.CUSTOM_RPC, {"move": [3, 4], "seat": bridge.my_peer_id})
bridge.set_ready_status(true)
await bridge.request_exit_game()     # 上下文感知退出
```

协议枚举统一来自 `GameProtocol`（`core/framework/game_protocol.gd`）：

```gdscript
match state:
    GameProtocol.MatchState.PLAYING: ...
    GameProtocol.MatchMode.CREATE: ...
    GameProtocol.PlayerStatus.CONNECTED: ...
```

## 6. 联机对局

- 状态发送：`send_match_data(op, payload)`（String/PackedByteArray/Dictionary 自动分派）；
- 接收：`bridge.connect_match_state(cb)`，或实现 `on_network_packet(op_code, payload)`；
- 对局 ID / 座位 / 玩家表：`match_id`、`my_peer_id`、`players`、`get_player_names_by_peer_id()`；
- 不要自己 `LeaveMatch`，退出时框架统一处理。

## 6.1 骨骼动画（NativeCharacterAvatar，替代 DragonBones）

原生骨骼动画由 `tools/dragonbones_converter.gd` 从 DragonBones 的 `_ske.json/_tex.json` 生成，
使用 `shared/avatar/native_character_avatar.gd` 播放：

```gdscript
@onready var avatar: NativeCharacterAvatar = $Avatar

func _ready() -> void:
    if avatar.has_animation("animation"):
        avatar.play_animation("animation", true, 0.2)

func stop_effect() -> void:
    avatar.stop_animation()
```

`NativeCharacterAvatar` API：`play_animation(name, loop=true, blend_time=0.2)`、
`stop_animation()`、`set_skin(name) -> bool`、`has_animation(name) -> bool`、`animation_names()`。
`avatar_scene` 指向生成的原生 `.tscn`，`autoplay_animation` 可配置进入树后自动播放。
## 7. 沙盒规则（校验会拦截）

1. `games/**/*.gd` 不得出现任何 `Global.`（唯一入口是 `GameHostBridge.current`）；
2. 不得跨插件引用 `res://games/<other>/`；
3. `entry_scene` 必须指向本目录 `entry.tscn`，且能加载/实例化；
4. `game_id` 必须等于目录名，且不能与其它插件重复；
5. `min_players <= max_players`，`support_voice/support_video` 必须是 bool；
6. 资源引用全部使用 `res://games/<key>/...`。

校验命令：

```powershell
$g = 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe'
& $g --headless --path . --script res://tools/validate_plugins.gd -- --strict-sandbox
& $g --headless --path . --script res://tools/test_navigation.gd
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
3. `SceneRouter.enter_pending_game(key)`（加载页内部调用）。

当前仍解压到 `res://games/`（导出包只读），正式发布前应改 `user://games/` + PCK；
`GameRegistry` 已经会扫描 `user://games/*/game_meta.tres`。

## 9. 自检清单

- [ ] 目录名 == `game_meta.game_id` == 服务端 `en_name`；
- [ ] `entry.tscn` 存在且可实例化；
- [ ] 没有任何 `Global.` 调用；
- [ ] 没有引用其它子游戏的文件；
- [ ] 生命周期钩子齐全，`on_game_destroy()` 会断信号/停 Timer；
- [ ] 退出/重开/结算走 `GameHostBridge` / `SceneRouter`；
- [ ] `validate_plugins --strict-sandbox`、`test_navigation`、`test_plugin_lifecycle` 通过。
