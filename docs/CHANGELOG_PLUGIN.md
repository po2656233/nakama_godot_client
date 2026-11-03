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

收尾：`lobby/gamelist/game_card.tscn` 的 7 个 DragonBones 节点已替换为 `NativeCharacterAvatar`；
`addons/gddragonbones`、全部 `*.dbfactory` 与 `*_dragon_bones_factory.tres` 已删除（约 -278 MB），项目不再包含任何 GDExtension。
另外转换了 shaibao / startgame 两套备用资产。
## P10 = PROMPT_REFACTOR 阶段 3：Global 拆解 + RTC 音视频

Global 拆解（消灭上帝对象）：

- `core/bootstrap/service_catalog.gd`：`ServiceCatalog`，只负责配置读取与内置兜底；
- `core/bootstrap/service_container.gd`：`ServiceContainer`，只负责懒加载/缓存/挂载；
- `core/bootstrap/global.gd`：变为薄门面，公开 API 不变。

RTC：

- `core/rtc/rtc_protocol.gd`：`RtcProtocol`（Kind/CallState、op_code、JSON + base64 编解码）；
- `core/rtc/rtc_signaling.gd`：`RtcSignaling`（通话状态机、Nakama match state 信令、
  offer/answer/ice 透传、音视频帧转发、无 socket 降级）；
- `core/rtc/rtc_media.gd`：`RtcMedia`（AudioEffectCapture 采集、AudioStreamGenerator 回放、
  CameraServer/CameraFeed -> CameraTexture）；
- `shared/ui/rtc/call_modal.gd/.tscn`：来电/呼叫面板；
- `shared/ui/rtc/rtc_video_grid.gd/.tscn`：视频网格、JPEG 帧显示、麦克风/摄像头/挂断；
- `tools/test_rtc.gd`：34 项断言（协议/状态机/媒体降级/UI 实例化）。

已知限制：桌面端无内置 WebRTC peer connection，当前为“Nakama 信令 + 应用层媒体帧转发”；
生产环境建议服务端补 SFU/转发节点。
## P11 = PROMPT_REFACTOR 阶段 4：子游戏迁移到 GameBase + 验收

- `games/tetris/scripts/tetris_game.gd`：tetris 入口根节点改为 `extends GameBase`，
  实现 `on_game_init(room_info, bridge)` / `on_game_start()` / `on_game_destroy()`；
  `games/tetris/entry.tscn` 根节点挂载该脚本；
- `SignalMgr.GameDestroyedSIG(gameId)`：SceneRouter 调用 `on_game_destroy()` 后广播，便于验收释放；
- `games/tetris/scripts/ui.gd`：结算面板返回优先走 `GameHostBridge.request_exit_game()`；
- `tools/test_phase4.gd`：24 项断言——
  从游戏列表进入 → 退出回 `gamelist`；从房间列表进入 → 退出回 `roomlist`；
  `on_game_start`/`on_game_destroy` 被调用、`room_info` 注入、场景实例被释放。
## P12 = 2026-11 阶段 1：骨骼转换器修复（真机显示错乱）

根因（逐项验证，非猜测）：

1. 图集裁剪 `frameX/frameY/frameWidth/frameHeight` 被忽略 → 贴图相对骨骼整体偏移；
2. slot 变换与 display 变换混在同一层，且绘制顺序按骨骼树递归而非 DragonBones slot 顺序
   （puke 有 35 处逆序），造成前后遮挡错乱；
3. 动画帧被当成绝对值：实测 jiangbei 奖杯骨骼 base 旋转 -111.8°，帧值 -1.52，
   绝对值会把奖杯转 110°；用原 `addons/gddragonbones` 参考渲染确认帧值是
   **相对 base pose 的增量**（位移相加、旋转相加、缩放相乘）；
4. `curve` 贝塞尔与 `tweenEasing` 被一律当线性，动作失真；
5. `rotate` 字段（DragonBones 实际字段名）未被读取，早期版本直接漏掉旋转动画。

修改：

- 重写 `tools/dragonbones_converter.gd`（v2）：裁剪补偿 + pivot、slot 子层、
  绝对 `z_index`、增量骨骼语义、曲线/缓动烘焙、step 段、图集改名容错；
- 重新生成 10 套 `*_avatar.tscn`；`addons/gddragonbones` 与 `*.dbfactory` 再次移除；
- 新增 `tools/test_avatar_geometry.gd`（4634 项矩阵/offset/z_index/可见性断言）；
- 新增 `tools/preview_avatar.gd`（真实渲染截图，支持 seek/delay）；
- `tools/test_avatar.gd` 更新为新的 daojishi 场景名。

验证：

- `test_avatar` 22/22；`test_avatar_geometry` 4634/4634；
- 与原 gddragonbones 参考渲染逐帧比对 jiangbei：修复后姿态一致（修复前丝带飞散、奖杯翻转）；
- 场景 121/121、脚本 196/196、引用 0 新增悬空、插件 4/0/0。

限制：带 `weights` 的网格（shaibao 26、puke 3）尚不支持蒙皮变形，按矩形贴图近似。

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