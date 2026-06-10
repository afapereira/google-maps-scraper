#!/usr/bin/env bash
# Re-apply the local scrapemate patches on top of the vendored v1.2.0 checkout.
#
# The vendored ./third_party/scrapemate gitlink points at the upstream v1.2.0
# tag (Playwright-only; Rod was removed upstream). Two small Windows/runtime
# fixes are NOT upstream and live only in scrapemate-local-patches.diff:
#   1. jshttp.go   — skip --no-zygote/--single-process on Windows (Chromium crash)
#   2. scrapemate.go — don't trip -exit-on-inactivity before the first job finishes
#
# Run this after a fresh clone / submodule checkout, from the repo root:
#   bash scripts/apply-scrapemate-patches.sh
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root/third_party/scrapemate"

if git apply --check "$repo_root/scrapemate-local-patches.diff" 2>/dev/null; then
  git apply "$repo_root/scrapemate-local-patches.diff"
  echo "scrapemate local patches applied."
else
  echo "Patches already applied or do not apply cleanly; skipping." >&2
fi
