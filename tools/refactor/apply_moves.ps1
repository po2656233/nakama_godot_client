# Migration tool (step 1): move files according to a mapping table only.
# Reference rewriting is done by tools/refactor/rewrite_refs.gd (GDScript, UTF-8 safe).
#
# Usage:
#   powershell -File tools/refactor/apply_moves.ps1 -Map tools/refactor/maps/p1_shared.json
#   powershell -File tools/refactor/apply_moves.ps1 -Map ... -DryRun
#
# Map format:
#   { "name": "...", "moves": [ { "from": "a/b", "to": "c/d", "exclude": ["x"] } ] }
#
# Behavior:
#   1. Directory entries move all files recursively (including .uid / .import companions);
#   2. File entries also move <file>.uid / <file>.import;
#   3. Conflict pre-check aborts before touching anything;
#   4. Resume-friendly: source missing + destination present => already done, skipped;
#   5. Writes a journal for manual rollback (git is the recommended rollback).
# Windows PowerShell 5.1 compatible. ASCII-only output to avoid console encoding issues.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Map,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = ((& git rev-parse --show-toplevel 2>&1 | Out-String).Trim()).Replace('\', '/')
Set-Location -LiteralPath $repoRoot

function Get-RelPath([string]$full) {
    $b = $repoRoot.TrimEnd('/')
    $f = $full.Replace('\', '/')
    if ($f.StartsWith($b, [StringComparison]::OrdinalIgnoreCase)) {
        return $f.Substring($b.Length).TrimStart('/')
    }
    return $f
}

function Get-FilesUnder([string]$relPath) {
    $abs = Join-Path $repoRoot $relPath
    if (-not (Test-Path -LiteralPath $abs)) { return @() }
    if (Test-Path -LiteralPath $abs -PathType Container) {
        return @(Get-ChildItem -LiteralPath $abs -Recurse -File -Force | ForEach-Object { Get-RelPath $_.FullName })
    }
    return @($relPath.Replace('\', '/'))
}

$mapFull = Join-Path $repoRoot $Map
if (-not (Test-Path -LiteralPath $mapFull)) { throw "map not found: $mapFull" }
$data = Get-Content -Raw -LiteralPath $mapFull -Encoding UTF8 | ConvertFrom-Json
$name = if ($data.name) { $data.name } else { [IO.Path]::GetFileNameWithoutExtension($Map) }

Write-Host "==> [$name] repo: $repoRoot"

$filePairs = New-Object System.Collections.Generic.List[object]
$dirPairs = New-Object System.Collections.Generic.List[object]

foreach ($m in @($data.moves)) {
    $from = $m.from.Replace('\', '/').Trim('/')
    $to = $m.to.Replace('\', '/').Trim('/')
    $fromAbs = Join-Path $repoRoot $from

    if (-not (Test-Path -LiteralPath $fromAbs)) {
        Write-Warning "source missing, skip: $from"
        continue
    }

    if (Test-Path -LiteralPath $fromAbs -PathType Container) {
        $dirPairs.Add([pscustomobject]@{ from = $from; to = $to })
        $files = @(Get-FilesUnder $from)
        if ($files.Count -eq 0) { Write-Warning "empty dir, skip: $from"; continue }
        $excludes = @()
        if ($m.exclude) { $excludes = @($m.exclude | ForEach-Object { ([string]$_).Trim('/') }) }
        $added = 0
        foreach ($f in $files) {
            $rel = $f.Substring($from.Length).TrimStart('/')
            $relBase = $rel -replace '\.(uid|import)$', ''
            $skip = $false
            foreach ($ex in $excludes) {
                if ($rel -eq $ex -or $relBase -eq $ex -or
                    $rel.StartsWith("$ex/") -or $relBase.StartsWith("$ex/")) { $skip = $true; break }
            }
            if ($skip) { continue }
            $dest = if ($rel) { "$to/$rel" } else { $to }
            $filePairs.Add([pscustomobject]@{ from = $f; to = $dest })
            $added++
        }
        if ($added -eq 0) { Write-Warning "all excluded, skip: $from" }
    } else {
        $filePairs.Add([pscustomobject]@{ from = $from; to = $to })
        foreach ($suffix in @('.uid', '.import')) {
            $cFrom = "$from$suffix"
            if (Test-Path -LiteralPath (Join-Path $repoRoot $cFrom)) {
                $filePairs.Add([pscustomobject]@{ from = $cFrom; to = "$to$suffix" })
            }
        }
    }
}

if ($filePairs.Count -eq 0) { throw 'no file to move' }

$dupDest = $filePairs | Group-Object to | Where-Object { $_.Count -gt 1 }
if ($dupDest) { throw ("duplicate destination: " + (@($dupDest | ForEach-Object { $_.Name }) -join ', ')) }
$dupSrc = $filePairs | Group-Object from | Where-Object { $_.Count -gt 1 }
if ($dupSrc) { throw ("duplicate source: " + (@($dupSrc | ForEach-Object { $_.Name } | Select-Object -First 10) -join ', ')) }

$todo = @()
$already = 0
$conflicts = @()
foreach ($p in $filePairs) {
    if ($p.from -eq $p.to) { continue }
    $srcExists = Test-Path -LiteralPath (Join-Path $repoRoot $p.from)
    $dstExists = Test-Path -LiteralPath (Join-Path $repoRoot $p.to)
    if (-not $srcExists -and $dstExists) { $already++; continue }
    if ($dstExists) { $conflicts += $p.to; continue }
    $todo += $p
}
if ($conflicts.Count -gt 0) {
    throw ("destination exists ({0}), aborted: {1}" -f $conflicts.Count, ((@($conflicts | Select-Object -First 10)) -join ', '))
}

Write-Host ("==> moving {0} files ({1} dir entries, {2} already done)" -f $todo.Count, $dirPairs.Count, $already)
if ($DryRun) {
    $todo | Select-Object -First 30 | ForEach-Object { Write-Host ("  {0} -> {1}" -f $_.from, $_.to) }
    Write-Host '==> dry run, nothing changed'
    return
}

$moved = 0
foreach ($p in $todo) {
    $srcAbs = Join-Path $repoRoot $p.from
    $dstAbs = Join-Path $repoRoot $p.to
    $dstDir = Split-Path -Parent $dstAbs
    if (-not (Test-Path -LiteralPath $dstDir)) {
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    }
    $trackedOut = (& git ls-files -- $p.from 2>&1 | Out-String).Trim()
    if ($trackedOut.Length -gt 0) {
        $mvOut = (& git mv --force -- $p.from $p.to 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw "git mv failed: $($p.from) -> $($p.to) :: $mvOut" }
    } else {
        Move-Item -LiteralPath $srcAbs -Destination $dstAbs -Force
    }
    $moved++
}

Write-Host "==> moved $moved files"

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$journalDir = Join-Path $repoRoot 'tools/refactor/journal'
if (-not (Test-Path -LiteralPath $journalDir)) { New-Item -ItemType Directory -Force -Path $journalDir | Out-Null }
$journalPath = Join-Path $journalDir ("{0}-{1}.json" -f $name, $stamp)
$entries = @()
foreach ($d in $dirPairs) { $entries += [pscustomobject]@{ from = $d.from; to = $d.to } }
foreach ($p in $filePairs) { $entries += [pscustomobject]@{ from = $p.from; to = $p.to } }
([pscustomobject]@{ name = $name; time = (Get-Date -Format o); entries = $entries }) |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $journalPath -Encoding utf8
Write-Host ('==> journal: ' + (Get-RelPath $journalPath))
Write-Host "==> next: godot --headless --path . --script res://tools/refactor/rewrite_refs.gd -- --map=$Map"
