# Migration: move game scripts off Global.* services onto GameBridge / GameProtocol.
# Idempotent-ish: only applies replacements that are present. UTF-8 safe.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tools/refactor/migrate_sandbox.ps1 [-DryRun]

[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$repoRoot = ((& git rev-parse --show-toplevel 2>&1 | Out-String).Trim()).Replace('\', '/')
Set-Location -LiteralPath $repoRoot

# Order matters: most specific first.
$rules = @(
	@('await Global.Online.session_changed',    'await GameBridge.current.wait_session_changed()'),
	@('await Global.Online.session_connected',  'await GameBridge.current.wait_session_connected()'),
	@('await Global.Online.socket_connected',   'await GameBridge.current.wait_socket_connected()'),

	@('Global.OnlineMatch.MatchState.',    'GameProtocol.MatchState.'),
	@('Global.OnlineMatch.MatchMode.',     'GameProtocol.MatchMode.'),
	@('Global.OnlineMatch.PlayerStatus.',  'GameProtocol.PlayerStatus.'),
	@('Global.OnlineMatch.MatchOpCode.',   'GameProtocol.MatchOpCode.'),
	@('Global.OnlineGame.game_status.',    'GameProtocol.GameStatus.'),

	@('Global.OnlineMatch.connect(',       'GameBridge.current.connect_match_signal('),
	@('Global.OnlineMatch.create_match(Global.Online.nakama_socket)', 'GameBridge.current.create_match()'),
	@('Global.OnlineMatch.join_match(Global.Online.nakama_socket, ',  'GameBridge.current.join_match('),
	@('Global.OnlineMatch.joinMatchmaker(', 'GameBridge.current.join_matchmaker('),
	@('Global.OnlineMatch.start_matchmaking(', 'GameBridge.current.start_matchmaking('),
	@('Global.OnlineMatch.custom_rpc_sync(',    'GameBridge.current.custom_rpc_sync('),
	@('Global.OnlineMatch.custom_rpc_id_sync(', 'GameBridge.current.custom_rpc_id_sync('),
	@('Global.OnlineMatch.custom_rpc_id(',      'GameBridge.current.custom_rpc_id('),
	@('Global.OnlineMatch.custom_rpc(',         'GameBridge.current.custom_rpc('),

	@('Global.OnlineGame.sendToMatchRpc(',      'GameBridge.current.send_match_rpc('),
	@('Global.OnlineGame.sendToMatch(',         'GameBridge.current.send_match_state('),
	@('Global.OnlineGame.getGameMaxPeople(',    'GameBridge.current.get_game_max_people('),
	@('Global.OnlineGame.online_play',          'GameBridge.current.online_play'),

	@('Global.OnlineLogin.get_my_id()',         'GameBridge.current.get_my_id()'),

	@('Global.WindowPopup.show_dynamic(',  'GameBridge.current.toast('),
	@('Global.WindowPopup.show_message(',  'GameBridge.current.message('),
	@('Global.WindowPopup.show_confirm(',  'GameBridge.current.confirm('),
	@('Global.WindowPopup.',               'GameBridge.current.'),

	@('Global.SceneMgr.go_back(',          'GameBridge.current.exit('),
	@('Global.SceneMgr.switch_to_scene(',  'GameBridge.current.restart('),
	@('Global.SceneMgr.',                  'GameBridge.current.'),

	@('Global.GameLauncher.is_game_running(', 'GameBridge.current.is_running('),
	@('Global.GameLauncher.start_game(',      'GameBridge.current.restart('),
	@('Global.GameLauncher.restart_game(',    'GameBridge.current.restart('),
	@('Global.GameLauncher.exit_game(',       'GameBridge.current.exit('),
	@('Global.GameLauncher.finish_game(',     'GameBridge.current.finish('),
	@('Global.GameLauncher.',                 'GameBridge.current.'),

	@('Global.SettingsMgr.show_settings(', 'GameBridge.current.open_settings('),
	@('Global.SettingsMgr.',               'GameBridge.current.'),

	# 兜底：捕获剩余 Global.Online* / OnlineMatch 访问
	@('Global.OnlineMatch.', 'GameBridge.current.'),
	@('Global.OnlineGame.',  'GameBridge.current.'),
	@('Global.Online.',      'GameBridge.current.'),
	@('Global.OnlineLogin.', 'GameBridge.current.'),

	# 俄罗斯方块：私有常量表，不再走全局服务
	@('Global.Shared.Tetromino',                        'TetrisShared.Tetromino'),
	@('Global.Shared.cells',                            'TetrisShared.shared().cells'),
	@('Global.Shared.data',                             'TetrisShared.shared().data'),
	@('Global.Shared.wall_kicks_i',                     'TetrisShared.shared().wall_kicks_i'),
	@('Global.Shared.wall_kicks_jlostz',                'TetrisShared.shared().wall_kicks_jlostz'),
	@('Global.Shared.clockwise_rotation_matrix',        'TetrisShared.shared().clockwise_rotation_matrix'),
	@('Global.Shared.counter_clockwise_rotation_matrix','TetrisShared.shared().counter_clockwise_rotation_matrix'),
	@('Shared.Tetromino',                               'TetrisShared.Tetromino')
)

$changedFiles = 0
$changedHits = 0
$files = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'games') -Recurse -File -Filter *.gd

foreach ($file in $files) {
	$text = Get-Content -Raw -LiteralPath $file.FullName -Encoding UTF8
	if ($null -eq $text) { continue }
	$original = $text
	foreach ($rule in $rules) {
		$from = $rule[0]
		$to = $rule[1]
		if (-not $text.Contains($from)) { continue }
		$hits = ([regex]::Matches($text, [regex]::Escape($from))).Count
		$text = $text.Replace($from, $to)
		$changedHits += $hits
	}
	if ($text -ne $original) {
		$changedFiles++
		$rel = $file.FullName.Replace($repoRoot.Replace('/', '\') + '\', '')
		Write-Host ("  MIGRATE {0}" -f $rel)
		if (-not $DryRun) {
			[IO.File]::WriteAllText($file.FullName, $text, (New-Object Text.UTF8Encoding($false)))
		}
	}
}

$suffix = if ($DryRun) { " (dry-run)" } else { "" }`nWrite-Host ("==> {0} files, {1} replacements{2}" -f $changedFiles, $changedHits, $suffix)
