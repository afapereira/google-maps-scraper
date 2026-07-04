# Scraping every restaurant in Portugal → NomNom ingest

End-to-end runbook: discover all Portuguese restaurants on Google Maps, scrape
their details + reviews, and push them into the NomNom app via its ingest API.

This is the complete "how to run it" reference. Read the [Overview](#overview),
then follow [The full run](#the-full-run-all-of-portugal).

---

## Overview

Google Maps caps **every search at ~120 results**, so you can't get a whole
country (or even a city) from one query. Two levers beat the cap, and the
scraper's shared deduper (`place_id`) merges the overlaps into one clean set:

1. **Location subdivision** — search each of Portugal's ~3,074 civil parishes
   (freguesias) individually. The list already includes the dense urban
   parishes (Lisbon/Porto are split into their ~24 / ~15 parishes), so most
   searches stay under the 120 cap.
2. **Category subdivision** — for the ~30–50 densest parishes that still cap
   out, re-search with different food terms (`café`, `petiscos`, `sushi`, …).
   Each returns a different 120-slice; the union fills the gap.

Pipeline:

```
parish list ──▶ BASE PASS (scrape) ──▶ pt-base.json ──┐
                     │ (log)                           ├─▶ FEEDER ─▶ ingest API ─▶ Supabase
                     ▼                                  │
             gen-booster-queries.mjs                    │
                     │                                  │
                     ▼                                  │
             booster-queries.txt ─▶ BOOSTER PASS ─▶ pt-boost.json ┘
```

---

## Prerequisites

- **Build the scraper** (from repo root):
  ```bash
  go build -o google-maps-scraper.exe .
  ```
- **Google Chrome installed.** The scraper launches the real Chrome channel
  (falls back to bundled Chromium if absent). Real Chrome + new-headless + a
  modern UA is what defeats Google's review anti-bot cap — do not "fix" this
  back to plain Chromium.
- **Node.js** (for the booster generator and the ingest feeder).
- **Residential proxies** (rotating). Datacenter proxies are pre-blocked by
  Google at volume — see [Proxies](#proxies). Put them one-per-line in a file
  as `http://user:pass@host:port` (or `socks5://…`).
- **The parish list**: `C:\Users\andre\Downloads\justnomnom\restaurants-by-place.txt`
  (one `restaurants <parish>` per line).
- **The NomNom ingest API** running/deployed, plus its `RESTAURANT_INGEST_SECRET`.
  The ingest endpoint is rate-limited (60/hr per IP by default) — raise/allowlist
  it for the scraper's IP before a country run.

---

## The full run (all of Portugal)

All commands are run from the repo root (`google-maps-scraper/`). Windows paths
shown; adjust as needed.

### Quick start (one command)

`run-portugal.sh` chains all four phases. Configure via env, then run:

```bash
export PROXIES="$PWD/residential.txt"
export INGEST_ENDPOINT="https://<your-app>/api/restaurants/ingest"
export RESTAURANT_INGEST_SECRET="<secret>"

./restaurants/run-portugal.sh all          # discover + feed (default)
# or run phases individually:
./restaurants/run-portugal.sh discover      # scrape only (base + boosters), no feed
./restaurants/run-portugal.sh base          # just the base pass
./restaurants/run-portugal.sh boost-gen boost   # boosters after a base pass
./restaurants/run-portugal.sh feed          # feed existing outputs to the API
```

It fails fast if the ingest env is missing before starting a long scrape, skips
the booster pass when nothing saturated, and the feed step resumes on re-run.
Override any default (`CONCURRENCY`, `MAX_REVIEWS`, `DEPTH`, `THRESHOLD`,
`PARISH_LIST`, …) via env — see the header of the script. The phases below
document what each step does under the hood.

### Chunked run (interruption-safe — recommended on a PC)

For a multi-day run on one machine, process the parishes in chunks so a
crash/reboot only costs the current chunk (file output isn't resumable). The
list is pre-split into ~350-parish files under `restaurants/out/chunks/`.
Regenerate any time with:

```bash
split -l 350 -d --additional-suffix=.txt \
  "C:/Users/andre/Downloads/justnomnom/restaurants-by-place.txt" \
  restaurants/out/chunks/parish-chunk-
```

`TAG` keeps each chunk's outputs separate (`pt-base-00.json`, `pt-base-01.json`, …):

```bash
# 1) scrape each chunk (already-scraped chunks are skipped)
for c in restaurants/out/chunks/parish-chunk-*.txt; do
  tag="-$(basename "$c" .txt | sed 's/parish-chunk-//')"
  [ -f "restaurants/out/pt-base${tag}.json" ] && continue
  TAG="$tag" PARISH_LIST="$c" ./restaurants/run-portugal.sh discover
done

# 2) then feed every chunk (resumable; dedups across chunks by place_id)
for c in restaurants/out/chunks/parish-chunk-*.txt; do
  tag="-$(basename "$c" .txt | sed 's/parish-chunk-//')"
  TAG="$tag" ./restaurants/run-portugal.sh feed
done
```

Each ~350-parish chunk is roughly half a day to a day of scraping.

### Phase 1 — Base pass (all parishes)

Scrape every parish. Keep `stderr` — the booster generator mines it. Use a high
`-depth` so each search actually scrolls to ~120.

```bash
export DISABLE_TELEMETRY=1
./google-maps-scraper.exe \
  -input "C:/Users/andre/Downloads/justnomnom/restaurants-by-place.txt" \
  -results restaurants/out/pt-base.json \
  -json -email -extra-reviews -review-sort newest -max-reviews 20 \
  -depth 20 -c 8 \
  -proxies-file residential.txt \
  -exit-on-inactivity 10m \
  2> restaurants/out/pt-base.log
```

Output: `restaurants/out/pt-base.json` (JSONL, one restaurant per line) and
`restaurants/out/pt-base.log` (needed for Phase 2).

### Phase 2 — Detect saturation & generate boosters

Find parishes that hit the ~120 cap and emit category-diversified queries:

```bash
node restaurants/gen-booster-queries.mjs restaurants/out/pt-base.log \
  --threshold 100 \
  --out restaurants/out/booster-queries.txt
```

It prints the top saturated parishes and how many booster queries it wrote.
Tuning: lower `--threshold` catches more borderline parishes (more thorough,
more searches); override categories with `--cats file.txt`.

### Phase 3 — Booster pass (saturated parishes only)

```bash
./google-maps-scraper.exe \
  -input restaurants/out/booster-queries.txt \
  -results restaurants/out/pt-boost.json \
  -json -email -extra-reviews -review-sort newest -max-reviews 20 \
  -depth 20 -c 8 \
  -proxies-file residential.txt \
  -exit-on-inactivity 10m \
  2> restaurants/out/pt-boost.log
```

`place_id` dedup means boosters only add restaurants the base pass missed.

### Phase 4 — Feed into the NomNom ingest API

The feeder lives in the NomNom repo (`justnomnom/scripts/import-restaurants-from-json.mjs`).
It streams JSONL, remaps the deep reviews, retries on 429/5xx, and is resumable
(progress keyed by `place_id` in `scripts/.ingest-progress.json`).

```bash
cd C:/Users/andre/Downloads/justnomnom

export INGEST_ENDPOINT="https://<your-app>/api/restaurants/ingest"   # or http://localhost:3032/... for local
export RESTAURANT_INGEST_SECRET="<the secret from .env.local>"
export CONCURRENCY=4        # keep low: each ingest runs AI + image work (~7-15s)

node scripts/import-restaurants-from-json.mjs C:/Users/andre/Downloads/google-maps-scraper/restaurants/out/pt-base.json
node scripts/import-restaurants-from-json.mjs C:/Users/andre/Downloads/google-maps-scraper/restaurants/out/pt-boost.json
```

Ingest upserts by `external_place_id` (= `place_id`), so re-running is safe.
Non-Portugal / permanently-closed places return 422 and are skipped.

---

## Alternative: lat/lon grid tiling

If you don't have a location list, tile a bounding box instead (more searches,
less precise, but no list needed):

```bash
# nationwide 2km grid (mainland bbox)
./google-maps-scraper.exe -produce -dsn "postgres://…" \
  -grid-bbox "36.95,-9.55,42.16,-6.19" -grid-cell 2 -zoom 15 \
  -input restaurants/restaurant-queries.txt
# then run consumers against the same DSN (see Resumable runs)
```

The parish-list approach above is preferred (~15–50× fewer searches).

---

## Resumable multi-day runs (Postgres)

For runs too big to finish in one sitting, use the database producer/consumer so
work survives restarts:

```bash
# 1. produce jobs into Postgres (fast)
./google-maps-scraper.exe -produce -dsn "postgres://user:pass@host/db" \
  -input "C:/Users/andre/Downloads/justnomnom/restaurants-by-place.txt"

# 2. run one or more consumers (stop/restart freely; add machines for parallelism)
./google-maps-scraper.exe -dsn "postgres://user:pass@host/db" \
  -c 8 -extra-reviews -max-reviews 20 -proxies-file residential.txt \
  -exit-on-inactivity 15m
```

The file-output passes above are simpler and are fine when a pass fits in a few
hours; use Postgres for the full-country marathon.

---

## Proxies

Sustained country-wide volume from one IP gets banned even with stealth. Use
**rotating residential** (or mobile for the toughest listings):

| Type | Providers | ~Price | Notes |
|---|---|---|---|
| Rotating residential ✅ | IPRoyal, Smartproxy/Decodo, Oxylabs, Bright Data | $1.75–8/GB | Point `-proxies-file` at the rotating gateway |
| ISP / static residential | Webshare (residential plan), IPRoyal | $2–3/IP/mo | Fewer IPs, more stable |
| Mobile (4G/5G) | Bright Data, Soax | $50–150/port/mo | Most block-proof, priciest |

Datacenter proxies (e.g. Webshare's default) do **not** work — verified. Images
are disabled by default (saves ~70% bandwidth); budget ~60–150 GB for all of
Portugal (~$150–500 on residential).

---

## Key flags

| Flag | Meaning |
|---|---|
| `-input FILE` | Query file, one search per line |
| `-results FILE` | Output path (JSONL when `-json`) |
| `-json` | JSONL output (one object per line) |
| `-email` | Also extract emails from websites |
| `-extra-reviews` | Pull individual reviews (with per-review star ratings) |
| `-review-sort newest\|relevant\|highest\|lowest` | Review ordering; `newest` uses the deep DOM path |
| `-max-reviews N` | Cap reviews per place (depth vs time; 20 is a good country-run value) |
| `-depth N` | Search scroll depth — raise (e.g. 20) so searches reach the ~120 cap |
| `-c N` | Concurrency (browser workers). 8 is a good per-machine value |
| `-proxies-file FILE` | Rotating proxy list |
| `-exit-on-inactivity DUR` | Stop after idle (e.g. `10m`) |
| `-grid-bbox` / `-grid-cell` / `-zoom` | Lat/lon grid tiling |
| `-dsn` / `-produce` | Postgres queue (resumable producer/consumer) |

---

## Completeness & tuning

- **Saturation is the signal.** A base-pass search returning ~120 means it
  undercounted. `gen-booster-queries.mjs --threshold 100` flags those.
- **Convergence.** When more categories / finer searches stop finding new
  `place_id`s, you've effectively converged. Cross-check a hand-countable city
  or INE food-service stats.
- **No method is 100%.** Google exposes no "list all" — this is best-effort by
  design.

---

## Timeline & cost estimates (running on your PC)

Figures for running the whole pipeline on **one Windows PC on home broadband**,
`-max-reviews 20`, ~50,000–75,000 unique restaurants. Concurrency is capped by
your hardware — each `-c` worker is a full Chrome instance (~300–500 MB RAM).

| Phase | Work | Time on one PC |
|---|---|---|
| Base pass | ~3,074 searches + ~50–75k place extractions (details + reviews) | **~5–10 days** |
| Boost-gen | parse the log | seconds |
| Booster pass | few hundred–1,500 searches + the incremental new places | ~6–18 hours |
| Feed (ingest) | ~50–75k POSTs @ 7–15s each (AI + images, runs remotely) | **~3–6 days** |

Run the scrape and the feed **sequentially, not at the same time** — they'd
fight for CPU/RAM. Realistic end-to-end on a single PC left running:
**~2–3 weeks.** You can't scale across machines here, so this is bounded by the
one box.

| Cost item | On your PC | Notes |
|---|---|---|
| Proxies | **$0–200** | Your home IP is already residential — you may not need paid proxies. Buy a small residential plan (~$50 / 30 GB) only if Google starts blocking. |
| Qwen LLM (ingest) | ~$10–100 | Remote API — same regardless of where the scraper runs |
| Supabase storage | variable | up to 25 re-hosted images per restaurant (remote) |
| Electricity | ~$10–30 | PC running continuously for weeks |

No VPS/proxy bill if your home IP holds up — the main "cost" is your PC being
tied up for a couple of weeks.

### Running on a single PC — read this first

- **Your home IP is residential** (good — that's what defeats Google's bot
  checks), but ~50k+ requests from one IP over days can still trip rate limits.
  Start at **`-c 4`** at a normal pace; if the log shows block/captcha pages,
  lower `-c` or add a few residential proxies as fallback (`-proxies-file`).
- **Resumability matters over a 1–2 week run.** A Windows update, sleep, or
  crash will interrupt it — and file-output passes are **not resumable**, so
  you'd lose progress. Two safe options:
  1. **Postgres producer/consumer** ([Resumable runs](#resumable-multi-day-runs-postgres)) — survives restarts.
  2. **Chunk the list** — split the parish file into smaller batches and run
     them one at a time, so an interruption only costs the current chunk:
     ```bash
     split -l 500 restaurants-by-place.txt restaurants/out/parish-chunk-
     # then run each chunk as its own base pass (-input parish-chunk-aa, ab, …)
     ```
- **Disable sleep/hibernate** for the duration (Settings → Power & sleep → Never).
- **Pick `-c` by free RAM:** ~2 GB per worker. 16 GB machine → `-c 4–6`; 32 GB
  → `-c 8–10`. Too high and the Chrome instances thrash and slow everything.
- The **feed step barely uses your CPU** (the AI runs remotely), but still run
  it *after* the scrape, not during.

---

## Troubleshooting

- **All places cap at 10 / empty reviews** → real Chrome not installed (fell
  back to Chromium). Install Chrome; the launcher prefers its channel.
- **Feeder: 429 "Too many requests"** → the ingest rate limit (60/hr per IP).
  Raise/allowlist it for the scraper's IP. The feeder backs off automatically
  but can't outrun a hard cap at scale.
- **Feeder: `no_municipality_for_point` (422)** → place is outside Portugal
  boundaries; correctly skipped.
- **Base pass dies mid-run** → file output isn't resumable; use the Postgres
  producer/consumer for long runs, or re-run (the feeder dedups on ingest).
- **Booster generator finds 0 saturated** → base pass `-depth` too low to reach
  the cap, or genuinely nothing dense in that slice. Raise `-depth`.
