#!/usr/bin/env bash
#
# Aggregate public proxy lists from GitHub mirrors and free proxy APIs, formatted
# for google-maps-scraper -proxies (protocol://host:port).
#
# Sources (verify terms/rate limits before heavy use):
#   GitHub: TheSpeedX/PROXY-List, monosans/proxy-list, Thordata/awesome-free-proxy-list,
#           clarketm/proxy-list, theriturajps/proxy-list, jetkai/proxy-list, hw630590/free-proxy-list,
#           ShiftyTR/Proxy-List, mmpx12/proxy-list, roosterkid/openproxylist (HTTPS + SOCKS files)
#   APIs:  ProxyScrape, Geonode proxy-list, PubProxy
#   Optional (env): GETPROXYLIST_API_KEY — api.getproxylist.com (repeated single-proxy calls)
#                   PROXY_TOOLS_BEARER — proxy-tools.com API
#
# Requires: bash, curl, grep, sort; for JSON APIs: jq OR Python (python3 / python / py -3)
#
# Usage:
#   ./scripts/fetch-public-proxies.sh --protocol http
#   GEONODE_MAX_PAGES=5 ./scripts/fetch-public-proxies.sh -p socks5 -o proxies.txt
#   GEONODE_ABSOLUTE_MAX_PAGES=0 ./scripts/fetch-public-proxies.sh -p http
#   GETPROXYLIST_API_KEY=... ./scripts/fetch-public-proxies.sh -p http --max 200
#   ./scripts/fetch-public-proxies.sh --fast --log-file fetch.log -o proxies.txt --comma --max 25
#
# Flags:
#   --fast              Shorter timeouts, lower default candidate cap (see FETCH_FAST)
#   --log-file PATH     Write progress lines to PATH (see FETCH_LOG_FILE)
#
# Env:
#   GEONODE_PAGE_SIZE       Proxies per Geonode request (default 500, max per API)
#   GEONODE_MAX_PAGES       Cap pages (0 = no cap — fetch all pages implied by API total)
#   GEONODE_ABSOLUTE_MAX_PAGES  Hard safety ceiling when uncapped (default 200; 0 = disable)
#   PROXY_TOOLS_PAGE_LIMIT  Proxies per Proxy-Tools page (default 100, API max 100)
#   PROXY_TOOLS_MAX_PAGES   Max page index to request (default 500)
#   PUBPROXY_REQUESTS       PubProxy calls to merge (no offset API; default 4 × limit 100)
#   GETPROXYLIST_REQUESTS   GetProxyList: one proxy per HTTP call (default 30)
#   FETCH_RETRY_DELAY_SEC   Pause before the single retry (default 1; set 0 to disable)
#   SKIP_PROXY_VALIDATION   If 1, skip live checks (not recommended). Otherwise every candidate
#                           is tested with curl through it to PROXY_VALIDATE_URL; only HTTP ok
#                           responses are written to the output file.
#   FETCH_FAST              If 1 or --fast: smaller default PROXY_VALIDATE_MAX, shorter curl timeouts,
#                           zero retry delay (override any default via explicit env).
#   FETCH_LOG_FILE          If set (or --log-file), append all progress lines here (still see stderr unless -q).
#   PROXY_SHUFFLE_CANDIDATES If non-zero (default 1) and shuf exists, randomize order before validation
#                           (sorted lists cluster dead subnets; shuffle finds hits sooner).
#   PROXY_VALIDATE_PARALLEL Max concurrent curl checks (default ~3× CPU cores, capped 16–40).
#   PROXY_VALIDATE_CONNECT  curl --connect-timeout seconds (default 5, or 4 with FETCH_FAST)
#   PROXY_VALIDATE_TIMEOUT  curl --max-time seconds (default 12, or 9 with FETCH_FAST)
#   PROXY_VALIDATE_URL      URL to fetch via proxy (default https://www.google.com/ — use HTTPS, not HTTP)
#   PROXY_DUAL_VALIDATION     If 1 (default): each proxy must pass PROXY_VALIDATE_URL then PROXY_VALIDATE_STAGE2_URL
#                             (Google + Maps). Much closer to Chromium/Rod; yields fewer but better proxies.
#   PROXY_VALIDATE_STAGE2_URL Second check (default https://www.google.com/maps). Set PROXY_DUAL_VALIDATION=0 to skip.
#   PROXY_STRICT_CHROME       If 1 (default): use Chrome-like curl headers (same family as Rod), enforce minimum
#                             connect (8s) and max-time (35s) so "fast" lists cannot pass with tiny curl-only windows.
#   PROXY_STRICT_BODY_CHECK   If 1 (default): response bodies must match ERE patterns (real HTML, not blank/captcha).
#   PROXY_CURL_UA             Override User-Agent (default matches Rod rodhttp Chrome/120 Windows).
#   PROXY_CURL_COMPRESSED     If 1 (default), add curl --compressed (set 0 if curl errors).
#   PROXY_GOOGLE_BODY_ERE     grep -E pattern for PROXY_VALIDATE_URL response (dual or single fallback).
#   PROXY_MAPS_BODY_ERE       grep -E pattern for Maps stage (dual validation).
#   PROXY_VALIDATE_BODY_ERE   Single-URL mode only: body pattern; defaults to PROXY_GOOGLE_BODY_ERE when strict.
#   PROXY_MAX_FILE_PRIMARY    Max bytes downloaded for primary URL check (default 524288).
#   PROXY_MAX_FILE_STAGE2     Max bytes for stage-2 Maps check (default 4194304 / 4 MB — Maps search pages are large).
#   PROXY_MAPS_RECHECK        If 1 (default): fetch Maps URL twice; both must pass (drops flaky proxies; slower).
#                             Set 0 to skip the second Maps check for speed.
#   PROXY_VALIDATE_TIMEOUT_STAGE2  max-time for the Maps stage curl (default: PROXY_VALIDATE_TIMEOUT+15, min 50s).
#                             Maps search pages load more JS than google.com; this prevents valid proxies
#                             from being rejected due to under-timed downloads.
#   PROXY_PROXYSCRAPE_SSL_ONLY If 1 (default): ProxyScrape ssl=yes (proxies that advertise HTTPS support).
#   GEONODE_QUERY_EXTRA       Optional string appended to Geonode URLs e.g. '&anonymityLevel=elite' if your tier supports it.
#   PROXY_VALIDATE_MAX      Max deduped candidates to test (default 6000, or 4000 with FETCH_FAST; 0 = all — slow)
#   PROXY_VALIDATE_SOCKS5H  For socks5: use socks5h (DNS via proxy), default 1; set 0 for socks5
#   PROXY_SANE_FILTER       If non-zero (default 1), drop non-public/invalid IPv4 (e.g. 0.x.x.x,
#                           leading-zero octets, RFC1918) before validation/output.
#   PROXY_FETCH_LOG_INTERVAL  During validation, log progress every N lines queued (default 80;
#                             set 0 to disable intra-batch progress).
#
# Note: Each URL is tried twice on failure, then skipped. Free proxies are unreliable;
# cap --max when passing to -proxies to avoid shell limits.
# With validation enabled, --max N stops testing further candidates as soon as N proxies pass
# (still bounded by PROXY_VALIDATE_MAX candidates to try from the merged list).

