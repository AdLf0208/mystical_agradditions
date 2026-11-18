#!/usr/bin/env bash
# Three e2e legs in one go: the default scenario (must pass), the selftest
# (must fail at the live growth assertion) and the negative (must fail at the
# young-crop essence expectation). The game is a launcher-built binary carrying
# the package, so it is passed in, not built here:
#   horizon-launcher native-build ports/mysticalagradditions --instance <i> --trust-native-code
#   GAME=<that horizon-client> tools/e2e-all.sh
#   CONTROL_GAME=<an unmodified horizon-client> GAME=… tools/e2e-all.sh   # adds the counterfactual
set -euo pipefail

PORT=/home/adlf/Desktop/all_the_mods_10_rust_rewrite/ports/mysticalagradditions
LOG=/home/adlf/Desktop/all_the_mods_10_rust_rewrite/ports/_shared/evidence/mysticalagradditions
mkdir -p "$LOG"

[ -n "${GAME:-}" ] || {
    echo "GAME must be a launcher-built horizon-client carrying this mod:" >&2
    echo "  horizon-launcher native-build $PORT --instance <i> --trust-native-code" >&2
    exit 1
}

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
