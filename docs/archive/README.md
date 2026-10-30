# 归档：未接入的原型代码

这里保留的是早期尝试但**没有接入任何自动加载/场景**的代码。它们不是构建的一部分，
且存在解析错误或重复实现，保留目的只是避免思路丢失。

| 目录 | 内容 | 现状 |
| --- | --- | --- |
| `nakama_service/` | `NakamaCore / AuthService / ChatService / GameService / MatchService` 分层原型 | 未注册、存在解析错误 |
| `message_parser/` | 聊天消息字符串解析器 | 与 `DataMgr.parse_message()` 重复，未引用 |
| `network_wrapper/` | `Util.async_call` 的替代实现 | 未引用、存在语法错误 |
| `time_utils/` | 时间格式化工具 | 与 `Util.format_china_time()` 重复，未引用 |

归档文件统一使用 `.gd.txt` 扩展名，避免被 Godot 当成可编译脚本扫描。
如需恢复，改回 `.gd` 并按对应 README 修复后再注册到 `global_config.cfg`。

当前运行时的网络层仍以 `autoload/nakama/Online*.gd` 为准，时间/消息解析以
`autoload/global/util.gd` 与 `autoload/managers/data_manager.gd` 为准。
