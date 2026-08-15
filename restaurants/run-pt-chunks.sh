#!/usr/bin/env bash
# Chunked Portugal discovery run: base + boost-gen + boost per ~350-parish
# chunk, resumable at chunk granularity (a finished chunk's pt-base-NN.json
# skips it on re-run). Mirrors run-portugal.sh discover, minus the proxies
# requirement (home IP first — add -proxies-file if Google starts blocking).
# Progress lines go to restaurants/out/pt-run-progress.log.
set -u

# When launched outside a Git Bash session (e.g. via WMI), the Windows PATH
# lacks Git's usr/bin, so date/basename/wc/sed silently vanish — and the empty
# $(basename …) tag would funnel every chunk into the same output file.
export PATH="/usr/bin:/bin:$PATH"
command -v basename >/dev/null || exit 1

ROOT="C:/Users/andre/Downloads/google-maps-scraper"
OUT="$ROOT/restaurants/out"
SCRAPER="$ROOT/google-maps-scraper.exe"
GEN="$ROOT/restaurants/gen-booster-queries.mjs"
MASTER="$OUT/pt-run-progress.log"

MAX_REVIEWS=200
DEPTH=20
CONC=4
INACTIVITY=10m

export DISABLE_TELEMETRY=1

say() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$MASTER"; }

scrape() { # $1=input $2=results $3=log
  "$SCRAPER" -input "$1" -results "$2" \
    -json -email -extra-reviews -review-sort newest -max-reviews "$MAX_REVIEWS" \
    -depth "$DEPTH" -c "$CONC" -exit-on-inactivity "$INACTIVITY" 2> "$3"
}

say "RUN START ($(ls "$OUT"/chunks/parish-chunk-*.txt | wc -l) chunks, c=$CONC depth=$DEPTH max-reviews=$MAX_REVIEWS)"

for c in "$OUT"/chunks/parish-chunk-*.txt; do
  tag="-$(basename "$c" .txt | sed 's/parish-chunk-//')"
  base="$OUT/pt-base$tag.json"; blog="$OUT/pt-base$tag.log"
  bq="$OUT/booster-queries$tag.txt"; boost="$OUT/pt-boost$tag.json"; bl="$OUT/pt-boost$tag.log"

  if [ -f "$base" ]; then
    say "SKIP chunk$tag (pt-base$tag.json exists)"
    continue
  fi

  say "CHUNK$tag base start ($(wc -l < "$c" | tr -d ' ') parishes)"
  scrape "$c" "$base" "$blog"
  say "CHUNK$tag base done: $(wc -l < "$base" 2>/dev/null | tr -d ' ' || echo 0) places"

  node "$GEN" "$blog" --threshold 100 --out "$bq" >> "$MASTER" 2>&1

  if [ -s "$bq" ]; then
    say "CHUNK$tag boost start ($(wc -l < "$bq" | tr -d ' ') queries)"
    scrape "$bq" "$boost" "$bl"
    say "CHUNK$tag boost done: $(wc -l < "$boost" 2>/dev/null | tr -d ' ' || echo 0) places"
  else
    say "CHUNK$tag nothing saturated — boost skipped"
  fi
done

say "RUN COMPLETE — all chunks discovered (feed phase not started)"
