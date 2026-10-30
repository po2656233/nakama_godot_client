# 子游戏框架与结构重整（本轮变更）

> 范围：场景导航、启动器/注册表、加载页、子游戏入口、全局服务表、目录命名。
> 未改动：`addons/`、`gdprotobuf/`、协议字段、各子游戏内部玩法逻辑。

## 1. 新增：子游戏框架

| 文件 | 作用 |
| --- | --- |
| `scripts/game/core/game_catalog.gd` | 内置游戏唯一清单 |
| `scripts/game/core/game_descriptor.gd` | 游戏描述（key/别名/场景/人数/联机） |
| `scripts/game/core/game_registry.gd` | `Global.GameRegistry`，key/别名索引 + 下载游戏注册 |
| `scripts/game/core/game_launcher.gd` | `Global.GameLauncher`，启动/退出/重开/结算 + HUD |
| `scripts/game/core/game_context.gd` | 启动上下文 |
| `scripts/game/core/game_result.gd` | 统一结算结果 |
| `scripts/game/core/game_base_2d.gd` | Node2D 子游戏基类 |
| `scripts/game/core/game_base_control.gd` | Control 子游戏基类 |
| `scripts/game/template/` | 新游戏模板与 README |

效果：

- `SceneMgr` 不再硬编码 `chinesechess/tetris/mahjong_matching/fishgame`；
- 子游戏统一从 `GameLauncher.start_game(key)` 进入，自动注入上下文、挂返回按钮、通知对局服务；
- 退出/重开/结算不再各写一套；
- 新增游戏 = 场景 + 脚本 + `game_catalog.gd` 一条数据。

## 2. 场景导航拆分

`autoload/managers/scene_manager.gd`（原 662 行）拆为：

| 文件 | 职责 |
| --- | --- |
| `autoload/managers/scene_manager.gd` | 对外门面：切换/返回/查询 |
| `autoload/managers/scene_registry.gd` | 页面路由表 |
| `autoload/managers/scene_transition.gd` | 转场类型与 FancyFade 调用 |
| `autoload/managers/scene_overlay.gd` | 中央叠加页 |

同时：

- 修正 `loading` / `matchSuccess` 的错误路径；
- 删除未使用的 `hide_scene/show_scene/show_scene_on_right/remove_scene/scan_scenes_directory` 等实现；
- `go_back()` 不再直接 `LeaveMatch`（网络职责移到 `GameLauncher.exit_game()`）；
- headless 环境下转场直接替换场景，避免截图接口报错。

## 3. 加载页重写

`scripts/1common/loading/loading_screen.gd`：

- 下载/解压/注册/启动职责收敛，删除不可达的重复分类逻辑；
- `clamp(-5, value, 100)` 参数顺序修正；
- zip 解压增加绝对路径与 `..` 穿越校验；
- 解压后通过 `GameRegistry.register_external()` 注册，再交给 `GameLauncher` 启动；
- 修复“第二次进入游戏时进度仍为 100% 导致直接关闭”的状态残留（统一 `Show()` 重置）。

## 4. 全局服务表

- `Global` 重写：只读项目内 `global_config.cfg`，不再读取 `user://` 加密缓存；
- 配置缺项用 `DEFAULT_SERVICES` 补齐；
- 删除未使用的 `save_config/load_config/add_module_config` 与硬编码加密 key；
- `autoload/manger/` 目录更名为 `autoload/managers/`（修正拼写）；
- 删除未使用的 `network_manager.gd`、`thread_manager.gd`；
- 注册 `GameRegistry`、`GameLauncher` 两个新服务；
- `MessageQueue` 不再注册为 `Global` 服务，只由 `Util.reliable_queue` 内部创建，避免重复实例。

## 5. 关键 Bug 修复

| 问题 | 影响 | 处理 |
| --- | --- | --- |
| `Util.async_call` 用 `await task.completed` | Godot 4.7 下异步请求报错 | 改为 `await callable.callv(args)`，并恢复 `Asyn_Call` 兼容入口 |
| `MessageQueue.EnqueueMessage` 参数类型不匹配 | 文件无法编译 | 统一为 `(method, args, obj, success, fail)` |
| `Online.nakama_client/nakama_session` getter/setter 自递归 | 首次访问客户端/设置会话即栈溢出 | 改为 `_client`/`_session` 后端 + 内联 getter/setter |
| `OnlineLogin.player_data` 只读绑定 + 多处赋值 | 资料加载时报错 | 改为普通变量，保留 `get_my_info()` |
| `OnlineMatch` 多个属性 getter-only 但内部频繁赋值 | 匹配流程运行时报错 | 改为普通变量，保留 getter 方法 |
| `Errors.humanize/is_network_error` 缺失 | 错误无法中文化/无法分类重试 | 补齐方法 |
| `ClubDetailScene` 信号只发 1 个参数 | `ChangeSceneSIG` 期望 4 个，运行时报错 | 补齐参数 |
| `loading_screen` 进度 clamp 参数顺序错误 | 失败进度不可达 | 修正为 `clampf(value, -5, 100)` |
| 子游戏内 `change_scene_to_file()/reload_current_scene()` | 绕过启动器，丢失上下文与 HUD | 改为 `exit_game/restart_game`，保留无启动器时的兜底 |

## 6. 代码清理

- 删除临时文件：`loading_indicator.tscn*.tmp`、`tetCF80.tmp`、`Player.tscn*.tmp`；
- 删除死页面 `scripts/game/game.gd`（对应 `scenes/game/game.tscn` 不存在）；
- 未接入且无法解析的原型移入 `docs/archive/`：
  `nakama_service/`、`message_parser/`、`network_wrapper/`、`time_utils/`；
- `tools/validate_scripts.gd` 失败时返回非零退出码。

## 7. 验证

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/validate_scripts.gd
godot --headless --path . --script res://tools/validate_game_framework.gd
godot --headless --path . --script res://tools/test_foundation.gd
godot --headless --path . --script res://tools/test_async_call.gd
```

子游戏场景 headless 冒烟：`tetris / xiangqi / mahjong_matching / fishgame` 均可实例化，无脚本解析错误。
