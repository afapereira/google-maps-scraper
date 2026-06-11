#!/usr/bin/env python3
"""
scrape-full-coverage.py — Multi-pass adaptive grid scraping for Google Maps.

Strategy
--------
Run multiple passes over the same bounding box with decreasing cell sizes
(coarse → fine).  Each pass lets the scraper fill gaps the previous pass
missed because the ~120-result-per-cell cap cut results short in dense areas.
After every pass, results are merged and deduplicated by place_id.  The
script stops automatically when a pass adds fewer than --min-gain-pct% new
unique places (i.e. coverage is saturated).

Why this works
--------------
Google Maps caps results at ~120 per search cell.  A 2 km cell in a dense
neighbourhood hits that cap; a 0.5 km cell of the same area returns ~10-30
results — well below the cap.  Running coarse first is fast (fewer cells) and
gets the bulk of places.  Each finer pass fills the dense pockets that were
truncated.  Deduplication by place_id means no place is counted twice.

Usage
-----
  # Build the scraper first:  go build -o google-maps-scraper.exe .
  python3 scripts/scrape-full-coverage.py \\
    --bbox "38.69,-9.23,38.80,-9.09" \\
    --query "restaurants" \\
    --bin ./google-maps-scraper.exe \\
    --out restaurants/out/restaurants-full.json \\
    --proxies-file restaurants/proxies-comma.txt

  # Faster run (no emails, no extra reviews, coarser grid):
  python3 scripts/scrape-full-coverage.py \\
    --bbox "38.69,-9.23,38.80,-9.09" \\
    --query "restaurants" \\
    --bin ./google-maps-scraper.exe \\
    --out restaurants/out/restaurants-full.json \\
    --cell-sizes "2,1" --no-email --no-reviews --depth 20

  # Resume an interrupted run (existing output is loaded and extended):
  python3 scripts/scrape-full-coverage.py ... --resume

Flags
-----
  --bbox          minLat,minLon,maxLat,maxLon
  --query         Search term passed to every grid cell (e.g. "restaurants")
  --bin           Path to scraper binary (build with: go build -o google-maps-scraper.exe .)
  --out           Output JSON file (array of place objects)
  --cell-sizes    Comma-separated cell sizes in km, coarse→fine (default: 2,1,0.5)
  --min-gain-pct  Stop when a pass adds fewer than this % new places (default: 3.0)
  --depth         Scroll depth per cell (default: 30; higher = more results but slower)
  --concurrency   Parallel browser tabs during each pass (default: 2)
  --inactivity    Exit-on-inactivity timeout per pass (default: 15m)
  --no-email      Skip email scraping (much faster)
  --no-reviews    Skip extra reviews (much faster)
  --resume        Load existing --out file and skip any pass that adds 0 new places
  --proxies-file  Path to comma-separated proxy file (e.g. restaurants/proxies-comma.txt)
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from typing import Dict, List, Tuple


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def place_uid(entry: Dict) -> str:
    """Best unique key for a place — prefer place_id, fall back to link."""
    return (
        entry.get("place_id")
        or entry.get("cid")
        or entry.get("data_id")
        or entry.get("link", "")
    )


def merge_into(store: Dict[str, Dict], entries: List[Dict]) -> int:
    """Add entries to store (keyed by uid). Returns count of genuinely new places."""
    added = 0
    for e in entries:
        uid = place_uid(e)
        if not uid:
            continue
        if uid not in store:
            added += 1
        store[uid] = e
    return added


def save_atomic(store: Dict[str, Dict], path: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(list(store.values()), f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def load_existing(path: str) -> Dict[str, Dict]:
    store: Dict[str, Dict] = {}
    if not (os.path.exists(path) and os.path.getsize(path) > 0):
        return store
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, list):
            for e in data:
                uid = place_uid(e)
                if uid:
                    store[uid] = e
        print(f"Resumed: loaded {len(store)} existing places from {path}")
    except Exception as exc:
        print(f"Warning: could not load existing output ({exc}); starting fresh.", file=sys.stderr)
    return store


# ---------------------------------------------------------------------------
# Scraper runner
# ---------------------------------------------------------------------------

def estimate_cell_count(bbox: str, cell_km: float) -> int:
    """Rough cell count estimate (lat × lon, rectangular approximation)."""
    parts = [float(x) for x in bbox.split(",")]
    min_lat, min_lon, max_lat, max_lon = parts
    import math
    lat_km = (max_lat - min_lat) * 111.32
    mid_lat_rad = math.radians((min_lat + max_lat) / 2)
    lon_km = (max_lon - min_lon) * 111.32 * abs(math.cos(mid_lat_rad))
    lat_cells = max(1, math.ceil(lat_km / cell_km))
    lon_cells = max(1, math.ceil(lon_km / cell_km))
    return lat_cells * lon_cells


def run_pass(
    bin_path: str,
    query: str,
    bbox: str,
    cell_km: float,
    depth: int,
    concurrency: int,
    inactivity: str,
    extra_args: List[str],
    docker_image: str = "",
    proxies_file: str = "",
) -> List[Dict]:
    """Run one full-bbox pass at cell_km resolution. Returns parsed place list."""
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".txt", delete=False, encoding="utf-8"
    ) as qf:
        qf.write(query + "\n")
        query_file = qf.name

    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as rf:
        results_file = rf.name
    # Docker needs a pre-existing writable file to mount
    open(results_file, "w").close()

    try:
        if docker_image:
            cmd = _build_docker_cmd(
                docker_image, query_file, results_file, proxies_file,
                bbox, cell_km, depth, concurrency, inactivity, extra_args,
            )
        else:
            cmd = [
                bin_path,
                "-input", query_file,
                "-results", results_file,
                "-json",
                "-grid-bbox", bbox,
                "-grid-cell", str(cell_km),
                "-depth", str(depth),
                "-c", str(concurrency),
                "-exit-on-inactivity", inactivity,
                *extra_args,
            ]

        print(f"  running: {' '.join(cmd)}", flush=True)
        proc = subprocess.run(cmd, check=False)
        if proc.returncode not in (0, 1):
            print(f"  warning: scraper exited with code {proc.returncode}", file=sys.stderr)

        if os.path.exists(results_file) and os.path.getsize(results_file) > 0:
            results = []
            with open(results_file, encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                        if isinstance(obj, list):
                            results.extend(obj)
                        elif isinstance(obj, dict):
                            results.append(obj)
                    except json.JSONDecodeError:
                        pass
            return results
        return []

    except Exception as exc:
        print(f"  warning: error reading results: {exc}", file=sys.stderr)
        return []
    finally:
        for p in (query_file, results_file):
            try:
                if p and os.path.exists(p):
                    os.unlink(p)
            except OSError:
                pass


def _build_docker_cmd(
    image: str,
    query_file: str,
    results_file: str,
    proxies_file: str,
    bbox: str,
    cell_km: float,
    depth: int,
    concurrency: int,
    inactivity: str,
    extra_args: List[str],
) -> List[str]:
    """Build a docker run command that mirrors the binary call."""
    scraper_flags = (
        f"-input /queries.txt -results /out.json -json"
        f" -grid-bbox '{bbox}' -grid-cell {cell_km}"
        f" -depth {depth} -c {concurrency}"
        f" -exit-on-inactivity {inactivity}"
    )
    for a in extra_args:
        # proxies-file is handled via volume mount below
        if a != "-proxies-file" and not a.endswith(".txt"):
            scraper_flags += f" {a}"

    abs_query = os.path.abspath(query_file)
    abs_results = os.path.abspath(results_file)

    dr = [
        "docker", "run", "--rm",
        "-v", f"{abs_query}:/queries.txt:ro",
        "-v", f"{abs_results}:/out.json",
        "-e", "DISABLE_TELEMETRY=1",
        "--entrypoint", "/bin/sh",
    ]

    if proxies_file and os.path.isfile(proxies_file):
        abs_proxies = os.path.abspath(proxies_file)
        dr += ["-v", f"{abs_proxies}:/proxies.txt:ro"]
        inner = (
            f'PROXIES=$(tr -d "\\n\\r" < /proxies.txt) && '
            f'exec /usr/bin/google-maps-scraper {scraper_flags} -proxies "$PROXIES"'
        )
    else:
        inner = f'exec /usr/bin/google-maps-scraper {scraper_flags}'

    dr += [image, "-c", inner]
    return dr


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Multi-pass adaptive grid scraper for Google Maps",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--bbox", required=True,
                        help="minLat,minLon,maxLat,maxLon  (e.g. 38.69,-9.23,38.80,-9.09)")
    parser.add_argument("--query", required=True,
                        help='Search term for every cell (e.g. "restaurants")')
    parser.add_argument("--bin", required=True,
                        help="Path to google-maps-scraper binary")
    parser.add_argument("--out", required=True,
                        help="Output JSON file (array of place objects)")
    parser.add_argument("--cell-sizes", default="2,1,0.5",
                        help="Comma-separated cell sizes in km, coarse→fine (default: 2,1,0.5)")
    parser.add_argument("--min-gain-pct", type=float, default=3.0,
                        help="Stop when a pass adds fewer than this %% new places (default: 3.0)")
    parser.add_argument("--depth", type=int, default=30,
                        help="Scroll depth per cell (default: 30)")
    parser.add_argument("--concurrency", type=int, default=2,
                        help="Parallel browser tabs (default: 2)")
    parser.add_argument("--inactivity", default="15m",
                        help="Exit-on-inactivity timeout per pass (default: 15m)")
    parser.add_argument("--no-email", action="store_true",
                        help="Skip email scraping")
    parser.add_argument("--no-reviews", action="store_true",
                        help="Skip extra reviews")
    parser.add_argument("--resume", action="store_true",
                        help="Load existing --out and extend it (default: overwrite)")
    parser.add_argument("--proxies-file", default="",
                        help="Path to comma-separated proxy file")
    parser.add_argument("--docker-image", default="",
                        help="Use Docker instead of a local binary (e.g. gosom/google-maps-scraper)")
    args = parser.parse_args()

    # When --docker-image is given, always use Docker (even if a local binary
    # exists). The local Playwright build also handles authenticated proxies
    # (scrapemate strips user:pass into a local auth proxy), so Docker is just
    # an alternative runtime, not a requirement.
    use_docker = bool(args.docker_image)
    if not use_docker and not os.path.isfile(args.bin):
        print(f"ERROR: scraper binary not found: {args.bin}  (pass --docker-image to use Docker)", file=sys.stderr)
        sys.exit(1)

    # Parse cell sizes
    try:
        cell_sizes = [float(x.strip()) for x in args.cell_sizes.split(",") if x.strip()]
        assert cell_sizes
    except Exception:
        print("ERROR: --cell-sizes must be comma-separated numbers (e.g. 2,1,0.5)", file=sys.stderr)
        sys.exit(1)

    # Extra scraper args
    extra_args: List[str] = []
    if not args.no_email:
        extra_args += ["-email"]
    if not args.no_reviews:
        extra_args += ["-extra-reviews"]
    # proxies-file is passed separately so Docker can volume-mount it
    if args.proxies_file and not use_docker:
        if not os.path.isfile(args.proxies_file):
            print(f"WARNING: --proxies-file not found: {args.proxies_file}", file=sys.stderr)
        else:
            extra_args += ["-proxies-file", args.proxies_file]

    # Load existing results if resuming
    store: Dict[str, Dict] = load_existing(args.out) if args.resume else {}

    print()
    print("=" * 60)
    print("  Google Maps - Full Coverage Multi-Pass Scraper")
    print("=" * 60)
    runner_label = f"Docker ({args.docker_image})" if use_docker else args.bin
    print(f"  runner:      {runner_label}")
    print(f"  bbox:        {args.bbox}")
    print(f"  query:       {args.query}")
    print(f"  passes:      {cell_sizes} km")
    print(f"  stop when:   pass gain < {args.min_gain_pct}% new places")
    print(f"  depth:       {args.depth} scroll rounds/cell")
    print(f"  concurrency: {args.concurrency} browser tabs")
    print(f"  proxies:     {args.proxies_file or 'none'}")
    print(f"  output:      {args.out}")
    print()

    total_passes = len(cell_sizes)
    session_start = time.time()

    for pass_idx, cell_km in enumerate(cell_sizes, 1):
        approx_cells = estimate_cell_count(args.bbox, cell_km)
        before = len(store)

        print(f"--- Pass {pass_idx}/{total_passes}: cell_size={cell_km} km  (~{approx_cells} cells) ---", flush=True)
        pass_start = time.time()

        entries = run_pass(
            args.bin, args.query, args.bbox,
            cell_km, args.depth, args.concurrency,
            args.inactivity, extra_args,
            docker_image=args.docker_image if use_docker else "",
            proxies_file=args.proxies_file,
        )

        added = merge_into(store, entries)
        elapsed = time.time() - pass_start
        total = len(store)
        gain_pct = (added / before * 100) if before > 0 else 100.0

        print(
            f"  scraped={len(entries)}  new={added}  gain={gain_pct:.1f}%  "
            f"total={total}  elapsed={elapsed:.0f}s",
            flush=True,
        )

        save_atomic(store, args.out)
        print(f"  saved {total} places to {args.out}")

        # Early-stop check (skip on first pass — always run at least two)
        if pass_idx > 1 and gain_pct < args.min_gain_pct:
            print(
                f"\nGain {gain_pct:.1f}% is below the {args.min_gain_pct}% threshold "
                f"— coverage saturated after {pass_idx} pass(es). Stopping early."
            )
            break

        if pass_idx < total_passes:
            print(f"  next pass: {cell_sizes[pass_idx]} km cells\n")

    total_elapsed = time.time() - session_start
    print()
    print("=" * 60)
    print(f"  Done — {len(store)} unique places  ({total_elapsed:.0f}s total)")
    print(f"  Output: {args.out}")
    print("=" * 60)


if __name__ == "__main__":
    main()
