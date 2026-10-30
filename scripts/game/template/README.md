# 子游戏模板

这个目录只放“复制用模板”，不会被 GameRegistry 当成可启动游戏。

新增一个子游戏的完整步骤见 [docs/GAME_DEVELOPMENT.md](../../../docs/GAME_DEVELOPMENT.md)。

最简流程：

1. 复制 `template_game.gd` 到 `scripts/game/<key>/<key>.gd` 并改名；
2. 创建 `scenes/game/<key>/<key>.tscn`，根节点挂上新脚本；
3. 在 `scripts/game/core/game_catalog.gd` 增加一条清单；
4. 启动：`Global.GameLauncher.start_game("<key>")`。

约定：

- `<key>` 与服务端游戏列表的 `en_name` 保持一致；
- 场景目录名与场景文件名一致（`scenes/game/space_run/space_run.tscn`），外部下载游戏才能被自动发现；
- 退出、重开、结算统一走 `exit_game()` / `restart_game()` / `finish_game()`，不要自己 `change_scene_to_file()`。