set -u

PROTOCOL="http"
OUT_PATH=""
COMMA=0
MAX_LINES=0
QUIET=0
GEONODE_PAGE_SIZE="${GEONODE_PAGE_SIZE:-500}"
GEONODE_MAX_PAGES="${GEONODE_MAX_PAGES:-0}"
GEONODE_ABSOLUTE_MAX_PAGES="${GEONODE_ABSOLUTE_MAX_PAGES:-200}"
PROXY_TOOLS_PAGE_LIMIT="${PROXY_TOOLS_PAGE_LIMIT:-100}"
PROXY_TOOLS_MAX_PAGES="${PROXY_TOOLS_MAX_PAGES:-500}"
PUBPROXY_REQUESTS="${PUBPROXY_REQUESTS:-${PUBPROXY_BATCHES:-4}}"
GETPROXYLIST_REQUESTS="${GETPROXYLIST_REQUESTS:-30}"
SKIP_PROXY_VALIDATION="${SKIP_PROXY_VALIDATION:-0}"
PROXY_VALIDATE_URL="${PROXY_VALIDATE_URL:-https://www.google.com/}"
PROXY_DUAL_VALIDATION="${PROXY_DUAL_VALIDATION:-1}"
# Use a Maps search URL — much closer to what the scraper does; captcha/blocks surface here
# but not always on the Maps homepage.
PROXY_VALIDATE_STAGE2_URL="${PROXY_VALIDATE_STAGE2_URL:-https://www.google.com/maps/search/restaurants}"
PROXY_PROXYSCRAPE_SSL_ONLY="${PROXY_PROXYSCRAPE_SSL_ONLY:-1}"
FETCH_FAST="${FETCH_FAST:-0}"
FETCH_LOG_FILE="${FETCH_LOG_FILE:-}"
PROXY_SHUFFLE_CANDIDATES="${PROXY_SHUFFLE_CANDIDATES:-1}"

die() {
	echo "fetch-public-proxies: $*" >&2
	if [[ -n "${FETCH_LOG_FILE:-}" ]]; then
		echo "fetch-public-proxies: $*" >>"$FETCH_LOG_FILE"
	fi
	exit 1
}

# Timestamped log line: stderr unless -q; always appended when FETCH_LOG_FILE is set.
log_msg() {
	local ts line
	ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date 2>/dev/null || echo '?')
	line="[${ts}] fetch-public-proxies: $*"
	[[ "${QUIET:-0}" -eq 0 ]] && printf '%s\n' "$line" >&2
	if [[ -n "${FETCH_LOG_FILE:-}" ]]; then
		printf '%s\n' "$line" >>"$FETCH_LOG_FILE"
	fi
}

usage() {
	sed -n '1,130p' "$0" | tail -n +2
	exit 0
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-p | --protocol)
		[[ $# -lt 2 ]] && die "--protocol needs a value"
		PROTOCOL="$2"
		shift 2
		;;
	-o | --output)
		[[ $# -lt 2 ]] && die "--output needs a path"
		OUT_PATH="$2"
		shift 2
		;;
	--comma)
		COMMA=1
		shift
		;;
	--max)
		[[ $# -lt 2 ]] && die "--max needs a number"
		MAX_LINES="$2"
		shift 2
		;;
	-q | --quiet)
		QUIET=1
		shift
		;;
	--fast)
		FETCH_FAST=1
		shift
		;;
	--log-file)
		[[ $# -lt 2 ]] && die "--log-file needs a path"
		FETCH_LOG_FILE="$2"
		shift 2
		;;
	-h | --help)
		usage
		;;
	*)
		die "unknown option: $1 (try --help)"
		;;
	esac
done

case "$PROTOCOL" in
http | socks4 | socks5) ;;
*) die "protocol must be http, socks4, or socks5 (got: $PROTOCOL)" ;;
esac

_nproc=4
if command -v nproc >/dev/null 2>&1; then
	_nproc=$(nproc 2>/dev/null || echo 4)
fi
[[ "${_nproc}" =~ ^[0-9]+$ ]] || _nproc=4
_default_parallel=$((_nproc * 3))
[[ "$_default_parallel" -lt 16 ]] && _default_parallel=16
[[ "$_default_parallel" -gt 40 ]] && _default_parallel=40

if [[ "${FETCH_FAST}" == 1 ]]; then
	PROXY_VALIDATE_MAX="${PROXY_VALIDATE_MAX:-4000}"
	PROXY_VALIDATE_PARALLEL="${PROXY_VALIDATE_PARALLEL:-$_default_parallel}"
	PROXY_VALIDATE_CONNECT="${PROXY_VALIDATE_CONNECT:-5}"
	PROXY_VALIDATE_TIMEOUT="${PROXY_VALIDATE_TIMEOUT:-11}"
	PROXY_FETCH_LOG_INTERVAL="${PROXY_FETCH_LOG_INTERVAL:-50}"
	FETCH_RETRY_DELAY_SEC="${FETCH_RETRY_DELAY_SEC:-0}"
