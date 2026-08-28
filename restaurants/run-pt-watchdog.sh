#!/usr/bin/env bash
# Chunked Portugal discovery with an EXTERNAL stall-watchdog.
#
# Why: the scraper can deadlock on a bad review-extraction (Chrome/CDP hang) in
# a way its own -exit-on-inactivity watchdog doesn't catch, freezing the whole
# multi-day run. This wrapper watches each chunk's output file; if it stops
# growing for STALL_LIMIT, it force-kills the scraper + its Playwright Chrome and
# retries the chunk. A per-chunk `.done` sentinel (written only after a clean
# finish) drives resume — not mere file existence, since a stalled chunk leaves a
# partial .json behind.
set -u
export PATH="/usr/bin:/bin:$PATH"
command -v basename >/dev/null || exit 1

ROOT="C:/Users/andre/Downloads/google-maps-scraper"
OUT="$ROOT/restaurants/out"
SCRAPER="$ROOT/google-maps-scraper.exe"
GEN="$ROOT/restaurants/gen-booster-queries.mjs"
MASTER="$OUT/pt-run-progress.log"

MAX_REVIEWS=${MAX_REVIEWS:-100}
DEPTH=${DEPTH:-20}
CONC=${CONC:-2}      # 6 thrashed RAM (~3x slower, never completed); 4 died when League+apps
                     # left <2 GB available. 2 coexists with a loaded desktop.
                     # On a DEDICATED 16 GB box use CONC=4 (env override) — that is the
                     # measured sweet spot; do NOT go to 6, it was net slower.
INACTIVITY=10m       # scraper's own idle-exit (first line of defense)
STALL_LIMIT=900      # watchdog: force-kill if output file idle this many seconds (> INACTIVITY)
POLL=60
MAX_TRIES=3
COOLDOWN=60          # pause after a force-kill so RAM/Chrome recover before retry

# Google-block guard. The scraper already detects block pages per-job
# (gmaps/place.go isGoogleBlockPage -> ErrGoogleBlocked) and retries on a fresh
# browser, which self-heals a one-off. What it CANNOT do is notice that the whole
# IP is soft-blocked — and then the 3x chunk retry below hammers Google while
# flagged, turning a ~15 min soft block into a 24-72h one. So: count block hits
# per try, and past the threshold stop the entire run instead of retrying.
# -email spawns an EXTRA job per place (gmaps/place.go:209 -> NewEmailJob) that
# fetches the restaurant's own website. NomNom's ingest never reads the email
# field (no match for "email" in scripts/import-restaurants-from-json.mjs), so
# that work was being thrown away. Off by default now; set WANT_EMAIL=1 to
# restore the old behaviour.
EMAIL_FLAG=""
[ "${WANT_EMAIL:-0}" = "1" ] && EMAIL_FLAG="-email"

# Which chunk set to run. Default = the full 308-chunk country sweep. Set
# CHUNK_GLOB to a different set (e.g. out/chunks-aml/parish-chunk-A*.txt) to run
# a priority region first; .done sentinels are keyed off each file's basename, so
# the two sets have separate namespaces and neither disturbs the other's resume.
CHUNK_GLOB="${CHUNK_GLOB:-$OUT/chunks/parish-chunk-*.txt}"
CHUNK_SET="${CHUNK_SET:-country}"

BLOCK_THRESHOLD=${BLOCK_THRESHOLD:-20}
BLOCK_PATTERN='google block page detected|unusual traffic|automated queries|/sorry/'

export DISABLE_TELEMETRY=1

say() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$MASTER"; }

# Delete leftover Playwright temp profile dirs. A force-killed scraper never
# cleans its own profile, so without this they pile up in %TEMP% and leak
# gigabytes of RAM/disk across a multi-day run (observed: 28 dirs ~= 5 GB).
cleanup_profiles() {
  powershell -NoProfile -Command "Get-ChildItem \$env:TEMP -Directory -Filter 'playwright_chromiumdev_profile*' -ErrorAction SilentlyContinue | ForEach-Object { [System.IO.Directory]::Delete(\$_.FullName, \$true) }" >/dev/null 2>&1
}

