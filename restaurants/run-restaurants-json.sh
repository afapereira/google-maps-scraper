#!/usr/bin/env bash
#
# Scrape Google Maps for restaurants: JSON output, website emails, extended reviews.
# Run from the repo: bash restaurants/run-restaurants-json.sh
#
# This directory holds:
#   restaurant-queries.txt  — one Maps search per line
#   proxies-comma.txt       — written by this script via scripts/fetch-public-proxies.sh (validated only)
#   out/                    — all JSON results (see OUT below)
#
# Proxies (USE_PROXIES=1):
#   Before scraping, the fetch script runs with live validation (curl via each proxy to HTTPS).
#   Only proxies that pass are written — never a raw unvalidated list. Override with REFRESH_PROXIES=0
#   to reuse the existing proxies-comma.txt without refetching.
#
# Prerequisites:
#   - Docker: docker pull gosom/google-maps-scraper (default runner when docker is on PATH)
#   - Or build locally: (repo root) go build -o google-maps-scraper.exe .
#   - With USE_PROXIES=1 and anonymous lists (http://ip:port), without Docker: also build Rod binary:
#       go build -tags rod -o google-maps-scraper-rod.exe .
#
# Env (optional):
#   OUT, QUERIES, PROXIES_FILE, DEPTH, CONCURRENCY, INACTIVITY
#   DEPTH — default 100 (max scroll rounds in Maps results). The Go binary requires depth >= 1; there is no
#           true "infinite" flag. Use 0, max, or unlimited (case-insensitive) as aliases for 100.
#   USE_PROXIES — default 1: pass -proxies-file when using Rod. Set 0 for direct connection.
#   ALLOW_DIRECT_ON_NO_PROXY — default 1: if proxy fetch yields an empty file, continue without proxies
#                              instead of exiting (free lists often yield zero usable proxies).
#   REFRESH_PROXIES — default 1 with USE_PROXIES=1: rebuild proxies-comma.txt via fetch-public-proxies.sh
#                     (validated only). Set 0 to reuse the current file.
#   PROXY_FETCH_MAX — default 55: stop after this many good unique proxies (fetch script --max).
#   USE_DOCKER — default 1: use gosom/google-maps-scraper when `docker` is available. Set 0 to prefer local binaries.
#   DOCKER_IMAGE — default gosom/google-maps-scraper (e.g. gosom/google-maps-scraper:latest-rod for Rod).
#   EMAIL_REVIEWS — default 1: pass -email -extra-reviews (slow). Set 0 for place data only (much faster).
#   INACTIVITY — default 120m (email + extra-reviews + deep scroll needs long idle tolerance).
#   PROXY_VALIDATE_URL — optional; export before run to change the URL curl uses when testing each proxy
#                         (default in fetch script: https://www.google.com/).
#   Further tuning: scripts/fetch-public-proxies.sh — PROXY_STRICT_CHROME (default 1), PROXY_STRICT_BODY_CHECK,
#     PROXY_MAPS_RECHECK=1 for a second Maps fetch, PROXY_STRICT_CHROME=0 to restore legacy fast curl checks.

set -euo pipefail

REST_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$REST_DIR/.." && pwd)"
cd "$REST_DIR"

OUT="${OUT:-out/restaurants-full.json}"
QUERIES="${QUERIES:-restaurant-queries.txt}"
PROXIES_FILE="${PROXIES_FILE:-proxies-comma.txt}"
USE_PROXIES="${USE_PROXIES:-1}"
ALLOW_DIRECT_ON_NO_PROXY="${ALLOW_DIRECT_ON_NO_PROXY:-1}"
REFRESH_PROXIES="${REFRESH_PROXIES:-1}"
PROXY_FETCH_MAX="${PROXY_FETCH_MAX:-55}"
EMAIL_REVIEWS="${EMAIL_REVIEWS:-1}"
CONCURRENCY="${CONCURRENCY:-2}"
INACTIVITY="${INACTIVITY:-120m}"

# -depth must be >= 1 in the scraper; default 100 ≈ deepest practical scroll (alias: 0, max, unlimited).
_depth_env="${DEPTH:-}"
if [[ -z "$_depth_env" ]]; then
	DEPTH=100