else
	PROXY_VALIDATE_MAX="${PROXY_VALIDATE_MAX:-6000}"
	PROXY_VALIDATE_PARALLEL="${PROXY_VALIDATE_PARALLEL:-$_default_parallel}"
	PROXY_VALIDATE_CONNECT="${PROXY_VALIDATE_CONNECT:-5}"
	PROXY_VALIDATE_TIMEOUT="${PROXY_VALIDATE_TIMEOUT:-12}"
	PROXY_FETCH_LOG_INTERVAL="${PROXY_FETCH_LOG_INTERVAL:-80}"
	FETCH_RETRY_DELAY_SEC="${FETCH_RETRY_DELAY_SEC:-1}"
fi

# Stricter validation: align curl with Chromium (Rod) and reject non-HTML / trivial 200s.
PROXY_STRICT_CHROME="${PROXY_STRICT_CHROME:-1}"
PROXY_STRICT_BODY_CHECK="${PROXY_STRICT_BODY_CHECK:-1}"
if [[ "${PROXY_STRICT_CHROME}" != 0 ]] && [[ "${SKIP_PROXY_VALIDATION}" -eq 0 ]]; then
	_bc="${PROXY_VALIDATE_CONNECT:-0}"
	_bt="${PROXY_VALIDATE_TIMEOUT:-0}"
	[[ "${_bc}" =~ ^[0-9]+$ ]] || _bc=0
	[[ "${_bt}" =~ ^[0-9]+$ ]] || _bt=0
	[[ "${_bc}" -lt 8 ]] && PROXY_VALIDATE_CONNECT=8
	[[ "${_bt}" -lt 32 ]] && PROXY_VALIDATE_TIMEOUT=35
fi

if [[ -n "${FETCH_LOG_FILE}" ]]; then
	: >"$FETCH_LOG_FILE" || die "cannot write --log-file / FETCH_LOG_FILE: $FETCH_LOG_FILE"
fi

_dual="off"
[[ "${SKIP_PROXY_VALIDATION}" -eq 0 ]] && [[ "${PROXY_DUAL_VALIDATION:-0}" != 0 ]] && [[ -n "${PROXY_VALIDATE_STAGE2_URL:-}" ]] && _dual="on (${PROXY_VALIDATE_STAGE2_URL})"
_strict="strict_chrome=${PROXY_STRICT_CHROME:-1}, body=${PROXY_STRICT_BODY_CHECK:-1}"
log_msg "start — protocol=${PROTOCOL}, --max=${MAX_LINES:-0} (0=unlimited), output=${OUT_PATH:-stdout}, comma_mode=${COMMA}, fast=${FETCH_FAST}, validate=$( [[ "${SKIP_PROXY_VALIDATION}" -eq 1 ]] && echo off || echo on ), dual=${_dual}, ${_strict}, log=${FETCH_LOG_FILE:-stderr-only}"

if ! command -v curl >/dev/null 2>&1; then
	die "curl is required"
fi

# Prefer python3; on Windows, python3 is often a Microsoft Store shim — use python or py -3.
python_for_json() {
	if command -v python3 >/dev/null 2>&1 && python3 -c "pass" 2>/dev/null; then
		python3 "$@"
		return $?
	fi
	if command -v python >/dev/null 2>&1 && python -c "pass" 2>/dev/null; then
		python "$@"
		return $?
	fi
	if command -v py >/dev/null 2>&1 && py -3 -c "pass" 2>/dev/null; then
		py -3 "$@"
		return $?
	fi
	return 127
}

# IPv4 host:port or [IPv6]:port
filter_lines() {
	grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}:[0-9]+$|^\[[0-9a-fA-F:]+\]:[0-9]+$'
}

# Drop junk / non–globally-routable endpoints often found in scraped lists:
#   invalid IPv4 (leading zeros, octet >255), 0.0.0.0/8, RFC1918, loopback, CGNAT,
#   link-local, and reserved/multicast (>=224). IPv6 lines: basic port check only.
# Set PROXY_SANE_FILTER=0 to skip (not recommended).
filter_sane_proxy_lines() {
	if [[ "${PROXY_SANE_FILTER:-1}" == 0 ]]; then
		cat
		return
	fi
	awk '
	function is_reserved(a, b, c, d) {
		if (a == 0) return 1
		if (a == 10) return 1
		if (a == 127) return 1
		if (a == 169 && b == 254) return 1
		if (a == 172 && b >= 16 && b <= 31) return 1
		if (a == 192 && b == 168) return 1
		if (a == 100 && b >= 64 && b <= 127) return 1
		if (a >= 224) return 1
		return 0
	}
	/^\[[0-9a-fA-F:]+\]:[0-9]+$/ {
		i = index($0, "]:")
		if (i == 0) next
		port = substr($0, i + 2)
		if (port ~ /^[0-9]+$/ && port + 0 >= 1 && port + 0 <= 65535) print
		next
	}
	/^[0-9]{1,3}(\.[0-9]{1,3}){3}:[0-9]+$/ {
		idx = index($0, ":")
		ip = substr($0, 1, idx - 1)
		port = substr($0, idx + 1)
		if (port !~ /^[0-9]+$/ || port + 0 < 1 || port + 0 > 65535) next
		if (split(ip, o, ".") != 4) next
		for (i = 1; i <= 4; i++) {
			if (o[i] !~ /^[0-9]+$/) next
			if (length(o[i]) > 1 && substr(o[i], 1, 1) == "0") next
			v = o[i] + 0
			if (v < 0 || v > 255) next
			oi[i] = v
		}
		if (is_reserved(oi[1], oi[2], oi[3], oi[4])) next
		print
		next
	}
	'
}

# Lines with extra text (e.g. roosterkid/openproxylist "flag IP:PORT latency …")
extract_ip_port_loose() {
	grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}:[0-9]{1,5}' | grep -vE '^0\.0\.0\.0:' || true
}

# Two attempts per URL (initial + one retry). On failure, prints nothing; callers skip empty bodies.
fetch_url() {
	local url="$1"
	shift
	local attempt out
	for attempt in 1 2; do
		if out=$(curl -fsSL --connect-timeout 20 --max-time 180 "$@" "$url" 2>/dev/null); then
			printf '%s\n' "$out"
			return 0
		fi
		[[ "$attempt" -eq 2 ]] && break
		sleep "${FETCH_RETRY_DELAY_SEC:-1}" 2>/dev/null || true
	done
	log_msg "warning: failed after 2 attempts, skipping: $url"
	return 1
}