# Force-kill the scraper family without touching the dev server or personal
# Chrome: the Go exe by name (only our run uses it) + chrome/node on the
# Playwright temp profile. Then purge the orphaned profile dirs.
kill_scraper() {
  taskkill //F //IM google-maps-scraper.exe >/dev/null 2>&1
  powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe' OR Name='node.exe'\" | Where-Object { \$_.CommandLine -like '*playwright_chromiumdev_profile*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }" >/dev/null 2>&1
  sleep 3
  cleanup_profiles
}

mtime() { stat -c %Y "$1" 2>/dev/null || echo 0; }

# Count Google block-page hits in a scrape log.
block_hits() { local n; n=$(grep -Eic "$BLOCK_PATTERN" "$1" 2>/dev/null); echo "${n:-0}"; }

# Run one scrape with the stall-watchdog.
# Returns 0 on clean finish, 1 if it had to force-kill a stall, 2 if the log
# shows a sustained Google block (caller must STOP, not retry).
guarded_scrape() { # $1=input $2=results $3=log
  local input="$1" results="$2" log="$3"
  # shellcheck disable=SC2086 # EMAIL_FLAG is intentionally word-split (empty = omit)
  "$SCRAPER" -input "$input" -results "$results" \
    -json $EMAIL_FLAG -extra-reviews -review-sort newest -max-reviews "$MAX_REVIEWS" \
    -depth "$DEPTH" -c "$CONC" -exit-on-inactivity "$INACTIVITY" 2> "$log" &
  local pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    sleep "$POLL"
    local now last idle
    now=$(date +%s)
    # Base progress on the results file when it exists yet, else the log (covers
    # the search phase before the first place is written).
    if [ -f "$results" ]; then last=$(mtime "$results"); else last=$(mtime "$log"); fi
    idle=$(( now - last ))
    if [ "$idle" -ge "$STALL_LIMIT" ]; then
      say "  WATCHDOG stall ${idle}s (>$STALL_LIMIT) — force-killing scraper"
      kill_scraper
      wait "$pid" 2>/dev/null
      [ "$(block_hits "$log")" -ge "$BLOCK_THRESHOLD" ] && return 2
      return 1
    fi
  done
  wait "$pid" 2>/dev/null
  [ "$(block_hits "$log")" -ge "$BLOCK_THRESHOLD" ] && return 2
  return 0
}

cleanup_profiles   # start from a clean slate (purge any leftover temp profiles)
say "WATCHDOG RUN START ($(ls $CHUNK_GLOB 2>/dev/null | wc -l) chunks [$CHUNK_SET], c=$CONC depth=$DEPTH max-reviews=$MAX_REVIEWS email=${WANT_EMAIL:-0} stall_limit=${STALL_LIMIT}s keep-best cooldown=${COOLDOWN}s block_threshold=$BLOCK_THRESHOLD)"

