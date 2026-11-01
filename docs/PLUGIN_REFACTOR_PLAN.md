# 插拔化重构总计划（.cursorrules 的工程化落地）

> 本文件把 `.cursorrules` 的三条使命拆成**可执行、可验证、可回滚**的阶段任务。
> 每个阶段都必须通过「门禁」才能进入下一阶段；门禁失败即回滚本阶段。
>
> 当前基线：Godot 4.7.2，1644 个受版本管理文件（144 个 `.gd`、107 个 `.tscn`）。
> 基线全量导入检查 `--editor --quit` 无脚本错误。
> 工作分支：`refactor/plugin-arch`（`master` 保持原样，可随时回退）。

---

## 0. 验收定义（Definition of Done）

| 目标 | 可验证的判据 |
| --- | --- |
| 结构极致清晰 | `res://` 下只保留 `core/ shared/ lobby/ games/ app/ assets/ addons/ gdprotobuf/ docs/ tools/`；不存在 `scripts/`、`scenes/`、`autoload/`、`1common/`、`themes/game/` |
| 功能内聚 | 每个业务模块的 `.gd` 与 `.tscn` 同目录；无跨层硬编码路径 |
| 子游戏彻底插拔 | 新增/删除一个子游戏 = 增删 `games/<key>/` 一个目录；大厅代码零改动；目录自带 `game_meta.tres` + `entry.tscn` + `scripts/` + `assets/` |
| 沙盒隔离 | 子游戏内不出现 `Global.Online*` / `Global.DataMgr` / `Global.SceneMgr` / `Global.WindowPopup`，只通过 `GameBridge`；不引用其他子游戏文件 |
| 工程质量 | `--headless --editor --quit` 零脚本错误；`check_refs.ps1` 零新增悬空；`validate_plugins.gd` 零违规；`validate_scripts` / `validate_game_framework` 通过 |

---

## 1. 现状盘点（基线问题）

| # | 问题 | 证据 | 影响 |
| --- | --- | --- | --- |
| 1 | 目录按文件类型/历史命名切分，不按功能 | `scripts/1common/`、`scripts/game/`、`scenes/1common/`、`autoload/` | 找一个页面要跨 3 个目录 |
| 2 | `1common` 命名黑客 + 脚本与场景分离 | `scripts/1common/setting.gd` ↔ `scenes/1common/setting.tscn` | 改名/迁移成本高 |
| 3 | 子游戏不自包含 | 脚本在 `scripts/game/<k>/`、场景在 `scenes/game/<k>/`、资源在 `assets/game/<k>/`、主题在 `themes/game/<k>/` | 无法整目录打包 `.pck` |
| 4 | 子游戏清单硬编码在大厅 | `scripts/game/core/game_catalog.gd` 的 `BUILTIN` 数组 | 新增游戏必须改框架代码 |
| 5 | 子游戏直接操作网络层 | 游戏脚本内 `Global.OnlineMatch` 57 处、`Global.OnlineGame` 37 处、`Global.Online` 30 处 | 无法沙盒化、无法独立打包 |
| 6 | 子游戏污染全局命名空间 | `class_name Shared`（俄罗斯方块私有数据）被注册为 `Global.Shared` | 全局服务表被游戏占用 |
| 7 | 下载游戏解压到 `res://` | `loading_screen.gd` 的 `GAME_SCENE_ROOT := "res://scenes/game/"` | 导出包 `res://` 只读，线上必坏 |

---

## 2. 目标拓扑

