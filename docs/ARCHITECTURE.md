# 折纸屋客户端架构说明

> 本文描述当前代码分层、服务职责、子游戏接入方式。
> 目标：**页面与子游戏解耦、路由与业务解耦、公共能力只保留一份**。

## 1. 启动与全局服务

`project.godot` 只注册 4 个 autoload：

| 顺序 | 名称 | 作用 |
| --- | --- | --- |
| 1 | `Nakama` | Nakama 官方插件入口 |
| 2 | `Global` | 服务注册表（懒加载 `Global.Xxx`） |
| 3 | `Util` | 异步调用、排序、时间、图片、可靠消息队列 |
| 4 | `Errors` | 错误中文化、网络错误识别 |

`Global` 启动时读取 `autoload/global/global_config.cfg`，把“服务名 -> 脚本路径”登记到内存；
第一次访问 `Global.Xxx` 时才实例化并挂到 `Global` 节点下。配置文件缺项会用
`global.gd` 里的 `DEFAULT_SERVICES` 补齐，且**不再读取 `user://` 缓存**，避免旧路径覆盖新配置。

### 服务一览

| 服务 | 文件 | 职责 |
| --- | --- | --- |
| `SignalMgr` | `autoload/managers/signal_manager.gd` | 跨模块信号总线 |
| `SceneMgr` | `autoload/managers/scene_manager.gd` | 场景路由、切换/返回、转场、叠加页 |
| `SettingsMgr` | `autoload/managers/settings_manager.gd` | 设置面板与背景音乐 |
| `DataMgr` | `autoload/managers/data_manager.gd` | 本地存档、聊天记录、好友/俱乐部缓存 |
| `MailMgr` | `autoload/managers/mail_manager.gd` | 邮件列表（本地 mock） |
| `WindowDrag` | `autoload/window/drag.gd` | 无边框窗口拖动 / 全屏 |
| `WindowPopup` | `autoload/window/popup.gd` | 消息框、确认框、飘字 |
| `Online` | `autoload/nakama/Online.gd` | Client / Session / Socket / 心跳 / RPC |
| `OnlineLogin` | `autoload/nakama/OnlineLogin.gd` | 登录、注册、玩家资料 |
| `OnlineChat` | `autoload/nakama/OnlineChat.gd` | 频道、消息、好友、俱乐部 |
| `OnlineGame` | `autoload/nakama/OnlineGame.gd` | 游戏列表、房间 RPC、对局消息 |
| `OnlineMatch` | `autoload/nakama/OnlineMatch.gd` | 对局创建/加入/匹配、自定义 RPC |
| `GameRegistry` | `scripts/game/core/game_registry.gd` | 子游戏清单与 key/别名查询 |
| `GameLauncher` | `scripts/game/core/game_launcher.gd` | 子游戏启动、上下文注入、退出/重开/结算 |
| `MessageQueue` | `autoload/nakama/MessageQueue.gd` | 可靠重发队列（`Util.reliable_queue` 内部实例，不注册为 Global 服务） |
| `FancyFade` / `Transitions` | `addons/transitions/` | 第三方转场动画 |

`SceneMgr` 内部由三个小模块组成，职责单一：

| 模块 | 文件 | 职责 |
| --- | --- | --- |
| 路由表 | `autoload/managers/scene_registry.gd` | 只维护“页面名 -> 路径” |
| 转场 | `autoload/managers/scene_transition.gd` | 转场类型表 + 调用 `FancyFade` |
| 叠加页 | `autoload/managers/scene_overlay.gd` | 在当前场景上层开页面 |

## 2. 分层与依赖方向

```
场景 / UI 脚本（scenes + scripts）
        │  只通过 Global.Xxx 调用
        ▼
全局服务层（SceneMgr / SettingsMgr / DataMgr / GameRegistry / GameLauncher）
        │
        ├── 子游戏层（scripts/game/<key>，继承 GameBase2D / GameBaseControl）
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
- 子游戏启动/退出/重开统一走 `GameLauncher`，不直接改场景；
- 本地持久化统一走 `DataMgr`，UI 不直接读写 `user://`。

## 3. 子游戏框架

```
GameCatalog（数据清单）
      │
      ▼
GameRegistry（Global.GameRegistry）──查 key/别名──> GameDescriptor
      │
      ▼
GameLauncher（Global.GameLauncher）
      ├─ 实例化场景
      ├─ 注入 GameContext（房间、对局、模式、入口页）
      ├─ 挂统一返回按钮 HUD
      ├─ 通知服务端 LOADING_MAP_FINISH
      └─ 统一 exit_game / restart_game / finish_game
      │
      ▼
子游戏（GameBase2D / GameBaseControl）
```

