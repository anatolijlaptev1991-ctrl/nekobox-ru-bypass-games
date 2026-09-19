<#
.SYNOPSIS
    Installs the "RU-bypass + Games" routing profile into a NekoRay/NekoBox
    installation, finding it automatically.
.DESCRIPTION
    Search order:
      1. Running nekobox.exe process
      2. .lnk shortcuts on Desktop(s)/Start Menu pointing at nekobox.exe
      3. Well-known folders
      4. Shallow recursive scan of fixed drives
    If not found: asks the user for the folder/path and validates it.
    Then: backs up existing route set, installs the profile, and (if NekoBox
    is NOT running) sets it active in config\groups\nekobox.json.
.NOTES
    Run with: powershell -ExecutionPolicy Bypass -File .\install-routes.ps1
    No admin rights required (config lives in the user profile folder).
#>

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ProfileName = 'RU-bypass + Games'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$profileFile = Join-Path $scriptDir $ProfileName

function Write-Step($m) { Write-Host ("==> " + $m) -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host ("  OK " + $m) -ForegroundColor Green }
function Write-Warn2($m){ Write-Host ("  !! " + $m) -ForegroundColor Yellow }

# ---------- 0. sanity: profile file next to the script ----------
if (-not (Test-Path -LiteralPath $profileFile)) {
    Write-Host "FATAL: '$ProfileName' not found next to this script ($scriptDir)." -ForegroundColor Red
    exit 1
}
try {
    $null = Get-Content -LiteralPath $profileFile -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Host "FATAL: '$ProfileName' is not valid JSON." -ForegroundColor Red
    exit 1
}

# ---------- 1. auto-detect ----------
Write-Step "Searching for NekoBox installation..."

$candidates = New-Object System.Collections.Generic.List[string]

# 1a. running process
$p = Get-Process nekobox -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
if ($p) { $candidates.Add((Split-Path -Parent $p.Path)) ; Write-Ok ("found via running process: " + (Split-Path -Parent $p.Path)) }

# 1b. shortcuts (.lnk) on Desktops + Start Menu -> target = nekobox.exe
$sh = New-Object -ComObject WScript.Shell
$lnkDirs = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'),
    [Environment]::GetFolderPath('StartMenu'),
    [Environment]::GetFolderPath('CommonStartMenu'),
    (Join-Path $env:APPDATA  'Microsoft\Windows\Start Menu\Programs'),
    (Join-Path $env:PROGRAMDATA 'Microsoft\Windows\Start Menu\Programs')
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

foreach ($d in $lnkDirs) {
    Get-ChildItem $d -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $t = $sh.CreateShortcut($_.FullName).TargetPath
            if ($t -and ((Split-Path -Leaf $t) -match '^(nekobox|nekoray)\.exe$')) {
                $candidates.Add((Split-Path -Parent $t))
                Write-Ok ("found via shortcut " + $_.Name + " -> " + (Split-Path -Parent $t))
            }
        } catch { }
    }
}

# 1c. well-known folders
$wellKnown = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) '01_Программы\SOFT\nekoray'),
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'SOFT\nekoray'),
    "$env:PROGRAMFILES\nekoray",
    "${env:PROGRAMFILES(X86)}\nekoray",
    "$env:LOCALAPPDATA\nekoray",
    "$env:LOCALAPPDATA\Programs\nekoray",
    'D:\nekoray', 'D:\SOFT\nekoray', 'C:\nekoray'
) | Where-Object { $_ }
foreach ($d in $wellKnown) {
    if (Test-Path -LiteralPath (Join-Path $d 'nekobox.exe')) {
        $candidates.Add($d)
        Write-Ok ("found in well-known path: " + $d)
    }
}

# 1d. shallow scan of fixed drives (depth-limited, only if still empty)
if ($candidates.Count -eq 0) {
    Write-Step "Not found yet - scanning drives (this may take a minute)..."
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null }
    foreach ($drv in $drives) {
        $root = $drv.Root
        Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $lvl1 = $_.FullName
            if (Test-Path -LiteralPath (Join-Path $lvl1 'nekobox.exe')) { $candidates.Add($lvl1); return }
            Get-ChildItem $lvl1 -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $lvl2 = $_.FullName
                if (Test-Path -LiteralPath (Join-Path $lvl2 'nekobox.exe')) { $candidates.Add($lvl2) }
            }
        }
    }
    if ($candidates.Count -gt 0) { Write-Ok ("drive scan found: " + ($candidates -join ', ')) }
}