```text
res://
├── core/                        平台底层（框架生命周期、网络网关、场景调度、插件契约）
│   ├── bootstrap/               Global / Util / Errors / global_config.cfg（autoload 入口）
│   ├── network/                 Online*.gd + MessageQueue（Nakama 连接、协议分发）
│   ├── scene/                   SceneMgr / 路由表 / 转场 / 叠加页
│   ├── services/                SignalMgr / SettingsMgr / DataMgr / MailMgr
│   ├── window/                  无边框拖动、消息框
│   └── framework/               插件契约：GameMeta / GamePlugin(GameBase*) / GameRegistry /
│                                GameLauncher / GameBridge / GameContext / GameResult / GameInstaller
├── shared/                      跨模块共享（无业务语义）
│   ├── ui/                      通用 UI：设置、排行榜、加载、弹窗、列表、返回按钮、倒计时…
│   │   ├── controls/            轻量控件行为（抖动、变色、可复制文本…）
│   │   ├── loading/             加载页与进度控件
│   │   ├── popup/               通用弹窗
│   │   └── gridanimation/       网格动画
│   ├── utils/                   无状态工具（static / class_name）
│   └── styles/                  全局主题、样式、字体、Shader
├── lobby/                       大厅与社交（按业务分包，脚本与场景同目录）
│   ├── home/                    主页
│   ├── chat/                    频道聊天、好友
│   ├── club/                    俱乐部（列表 + 详情 + 成员）
│   ├── room/                    房间列表、创建/等待房间
│   ├── match/                   匹配中、匹配成功
│   ├── gamelist/                游戏列表、卡片
│   ├── email/                   邮件
│   ├── approval/                审批
│   └── announcement/            公告
├── app/                         应用外壳页（不属于大厅）
│   ├── login/  register/
├── games/                       ★ 完全隔离的插件目录
│   ├── chinesechess/
│   │   ├── game_meta.tres       自描述元数据（GameMeta）
│   │   ├── entry.tscn           唯一入口场景
│   │   ├── scripts/             游戏私有逻辑
│   │   ├── scenes/              游戏内部子场景
│   │   └── assets/              私有贴图/音频/主题
│   ├── tetris/  mahjong_matching/  fishgame/
│   └── template/                复制用模板
├── assets/                      共享美术/音频（保持集中，避免与插件私有资源混淆）
├── addons/ gdprotobuf/ docs/ tools/    第三方/生成代码/文档/校验工具（默认不改）
```

> 与 `.cursorrules` 的差异（有意为之，均在本文登记）：
> 1. `games/chess` → `games/chinesechess`、`games/fishing` → `games/fishgame`：目录名必须与服务端 `en_name` 一致，否则联机匹配对不上；
> 2. 增加 `core/bootstrap|services|window`、`app/`：`.cursorrules` 的四分法没有给 autoload 与服务层定位，按「平台底层」语义归入 `core/`；
> 3. `shared/utils` 只放无状态工具（当前项目绝大多数 UI 逻辑放 `shared/ui`），不为了凑目录强行搬迁。

---

## 3. 插件契约（P4/P5 落地内容）

### 3.1 `GameMeta`（每个游戏自描述）

`games/<key>/game_meta.tres`，资源类型 `GameMeta extends Resource`：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `key` | String | 与服务端 `en_name` 一致，小写 |
| `title` | String | 展示名 |
| `entry_scene` | String | 入口场景路径，约定 `res://games/<key>/entry.tscn` |
| `max_players` | int | 最大人数（本地兜底） |
| `online` | bool | 是否需要 Nakama 对局 |
| `show_back_button` | bool | 是否自动挂统一返回按钮 |
| `order` | int | 列表排序 |
| `aliases` | PackedStringArray | 兼容旧 key / 服务端别名 |
| `tags` | PackedStringArray | 分类标签 |
| `version` | String | 插件版本（对外包用） |
| `min_client` | String | 最低客户端版本 |
| `description` | String | 一句话简介 |

### 3.2 `GameRegistry` 发现规则

按优先级扫描，先到先得、内置不可被外部覆盖同 key：

1. `res://games/*/game_meta.tres`（内置插件）
2. `user://games/*/game_meta.tres`（下载/热更插件）
3. 已加载 `.pck` 内的 `game_meta.tres`（`GameInstaller.install_pack()`）
4. 兼容兜底：`user://games/<key>/entry.tscn` 存在但无 meta 时，按目录名注册

### 3.3 生命周期（`GamePlugin` 契约）

```text
GameRegistry 发现 --> GameLauncher.start_game(key, options)
  ├─ 创建 GameBridge(context)              # 唯一对外通道
  ├─ 实例化 entry.tscn
  ├─ on_game_context(context, bridge)      # 注入，等价旧 on_game_context
  ├─ SceneMgr 切换场景
  ├─ 挂 __GameHUD（可选）
  ├─ on_game_launched(context)
  └─ 联机时通知 LOADING_MAP_FINISH
退出：exit_game(result?) -> on_game_result -> on_game_exit -> game_finished -> LeaveMatch -> go_back
重开：restart_game() -> 保留 match/room 上下文重新实例化
结算：finish_game(result)
```

### 3.4 `GameBridge` 窄接口（子游戏唯一允许的框架入口）

| 分类 | API |
| --- | --- |
| 上下文 | `context`、`key`、`is_online()`、`option(name, default)` |
| 对局 | `send_state(op, payload)`、`state_received` 信号、`finish(result)`、`exit(result?)`、`restart()` |
| UI | `toast(text)`、`confirm(text, on_ok)` |
| 存档 | `save(namespace, data)`、`load(namespace, default)`（按 key 隔离） |
| 生命周期 | `launched` / `finished` / `exiting` 信号 |

