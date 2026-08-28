# Supervisor for run-pt-watchdog.sh.
#
# Why: Git Bash (MSYS2) fork() dies on long-running loops on Windows —
#   "dofork: child -1 ... exit code 0xC000026B, errno 11"
#   "fork: Resource temporarily unavailable"
# The watchdog forks date/stat/wc/grep every POLL, so it reliably dies after a
# few hours (observed 2026-08-19 22:40 and 2026-08-20 00:11) leaving the run
# silently stopped. .done sentinels make a restart cheap: it resumes at the next
# unfinished chunk, losing at most the in-flight chunk.
#
# Exit-code contract with the watchdog:
#   3 = Google block detected -> STOP PERMANENTLY. Restarting into a block is
#       what turns a 15-min soft block into a 24-72h one.
#   0 = all chunks processed -> done.
#   * = crash/fork-death -> cool down, purge leaked profiles, restart.

param(
    [string]$Repo = 'C:\Users\andre\Downloads\google-maps-scraper',
    [int]$CooldownSec = 120,
    [int]$MaxRestarts = 500,
    # Which chunk set the watchdog runs. 'country' = the full 308-chunk sweep;
    # 'aml' = the Lisbon metro priority set (out/chunks-aml). The two use separate
    # .done namespaces, so switching between them is lossless.
    [ValidateSet('country','aml')]
    [string]$ChunkSet = 'country',
    # Scraper concurrency. 2 is safe on a loaded desktop; 4 roughly doubles
    # throughput but needs ~5 GB free or Chrome OOMs and the boost dies.
    [int]$Conc = 0,
    # Optional trimmed booster-category file (see booster-cats-fast.txt).
    [string]$BoostCats = ''
)

$bash   = "$env:ProgramFiles\Git\bin\bash.exe"
$script = '/c/Users/andre/Downloads/google-maps-scraper/restaurants/run-pt-watchdog.sh'
$out    = Join-Path $Repo 'restaurants\out'
$sup    = Join-Path $out 'supervisor.log'
$wrap   = '/c/Users/andre/Downloads/google-maps-scraper/restaurants/out/watchdog-wrapper.log'

function Say($m) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') SUPERVISOR $m"
    Write-Host $line
    # -Encoding utf8: Tee-Object/Out-File default to UTF-16 on PS 5.1, which makes
    # the log unreadable with tail/grep from Git Bash.
    Add-Content -Path $sup -Value $line -Encoding utf8
}

Say "start (set=$ChunkSet, conc=$Conc, cats=$(if($BoostCats){Split-Path $BoostCats -Leaf}else{'default'}), cooldown ${CooldownSec}s)"

for ($i = 1; $i -le $MaxRestarts; $i++) {
    # Leaked Playwright profiles are the memory hog across restarts.
    Get-ChildItem $env:TEMP -Directory -Filter 'playwright_chromiumdev_profile*' -ErrorAction SilentlyContinue |
        ForEach-Object { try { [System.IO.Directory]::Delete($_.FullName, $true) } catch {} }

    $free = [math]::Round((Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue)
    Say "launch #$i (free RAM ${free} MB)"

    if ($ChunkSet -eq 'aml') {
        $glob = '/c/Users/andre/Downloads/google-maps-scraper/restaurants/out/chunks-aml/parish-chunk-A*.txt'
    } else {
        $glob = '/c/Users/andre/Downloads/google-maps-scraper/restaurants/out/chunks/parish-chunk-*.txt'
    }
    # Pass config through the ENVIRONMENT, not the command string. Start-Process
    # -ArgumentList mangles embedded single quotes, which silently produced a
    # no-op command that exited 0 and looked like "all chunks processed".
    $env:CHUNK_SET  = $ChunkSet
    $env:CHUNK_GLOB = $glob
    if ($Conc)      { $env:CONC = "$Conc" }
    if ($BoostCats) { $env:BOOST_CATS = $BoostCats }
    $p = Start-Process -FilePath $bash -ArgumentList '-lc', "$script >> $wrap 2>&1" -NoNewWindow -Wait -PassThru
    $code = $p.ExitCode

    if ($code -eq 3) { Say "watchdog exited 3 = GOOGLE BLOCK. Stopping. Wait a few hours, then rerun this supervisor."; break }
    if ($code -eq 0) { Say "watchdog exited 0 = all chunks processed. Done."; break }

    $done = (Get-ChildItem $out -Filter '*.done' -ErrorAction SilentlyContinue | Measure-Object).Count
    Say "watchdog died (exit $code); $done/308 chunks done; restarting in ${CooldownSec}s"
    Start-Sleep -Seconds $CooldownSec
}

Say "supervisor exiting"
