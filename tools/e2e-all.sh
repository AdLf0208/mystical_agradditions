#!/usr/bin/env bash
# One lease, three e2e legs: the default scenario (must pass), the selftest
# (must fail at the live assertion) and the negative (must fail at the
# young-crop essence expectation). Run through:
#   build-slot.sh e2e --job … --port ports/mysticalagradditions -- tools/e2e-all.sh
set -euo pipefail

PORT=${CAMPAIGN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}/ports/mysticalagradditions
LOG=${CAMPAIGN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}/ports/_shared/evidence/mysticalagradditions
mkdir -p "$LOG"

echo "== e2e default =="
if ! "$PORT/tools/e2e.sh" >"$LOG/e2e-default.log" 2>&1; then
    tail -30 "$LOG/e2e-default.log" >&2
    echo "FAIL: the default e2e leg" >&2
    exit 1
fi
grep -E "^(PASS|EXIT):" "$LOG/e2e-default.log" | tail -2

echo "== e2e selftest (expected to fail) =="
if SELFTEST=1 "$PORT/tools/e2e.sh" >"$LOG/e2e-selftest.log" 2>&1; then
    echo "FAIL: the selftest leg passed; the growth assertion is not alive" >&2
    exit 1
fi
grep -E "^(FAIL|EXIT):" "$LOG/e2e-selftest.log" | tail -2

echo "== e2e negative (expected to fail) =="
if NEGATIVE=1 "$PORT/tools/e2e.sh" >"$LOG/e2e-negative.log" 2>&1; then
    echo "FAIL: the negative leg passed; the drop assertion is not alive" >&2
    exit 1
fi
grep -E "^(FAIL|EXIT):" "$LOG/e2e-negative.log" | tail -2

echo "PASS: default EXIT:0, selftest and negative exit non-zero"
echo "EXIT:0"
