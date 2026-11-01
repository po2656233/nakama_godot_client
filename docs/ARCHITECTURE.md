# 折纸屋客户端架构说明

> 本文描述重构后的代码分层、服务职责、子游戏插件契约与校验方式。
> 目标：**页面与子游戏解耦、路由与业务解耦、公共能力只保留一份、子游戏可整目录插拔**。

## 1. 目录拓扑

```text
res://
├── core/                        平台底层
│   ├── bootstrap/               Global / Util / Errors（autoload）+ global_config.cfg
│   ├── network/                 Online / OnlineLogin / OnlineChat / OnlineGame / OnlineMatch / MessageQueue
│   ├── scene/                   SceneMgr + 路由表 + 转场 + 叠加页
│   ├── navigation/              SceneRouter + NavigationContext（上下文感知回退）
│   ├── services/                SignalMgr / SettingsMgr / DataMgr / MailMgr
│   ├── window/                  无边框拖动、消息框
│   └── framework/               插件契约：GameMetadata / GameBase* / GameHostBridge /
│                                GameRegistry / GameLauncher / GameProtocol /
│                                GameContext / GameResult / GameDescriptor
├── shared/                      跨模块共享（无业务语义）
│   ├── ui/                      通用 UI（设置、排行榜、加载、弹窗、列表、返回按钮…）
│   │   ├── controls/ loading/ popup/ gridanimation/
│   ├── avatar/                  原生骨骼动画门面 NativeCharacterAvatar（DragonBones 平替）
│   ├── utils/                   无状态工具
│   └── styles/                  主题、样式、字体、Shader
├── lobby/                       大厅与社交（脚本与场景同目录）
│   ├── home/ chat/ club/ room/ match/ gamelist/ email/ approval/ announcement/
│   └── club/list/               俱乐部详情（与成员管理分目录）
├── app/                         应用外壳页：login/ register/
├── games/                       ★ 完全隔离的子游戏插件目录
│   ├── chinesechess/            game_meta.tres + entry.tscn + scripts/ + scenes/ + assets/
│   ├── tetris/  mahjong_matching/  fishgame/
│   └── template/                复制用模板（注册表扫描时跳过）
├── assets/                      共享美术/音频/字体（子游戏私有资源放在各自 games/<key>/assets 下）
├── addons/ gdprotobuf/          第三方与生成代码（默认不改）
├── docs/                        架构、接入指南、重构记录
└── tools/                       headless 校验与迁移工具
```

> 目录名 `app/` 存放登录/注册这类“应用外壳”页面，不属于大厅，也不算平台底层。

## 2. 启动与全局服务

`project.godot` 只注册 4 个 autoload：

| 顺序 | 名称 | 作用 |
| --- | --- | --- |
| 1 | `Nakama` | Nakama 官方插件入口 |
| 2 | `Global` | 服务注册表（懒加载 `Global.Xxx`） |
| 3 | `Util` | 异步调用、排序、时间、图片、可靠消息队列 |
| 4 | `Errors` | 错误中文化、网络错误识别 |

`Global` 启动时读取 `core/bootstrap/global_config.cfg`，把“服务名 -> 脚本路径”登记到内存；
第一次访问 `Global.Xxx` 时才实例化并挂到 `Global` 节点下。配置缺项会用 `global.gd` 里的
`DEFAULT_SERVICES` 补齐，且**不读取 `user://` 缓存**，避免旧路径覆盖新配置。

### 服务一览