elif [[ "$_depth_env" == "0" ]] || [[ "${_depth_env,,}" == "unlimited" ]] || [[ "${_depth_env,,}" == "max" ]]; then
	DEPTH=100
else
	DEPTH="$_depth_env"
fi
if ! [[ "$DEPTH" =~ ^[0-9]+$ ]] || [[ "$DEPTH" -lt 1 ]]; then
	echo "run-restaurants-json: invalid DEPTH (got: ${DEPTH:-empty}); use a positive integer, 0, max, or unlimited" >&2
	exit 1
fi

export DISABLE_TELEMETRY="${DISABLE_TELEMETRY:-1}"

USE_DOCKER="${USE_DOCKER:-1}"
DOCKER_IMAGE="${DOCKER_IMAGE:-gosom/google-maps-scraper}"

FETCH_SCRIPT="$REPO_ROOT/scripts/fetch-public-proxies.sh"

mkdir -p "$(dirname "$REST_DIR/$OUT")"

if [[ ! -f "$REST_DIR/$QUERIES" ]]; then
	echo "run-restaurants-json: missing queries file: $REST_DIR/$QUERIES" >&2
	exit 1
fi

PROXY_ARGS=()
if [[ "$USE_PROXIES" != 0 ]]; then
	_need_fetch=0
	if [[ ! -f "$REST_DIR/$PROXIES_FILE" ]]; then
		_need_fetch=1
	elif [[ "$REFRESH_PROXIES" != 0 ]]; then
		_need_fetch=1
	fi

	if [[ "$_need_fetch" -eq 1 ]]; then
		if [[ ! -f "$FETCH_SCRIPT" ]]; then
			echo "run-restaurants-json: missing $FETCH_SCRIPT (cannot fetch validated proxies)" >&2
			exit 1
		fi
		echo "run-restaurants-json: fetching validated HTTP proxies (max ${PROXY_FETCH_MAX} good) → $REST_DIR/$PROXIES_FILE ..." >&2
		# fetch-public-proxies tests each candidate with curl; only successes are written.
		# Override test URL: export PROXY_VALIDATE_URL before running this script.
		SKIP_PROXY_VALIDATION=0 bash "$FETCH_SCRIPT" -p http --comma --max "$PROXY_FETCH_MAX" \
			-o "$REST_DIR/$PROXIES_FILE" --fast
	fi

	if [[ ! -s "$REST_DIR/$PROXIES_FILE" ]]; then
		if [[ "${ALLOW_DIRECT_ON_NO_PROXY}" != 0 ]]; then
			echo "run-restaurants-json: no validated proxies in $REST_DIR/$PROXIES_FILE — continuing with direct connection (ALLOW_DIRECT_ON_NO_PROXY=0 to fail instead)" >&2
			USE_PROXIES=0
		else
			echo "run-restaurants-json: no validated proxies in $REST_DIR/$PROXIES_FILE (try USE_PROXIES=0, PROXY_FETCH_MAX, or scripts/fetch-public-proxies.sh)" >&2
			exit 1
		fi
	fi
fi

if [[ "$USE_PROXIES" != 0 ]]; then
	PROXY_ARGS=(-proxies-file "$REST_DIR/$PROXIES_FILE")
	_proxy_count=$(tr ',' '\n' < "$REST_DIR/$PROXIES_FILE" | grep -cve '^[[:space:]]*$' || echo 0)
	echo "Using validated proxies from $REST_DIR/$PROXIES_FILE (${_proxy_count} URL(s))" >&2
else
	echo "run-restaurants-json: direct connection (no -proxies-file)" >&2
fi

run_local() {
	local BIN="$1"
	shift
	exec "$BIN" "$@"
}

ARGS_BASE=(
	-input "$REST_DIR/$QUERIES"
	-results "$REST_DIR/$OUT"
	-json
	-exit-on-inactivity "$INACTIVITY"
	-c "$CONCURRENCY"
	-depth "$DEPTH"
)
if [[ "${EMAIL_REVIEWS}" != 0 ]]; then
	ARGS_BASE+=( -email -extra-reviews )
fi