**沙盒规则（`tools/validate_plugins.gd` 静态扫描）**：

1. `games/**/*.gd` 不得出现 `Global.Online`、`Global.OnlineMatch`、`Global.OnlineGame`、`Global.OnlineLogin`、`Global.DataMgr`、`Global.MailMgr`、`Global.SceneMgr`、`Global.WindowPopup`、`Global.Shared`；
2. `games/**` 不得引用 `res://games/<other>/`、`res://lobby/`、`res://core/network/`；
3. `games/<key>/` 必含 `game_meta.tres` + `entry.tscn`，且 `entry_scene` 路径存在；
4. `game_meta.key` == 目录名；`key` 全局唯一；
5. 每个游戏的 `.gd` 必须 `extends GamePlugin2D|GamePluginControl`（或显式声明 `plugin_sandbox = false` 并说明原因）。

---

## 4. 阶段计划

每个阶段的固定动作：**迁移 → 重写引用 → 引用完整性检查 → Godot 导入检查 → 校验脚本 → 记录**。

### P0 护栏（已完成）

- 新建安全分支 `refactor/plugin-arch`；
- `tools/refactor/apply_moves.ps1`：按映射表移动文件（含 `.uid` / `.import` 伴随文件），支持 exclude / 断点续跑 / 冲突预检 / journal；
- `tools/refactor/rewrite_refs.gd`：GDScript 重写 `res://` 引用（UTF-8 安全、最长前缀优先、支持 exclude、跳过 addons/gdprotobuf）；
- `tools/validate_refs.gd`：全仓库引用完整性检查（基线比对，只报新增悬空）；
- `tools/validate_scenes.gd`：逐个 ResourceLoader.load 全部 `.tscn`，暴露断掉的 ext_resource；
- 基线：`--editor --quit` 无脚本错误；`refs_baseline.json` 记录 8 处历史悬空。

**门禁**：`check_refs.ps1` 无新增悬空。

### P1 shared/（进行中）

- `scripts/1common/**` → `shared/ui/**`（含 `controls/ loading/ popup/` 子目录）；
- `scenes/1common/**` → `shared/ui/**`（脚本与场景同目录）；
- `scenes/1common/gridanimation/` → `shared/ui/gridanimation/`（含内嵌脚本）；
- `styles/*.tres` → `shared/styles/styles/`；`themes/*.tres` → `shared/styles/themes/`；`shaders/*` → `shared/styles/shaders/`；`assets/font/**` → `shared/styles/fonts/`；
- 更新 `project.godot` 的 `gui/theme/custom_font`、`[shader_library]` 路径。

**门禁**：`check_refs` 0 新增 + Godot 导入无错误。

### P2 core/

- `autoload/global/**` → `core/bootstrap/**`（更新 `project.godot` autoload 4 条路径）；
- `autoload/managers/scene_*` → `core/scene/`；`signal/settings/data/mail_manager` → `core/services/`；
- `autoload/nakama/**` → `core/network/**`；
- `autoload/window/**` → `core/window/**`；
- 更新 `global_config.cfg` 全部服务路径。

**门禁**：同上 + `tools/validate_scripts.gd`。

### P3 lobby/ + app/

- `scripts/chat` + `scenes/chat` → `lobby/chat/`；`find_friend.*` 一并归入；
- `scripts/club` + `scenes/club` + `scripts/clublist` + `scenes/clublist` → `lobby/club/`；
- `scripts/roomlist` + `scenes/roomlist` → `lobby/room/`；
- `scripts/match` + `scenes/match` → `lobby/match/`；
- `scripts/gamelist` + `scenes/gamelist` → `lobby/gamelist/`；
- `scripts/email` + `scenes/email` → `lobby/email/`；
- `scripts/approval` + `scenes/approval` → `lobby/approval/`；
- `scripts/announcements` + `scenes/1common/announcements` → `lobby/announcement/`；
- `scripts/home.gd` + `scenes/home.tscn` → `lobby/home/`；
- `scripts/login.gd` `register.gd` + 对应场景 → `app/login/`、`app/register/`；
- 重写 `scene_registry.gd` 路由表。

**门禁**：同上 + 路由表自检（`SceneRegistry` 每条路径存在）。

### P4 games/ 自包含

- `scripts/game/core/**` → `core/framework/**`；
- `scripts/game/<key>/**` → `games/<key>/scripts/**`；
- 主场景 → `games/<key>/entry.tscn`，其余子场景 → `games/<key>/scenes/**`；
- `assets/game/<key>/**` → `games/<key>/assets/**`；`themes/game/<key>/**` → `games/<key>/assets/themes/**`；
- 为每个游戏生成 `game_meta.tres`（内容取自现 `game_catalog.gd`）；
- 删除 `game_catalog.gd`，`GameRegistry` 改为 meta 扫描；
- `loading_screen` 的下载安装抽成 `GameInstaller`，落盘目录改 `user://games/<key>/`；
- `scripts/game/template/` → `games/template/`。