关键文件：

- `scripts/game/core/game_catalog.gd`：**新增游戏只改这里**（key、标题、场景、人数、联机、别名）；
- `scripts/game/core/game_registry.gd`：key/别名索引 + 下载游戏的运行时注册；
- `scripts/game/core/game_launcher.gd`：启动、上下文、HUD、退出/重开/结算；
- `scripts/game/core/game_context.gd`：启动上下文；
- `scripts/game/core/game_result.gd`：统一结算结果；
- `scripts/game/core/game_base_2d.gd`、`game_base_control.gd`：子游戏基类；
- `scripts/game/template/`：复制用模板。

子游戏接入步骤见 [GAME_DEVELOPMENT.md](GAME_DEVELOPMENT.md)。

### 3.1 启动流程

```
游戏列表/房间
  └─ Global.SignalMgr.LoadingGameSIG.emit(game_id)
       └─ loading_screen.gd
            ├─ 本地已有场景 -> GameLauncher.start_game(en_name)
            └─ 本地缺失     -> 下载 zip、解压、GameRegistry.register_external()
                               -> GameLauncher.start_game(en_name)
                                   ├─ GameRegistry.find() -> GameDescriptor
                                   ├─ SceneMgr.switch_to_scene_instance()
                                   ├─ 注入 GameContext + 挂 __GameHUD
                                   └─ OnlineGame.sendToMatch(LOADING_MAP_FINISH)
```

### 3.2 退出流程

```
返回按钮 / 游戏内退出
  └─ GameLauncher.exit_game(result?)
       ├─ 回调 on_game_result / on_game_exit
       ├─ 广播 game_finished
       ├─ OnlineMatch.LeaveMatch(match_id)（仅联机）
       └─ SceneMgr.go_back()
```

## 4. 异步调用规范

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

也可以传 Callable：

```gdscript
await Util.async_call(
    Global.Online.nakama_client.authenticate_email_async,
    [email, password, null, false],
    on_success,
    on_failure
)
```

- 返回 `NakamaAsyncResult` 且 `is_exception()` 为真时视为失败；
- 失败文本先经 `Errors.humanize()` 中文化；
- 仅 `Errors.is_network_error()` 为真的错误进入 `MessageQueue`，业务错误不重试；
- 登录/注册类接口不重试（见 `Errors.Non_Retry_API`）。

## 5. 数据与存档

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

## 6. 目录说明

```
autoload/                全局服务（启动、管理器、Nakama 封装、窗口）
  global/                Global / Util / Errors / global_config.cfg
  managers/              SceneMgr / SettingsMgr / DataMgr / MailMgr / SignalMgr
  nakama/                Online* 网络服务
  window/                无边框拖动、弹窗
scenes/                  页面与预制体
scripts/
  game/core/             子游戏框架（注册表、启动器、上下文、基类）
  game/template/         新子游戏模板
  game/<key>/            各内置子游戏
  1common/               通用 UI（设置、加载、排行榜、弹窗、列表）
  chat/ roomlist/ match/ clublist/ club/ gamelist/ email/ ...
assets/game/<key>/       子游戏资源
addons/                  第三方插件（不改）
gdprotobuf/              协议生成代码（不改）
docs/                    架构与接入文档
tools/                   headless 校验脚本
```

## 7. 校验方式

```powershell
# 1. 全项目导入/脚本编译检查
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --editor --quit

# 2. 批量加载业务脚本
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --script res://tools/validate_scripts.gd

# 3. 子游戏框架校验
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --script res://tools/validate_game_framework.gd

# 4. 基础层 / 异步封装测试
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --script res://tools/test_foundation.gd
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --script res://tools/test_async_call.gd
```

## 8. 已知边界

- `addons/`、`gdprotobuf/` 为第三方/生成代码，未重构；
- 子游戏内部玩法（fishgame / tetris / xiangqi / mahjong）只保证入口兼容，内部玩法未逐行重写；
- 下载游戏目前仍解压到 `res://scenes/game/`，在导出包中 `res://` 只读，后续应迁移到 `user://` 或 PCK；
- 部分 `.tscn` 的 `ext_resource uid` 与本机 `.uid`/`.import` 不一致，Godot 会回退到路径加载（仅警告）；
- `docs/archive/` 存放未接入的旧原型，不属于构建；
- 端到端联调需要真实 Nakama 服务端，建议在登录、聊天、房间、匹配四条链路各过一次冒烟。