| 服务 | 文件 | 职责 |
| --- | --- | --- |
| `SignalMgr` | `core/services/signal_manager.gd` | 跨模块信号总线 |
| `SceneMgr` | `core/scene/scene_manager.gd` | 场景路由、切换/返回、转场、叠加页 |
| `SceneRouter` | `core/navigation/scene_router.gd` | 子游戏进入/退出、导航栈、按来源上下文回退 |
| `SettingsMgr` | `core/services/settings_manager.gd` | 设置面板与背景音乐 |
| `DataMgr` | `core/services/data_manager.gd` | 本地存档、聊天记录、好友/俱乐部缓存 |
| `MailMgr` | `core/services/mail_manager.gd` | 邮件列表（本地 mock） |
| `WindowDrag` | `core/window/drag.gd` | 无边框窗口拖动 / 全屏 |
| `WindowPopup` | `core/window/popup.gd` | 消息框、确认框、飘字 |
| `Online` | `core/network/Online.gd` | Client / Session / Socket / 心跳 / RPC |
| `OnlineLogin` | `core/network/OnlineLogin.gd` | 登录、注册、玩家资料 |
| `OnlineChat` | `core/network/OnlineChat.gd` | 频道、消息、好友、俱乐部 |
| `OnlineGame` | `core/network/OnlineGame.gd` | 游戏列表、房间 RPC、对局消息 |
| `OnlineMatch` | `core/network/OnlineMatch.gd` | 对局创建/加入/匹配、自定义 RPC |
| `GameRegistry` | `core/framework/game_registry.gd` | 插件发现与 key/别名索引 |
| `GameLauncher` | `core/framework/game_launcher.gd` | 插件启动、桥注入、退出/重开/结算 |

`SceneMgr` 内部由三个小模块组成：`scene_registry.gd`（路由表）、`scene_transition.gd`（转场）、
`scene_overlay.gd`（叠加页）。

## 3. 分层与依赖方向

```
页面 / UI（lobby、app、shared/ui）
        │  只通过 Global.Xxx 调用框架服务
        ▼
全局服务层（SceneMgr / SettingsMgr / DataMgr / GameRegistry / GameLauncher）
        │
        ├── 子游戏插件（games/<key>，只通过 GameHostBridge / GameProtocol 访问框架）
        │
        ▼
网络层（Online / OnlineLogin / OnlineChat / OnlineGame / OnlineMatch）
        │
        ▼
Nakama 插件（addons/com.heroiclabs.nakama）+ 服务端
```

约束：

- UI 不直接操作 `NakamaClient`，统一走 `Global.Online*`；
- 跨模块事件走 `SignalMgr`，避免 UI 之间直接连线；
- 页面切换统一走 `SceneMgr`，不在业务里手动 `change_scene_to_file()`；
- 子游戏启动/退出/重开统一走 `GameLauncher`，游戏内只通过 `GameHostBridge` 回调；
- 本地持久化统一走 `DataMgr`，UI 不直接读写 `user://`。

## 4. 子游戏插件框架

```
games/<key>/game_meta.tres（GameMetadata 自描述）
      │  GameRegistry 扫描 res://games/* + user://games/*
      ▼
GameDescriptor（key/别名/入口/人数/联机/音视频能力）
      │
      ▼
SceneRouter.enter_game(game_id, room_info, NavigationContext)   ← UI 唯一入口
      │  （下载游戏的加载页用 enter_pending_game() 消费 pending 上下文）
      ▼
GameLauncher.start_game(key, options)
      ├─ 创建 GameHostBridge（唯一对外通道，写入 GameHostBridge.current）
      ├─ 实例化 entry.tscn
      ├─ 注入 on_game_init(room_info, bridge) / on_game_context(context)
      ├─ SceneMgr 切换场景 + 挂 __GameHUD（可配置）
      ├─ on_game_launched → on_game_start
      └─ 联机时通知服务端 LOADING_MAP_FINISH
退出：SceneRouter.exit_game()
      ├─ 调子游戏 on_game_destroy()（断信号/停 Timer/Tween，只一次）
      ├─ 通知服务端离开房间（leave_table，best-effort）
      ├─ GameLauncher.exit_game(result, navigate_back=false)（on_game_result/on_game_exit/LeaveMatch）
      └─ 按 NavigationContext.source 回退：
            GAME_LIST → gamelist；ROOM_LIST → roomlist；CLUB_ROOM_LIST → clubhome；CHAT_INVITE → home
           并广播 SignalMgr.GameReturnedSIG(source, gameId, roomId) 供页面刷新
重开：restart_game()（保留 match/room 上下文，先 on_game_destroy 旧实例）
结算：finish_game(result)
```

关键文件：