# curl -x scheme for this script's PROTOCOL (socks5h avoids local DNS for SOCKS).
curl_proxy_scheme() {
	case "$PROTOCOL" in
	http) echo "http" ;;
	socks4) echo "socks4" ;;
	socks5)
		if [[ "${PROXY_VALIDATE_SOCKS5H:-1}" != 0 ]]; then
			echo "socks5h"
		else
			echo "socks5"
		fi
		;;
	esac
}

# Default User-Agent matches Rod rodhttp (third_party/scrapemate) so curl and Chromium agree.
PROXY_CURL_UA_DEFAULT='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

# curl via proxy with browser-like headers. Remaining args: e.g. -o file URL or --max-filesize N -o file URL.
_curl_chrome_through() {
	local px="$1"
	local c="$2"
	local t="$3"
	shift 3
	local ua="${PROXY_CURL_UA:-$PROXY_CURL_UA_DEFAULT}"
	if [[ "${PROXY_CURL_COMPRESSED:-1}" != 0 ]]; then
		curl -fsS --connect-timeout "$c" --max-time "$t" -x "$px" \
			-H "User-Agent: $ua" \
			-H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8" \
			-H "Accept-Language: en-US,en;q=0.9" \
			--compressed \
			"$@" 2>/dev/null
	else
		curl -fsS --connect-timeout "$c" --max-time "$t" -x "$px" \
			-H "User-Agent: $ua" \
			-H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8" \
			-H "Accept-Language: en-US,en;q=0.9" \
			"$@" 2>/dev/null
	fi
}

curl_validate_one_line() {
	local line="$1"
	local scheme="$2"
	local url="$3"
	local c="$4"
	local t="$5"
	local px="${scheme}://${line}"
	local tmp ere

	if [[ "${PROXY_STRICT_BODY_CHECK:-1}" != 0 ]]; then
		ere="${PROXY_VALIDATE_BODY_ERE:-}"
		[[ -z "$ere" ]] && ere="${PROXY_GOOGLE_BODY_ERE:-googlelogo|name=\"q\"|google\\.com}"
		tmp=$(mktemp) || return
		if _curl_chrome_through "$px" "$c" "$t" \
			--max-filesize "${PROXY_MAX_FILE_PRIMARY:-524288}" -o "$tmp" "$url" \
			&& grep -qE "$ere" "$tmp" 2>/dev/null; then
			rm -f "$tmp"
			printf '%s\n' "$line"
		else
			rm -f "$tmp"
		fi
		return
	fi

	if _curl_chrome_through "$px" "$c" "$t" -o /dev/null "$url"; then
		printf '%s\n' "$line"
	fi
}

# Both URLs must succeed (stricter — weeds out proxies that only work for trivial GETs).
curl_validate_one_line_dual() {
	local line="$1"
	local scheme="$2"
	local url1="$3"
	local url2="$4"
	local c="$5"
	local t="$6"
	local px="${scheme}://${line}"
	local tmp1 tmp2 ere1 ere2
	# Maps search pages load significantly more JS than google.com; give stage-2 extra time.
	# Override via PROXY_VALIDATE_TIMEOUT_STAGE2. Default: t+15s (floor 50s under strict-chrome).
	local _t2_add=15
	local t2="${PROXY_VALIDATE_TIMEOUT_STAGE2:-}"
	if [[ -z "$t2" ]]; then
		t2=$((t + _t2_add))
		[[ "${PROXY_STRICT_CHROME:-1}" != 0 ]] && [[ "$t2" -lt 50 ]] && t2=50
	fi

	if [[ "${PROXY_STRICT_BODY_CHECK:-1}" != 0 ]]; then
		ere1="${PROXY_GOOGLE_BODY_ERE:-googlelogo|name=\"q\"|google\\.com}"
		# APP_INITIALIZATION_STATE only appears when Maps app fully initializes (absent on captcha/block pages).
		ere2="${PROXY_MAPS_BODY_ERE:-maps\\.gstatic\\.com|APP_INITIALIZATION_STATE|/maps/_/rpc|Google[[:space:]]Maps}"
		tmp1=$(mktemp) || return 1
		tmp2=$(mktemp) || {
			rm -f "$tmp1"
			return 1
		}
		if ! _curl_chrome_through "$px" "$c" "$t" \
			--max-filesize "${PROXY_MAX_FILE_PRIMARY:-524288}" -o "$tmp1" "$url1" \
			|| ! grep -qE "$ere1" "$tmp1" 2>/dev/null; then
			rm -f "$tmp1" "$tmp2"
			return 1
		fi
		rm -f "$tmp1"
		# Stage 2: Maps search — 4 MB limit (search pages are heavier), longer timeout.
		if ! _curl_chrome_through "$px" "$c" "$t2" \
			--max-filesize "${PROXY_MAX_FILE_STAGE2:-4194304}" -o "$tmp2" "$url2" \
			|| ! grep -qE "$ere2" "$tmp2" 2>/dev/null; then
			rm -f "$tmp2"
			return 1
		fi
		rm -f "$tmp2"

		if [[ "${PROXY_MAPS_RECHECK:-1}" != 0 ]]; then
			tmp2=$(mktemp) || return 1
			if ! _curl_chrome_through "$px" "$c" "$t2" \
				--max-filesize "${PROXY_MAX_FILE_STAGE2:-4194304}" -o "$tmp2" "$url2" \
				|| ! grep -qE "$ere2" "$tmp2" 2>/dev/null; then
				rm -f "$tmp2"
				return 1
			fi
			rm -f "$tmp2"
		fi
	else
		if ! _curl_chrome_through "$px" "$c" "$t" -o /dev/null "$url1"; then
			return 1
		fi
		if ! _curl_chrome_through "$px" "$c" "$t2" -o /dev/null "$url2"; then
			return 1
		fi
	fi

	printf '%s\n' "$line"
}

