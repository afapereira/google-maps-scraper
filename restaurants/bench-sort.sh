#!/usr/bin/env bash
# Time one chunk under a given review-sort so the RPC-vs-DOM cost is measured,
# not guessed. Both arms MUST use the same chunk and the same -c to compare.
#
#   ./bench-sort.sh newest 013
#   ./bench-sort.sh relevant 013
#
# Writes TEST-<sort>-<chunk>.{json,log,result} into restaurants/out.
# Never writes a .done — this must not affect the real run's resume state.
set -u
export PATH="/usr/bin:/bin:$PATH"

SORT="${1:-newest}"
CHUNK="${2:-013}"
CONC="${CONC:-2}"
MAX_REVIEWS="${MAX_REVIEWS:-100}"

ROOT="C:/Users/andre/Downloads/google-maps-scraper"
OUT="$ROOT/restaurants/out"
IN="$OUT/chunks/parish-chunk-$CHUNK.txt"
RES="$OUT/TEST-$SORT-$CHUNK.json"
LOG="$OUT/TEST-$SORT-$CHUNK.log"
OUTCOME="$OUT/TEST-$SORT-$CHUNK.result"

[ -f "$IN" ] || { echo "no such chunk: $IN" >&2; exit 1; }
rm -f "$RES" "$LOG" "$OUTCOME"

start=$(date +%s)
echo "START $(date '+%F %T') sort=$SORT chunk=$CHUNK c=$CONC max_reviews=$MAX_REVIEWS" > "$OUTCOME"

"$ROOT/google-maps-scraper.exe" -input "$IN" -results "$RES" \
  -json -extra-reviews -review-sort "$SORT" -max-reviews "$MAX_REVIEWS" \
  -depth 20 -c "$CONC" -exit-on-inactivity 10m 2> "$LOG"
rc=$?

end=$(date +%s)
elapsed=$(( end - start ))
places=$(wc -l < "$RES" 2>/dev/null | tr -d ' '); places=${places:-0}
rpc=$(grep -c "RPC extraction successful" "$LOG" 2>/dev/null); rpc=${rpc:-0}
dom=$(grep -c "DOM extraction.*successful" "$LOG" 2>/dev/null); dom=${dom:-0}

{
  echo "END      $(date '+%F %T')  exit=$rc"
  echo "ELAPSED  ${elapsed}s ($(( elapsed / 60 )) min)"
  echo "PLACES   $places"
  [ "$places" -gt 0 ] && echo "RATE     $(( places * 3600 / (elapsed>0?elapsed:1) )) places/hour"
  [ "$places" -gt 0 ] && echo "PER_PLACE $(( elapsed / places ))s"
  echo "PATH_RPC $rpc"
  echo "PATH_DOM $dom"
} >> "$OUTCOME"

cat "$OUTCOME"
