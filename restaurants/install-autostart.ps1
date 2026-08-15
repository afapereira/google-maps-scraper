# Register the Portugal scrape to start automatically on the dedicated box.
#
# Trigger is AtLogOn (not AtStartup) on purpose: the scraper drives a real
# Google Chrome, and Chrome is far better behaved inside a normal interactive
# session than as SYSTEM. Pair this with auto-login on the dedicated machine
# (netplwiz -> uncheck "Users must enter a user name and password") so a power
# cut resumes the run with no human present.
#
# Deliberately NOT set to restart on exit: run-pt-watchdog.sh exits 3 when it
# detects a Google block, and auto-restarting into a block is what turns a
# 15-minute soft block into a 72-hour one. A block is meant to stay stopped.
#
# Usage:  powershell -ExecutionPolicy Bypass -File install-autostart.ps1
#         powershell -ExecutionPolicy Bypass -File install-autostart.ps1 -Remove

param(
    [string]$Repo = "C:\Users\$env:USERNAME\Downloads\google-maps-scraper",
    [int]$Conc = 4,
    [switch]$Remove
)

$TaskName = "PortugalScrapeWatchdog"

if ($Remove) {
    try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop; "Removed $TaskName" }
    catch { "Task $TaskName not found - nothing to remove" }
    return
}

# --- preflight ---
$bash = "$env:ProgramFiles\Git\bin\bash.exe"
if (-not (Test-Path $bash)) { throw "Git Bash not found at $bash - install Git for Windows first" }

$script = Join-Path $Repo "restaurants\run-pt-watchdog.sh"
if (-not (Test-Path $script)) { throw "Watchdog not found at $script - check -Repo" }

$exe = Join-Path $Repo "google-maps-scraper.exe"
if (-not (Test-Path $exe)) { Write-Warning "google-maps-scraper.exe missing at $exe - build it before the first boot" }

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Warning "node not on PATH - the per-chunk booster step (gen-booster-queries.mjs) will be skipped"
}

$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chrome) {
    Write-Warning "Google Chrome not installed. The fetcher prefers channel 'chrome' and falls back to bundled Chromium, which Google treats as bot-like and serves capped review data to. Install Chrome."
}

# The watchdog hardcodes its own ROOT; pass CONC through the environment.
# Convert the Windows repo path to the /c/... form bash expects.
$p = $script -replace '\\', '/'
$bashPath = "/" + $p.Substring(0,1).ToLower() + $p.Substring(2)

$action = New-ScheduledTaskAction -Execute $bash `
    -Argument "-lc `"export CONC=$Conc; exec '$bashPath'`"" `
    -WorkingDirectory $Repo

$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"

# Never stop it: this run is measured in weeks, and the default 3-day execution
# limit would silently kill it mid-chunk.
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 0 `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Settings $settings -Description "Resumable Portugal restaurant scrape (chunked watchdog)" -Force | Out-Null

"Registered '$TaskName' (CONC=$Conc, repo $Repo)"
"  start now : Start-ScheduledTask -TaskName $TaskName"
"  stop      : Stop-ScheduledTask  -TaskName $TaskName"
"  progress  : Get-Content '$Repo\restaurants\out\pt-run-progress.log' -Tail 20"