# Reads ip:port lines on stdin; prints lines where curl via proxy succeeds.
# Args: concurrent scheme url connect_timeout max_time [url2]
# If url2 is set, both url and url2 must succeed (Maps + Google, etc.).
validate_stdin_job_pool() {
	local concurrent="$1"
	local scheme="$2"
	local url="$3"
	local c="$4"
	local t="$5"
	local url2="${6:-}"
	local line dir running f
	local nread t0 ngood
	local log_iv="${PROXY_FETCH_LOG_INTERVAL:-100}"
	local probe_desc="$url"
	[[ -n "$url2" ]] && probe_desc="${url} + ${url2}"

	nread=0
	t0=$SECONDS
	dir=$(mktemp -d)
	while IFS= read -r line; do
		line="${line//$'\r'/}"
		[[ -z "$line" ]] && continue
		nread=$((nread + 1))
		if [[ "${QUIET:-0}" -eq 0 ]] && [[ "$log_iv" -gt 0 ]] && [[ $((nread % log_iv)) -eq 0 ]]; then
			running=$(jobs -pr 2>/dev/null | wc -l | tr -d ' \r\n')
			log_msg "validation pool: queued ${nread} checks, ${running} curl job(s) still running (~${t}s max-time, ${c}s connect; ${probe_desc})"
		fi
		while :; do
			running=$(jobs -pr 2>/dev/null | wc -l | tr -d ' \r\n')
			[[ "${running:-0}" -lt "$concurrent" ]] && break
			sleep 0.05 2>/dev/null || true
		done
		if [[ -n "$url2" ]]; then
			(
				if curl_validate_one_line_dual "$line" "$scheme" "$url" "$url2" "$c" "$t"; then
					f=$(mktemp "$dir/ok.XXXXXX")
					printf '%s\n' "$line" >"$f"
				fi
			) &
		else
			(
				if curl_validate_one_line "$line" "$scheme" "$url" "$c" "$t"; then
					f=$(mktemp "$dir/ok.XXXXXX")
					printf '%s\n' "$line" >"$f"
				fi
			) &
		fi
	done
	wait
	shopt -s nullglob
	ngood=0
	for f in "$dir"/ok.*; do
		if [[ -s "$f" ]]; then
			ngood=$((ngood + 1))
			cat "$f"
		fi
	done
	shopt -u nullglob
	rm -rf "$dir"
	if [[ "${QUIET:-0}" -eq 0 ]]; then
		log_msg "validation pool: finished chunk — ${nread} checked in $((SECONDS - t0))s, ${ngood} passed (${probe_desc})"
	fi
}

