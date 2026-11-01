# 本轮重构变更说明

> 范围：核心框架 + 主要流程（autoload、登录/注册/主页、聊天、房间/匹配、俱乐部/邮件、游戏列表、通用 UI）。
> 未改动：`addons/`、`gdprotobuf/`、`.tscn`、`project.godot` 的场景结构。

## 1. 结构性调整

- 新增 `docs/ARCHITECTURE.md`：分层、服务职责、主要流程、异步规范。
- `Global` 服务注册表：
  - 内置 `DEFAULT_SERVICES`，配置文件缺失时也能启动；
  - 首次访问时兜底加载注册表，兼容场景脚本早于 `Global._ready()` 的情况；
  - 删除硬编码加密 key、`user://` 加密配置、未使用的 `add_module_config/save_config/load_config`。
- 删除未使用模块：`autoload/managers/network_manager.gd`、`autoload/managers/thread_manager.gd`。
- `MessageQueue` 改为 `Util` 内部服务（不再在 `Global` 重复注册）。
- 统一文件头“模块 / 职责 / 依赖 / 对外接口”注释；关键方法补中文说明。

## 2. 关键 Bug 修复

### 基础层

| 问题 | 影响 | 处理 |
| --- | --- | --- |
| `Util.Asyn_Call` 用 `await task.completed` 等待异步结果 | Godot 4.7 下所有 Nakama 请求都会运行时报错 | 改为 `var result = await caller.callv(...)` |
| `loading_percent` 信号参数数量与实际 `emit()` 不一致 | 登录进度可能报错 | 统一为单参数，并移除信号自连接造成的递归风险 |
| `OnlineMatch` / `OnlineLogin` 使用只读属性赋值 | 赋值 `my_session_id` / `matchmaker_ticket` / `player_data` 会报错 | 改为普通 `var` + `get_xxx()` |
| `Errors.ResponeMapping[...]` 直接下标 | 未知错误时崩溃 | 新增 `Errors.humanize()` / `is_network_error()` |
| `OnlineMatch.getMatchList()` 调用不存在的 `RpcListData` | 匹配列表必然失败 | 在 `OnlineGame` 补 `RpcListData()` |
| `SceneMgr` 中 `loading` / `matchSuccess` 路径错误 | 对应场景切换失败 | 修正为实际 `.tscn` 路径，并在切换前检查文件存在 |
| `Online` 心跳在断开后不停止 | 空转、日志噪音 | socket 断开时 `stop_heartbeat()` |
| 主动重连时旧 socket 的 closed 回调提示“断线” | 误报 | 重连前标记 `is_socket_reset` |
| `DataManager.parse_message()` 以字符串偏移解析 | 字段缺失时误判、转义字符损坏、旧存档键错位 | 按固定字段顺序解析 + 新数据直接存字典 |
| `remove_chat_history` / `update_chat_history` 逻辑错误 | 删除/撤回后本地记录不更新 | 修复过滤与替换逻辑 |
| `MessageQueue` 非网络错误也无限重试 | 业务失败会死循环 | 仅网络错误重入队列，其他错误放弃并回调 |
| `WindowPopup.show_confirm` 重复关闭 | 可能二次 `queue_free` | 由弹窗自身关闭，回调只执行一次 |
| `message_popup` 强制 `auto_close=true` | `show_message(..., false)` 无法手动关闭 | 尊重调用方参数 |

### 聊天

- 消息控件复用索引越界、替换时节点泄漏。
- 时间分割线条件恒真，`last_shown_date` 未生效。
- `message_id_cache` 把布尔写进 `"message_id"` 键，去重永远失效。
- 跨频道消息刷进当前标签页。
- 滚动到底部公式错误。
- 撤回失败后内容永久停在“正在撤销”。
- 删除消息只删服务端、不删本地。
- 文件消息渲染端取 `"name"`、发送端写 `"file"` 的字段不一致。
- 头像异步返回时控件已复用导致串图（加请求令牌）。
- 好友在线状态 `joins/leaves` 互斥处理、遍历中 `move_item` 跳过条目。

### 房间 / 匹配

- 收藏 id 用 `Array.find(Callable)` 永远返回 -1，导致重复。
- `room_id` 在两种数据源中类型不一致，`substr()` 崩溃。
- `join_table` 成功后未校验 `joinMatch` 的异常，失败被当成功。
- 等待房间玩家节点只 `remove_child` 不释放。
- 重复 presence/match_state 事件重复添加玩家。
- 准备人数把“拒绝准备”也计入，可能误开局。
- `matching.maxplayer` 被永久改写，影响下一局。
- 房间列表窄窗口下 `columns=0` 导致分页除零。
- 创建房间弹窗隐藏时仍抢占 Enter/Esc。

### 俱乐部 / 邮件 / 通用 UI / 游戏列表

- 俱乐部详情清理动态节点时误删场景内 `InfoSection`，点成员必报错。
- 俱乐部页签全局信号未按游戏过滤，A 页签操作会影响 B 页签。
- 俱乐部成员列表搜索被服务端刷新覆盖；成员项每次重建菜单/重复连接信号；本人头像不加载。
- 群组成员列表 `queue_free` 同帧重复项；加好友/升降级/拉黑误用不存在的 client 方法。
- 创建俱乐部把本地 `Image` 当 `avatar_url` 传给服务端；现在头像选择仅本地预览。
- 审批列表 `get_all_requests()` 读的是节点 `name` 而不是申请数据；审批失败时仍会改状态。
- 好友列表右键菜单不可用、按文本匹配菜单项、调用不存在的 `refuse_friends_async/remove_group/remove_friend`；改为 action id + `OnlineChat`。
- 邮件领取广播早于 `setup()` 时访问空字典。
- 加载界面 `clamp(-5, value, 100)` 参数顺序错误，失败回退分支不可达。
- 加载完成可能重复切场景/重复实例化游戏场景。
- 游戏列表刷新重复创建卡片；`sendDataRPC` 失败回调 `_on_err` 缺失。
- 设置面板“邮件”按钮对 `PackedScene` 取 `.visible`。
- 静音后取消静音，BGM 不再播放。
- 排行榜 `queue_free` 清行导致同帧重复行。
- 确认框 `set_params` 节点路径错误，自定义按钮文案不生效。
- 公告栏重建时 `queue_free` 同帧重复；打字机模式下一条文本不显示。
- 俱乐部成员管理/审批/公告页面补齐模块头、类型标注与空值保护。

## 3. 验证

- `tools/validate_scripts.gd`：批量 `load()` 全部业务脚本，确认无解析/编译错误。
- `tools/test_async_call.gd`：验证 `Util.Asyn_Call` 的成功、业务异常、网络异常与重试入队。
- `tools/test_foundation.gd`：验证错误中文化、时间格式、旧消息解析、`OnlineMatch` 属性可写、场景注册表。
- `godot --headless --path . --quit-after 180`：主场景启动冒烟。
- `godot --headless --path . res://lobby/home/home.tscn --quit-after 120`：主页/聊天初始化冒烟。
- `godot --headless --path . res://lobby/chat/chat.tscn --quit-after 120`：聊天场景初始化冒烟。
- 俱乐部列表/成员列表/成员项/创建/加入/资料弹窗、查找好友、审批、公告场景逐个 headless 实例化冒烟。

> 说明：本机沙箱不允许写 `user://`，启动时会打印“存档写入失败”，这是环境限制，不是代码回归。
> 网络链路（登录、聊天、房间、匹配）仍需连接真实 Nakama 服务端做端到端验证。