# shellcheck disable=SC2086 # CHUNK_GLOB must word-split/glob
for c in $CHUNK_GLOB; do
  tag="-$(basename "$c" .txt | sed 's/parish-chunk-//')"
  base="$OUT/pt-base$tag.json"; blog="$OUT/pt-base$tag.log"
  done_marker="$OUT/pt-base$tag.done"
  bq="$OUT/booster-queries$tag.txt"; boost="$OUT/pt-boost$tag.json"; bl="$OUT/pt-boost$tag.log"

  if [ -f "$done_marker" ]; then
    say "SKIP chunk$tag (already done)"
    continue
  fi

  # Keep-best-partial: each try scrapes to its own temp file; we retain the try
  # that produced the MOST places (with its matching log for boost-gen). This
  # stops a broken retry — e.g. one where Chrome OOMs and returns ~0 — from
  # clobbering a good earlier partial. A clean finish still wins on merit
  # (it has the most places), but "clean" alone is no longer trusted.
  ok=0
  best=0
  rm -f "$base"
  for try in $(seq 1 "$MAX_TRIES"); do
    say "CHUNK$tag base try $try/$MAX_TRIES ($(wc -l < "$c" | tr -d ' ') parishes)"
    prev_best="$best"
    tmp="$base.try$try"; tmplog="$blog.try$try"
    rm -f "$tmp" "$tmplog"
    guarded_scrape "$c" "$tmp" "$tmplog"; rc=$?
    if [ "$rc" = 0 ]; then ok=1; fi
    n=$(wc -l < "$tmp" 2>/dev/null | tr -d ' '); n=${n:-0}
    if [ "$n" -gt "$best" ]; then best="$n"; cp -f "$tmp" "$base"; cp -f "$tmplog" "$blog"; fi
    # Keep the blocked log for diagnosis before the temp files are cleared.
    if [ "$rc" = 2 ]; then cp -f "$tmplog" "$OUT/BLOCKED$tag.log" 2>/dev/null; fi
    rm -f "$tmp" "$tmplog"
    if [ "$rc" = 2 ]; then
      say "CHUNK$tag GOOGLE BLOCK DETECTED (>=$BLOCK_THRESHOLD hits) — STOPPING RUN, not retrying."
      say "  Kept $best places for this chunk (no .done written; it re-runs on resume)."
      say "  Wait a few hours (soft blocks clear in 5-15 min, IP flags in 1-4h), then relaunch."
      say "  Diagnosis log: $OUT/BLOCKED$tag.log"
      exit 3
    fi
    if [ "$ok" = 1 ]; then
      say "CHUNK$tag base done (clean): try $try=$n places, best kept=$best"
      break
    fi
    say "CHUNK$tag base try $try stalled: $n places (best kept=$best)"
    # Adaptive early-stop: a retry that didn't beat the best won't next time
    # either — the stall is a random bad listing and the first good try usually
    # wins (observed: 554 -> 397 -> 516). Bail rather than burn ~80 min/try.
    # try 1 always "improves" from 0, so this only fires from try 2 on.
    if [ "$try" -gt 1 ] && [ "$n" -le "$prev_best" ]; then
      say "CHUNK$tag base retry not improving ($n <= best $prev_best) — stopping retries early"
      break
    fi
    cleanup_profiles
    sleep "$COOLDOWN"
  done

  if [ "$ok" != 1 ]; then
    say "CHUNK$tag base UNRECOVERED after $MAX_TRIES tries — keeping best=$best places, moving on"
  fi

  # Boosters from whatever base log we ended with.
  # BOOST_CATS trims the booster category list. Measured on the Lisbon chunks
  # A00+A01: the 4 dropped categories averaged 6-10 places/query vs 20-59 for the
  # rest, and overlap heavily with places the other categories already find.
  # shellcheck disable=SC2086 # CATS_ARG is intentionally word-split (empty = omit)
  CATS_ARG=""
  [ -n "${BOOST_CATS:-}" ] && CATS_ARG="--cats $BOOST_CATS"
  node "$GEN" "$blog" --threshold 100 $CATS_ARG --out "$bq" >> "$MASTER" 2>&1 || true
  if [ -s "$bq" ]; then
    say "CHUNK$tag boost start ($(wc -l < "$bq" | tr -d ' ') queries)"
    guarded_scrape "$bq" "$boost" "$bl"; brc=$?
    if [ "$brc" = 2 ]; then
      cp -f "$bl" "$OUT/BLOCKED$tag-boost.log" 2>/dev/null
      say "CHUNK$tag boost GOOGLE BLOCK DETECTED — STOPPING RUN (no .done written)."
      exit 3
    fi
    [ "$brc" = 0 ] || say "CHUNK$tag boost stalled; partial kept"
    say "CHUNK$tag boost done: $(wc -l < "$boost" 2>/dev/null | tr -d ' ' || echo 0) places"
  else
    say "CHUNK$tag nothing saturated — boost skipped"
  fi

  # Mark chunk complete (best-effort) so a relaunch resumes at the next chunk.
  : > "$done_marker"
done

say "WATCHDOG RUN COMPLETE — all chunks processed (feed phase not started)"
