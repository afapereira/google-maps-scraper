#!/usr/bin/env bash
#
# run-portugal.sh — one-shot pipeline to scrape every Portuguese restaurant and
# feed them into the NomNom ingest API. Chains the four phases documented in
# restaurants/README.md. Run individual phases or the whole thing.
#
# Usage:
#   ./restaurants/run-portugal.sh [phase ...]
#
#   phases:  base        scrape all parishes            -> pt-base.json + pt-base.log
#            boost-gen   detect saturation, gen queries -> booster-queries.txt
#            boost       scrape the saturated parishes  -> pt-boost.json
#            feed        POST both outputs to ingest API
#            discover    base + boost-gen + boost   (scrape only, no feed)
#            all         discover + feed            (default)
#
# Config via env (defaults shown):
#   PARISH_LIST   C:/Users/andre/Downloads/justnomnom/restaurants-by-place.txt
#   PROXIES       <repo>/residential.txt          (required for base/boost)
#   CONCURRENCY   8         MAX_REVIEWS  20        DEPTH        20
#   REVIEW_SORT   newest    INACTIVITY   10m       THRESHOLD    100
#   INGEST_ENDPOINT / RESTAURANT_INGEST_SECRET     (required for feed)
#   INGEST_CONCURRENCY  4
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRAPER="${SCRAPER:-$ROOT/google-maps-scraper.exe}"
GEN="$ROOT/restaurants/gen-booster-queries.mjs"
OUT_DIR="${OUT_DIR:-$ROOT/restaurants/out}"

PARISH_LIST="${PARISH_LIST:-C:/Users/andre/Downloads/justnomnom/restaurants-by-place.txt}"
FEEDER="${FEEDER:-C:/Users/andre/Downloads/justnomnom/scripts/import-restaurants-from-json.mjs}"
PROXIES="${PROXIES:-$ROOT/residential.txt}"

CONCURRENCY="${CONCURRENCY:-8}"
MAX_REVIEWS="${MAX_REVIEWS:-20}"
DEPTH="${DEPTH:-20}"
REVIEW_SORT="${REVIEW_SORT:-newest}"
INACTIVITY="${INACTIVITY:-10m}"
THRESHOLD="${THRESHOLD:-100}"

INGEST_ENDPOINT="${INGEST_ENDPOINT:-}"
RESTAURANT_INGEST_SECRET="${RESTAURANT_INGEST_SECRET:-}"
INGEST_CONCURRENCY="${INGEST_CONCURRENCY:-4}"

# TAG suffixes all output files so chunked runs don't clobber each other, e.g.
#   TAG=-00 PARISH_LIST=restaurants/out/chunks/parish-chunk-00.txt ./run-portugal.sh discover
TAG="${TAG:-}"

BASE_JSON="$OUT_DIR/pt-base${TAG}.json"
BASE_LOG="$OUT_DIR/pt-base${TAG}.log"
BOOST_QUERIES="$OUT_DIR/booster-queries${TAG}.txt"
BOOST_JSON="$OUT_DIR/pt-boost${TAG}.json"
BOOST_LOG="$OUT_DIR/pt-boost${TAG}.log"

export DISABLE_TELEMETRY=1

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

need_scraper() { [ -f "$SCRAPER" ] || die "scraper not built: $SCRAPER  (go build -o google-maps-scraper.exe .)"; }
need_proxies() { [ -f "$PROXIES" ] || die "proxies file not found: $PROXIES  (set PROXIES=/path/to/list)"; }
need_feed_env() {
  [ -n "$INGEST_ENDPOINT" ]          || die "INGEST_ENDPOINT not set"
  [ -n "$RESTAURANT_INGEST_SECRET" ] || die "RESTAURANT_INGEST_SECRET not set"
  [ -f "$FEEDER" ]                   || die "feeder not found: $FEEDER"
}

scrape() { # $1=input  $2=results  $3=log
  "$SCRAPER" -input "$1" -results "$2" \
    -json -email -extra-reviews -review-sort "$REVIEW_SORT" -max-reviews "$MAX_REVIEWS" \
    -depth "$DEPTH" -c "$CONCURRENCY" -proxies-file "$PROXIES" \
    -exit-on-inactivity "$INACTIVITY" 2> "$3"
}

phase_base() {
  need_scraper; need_proxies
  [ -f "$PARISH_LIST" ] || die "parish list not found: $PARISH_LIST"
  mkdir -p "$OUT_DIR"
  log "Phase 1/4 — base pass over parishes"
  scrape "$PARISH_LIST" "$BASE_JSON" "$BASE_LOG"
  log "base pass done: $(wc -l < "$BASE_JSON" 2>/dev/null || echo 0) places -> $BASE_JSON"
}

phase_boost_gen() {
  [ -f "$BASE_LOG" ] || die "base log not found: $BASE_LOG  (run 'base' first)"
  log "Phase 2/4 — detect saturation & generate boosters (threshold $THRESHOLD)"
  node "$GEN" "$BASE_LOG" --threshold "$THRESHOLD" --out "$BOOST_QUERIES"
}

phase_boost() {
  need_scraper; need_proxies
  [ -f "$BOOST_QUERIES" ] || die "no booster queries: $BOOST_QUERIES  (run 'boost-gen' first)"
  if [ ! -s "$BOOST_QUERIES" ]; then log "no saturated parishes — skipping booster pass"; return 0; fi
  mkdir -p "$OUT_DIR"
  log "Phase 3/4 — booster pass ($(wc -l < "$BOOST_QUERIES") queries)"
  scrape "$BOOST_QUERIES" "$BOOST_JSON" "$BOOST_LOG"
  log "booster pass done: $(wc -l < "$BOOST_JSON" 2>/dev/null || echo 0) places -> $BOOST_JSON"
}

phase_feed() {
  need_feed_env
  local feeder_root; feeder_root="$(cd "$(dirname "$FEEDER")/.." && pwd)"  # justnomnom repo (scripts/..)
  log "Phase 4/4 — feed to ingest API ($INGEST_ENDPOINT)"
  local fed=0
  for f in "$BASE_JSON" "$BOOST_JSON"; do
    if [ ! -f "$f" ]; then log "skip (missing): $f"; continue; fi
    log "feeding $f"
    ( cd "$feeder_root" && \
      INGEST_ENDPOINT="$INGEST_ENDPOINT" RESTAURANT_INGEST_SECRET="$RESTAURANT_INGEST_SECRET" \
      CONCURRENCY="$INGEST_CONCURRENCY" node "$FEEDER" "$f" )
    fed=1
  done
  [ "$fed" = 1 ] || die "nothing to feed — run the scrape phases first"
}

phases="${*:-all}"

# Fail fast: validate feed env up front so a long scrape isn't wasted.
case " $phases " in *" feed "*|*" all "*) need_feed_env ;; esac

for p in $phases; do
  case "$p" in
    base)      phase_base ;;
    boost-gen) phase_boost_gen ;;
    boost)     phase_boost ;;
    feed)      phase_feed ;;
    discover)  phase_base; phase_boost_gen; phase_boost ;;
    all)       phase_base; phase_boost_gen; phase_boost; phase_feed ;;
    *) die "unknown phase: $p  (use: base | boost-gen | boost | feed | discover | all)";;
  esac
done

log "pipeline complete: $phases"
