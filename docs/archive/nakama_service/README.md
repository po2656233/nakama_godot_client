# 归档：未接入的 Nakama 服务原型

这里保留的是一版未完成的 `NakamaCore / AuthService / ChatService / GameService / MatchService`
分层原型，**没有被任何自动加载或场景引用**，且存在解析错误与乱码文本。
文件扩展名已改为 `.gd.txt`，不会被 Godot 编译。

当前运行时的网络层仍以 `autoload/nakama/Online*.gd` 为准（见 `docs/ARCHITECTURE.md`）。
如需重启这套分层方案，请先把文件改回 `.gd` 并移回 `scripts/`，修复 `auth_service.gd` 的字符串与
`game_service.gd` / `match_service.gd` 末尾的 `<EOF>` 残留，并在
`autoload/global/global_config.cfg` 注册对应服务后再接入调用方。
