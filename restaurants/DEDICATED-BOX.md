# Move the Portugal run to a dedicated box

Option 2: a cheap always-on machine on your home connection. Keeps the residential
IP that is already working (zero proxy spend), and converts calendar weeks into
runtime hours. Verified against this repo on 2026-08-14.

## Why this and not the cloud

Your run has never been IP-blocked: **zero** captcha/403/429 hits across ~6,400 places,
and per-chunk yield rose over the series (418, 412, 538 for the last three). The
datacenter move is what would force ~$100–400 of residential proxies — the scrape
itself doesn't need them. You are at 4% after five weeks of *calendar* time, and the
bottleneck is that the run only moves while you're at the machine and not gaming.

## Hardware

**16 GB RAM is the spec that matters**, not the CPU. Chrome is the memory hog; 8 GB
reproduces the OOM stalls you already have and forces `CONC=2`. 16 GB runs `CONC=4`,
which is roughly 2× throughput. Do **not** go to 6 — measured net *slower* (173
places/h vs 490 healthy) from memory thrashing.

Any old laptop with 16 GB is ideal (built-in UPS for a 3-week unattended run). Failing
that, a used OptiPlex/ThinkCentre micro. Power draw ~10–15 W ≈ **€1–2** for the whole run.

## Install on the box

| | Why |
|---|---|
| **Google Chrome** | The fetcher sets `opts.Channel = "chrome"` and only falls back to bundled Chromium — which Google treats as bot-like and serves capped review data to. Not optional. |
| **Git for Windows** | The watchdog is bash. Installer expects `C:\Program Files\Git\bin\bash.exe`. |
| **Node.js** | `gen-booster-queries.mjs` (per-chunk booster step). Without it boosters are silently skipped. |
| **Go 1.26** *(optional)* | Only if you build rather than copy `google-maps-scraper.exe`. |

Then disable sleep/hibernate — this is the failure mode that kills unattended runs:

```powershell
powercfg /change standby-timeout-ac 0; powercfg /change hibernate-timeout-ac 0; powercfg /change monitor-timeout-ac 15
```

## Copy from this PC

Preserve `restaurants/out/` intact — the `.done` sentinels are what make the run
resume instead of restarting from chunk 000. You have **13 done**; losing them costs
you those five weeks over again.

```bash
robocopy "C:\Users\andre\Downloads\google-maps-scraper" "\\NEWBOX\c$\gms" /E /XD .git node_modules /R:1 /W:1
```

Sanity-check on the box before starting — expect **13**:

```bash
ls /c/gms/restaurants/out/*.done | wc -l
```

## Enable auto-resume

Turn on auto-login (`netplwiz` → uncheck "Users must enter a user name and password"),
then:

```powershell
powershell -ExecutionPolicy Bypass -File C:\gms\restaurants\install-autostart.ps1 -Repo C:\gms -Conc 4
```

Registers a `PortugalScrapeWatchdog` scheduled task, AtLogOn, no execution time limit
(the default 3-day cap would kill a multi-week run mid-chunk). It runs the same
watchdog you already trust; `.done` sentinels mean a reboot resumes at the next chunk.

Trigger is AtLogOn rather than AtStartup because Chrome misbehaves as SYSTEM. And it
deliberately does **not** restart on exit — see the block guard below.

## What changed in the watchdog

**1. Google-block guard (new).** The scraper already detects block pages per job
(`gmaps/place.go` `isGoogleBlockPage` → `ErrGoogleBlocked`, added in 48d4e50) and
retries on a fresh browser, which self-heals a one-off. What it could not see is the
whole *IP* being soft-blocked — and then the 3× chunk retry hammered Google while
flagged, turning a ~15-minute soft block into a 24–72 hour one. Now: ≥20 block hits in
a try (`BLOCK_THRESHOLD`) stops the entire run, writes `out/BLOCKED-<chunk>.log`, and
exits 3 without a `.done`. Wait a few hours, relaunch, and that chunk re-runs.

**2. `-email` off by default.** It spawned an extra job per place
(`gmaps/place.go:209` → `NewEmailJob`) to fetch each restaurant's own website — and
NomNom's ingest never reads the email field. That work was being thrown away.
`WANT_EMAIL=1` restores it.

**3. `CONC` / `MAX_REVIEWS` are env-overridable**, so the box runs `CONC=4` without
editing the script.

## Checking on it

```bash
tail -20 /c/gms/restaurants/out/pt-run-progress.log
```

Healthy: `CHUNK-0NN base done (clean)` lines advancing. A stalled scraper shows 0 CPU
movement over a 6-second sample. If `GOOGLE BLOCK DETECTED` appears, the run stopped
on purpose — don't relaunch immediately.

I can also poll this over SSH/Tailscale if you want me watching it between sessions.

## Expected time

~40–60 min per clean chunk at `CONC=4`; 295 chunks remain (~50–100k places).

| | 50k | 100k |
|---|---|---|
| Clean (~500/h) | 4 days | 8 days |
| **Realistic** (~275/h, ~40% of chunks stall a try) | **8 days** | **15 days** |

**~2 weeks continuous.** Dropping `-email` should beat that; it wasn't in the measured baseline.

## Further speed levers (your call)

- **Run both machines in parallel.** The `.done` design already supports it — split
  `out/chunks/` into two ranges and run your desktop on the other half. Nearly halves
  wall-clock. Caveat: doubles request rate from one IP, which is exactly the pressure
  the block guard now watches for. I'd start the box alone, confirm a week clean, then
  add the desktop.
- **`MAX_REVIEWS=50`** (from 100) — reviews dominate per-place time, so this is close
  to a linear win. Costs review-consensus quality in the ingest, so it's a product
  call, not a technical one.
- **Don't lower `-depth 20`** — that loses places, not time.
