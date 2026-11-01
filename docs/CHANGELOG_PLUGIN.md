# 插拔化重构变更记录（P0–P6）

> 分支：`refactor/plugin-arch`（`master` 保持重构前状态，可随时回退）。
> 目标与阶段划分见 [PLUGIN_REFACTOR_PLAN.md](PLUGIN_REFACTOR_PLAN.md)。
> 本文只记录“改了什么、破坏性变化、怎么验证”，架构与接入细节见
> [ARCHITECTURE.md](ARCHITECTURE.md)、[GAME_DEVELOPMENT.md](GAME_DEVELOPMENT.md)。

## 总览

| 阶段 | 内容 | 文件数 |
| --- | --- | --- |
| P0 | 迁移工具链 + 引用基线 | — |
| P1 | `scripts/1common`、主题/字体/Shader → `shared/` | 112 |
| P2 | `autoload/` → `core/{bootstrap,network,scene,services,window}` | 40 |
| P3 | 大厅业务 → `lobby/`；登录注册 → `app/` | 125 |
| P4 | 子游戏自包含 → `games/<key>/`（meta + entry） | 484 |
| P5 | `GameHostBridge` / `GameProtocol`，子游戏零 `Global.*` | 24 个脚本改写 |
| P6 | 文档重写与全量校验 | — |

累计移动/重命名约 **760 个文件**，重写 `res://` 引用 **600+ 处**。

## 破坏性变化（对外契约）

| 变化 | 影响 | 迁移方式 |
| --- | --- | --- |
| 子游戏注册不再用 `GameCatalog.BUILTIN` | 新增游戏不再改框架代码 | 在 `games/<key>/game_meta.tres` 声明 |
| 子游戏入口从 `scenes/game/<k>/<k>.tscn` 改为 `games/<k>/entry.tscn` | 外部下载包布局变化 | 打包时按新布局；旧布局有 `entry.tscn` 兜底 |
| 子游戏内禁止 `Global.*` | 旧游戏脚本需适配 | 改用 `GameHostBridge.current` / `GameProtocol` |
| `Global.Shared` 服务移除 | 俄罗斯方块常量表不再全局可见 | 游戏内 `TetrisShared.shared()` / `TetrisTypes` |
| `Global.OnlineMatch.MatchState` 等枚举 | 数值不变，但定义迁到 `GameProtocol` | `OnlineMatch`/`OnlineGame` 已别名兼容，外部可继续用旧写法 |
| 目录路径 | 场景/脚本/资源路径全部变化 | 见下方“最终目录” |

## P1 `shared/`

- `scripts/1common/**`、`scenes/1common/**` → `shared/ui/**`（含 `controls/ loading/ popup/ gridanimation/`）；
- `styles/ themes/ shaders/ assets/font/` → `shared/styles/{styles,themes,shaders,fonts}`；
- 新增 `shared/styles/shaders/shaderlib/README.md` 占位（该编辑器插件后续已整体删除，占位目录同步移除）；
- `project.godot` 的 `gui/theme/custom_font`、`shader_library` 路径同步（该编辑器插件后续已删除）。

## P2 `core/`

- `autoload/global/**` → `core/bootstrap/**`（Global/Util/Errors + `global_config.cfg`）；
- `autoload/managers/scene_*` → `core/scene/`；signal/settings/data/mail → `core/services/`；
- `autoload/nakama/**` → `core/network/**`；`autoload/window/**` → `core/window/**`；
- `project.godot` autoload 4 条路径、`global_config.cfg`、`Global.DEFAULT_SERVICES` 同步；
- 删除死文件 `autoload/global/global.tscn`（无人引用的 autoload 重复场景）。

## P3 `lobby/` + `app/`

- `chat → lobby/chat`；`club → lobby/club`；`clublist → lobby/club/list`
  （club 与 clublist 都含 `MemberItem`/`member_item`，Windows 大小写不敏感会撞名，故分子目录）；
- `roomlist → lobby/room`；`match → lobby/match`；`gamelist → lobby/gamelist`；
  `email → lobby/email`；`approval → lobby/approval`；`announcements → lobby/announcement`；
- `home → lobby/home`；`login/register → app/{login,register}`；
- `core/scene/scene_registry.gd` 路由表、`project.godot` 主场景路径同步。

## P4 `games/` 插件化

- `scripts/game/core/**` → `core/framework/**`；
- 每个游戏变为自包含目录：

```text
games/chinesechess/{game_meta.tres, entry.tscn, scripts/, scenes/, assets/}
games/tetris/{...}
games/mahjong_matching/{...}
games/fishgame/{...}
games/template/
```