# dedupe
$candidates = $candidates | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'nekobox.exe') } | Select-Object -Unique

# ---------- 2. pick / ask ----------
$target = $null
if ($candidates.Count -eq 1) {
    $target = $candidates[0]
} elseif ($candidates.Count -gt 1) {
    Write-Host "Multiple NekoBox installations found:" -ForegroundColor Yellow
    for ($i=0; $i -lt $candidates.Count; $i++) { Write-Host ("  [" + ($i+1) + "] " + $candidates[$i]) }
    $sel = Read-Host "Which one? (number, default 1)"
    if (-not $sel) { $sel = '1' }
    $target = $candidates[[int]$sel - 1]
} else {
    Write-Warn2 "Could not find NekoBox automatically."
}

while (-not $target) {
    $inp = Read-Host "Enter the FULL path to nekobox.exe or its folder (empty = exit)"
    if (-not $inp) { Write-Host "Cancelled."; exit 1 }
    $inp = $inp.Trim('"').Trim()
    if ((Test-Path -LiteralPath $inp) -and ((Split-Path -Leaf $inp) -eq 'nekobox.exe')) { $target = Split-Path -Parent $inp }
    elseif (Test-Path -LiteralPath (Join-Path $inp 'nekobox.exe')) { $target = $inp }
    else { Write-Warn2 "nekobox.exe not found there. Try again (example: C:\Tools\nekoray)" }
}

$configDir = Join-Path $target 'config'
if (-not (Test-Path -LiteralPath (Join-Path $configDir 'groups'))) {
    Write-Host "FATAL: '$target' does not look like a NekoBox folder (no config\groups)." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host ("NekoBox folder : " + $target) -ForegroundColor Green
Write-Host ("Config folder  : " + $configDir) -ForegroundColor Green
$confirm = Read-Host "Install profile here? (Y/n)"
if ($confirm -eq 'n') { Write-Host "Cancelled."; exit 0 }

# ---------- 3. backup existing ----------
$rb = Join-Path $configDir 'routes_box'
$dest = Join-Path $rb $ProfileName
if (Test-Path -LiteralPath $dest) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bakDir = Join-Path $configDir ("_backup_routes\" + $stamp)
    New-Item -Path $bakDir -ItemType Directory -Force | Out-Null
    Copy-Item -LiteralPath $dest (Join-Path $bakDir $ProfileName) -Force
    Write-Ok ("existing profile backed up to " + $bakDir)
}

# ---------- 4. install ----------
New-Item -Path $rb -ItemType Directory -Force | Out-Null
Copy-Item -LiteralPath $profileFile $dest -Force
Write-Ok ("profile installed -> " + $dest)

# ---------- 5. set active (only if NekoBox is not running) ----------
$running = Get-Process nekobox,nekoray -ErrorAction SilentlyContinue
if ($running) {
    Write-Warn2 "NekoBox is RUNNING. It overwrites its config on exit, so 'active' flag was NOT changed."
    Write-Host  "  After closing NekoBox, re-run this script to set the profile active,"
    Write-Host  "  or switch manually: Settings -> Routes -> '$ProfileName'."
} else {
    $gj = Join-Path $configDir 'groups\nekobox.json'
    if (Test-Path -LiteralPath $gj) {
        Copy-Item -LiteralPath $gj (Join-Path $configDir ("_backup_routes\" + (Get-Date -Format 'yyyyMMdd-HHmmss') + "_nekobox.json")) -Force
        $raw = Get-Content -LiteralPath $gj -Raw -Encoding UTF8
        $json = $raw | ConvertFrom-Json
        $json.active_routing = $ProfileName
        $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $gj -Encoding UTF8
        Write-Ok ("active_routing set to '" + $ProfileName + "'")
    } else {
        Write-Warn2 "groups\nekobox.json not found - set the route manually in the GUI."
    }
}

Write-Host ""
Write-Host "DONE. Start NekoBox (or reconnect the tunnel) to apply." -ForegroundColor Green
Write-Host ("If VAN 68 / game connectivity issues appear, remember: TUN mode is required for process rules.") -ForegroundColor DarkGray
