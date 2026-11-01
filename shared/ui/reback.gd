extends Control

## 模块：通用返回按钮
## 职责：子游戏 HUD 与页面右上角共用的返回入口。
## 说明：子游戏内走 GameLauncher（会处理离开对局、结算回调）；普通页面走 SceneMgr。

var _busy := false

func _on_button_pressed() -> void:
	if _busy:
		return
	_busy = true

	if Global.has_global("GameLauncher") and Global.GameLauncher.is_game_running():
		if Global.has_global("SceneRouter"):
			await Global.SceneRouter.exit_game()
		else:
			await Global.GameLauncher.exit_game()
		return

	Global.SceneMgr.go_back()