# Reads ip:port lines on stdin.
# Arg 1: stop after this many unique successes (0 = test all stdin, then sort -u).
validate_proxies_against_google() {
	local stop_after="${1:-0}"
	local scheme concurrent connect_timeout max_time url
	local acc n
	local b
	local batch=()
	local chunk_results
	local t_val batch_num total_tested sz

	scheme=$(curl_proxy_scheme)
	concurrent="${PROXY_VALIDATE_PARALLEL:-20}"
	connect_timeout="${PROXY_VALIDATE_CONNECT:-6}"
	max_time="${PROXY_VALIDATE_TIMEOUT:-15}"
	url="${PROXY_VALIDATE_URL:-https://www.google.com/}"
	local url2=""
	if [[ "${PROXY_DUAL_VALIDATION:-0}" != 0 ]] && [[ -n "${PROXY_VALIDATE_STAGE2_URL:-}" ]] && [[ "${PROXY_VALIDATE_STAGE2_URL}" != "$url" ]]; then
		url2="${PROXY_VALIDATE_STAGE2_URL}"
	fi
	t_val=$SECONDS

	_vpool() {
		if [[ -n "$url2" ]]; then
			validate_stdin_job_pool "$concurrent" "$scheme" "$url" "$connect_timeout" "$max_time" "$url2"
		else
			validate_stdin_job_pool "$concurrent" "$scheme" "$url" "$connect_timeout" "$max_time"
		fi
	}

	if [[ "$stop_after" -le 0 ]]; then
		log_msg "validation (full list): begin — concurrency=${concurrent}, primary=${url}${url2:+, second=${url2}}, connect=${connect_timeout}s max-time=${max_time}s"
		_vpool | sort -u
		log_msg "validation (full list): done in $((SECONDS - t_val))s wall time"
		return
	fi

	log_msg "validation (early-stop): need ${stop_after} good unique proxy(ies) — concurrency=${concurrent}, checks=${url}${url2:+, ${url2}}"

	acc=$(mktemp)
	: >"$acc"
	batch_num=0
	total_tested=0

	flush_batch() {
		[[ ${#batch[@]} -eq 0 ]] && return
		batch_num=$((batch_num + 1))
		sz=${#batch[@]}
		n=$(wc -l <"$acc" | tr -d ' \r\n')
		log_msg "validation batch ${batch_num}: ${sz} parallel curl(s), valid ${n}/${stop_after} so far, ~${total_tested} candidates already tried, $((SECONDS - t_val))s elapsed"
		chunk_results=$(printf '%s\n' "${batch[@]}" | _vpool) || true
		total_tested=$((total_tested + sz))
		batch=()
		if [[ -n "$chunk_results" ]]; then
			printf '%s\n' "$chunk_results" >>"$acc"
			sort -u -o "$acc" "$acc"
		fi
		n=$(wc -l <"$acc" | tr -d ' \r\n')
		log_msg "validation batch ${batch_num} merged: ${n} unique good total"
	}

	while IFS= read -r line; do
		n=$(wc -l <"$acc" | tr -d ' \r\n')
		[[ "${n:-0}" -ge "$stop_after" ]] && break
		[[ -z "$line" ]] && continue
		batch+=("$line")
		if [[ ${#batch[@]} -ge "$concurrent" ]]; then
			flush_batch
			n=$(wc -l <"$acc" | tr -d ' \r\n')
			[[ "${n:-0}" -ge "$stop_after" ]] && break
		fi
	done

	n=$(wc -l <"$acc" | tr -d ' \r\n')
	if [[ "${n:-0}" -lt "$stop_after" ]]; then
		log_msg "validation: flushing partial batch (valid ${n}/${stop_after}, tried ~${total_tested} so far)"
		flush_batch
	fi

	n=$(wc -l <"$acc" | tr -d ' \r\n')
	log_msg "validation (early-stop): finished in $((SECONDS - t_val))s — ${n} good unique, ~${total_tested} candidates tested"

	head -n "$stop_after" "$acc"
	rm -f "$acc"
}

# --- JSON → ip:port lines (Geonode, PubProxy, GetProxyList one-shot, Proxy-Tools) ---
json_has_parser() {
	if command -v jq >/dev/null 2>&1; then
		return 0
	fi
	if python_for_json -c "pass" 2>/dev/null; then
		return 0
	fi
	return 1
}

warn_no_json() {
	log_msg "warning: install jq or Python 3 to fetch JSON APIs (Geonode, PubProxy, ...)"
}

parse_geonode_page() {
	if command -v jq >/dev/null 2>&1; then
		jq -r '.data[]? | select(.ip != null and .port != null) | "\(.ip):\(.port)"'
	else
		python_for_json -c '
import sys, json
try:
    d = json.load(sys.stdin)
    for r in d.get("data") or []:
        ip, p = r.get("ip"), r.get("port")
        if ip is not None and p is not None:
            print("%s:%s" % (ip, p))
except Exception:
    pass
'
	fi
}

# Read Geonode JSON meta: total count and page size (prints: total limit)
parse_geonode_pagination() {
	local ps="$1"
	if command -v jq >/dev/null 2>&1; then
		jq -r --argjson ps "$ps" '[(.total // 0 | tonumber), (.limit // $ps | tonumber)] | @tsv'
	else
		python_for_json -c '
import sys, json
ps = int(sys.argv[1])
d = json.load(sys.stdin)
lim = d.get("limit")
lim = ps if lim is None else int(lim)
total = int(d.get("total") or 0)
print("%d\t%d" % (total, lim))
' "$ps"
	fi
}

parse_pubproxy() {
	if command -v jq >/dev/null 2>&1; then
		jq -r '.data[]? | if .ipPort then .ipPort else "\(.ip):\(.port)" end'
	else
		python_for_json -c '
import sys, json
try:
    d = json.load(sys.stdin)
    for r in d.get("data") or []:
        if r.get("ipPort"):
            print(r["ipPort"])
        elif r.get("ip") and r.get("port") is not None:
            print("%s:%s" % (r["ip"], r["port"]))
except Exception:
    pass
'
	fi
}

# GetProxyList returns one proxy object per request
parse_getproxylist_object() {
	if command -v jq >/dev/null 2>&1; then
		jq -r 'if (type == "object") and (.ip != null) and (.port != null) then "\(.ip):\(.port)" else empty end'
	else
		python_for_json -c '
import sys, json
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict) and d.get("ip") is not None and d.get("port") is not None:
        print("%s:%s" % (d["ip"], d["port"]))
except Exception:
    pass
'
	fi
}

# Proxy-Tools responses vary; python handles nested lists/objects.
parse_proxy_tools() {
	python_for_json -c '
import sys, json
def emit_obj(o):
    if not isinstance(o, dict):
        return
    ip = o.get("ip") or o.get("host")
    port = o.get("port") if o.get("port") is not None else o.get("port_number")
    if ip is not None and port is not None:
        print("%s:%s" % (ip, port))
try:
    d = json.load(sys.stdin)
    if isinstance(d, list):
        for x in d:
            emit_obj(x)
    elif isinstance(d, dict):
        for key in ("proxies", "data", "results", "items"):
            arr = d.get(key)
            if isinstance(arr, list):
                for x in arr:
                    emit_obj(x)
        emit_obj(d)
except Exception:
    pass
' | filter_lines || true
}

pubproxy_type() {
	case "$PROTOCOL" in
	http) echo http ;;
	socks4) echo socks4 ;;
	socks5) echo socks5 ;;
	esac
}

collect_github_speedx_monosans() {
	case "$PROTOCOL" in
	http)
		fetch_url "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt"
		fetch_url "https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/http.txt"
		;;
	socks4)
		fetch_url "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks4.txt"
		fetch_url "https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/socks4.txt"
		;;
	socks5)
		fetch_url "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks5.txt"
		fetch_url "https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/socks5.txt"
		;;
	esac
}

collect_thordata() {
	local base="https://raw.githubusercontent.com/Thordata/awesome-free-proxy-list/main/proxies"
	case "$PROTOCOL" in
	http)
		fetch_url "$base/http.txt"
		fetch_url "$base/https.txt"
		fetch_url "$base/top-http.txt"
		;;
	socks4) fetch_url "$base/socks4.txt" ;;
	socks5) fetch_url "$base/socks5.txt" ;;
	esac
}

collect_clarketm() {
	fetch_url "https://raw.githubusercontent.com/clarketm/proxy-list/master/proxy-list-raw.txt"
}

collect_theriturajps() {
	# Plain ip:port list; treat as HTTP-oriented aggregate (same as many community lists).
	[[ "$PROTOCOL" == "http" ]] || return 0
	fetch_url "https://raw.githubusercontent.com/theriturajps/proxy-list/main/proxies.txt"
}

collect_jetkai() {
	local base="https://raw.githubusercontent.com/jetkai/proxy-list/main/online-proxies/txt"
	case "$PROTOCOL" in
	http)
		fetch_url "$base/proxies-http.txt"
		fetch_url "$base/proxies-https.txt"
		;;
	socks4) fetch_url "$base/proxies-socks4.txt" ;;
	socks5) fetch_url "$base/proxies-socks5.txt" ;;
	esac
}

collect_hw630590() {
	local base="https://raw.githubusercontent.com/hw630590/free-proxy-list/main/proxies"
	case "$PROTOCOL" in
	http)
		fetch_url "$base/http/http.txt"
		fetch_url "$base/https/https.txt"
		;;
	socks4) fetch_url "$base/socks4/socks4.txt" ;;
	socks5) fetch_url "$base/socks5/socks5.txt" ;;
	esac
}

collect_shiftytr() {
	local base="https://raw.githubusercontent.com/ShiftyTR/Proxy-List/master"
	case "$PROTOCOL" in
	http)
		fetch_url "$base/http.txt"
		fetch_url "$base/https.txt"
		;;
	socks4) fetch_url "$base/socks4.txt" ;;
	socks5) fetch_url "$base/socks5.txt" ;;
	esac
}