- `GameMeta` 资源类型 + 每个游戏一份 `game_meta.tres`（当时由迁移工具生成，工具已删除）；
- `GameRegistry` 改为扫描 `res://games/*/game_meta.tres` 与 `user://games/*`，删除 `game_catalog.gd`；
- `loading_screen.gd` 下载解压布局改为 `res://games/<key>/entry.tscn`；
- 新增 `tools/validate_plugins.gd`（结构 + 实例化冒烟 + 沙盒 lint）。

## P5 `GameHostBridge` / `GameProtocol`

- 新增 `core/framework/game_bridge.gd`：子游戏唯一框架入口（UI / 生命周期 / 网络 / 对局），
  `GameHostBridge.current` 由 `GameLauncher` 创建与清空；
- 新增 `core/framework/game_protocol.gd`：`MatchState` / `MatchMode` / `PlayerStatus` / `GameStatus`
  唯一来源，`OnlineMatch`/`OnlineGame` 改为别名引用；
- `GameLauncher` 注入 `on_game_bridge(bridge)` + `game_bridge` meta；基类新增 `bridge` 成员；
- 迁移 24 个游戏脚本：`Global.Online*` / `WindowPopup` / `SceneMgr` / `GameLauncher` 调用全部改走桥；
- 俄罗斯方块：`Global.Shared` 服务删除，改为 `TetrisShared.shared()` + `TetrisTypes`（拆出类型脚本
  以打断 `*.tres → piece_data.gd → TetrisShared` 的循环依赖）；
- `validate_plugins` 的沙盒规则升级为“禁止任何 `Global.`”，strict 模式 0 违规；
- 新增 `tools/test_plugin_lifecycle.gd`：启动 → 桥注入 → 场景进树 → 退出清理，16 项断言。

## 最终目录

```text
core/  shared/  lobby/  games/  app/  assets/  addons/  gdprotobuf/  docs/  tools/
```

`scripts/`、`scenes/`、`autoload/`、`themes/`、`1common/` 全部消失。

## 迁移工具（保留在仓库，后续可复用）

`tools/` 现在只保留日常适用的校验脚本（一次性迁移脚本已随重构完成删除，需要时可从 git 历史找回）：

| 工具 | 作用 |
| --- | --- |
| `tools/validate_refs.gd` | 悬空引用检查（对比 `tools/refs_baseline.json`） |
| `tools/validate_scenes.gd` | 全量场景可加载性 |
| `tools/validate_scripts.gd` | 全量业务脚本加载 |
| `tools/validate_plugins.gd` | 插件契约 + 沙盒 |
| `tools/validate_game_framework.gd` | 注册表/上下文/结算等框架断言 |
| `tools/test_plugin_lifecycle.gd` | 启动/退出生命周期冒烟 |
| `tools/test_foundation.gd`、`tools/test_async_call.gd` | 基础层与异步封装回归 |
| `tools/web_server.py` 等 | Web 导出本地测试服务器（对应 Web 导出预设） |

## P7 冗余清理（收尾）

- **删除未使用插件**：`addons/agones`、`addons/godot-livekit`（GDExtension，216 MB，无任何引用）、
  `addons/shader_library`（编辑器 Shader 浏览器，未启用），并同步移除 `project.godot` 的
  `[shader_library]` 段、`.godot/extension_list.cfg` 缓存与 `shared/styles/shaders/shaderlib/` 占位目录；
- 保留实际使用的 6 个插件：Nakama、protobuf、snopek-state-machine、transitions、virtual_joystick、gddragonbones；
- **删除构建产物/死文档**：`android/.build_version`、`docs/archive/`（未接入旧原型）、`docs/REFACTOR_GUIDE.md`；
- **tools/ 精简**：只保留 8 个日常校验/测试脚本、`refs_baseline.json` 与 Web 导出测试服务器；
  一次性迁移工具（`tools/refactor/*`）与外部游戏适配脚本（`tools/外部游戏*.gd/py`）已删除（git 历史可找回）；
- **清理机器本地残留**：删除 115 个失去宿主文件的 `.uid`/`.import`，移除 `scripts/`、`autoload/`、
  `shaders/` 等 36 个残留空目录。
## P8 = PROMPT_REFACTOR 阶段 1：插件底座 + 上下文感知导航

> 以 `PROMPT_REFACTOR.md` 为新的总纲；本阶段只做“可插拔底座与智能导航栈”。

新增：