- `core/navigation/navigation_context.gd`：`NavigationContext`（来源枚举 + game_id/room_id/extra_data）；
- `core/navigation/scene_router.gd`：`SceneRouter`（进入/退出、导航栈、按来源回退、资源释放）；
- `core/framework/game_metadata.gd`：`GameMetadata`（game_id/display_name/icon/min_players/max_players/
  entry_scene/support_voice/support_video/online/别名/顺序/版本）；
- `core/framework/game_registry.gd`：扫描 `res://games/*/game_meta.tres` 与 `user://games/*`，建立索引；
- `core/framework/game_launcher.gd`：启动、上下文与桥注入、on_game_init/on_game_start、HUD、退出/重开/结算；
- `core/framework/game_host_bridge.gd`：`GameHostBridge`（唯一框架入口：UI/生命周期/网络/对局/
  send_match_data/request_exit_game/set_ready_status）；
- `core/framework/game_base.gd`、`game_base_2d.gd`、`game_base_control.gd`：
  生命周期契约 `on_game_init/on_game_start/on_network_packet/on_game_pause/on_game_resume/on_game_destroy`；
- `core/framework/game_protocol.gd`：`MatchState` / `MatchMode` / `PlayerStatus` / `GameStatus` 唯一来源；
- `games/template/`：复制用模板。

接入步骤见 [GAME_DEVELOPMENT.md](GAME_DEVELOPMENT.md)。

### 4.1 沙盒规则

`tools/validate_plugins.gd --strict-sandbox` 会强制以下约束：

1. `games/**/*.gd` 不得出现任何 `Global.` 访问（唯一入口是 `GameHostBridge.current`）；
2. 子游戏之间不得互相引用 `res://games/<other>/`；
3. 每个 `games/<key>/` 必须含 `game_meta.tres` + `entry.tscn`，`entry_scene` 指向本目录 `entry.tscn`；
4. `game_meta.game_id` == 目录名，且 game_id 全局唯一；
5. `entry.tscn` 必须可加载并实例化。

### 4.2 原生骨骼动画（DragonBones 平替，阶段 2）

`addons/gddragonbones` 是 GDExtension，目标是替换为 Godot 原生 `Skeleton2D + Bone2D + AnimationPlayer`：

- `tools/dragonbones_converter.gd`：解析 DragonBones 的 `_ske.json` / `_tex.json` + 图集 png，
  生成原生 `.tscn`（骨骼层级、插槽 Sprite、blendMode=add、display/alpha/scale/translate 动画轨道）。

```powershell
$g = 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe'
& $g --headless --path . --script res://tools/dragonbones_converter.gd -- `
    --ske=res://sprites/daojishi/daojishitongyong_ske.json `
    --tex=res://sprites/daojishi/daojishitongyong_tex.json `
    --out=res://sprites/daojishi/daojishi_avatar.tscn
```

- `shared/avatar/native_character_avatar.gd`：统一门面（`play_animation/stop_animation/
  set_skin/has_animation`），由 `avatar_scene` 指向生成的原生场景，自动查找 `AnimationPlayer`。

当前状态：

| 资产 | 原生场景 | 是否已替换使用方 |
| --- | --- | --- |
| 倒计时 `daojishi` | `sprites/daojishi/daojishi_avatar.tscn` | ✅ `shared/ui/countdown_timer.tscn` 已改用 `NativeCharacterAvatar` |
| 游戏卡片 7 套（dibeichang/jiangbei/puke/baoxiang1-4） | `sprites/<name>/<name>_avatar.tscn` | ✅ `lobby/gamelist/game_card.tscn` 已替换 |
| shaibao / startgame | `sprites/<name>/<name>_avatar.tscn` | 备用资产，已转换 |

`addons/gddragonbones`（约 278 MB）与全部 `*.dbfactory` / `*_dragon_bones_factory.tres` 已删除，项目不再包含 GDExtension。
## 5. 异步调用规范

Godot 4.7 中，动态调用异步函数必须等待返回值本身：

```gdscript
var result = await caller.callv("method_name", args)
```

不能写成“先取返回值、再 `await result.completed`”（会直接运行时报错）。

统一入口：

```gdscript
await Util.Asyn_Call(
    Global.Online.nakama_client,
    "authenticate_email_async",
    [email, password, null, false],
    on_success,   # 参数：NakamaAsyncResult / NakamaSession
    on_failure    # 参数：中文错误文本
)
```

- 返回 `NakamaAsyncResult` 且 `is_exception()` 为真时视为失败；
- 失败文本先经 `Errors.humanize()` 中文化；
- 仅 `Errors.is_network_error()` 为真的错误进入 `MessageQueue`，业务错误不重试；
- 登录/注册类接口不重试（见 `Errors.Non_Retry_API`）。

## 6. 数据与存档

`DataMgr` 使用 `user://game_data.save` 保存一个字典：