collect_mmpx12() {
	local base="https://raw.githubusercontent.com/mmpx12/proxy-list/master"
	case "$PROTOCOL" in
	http)
		fetch_url "$base/http.txt"
		fetch_url "$base/https.txt"
		;;
	socks4) fetch_url "$base/socks4.txt" ;;
	socks5) fetch_url "$base/socks5.txt" ;;
	esac
}

collect_roosterkid() {
	local base="https://raw.githubusercontent.com/roosterkid/openproxylist/main"
	case "$PROTOCOL" in
	http)
		# Verbose lines; only HTTPS list exists at repo root.
		fetch_url "$base/HTTPS.txt" | extract_ip_port_loose
		;;
	socks4) fetch_url "$base/SOCKS4.txt" | extract_ip_port_loose ;;
	socks5) fetch_url "$base/SOCKS5.txt" | extract_ip_port_loose ;;
	esac
}

collect_proxyscrape() {
	local ps_proto="$PROTOCOL"
	local sslq="all"
	if [[ "${PROXY_PROXYSCRAPE_SSL_ONLY:-0}" != 0 ]]; then
		# ssl=yes tends to match HTTPS CONNECT behavior (Maps, Rod) better than “all”.
		sslq="yes"
	fi
	fetch_url "https://api.proxyscrape.com/v2/?request=displayproxies&protocol=${ps_proto}&timeout=20000&country=all&ssl=${sslq}&anonymity=all"
}

# Proxy-list.download — plain text ip:port (HTTP).
collect_proxy_list_download() {
	[[ "$PROTOCOL" == "http" ]] || return 0
	fetch_url "https://www.proxy-list.download/api/v1/get?type=http"
}

# Backup raw list (may be slow or empty depending on mirror).
collect_openproxylist_xyz() {
	[[ "$PROTOCOL" == "http" ]] || return 0
	fetch_url "https://openproxylist.xyz/http.txt"
}

collect_geonode() {
	json_has_parser || {
		warn_no_json
		return 0
	}
	local proto_q ps url body total lim pages_needed pages_to_fetch p n user_cap fuse
	proto_q="$PROTOCOL"
	ps="$GEONODE_PAGE_SIZE"
	# Optional: GEONODE_QUERY_EXTRA='&anonymityLevel=elite' (if supported by your API tier).
	_geo_extra="${GEONODE_QUERY_EXTRA:-}"
	url="https://proxylist.geonode.com/api/proxy-list?limit=${ps}&page=1&protocols=${proto_q}&sort_by=lastChecked&sort_type=desc${_geo_extra}"
	body=$(fetch_url "$url")
	[[ -z "$body" ]] && return 0

	IFS=$'\t' read -r total lim <<<"$(printf '%s' "$body" | parse_geonode_pagination "$ps")"
	total="${total:-0}"
	lim="${lim:-$ps}"
	[[ "$lim" -eq 0 ]] && lim="$ps"

	if [[ "$total" -gt 0 ]]; then
		pages_needed=$(((total + lim - 1) / lim))
		[[ "$pages_needed" -lt 1 ]] && pages_needed=1
	else
		# No total: single-page / unknown — emit this page only if non-empty
		n=$(printf '%s' "$body" | parse_geonode_page | wc -l | tr -d ' ')
		[[ "${n:-0}" -eq 0 ]] && return 0
		printf '%s\n' "$body" | parse_geonode_page
		return 0
	fi

	pages_to_fetch="$pages_needed"
	user_cap="$GEONODE_MAX_PAGES"
	if [[ "$user_cap" -gt 0 ]] && [[ "$pages_to_fetch" -gt "$user_cap" ]]; then
		pages_to_fetch="$user_cap"
	fi
	fuse="$GEONODE_ABSOLUTE_MAX_PAGES"
	if [[ "$fuse" -gt 0 ]] && [[ "$pages_to_fetch" -gt "$fuse" ]]; then
		pages_to_fetch="$fuse"
	fi

	printf '%s\n' "$body" | parse_geonode_page
	for ((p = 2; p <= pages_to_fetch; p++)); do
		url="https://proxylist.geonode.com/api/proxy-list?limit=${ps}&page=${p}&protocols=${proto_q}&sort_by=lastChecked&sort_type=desc${_geo_extra}"
		body=$(fetch_url "$url")
		[[ -z "$body" ]] && break
		n=$(printf '%s' "$body" | parse_geonode_page | wc -l | tr -d ' ')
		[[ "${n:-0}" -eq 0 ]] && break
		printf '%s\n' "$body" | parse_geonode_page
	done
}

collect_pubproxy() {
	json_has_parser || {
		warn_no_json
		return 0
	}
	# PubProxy does not document offset/cursor pagination — each call returns a batch (limit max).
	local i pt b
	pt=$(pubproxy_type)
	for ((i = 1; i <= PUBPROXY_REQUESTS; i++)); do
		b=$(fetch_url "http://pubproxy.com/api/proxy?format=json&type=${pt}&limit=100")
		[[ -z "$b" ]] && continue
		printf '%s\n' "$b" | parse_pubproxy
	done
}

collect_getproxylist() {
	[[ -n "${GETPROXYLIST_API_KEY:-}" ]] || return 0
	json_has_parser || {
		warn_no_json
		return 0
	}
	local i b
	for ((i = 1; i <= GETPROXYLIST_REQUESTS; i++)); do
		b=$(fetch_url "https://api.getproxylist.com/proxy?apiKey=${GETPROXYLIST_API_KEY}")
		[[ -z "$b" ]] && continue
		printf '%s\n' "$b" | parse_getproxylist_object
	done
}

proxy_tools_type_param() {
	# Proxy-Tools API: 4 = HTTP/HTTPS, 2 = SOCKS5, 1 = SOCKS4+SOCKS5
	case "$PROTOCOL" in
	http) echo 4 ;;
	socks5) echo 2 ;;
	socks4) echo 1 ;;
	esac
}