- `core/navigation/navigation_context.gd`：`NavigationContext`（EntrySource + game_id/room_id/extra_data，
  支持 `to_dict/from_dict` 与 `GAME_LIST/ROOM_LIST/CLUB_ROOM_LIST/CHAT_INVITE` 工厂）；
- `core/navigation/scene_router.gd`：`SceneRouter`（Global 服务）——
  导航栈、`prepare_*()`/`enter_game()`/`enter_pending_game()`、`exit_game()` 按来源回退、
  `on_game_destroy()` 资源释放、`leave_table` 离房通知、`SignalMgr.GameReturnedSIG`；
- `core/framework/game_metadata.gd`：`GameMetadata`（替代 `GameMeta`）——
  `game_id/display_name/icon/min_players/max_players/entry_scene/support_voice/support_video` 等；
- `core/framework/game_base.gd`：`GameBase` 生命周期契约（Node）；
  `GameBase2D` / `GameBaseControl` 同步实现同一契约（Node2D/Control 单继承限制）；
- `core/framework/game_host_bridge.gd`：`GameHostBridge`（由 `GameBridge` 更名）新增
  `send_match_data()` / `request_exit_game()` / `set_ready_status()` / `ready_status_changed`。

行为变化：

- 进入子游戏统一走 `SceneRouter`（`loading_screen`、`SceneMgr.to_game_scene` 已切换）；
- 退出按进入来源回退：游戏列表 → `gamelist`、房间列表 → `roomlist`、俱乐部 → `clubhome`、聊天邀请 → `home`；
- 退出前先调用子游戏 `on_game_destroy()`（幂等），再 `GameLauncher.exit_game(result, navigate_back=false)`；
- `GameLauncher.exit_game()` 新增 `navigate_back` 参数；`on_game_init(room_info, bridge)` 在进入树前注入。

迁移：

- 4 个 `game_meta.tres` 改为 `GameMetadata` 字段（`key→game_id`、`title→display_name`）；
- `tools/validate_plugins.gd` 校验新字段与人数/能力配置；
- 新增 `tools/test_navigation.gd`（26 项断言：来源映射、pending 生命周期、进入/退出全链路）。
## P9 = PROMPT_REFACTOR 阶段 2：DragonBones 原生平替（pilot）

新增：

- `tools/dragonbones_converter.gd`：DragonBones `_ske.json` + `_tex.json` + 图集 -> 原生
  `Skeleton2D + Bone2D + Sprite2D + AnimationPlayer` 场景；支持骨骼 translate/scale/rotate、
  插槽 displayFrame/colorFrame(aM)、blendMode=add、zOrder；贝塞尔曲线暂按线性近似；
- `shared/avatar/native_character_avatar.gd`：`NativeCharacterAvatar` 门面
  （`play_animation/stop_animation/set_skin/has_animation/animation_names`）；
- 生成 8 套原生骨骼场景：`sprites/daojishi/daojishi_avatar.tscn` 及
  `sprites/{dibeichang,jiangbei,puke,baoxiang1-4}/<name>_avatar.tscn`；
- `shared/ui/countdown_timer.tscn` 由 `DragonBones` 节点改为 `NativeCharacterAvatar`（pilot 平替）；
- 新增 `tools/test_avatar.gd`（22 项断言：结构/动画/门面 API/场景替换）。

注意：`lobby/gamelist/game_card.tscn` 的 7 个 DragonBones 节点尚未替换，
`addons/gddragonbones` 暂保留；替换 + 视觉验证后再删除该插件（约 278 MB）。
## 验证记录

各阶段门禁结果：

| 阶段 | 导入 | 场景 | 脚本 | 框架 | 插件 | 引用 |
| --- | --- | --- | --- | --- | --- | --- |
| P1 | 0 错误 | 108/108 | 174/174 | — | — | 0 新增悬空 |
| P2 | 0 错误 | 107/107 | 174/174 | 34/34 | — | 0 新增悬空 |
| P3 | 0 错误 | 107/107 | 174/174 | 34/34 | — | 0 新增悬空 |
| P4 | 0 错误 | 107/107 | 176/176 | 34/34 | 结构 0 失败 | 0 新增悬空 |
| P5/P6 | 0 错误 | 107/107 | 179/179 | 34/34 | strict 0 违规 | 0 新增悬空 |

补充测试：`test_foundation`、`test_async_call` 全绿；`test_plugin_lifecycle` 16/16。

## 回滚

```powershell
git checkout master          # 回到重构前
# 或只回滚某个阶段
git revert <stage-commit>
```