**门禁**：`validate_game_framework.gd`（改写为插件版）+ 每个 `entry.tscn` headless 实例化冒烟。

### P5 契约与沙盒

- `GameBridge` 落地，`GamePlugin2D/Control` 基类暴露 bridge 方法；
- 迁移子游戏内的 `Global.*` 调用到 bridge；
- 移除 `Global.Shared`（俄罗斯方块常量改为游戏内 `TetrisShared`，不经全局服务）；
- `tools/validate_plugins.gd` 上线，违规数必须为 0；
- API 兼容层：旧 `on_game_context(Context)` 保留一个版本，避免一次性打断。

**门禁**：`validate_plugins` 0 违规 + 四个游戏冒烟通过。

### P6 验证与文档

- 全量：`--editor --quit`、`validate_scripts`、`validate_game_framework`、`validate_plugins`、`test_foundation`、`test_async_call`、`check_refs`；
- 重写 `docs/ARCHITECTURE.md`、`docs/GAME_DEVELOPMENT.md`，新增 `docs/CHANGELOG_PLUGIN.md`；
- 更新 `.cursorrules` 末尾拓扑为最终实际结构。

---

## 5. 工具与命令

```powershell
# 1. 移动文件（按映射表，含 .uid/.import 伴随文件）
powershell -File tools/refactor/apply_moves.ps1 -Map tools/refactor/maps/p1_shared.json

# 2. 重写引用（GDScript，UTF-8 安全）
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --script res://tools/refactor/rewrite_refs.gd -- --map=res://tools/refactor/maps/p1_shared.json

# 3. 引用完整性 + 场景可加载性
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --script res://tools/validate_refs.gd
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --script res://tools/validate_scenes.gd

# 4. Godot 导入/解析检查
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --editor --quit

# 5. 业务脚本加载
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --script res://tools/validate_scripts.gd

# 6. 插件契约（P5 上线）
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --script res://tools/validate_plugins.gd
```

---

## 6. 风险登记

| 风险 | 等级 | 缓解 |
| --- | --- | --- |
| `.gd.uid` / `.import` 未随文件移动 → 场景按 `uid://` 引用失效 | 高 | 迁移脚本强制移动伴随文件；导入后检查 `Failed to load`/`uid` 警告 |
| `.import` 的 `dest_files` 指向旧缓存路径 | 中 | 迁移后让 Godot 重新导入；`.import` 保留 `uid` 字段，引用不丢 |
| 路径重写误伤前缀（`res://scripts/chat` 命中 `chat_system.gd`） | 高 | 解析器按 `key` 或 `key/` 精确匹配，不做朴素字符串替换 |
| 文本重写破坏 UTF-8 中文 | 高 | 重写统一用 `rewrite_refs.gd`（GDScript 原生 UTF-8），PowerShell 只负责移动 |
| 迁移跨阶段中断，项目处于半新半旧 | 中 | 每阶段独立映射文件；映射工具支持断点续跑；git 可回滚 |
| Autoload 路径改动导致启动失败 | 高 | `project.godot` 与 `global_config.cfg` 同步改，改完立刻 `--editor --quit` + 启动冒烟 |
| 子游戏内部玩法回归 | 中 | 只做结构性迁移与契约适配，不改玩法；每个游戏实例化冒烟 |
| 下载游戏从 `res://` 改 `user://` 后旧缓存失效 | 低 | 保留旧路径兜底一个版本，文档注明需要重新下载 |

---

## 7. 进度记录

| 阶段 | 状态 | 门禁结果 | 备注 |
| --- | --- | --- | --- |
| P0 护栏 | ✅ 完成 | 基线 8 处历史悬空已登记 | 工具链：apply_moves / rewrite_refs / check_refs |
| P1 shared/ | ✅ 完成 | 导入 0 错误；场景 108/108；脚本 174/174；引用 0 新增悬空 | 112 文件迁移；1common 消失；字体/主题/Shader 入 shared/styles |
| P2 core/ | ⏳ 待开始 | — | — |
| P3 lobby/ + app/ | ⏳ 待开始 | — | — |
| P4 games/ | ⏳ 待开始 | — | — |
| P5 契约与沙盒 | ⏳ 待开始 | — | — |
| P6 验证与文档 | ⏳ 待开始 | — | — |