collect_proxy_tools() {
	[[ -n "${PROXY_TOOLS_BEARER:-}" ]] || return 0
	if ! python_for_json -c "pass" 2>/dev/null; then
		warn_no_json
		return 0
	fi
	local pt_type lim page b cnt maxp
	pt_type=$(proxy_tools_type_param)
	lim="$PROXY_TOOLS_PAGE_LIMIT"
	maxp="$PROXY_TOOLS_MAX_PAGES"
	page=1
	while [[ "$page" -le "$maxp" ]]; do
		b=$(fetch_url "https://proxy-tools.com/api/v1/proxies?type=${pt_type}&limit=${lim}&page=${page}" \
			-H "Authorization: Bearer ${PROXY_TOOLS_BEARER}" \
			-H "Accept: application/json")
		[[ -z "$b" ]] && break
		cnt=$(printf '%s' "$b" | parse_proxy_tools | wc -l | tr -d ' ')
		[[ "${cnt:-0}" -eq 0 ]] && break
		printf '%s\n' "$b" | parse_proxy_tools
		[[ "$cnt" -lt "$lim" ]] && break
		page=$((page + 1))
	done
}

PREFIX="${PROTOCOL}://"

MERGE_T0=$SECONDS
log_msg "merge: downloading proxy lists and deduping (often 1–10+ min depending on APIs and network)..."

FORMATTED=$(
	{
		collect_github_speedx_monosans
		collect_thordata
		collect_clarketm
		collect_theriturajps
		collect_jetkai
		collect_hw630590
		collect_shiftytr
		collect_mmpx12
		collect_roosterkid
		collect_proxyscrape
		collect_proxy_list_download
		collect_openproxylist_xyz
		collect_geonode
		collect_pubproxy
		collect_getproxylist
		collect_proxy_tools
	} | tr -d '\r' | sed '/^\s*$/d' | filter_lines | filter_sane_proxy_lines | sort -u
)

if [[ -z "$FORMATTED" ]]; then
	die "no proxies retrieved (check network, install jq or Python for APIs, or try again later)"
fi

log_msg "merge: done in $((SECONDS - MERGE_T0))s — $(printf '%s\n' "$FORMATTED" | wc -l | tr -d ' \r\n') unique ip:port line(s) after filters (protocol prefix not applied yet)"

if [[ "${SKIP_PROXY_VALIDATION}" == 1 ]]; then
	log_msg "SKIP_PROXY_VALIDATION=1 — skipping live checks against ${PROXY_VALIDATE_URL}"
else
	if [[ "${PROXY_SHUFFLE_CANDIDATES:-1}" != 0 ]] && command -v shuf >/dev/null 2>&1; then
		BEFORE_SHUF=$(printf '%s\n' "$FORMATTED" | wc -l | tr -d ' \r\n')
		FORMATTED=$(printf '%s\n' "$FORMATTED" | shuf)
		log_msg "candidates: randomized order (${BEFORE_SHUF} lines; PROXY_SHUFFLE_CANDIDATES=0 to keep sorted order)"
	elif [[ "${PROXY_SHUFFLE_CANDIDATES:-1}" != 0 ]]; then
		log_msg "candidates: shuf not in PATH — using sorted order (install coreutils to randomize)"
	fi
	if [[ "${PROXY_VALIDATE_MAX}" -gt 0 ]]; then
		BEFORE_TRIM=$(printf '%s\n' "$FORMATTED" | wc -l | tr -d ' ')
		FORMATTED=$(printf '%s\n' "$FORMATTED" | head -n "${PROXY_VALIDATE_MAX}")
		if [[ "${BEFORE_TRIM}" -gt "${PROXY_VALIDATE_MAX}" ]]; then
			log_msg "candidate cap: at most ${PROXY_VALIDATE_MAX} of ${BEFORE_TRIM} will be tried (raise PROXY_VALIDATE_MAX or use 0 for all)"
		fi
	fi
	CAND=$(printf '%s\n' "$FORMATTED" | wc -l | tr -d ' ')
	if [[ "$MAX_LINES" -gt 0 ]]; then
		log_msg "next: live validation until ${MAX_LINES} good — up to ${CAND} candidates, ${PROXY_VALIDATE_PARALLEL} concurrent curls (slow if most proxies fail)"
		FORMATTED=$(printf '%s\n' "$FORMATTED" | validate_proxies_against_google "$MAX_LINES")
	else
		log_msg "next: live validation of all ${CAND} candidates — ${PROXY_VALIDATE_PARALLEL} concurrent curls"
		FORMATTED=$(printf '%s\n' "$FORMATTED" | validate_proxies_against_google 0)
	fi
	if [[ -z "$FORMATTED" ]]; then
		die "no proxies passed validation against ${PROXY_VALIDATE_URL} (try another network, higher timeouts, or SKIP_PROXY_VALIDATION=1 for debugging only; default test URL is https://www.google.com/)"
	fi
	OK=$(printf '%s\n' "$FORMATTED" | wc -l | tr -d ' ')
	if [[ "$MAX_LINES" -gt 0 ]]; then
		log_msg "result: ${OK} valid (target was ${MAX_LINES}; fewer means not enough working proxies in the candidate set)"
	else
		log_msg "result: ${OK} / ${CAND} passed validation"
	fi
fi

if [[ "$MAX_LINES" -gt 0 ]]; then
	FORMATTED=$(printf '%s\n' "$FORMATTED" | head -n "$MAX_LINES")
fi

if [[ "$COMMA" -eq 1 ]]; then
	OUT=$(echo "$FORMATTED" | sed "s|^|${PREFIX}|" | paste -sd, -)
else
	OUT=$(echo "$FORMATTED" | sed "s|^|${PREFIX}|")
fi

if [[ -n "$OUT_PATH" ]]; then
	printf '%s\n' "$OUT" >"$OUT_PATH"
	if [[ "$QUIET" -eq 0 ]]; then
		if [[ "$COMMA" -eq 1 ]]; then
			N=$(echo "$FORMATTED" | wc -l | tr -d ' ')
			log_msg "wrote $N proxies (comma-separated on one line) to $OUT_PATH"
		else
			log_msg "wrote $(echo "$OUT" | wc -l | tr -d ' ') line(s) to $OUT_PATH"
		fi
	fi
else
	printf '%s\n' "$OUT"
fi
