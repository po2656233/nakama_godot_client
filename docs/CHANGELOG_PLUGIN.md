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
| P5 | `GameBridge` / `GameProtocol`，子游戏零 `Global.*` | 24 个脚本改写 |
| P6 | 文档重写与全量校验 | — |

累计移动/重命名约 **760 个文件**，重写 `res://` 引用 **600+ 处**。

## 破坏性变化（对外契约）

| 变化 | 影响 | 迁移方式 |
| --- | --- | --- |
| 子游戏注册不再用 `GameCatalog.BUILTIN` | 新增游戏不再改框架代码 | 在 `games/<key>/game_meta.tres` 声明 |
| 子游戏入口从 `scenes/game/<k>/<k>.tscn` 改为 `games/<k>/entry.tscn` | 外部下载包布局变化 | 打包时按新布局；旧布局有 `entry.tscn` 兜底 |
| 子游戏内禁止 `Global.*` | 旧游戏脚本需适配 | 改用 `GameBridge.current` / `GameProtocol` |
| `Global.Shared` 服务移除 | 俄罗斯方块常量表不再全局可见 | 游戏内 `TetrisShared.shared()` / `TetrisTypes` |
| `Global.OnlineMatch.MatchState` 等枚举 | 数值不变，但定义迁到 `GameProtocol` | `OnlineMatch`/`OnlineGame` 已别名兼容，外部可继续用旧写法 |
| 目录路径 | 场景/脚本/资源路径全部变化 | 见下方“最终目录” |

## P1 `shared/`

- `scripts/1common/**`、`scenes/1common/**` → `shared/ui/**`（含 `controls/ loading/ popup/ gridanimation/`）；
- `styles/ themes/ shaders/ assets/font/` → `shared/styles/{styles,themes,shaders,fonts}`；
- 新增 `shared/styles/shaders/shaderlib/README.md` 占位，保持插件安装目录存在；
- `project.godot` 的 `gui/theme/custom_font`、`shader_library` 路径同步。

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

- `GameMeta` 资源类型 + 每个游戏一份 `game_meta.tres`（由 `tools/refactor/generate_game_meta.gd` 生成）；
- `GameRegistry` 改为扫描 `res://games/*/game_meta.tres` 与 `user://games/*`，删除 `game_catalog.gd`；
- `loading_screen.gd` 下载解压布局改为 `res://games/<key>/entry.tscn`；
- 新增 `tools/validate_plugins.gd`（结构 + 实例化冒烟 + 沙盒 lint）。

## P5 `GameBridge` / `GameProtocol`

- 新增 `core/framework/game_bridge.gd`：子游戏唯一框架入口（UI / 生命周期 / 网络 / 对局），
  `GameBridge.current` 由 `GameLauncher` 创建与清空；
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

| 工具 | 作用 |
| --- | --- |
| `tools/refactor/apply_moves.ps1` | 按映射表移动文件（含 `.uid`/`.import`，支持 exclude/断点续跑/冲突预检） |
| `tools/refactor/rewrite_refs.gd` | GDScript 重写 `res://` 引用（UTF-8 安全、最长前缀优先、支持 exclude） |
| `tools/refactor/maps/*.json` | P1–P4 的迁移映射表 |
| `tools/refactor/repair_import.gd` | 一次性修复被旧脚本污染的 `.import` |
| `tools/refactor/generate_game_meta.gd` | 生成 `game_meta.tres` |
| `tools/validate_refs.gd` | 悬空引用检查（基线比对） |
| `tools/validate_scenes.gd` | 全量场景可加载性 |
| `tools/validate_scripts.gd` | 全量业务脚本加载 |
| `tools/validate_plugins.gd` | 插件契约 + 沙盒 |
| `tools/test_plugin_lifecycle.gd` | 启动/退出生命周期冒烟 |

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