| 键 | 内容 |
| --- | --- |
| `chat_history_<uid>` | `{channel_id: [消息字典]}` |
| `uid_friend_<uid>` | 好友数组 |
| `uid_club_<uid>` | 俱乐部数组 |
| `uid_approval_<uid>` | 审批数组 |
| `cur_game` | 上一次对局 `{mode,gid,rid,mid,gname}` |
| `world_channel_id` | 世界频道 ID |

写入采用“临时文件 + 重命名”，避免写一半崩溃损坏存档。

## 7. 校验方式

```powershell
$g = 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe'

# 1. 全项目导入/脚本编译检查
& $g --headless --path . --editor --quit

# 2. 引用完整性（对比 refs_baseline.json，只报新增悬空）
& $g --headless --path . --script res://tools/validate_refs.gd

# 3. 场景可加载性（逐个 ResourceLoader.load）
& $g --headless --path . --script res://tools/validate_scenes.gd

# 4. 业务脚本加载
& $g --headless --path . --script res://tools/validate_scripts.gd

# 5. 插件契约 + 沙盒
& $g --headless --path . --script res://tools/validate_plugins.gd -- --strict-sandbox

# 6. 框架与生命周期
& $g --headless --path . --script res://tools/validate_game_framework.gd
& $g --headless --path . --script res://tools/test_plugin_lifecycle.gd

# 7. 基础层 / 异步封装测试
& $g --headless --path . --script res://tools/test_foundation.gd
& $g --headless --path . --script res://tools/test_async_call.gd
```

> 无服务端时 `test_plugin_lifecycle` 退出阶段会打印若干网络错误（返回大厅后聊天页会请求
> 俱乐部列表），属预期噪声，判定看最后的 `通过 N 项，失败 0 项`。

## 8. 已知边界

- `addons/`、`gdprotobuf/` 为第三方/生成代码，未重构；仓库只保留实际使用的 6 个插件
  （Nakama、protobuf、snopek-state-machine、transitions、virtual_joystick、gddragonbones）。
- 子游戏内部玩法（fishgame / tetris / chinesechess / mahjong_matching）只保证入口与桥接兼容，
  内部玩法未逐行重写；fishgame 的多人同步仍以 Nakama match 状态为主，通过 `GameHostBridge` 转发。
- 下载游戏目前仍解压到 `res://games/<key>/`，导出包中 `res://` 只读，正式发布前应迁移到
  `user://` + PCK（`GameRegistry` 已支持扫描 `user://games`）。
- `refs_baseline.json` 里有 8 处历史悬空引用（`res://icons/*.png`、`res://scenes/main_game.tscn`、
  两张 currency svg、joystick `mark.bmp`），不属于本轮范围，后续清理。
- 部分 `.tscn` 的 `ext_resource uid` 与本机 `.uid`/`.import` 不一致时，Godot 会回退到路径加载（仅警告）。
- `.uid` / `.import` 被 `.gitignore` 忽略（机器本地缓存），因此场景里的 `uid://` 引用在不同机器上会回退到路径加载并打印 warning，属正常现象；如需彻底消除，应把这两类文件纳入版本管理。
- 端到端联调需要真实 Nakama 服务端，建议在登录、聊天、房间、匹配四条链路各过一次冒烟。
- 按 PROMPT_REFACTOR 的阶段计划：阶段 1（插件底座 + 上下文导航）与阶段 2（DragonBones 原生平替）已完成；
  RTC 音视频（阶段 3）、子游戏深度迁移（阶段 4）进行中。