run_docker() {
	echo "Using Docker ($DOCKER_IMAGE)" >&2
	local -a dr=(
		docker run --rm
		-v "$REST_DIR/$QUERIES:/queries.txt:ro"
		-v "$REST_DIR/$OUT:/out.json"
		-e "DISABLE_TELEMETRY=$DISABLE_TELEMETRY"
		-e "GMS_C=$CONCURRENCY"
		-e "GMS_DEPTH=$DEPTH"
		-e "GMS_IDLE=$INACTIVITY"
		--entrypoint /bin/sh
		"$DOCKER_IMAGE"
	)
	if [[ "$USE_PROXIES" != 0 ]]; then
		dr+=( -v "$REST_DIR/$PROXIES_FILE:/proxies.txt:ro" )
	fi

	local inner
	if [[ "$USE_PROXIES" != 0 ]]; then
		if [[ "${EMAIL_REVIEWS}" != 0 ]]; then
			inner='PROXIES=$(tr -d "\n\r" < /proxies.txt) && exec /usr/bin/google-maps-scraper -input /queries.txt -results /out.json -json -email -extra-reviews -proxies "$PROXIES" -exit-on-inactivity "$GMS_IDLE" -c "$GMS_C" -depth "$GMS_DEPTH"'
		else
			inner='PROXIES=$(tr -d "\n\r" < /proxies.txt) && exec /usr/bin/google-maps-scraper -input /queries.txt -results /out.json -json -proxies "$PROXIES" -exit-on-inactivity "$GMS_IDLE" -c "$GMS_C" -depth "$GMS_DEPTH"'
		fi
	else
		if [[ "${EMAIL_REVIEWS}" != 0 ]]; then
			inner='exec /usr/bin/google-maps-scraper -input /queries.txt -results /out.json -json -email -extra-reviews -exit-on-inactivity "$GMS_IDLE" -c "$GMS_C" -depth "$GMS_DEPTH"'
		else
			inner='exec /usr/bin/google-maps-scraper -input /queries.txt -results /out.json -json -exit-on-inactivity "$GMS_IDLE" -c "$GMS_C" -depth "$GMS_DEPTH"'
		fi
	fi
	dr+=( -c "$inner" )
	"${dr[@]}"
}

if [[ "${USE_DOCKER}" != 0 ]] && command -v docker >/dev/null 2>&1; then
	run_docker
	exit $?
fi

if [[ -f "$REPO_ROOT/google-maps-scraper-rod.exe" ]]; then
	if [[ "$USE_PROXIES" != 0 ]]; then
		echo "Using Rod binary (proxies: $REST_DIR/$PROXIES_FILE)" >&2
		run_local "$REPO_ROOT/google-maps-scraper-rod.exe" "${ARGS_BASE[@]}" "${PROXY_ARGS[@]}"
	else
		echo "Using Rod binary (direct connection)" >&2
		run_local "$REPO_ROOT/google-maps-scraper-rod.exe" "${ARGS_BASE[@]}"
	fi
fi

if [[ -x "$REPO_ROOT/google-maps-scraper-rod" ]]; then
	if [[ "$USE_PROXIES" != 0 ]]; then
		echo "Using Rod binary (proxies: $REST_DIR/$PROXIES_FILE)" >&2
		run_local "$REPO_ROOT/google-maps-scraper-rod" "${ARGS_BASE[@]}" "${PROXY_ARGS[@]}"
	else
		echo "Using Rod binary (direct connection)" >&2
		run_local "$REPO_ROOT/google-maps-scraper-rod" "${ARGS_BASE[@]}"
	fi
fi

if [[ -x "$REPO_ROOT/google-maps-scraper" ]]; then
	echo "Using local binary (Playwright)" >&2
	run_local "$REPO_ROOT/google-maps-scraper" "${ARGS_BASE[@]}" "${PROXY_ARGS[@]}"
fi

if [[ -f "$REPO_ROOT/google-maps-scraper.exe" ]]; then
	echo "Using local binary (Playwright)" >&2
	run_local "$REPO_ROOT/google-maps-scraper.exe" "${ARGS_BASE[@]}" "${PROXY_ARGS[@]}"
fi

echo "run-restaurants-json: install Docker and ensure it is on PATH, or build with 'go build -o google-maps-scraper.exe .' in repo root (USE_DOCKER=0 to skip Docker)." >&2
exit 1
