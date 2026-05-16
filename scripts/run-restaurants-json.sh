#!/usr/bin/env bash
# Delegates to restaurants/run-restaurants-json.sh (queries, proxies, and out/ live under restaurants/).
exec "$(cd "$(dirname "$0")/.." && pwd)/restaurants/run-restaurants-json.sh" "$@"
