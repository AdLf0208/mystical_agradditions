#!/usr/bin/env bash
# Five e2e legs in one go: the default scenario (must pass), the growth selftest,
# the young-crop negative and the mob-drop selftest (all three must fail at their
# live assertion), and — when CONTROL_GAME is set — the same scenario on an
# unmodified game, which must fail at its first binding check. The game is a
# launcher-built binary carrying the package, so it is passed in, not built here:
#   horizon-launcher native-build ports/mysticalagradditions --instance <i> --trust-native-code
#   GAME=<that horizon-client> tools/e2e-all.sh
#   CONTROL_GAME=<an unmodified horizon-client> GAME=… tools/e2e-all.sh   # adds the counterfactual
# LOG=<evidence dir> overrides where the legs' transcripts are written.
set -euo pipefail

PORT=/home/adlf/Desktop/all_the_mods_10_rust_rewrite/ports/mysticalagradditions
LOG=${LOG:-/home/adlf/Desktop/all_the_mods_10_rust_rewrite/ports/_shared/evidence/mysticalagradditions}
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

echo "== e2e mob-drop selftest (expected to fail) =="
if DROPS_SELFTEST=1 "$PORT/tools/e2e.sh" >"$LOG/e2e-drops-selftest.log" 2>&1; then
    echo "FAIL: the mob-drop selftest passed; the Wither assertion is not alive" >&2
    exit 1
fi
grep -E "^(FAIL|EXIT):" "$LOG/e2e-drops-selftest.log" | tail -2

if [ -n "${CONTROL_GAME:-}" ]; then
    echo "== e2e control: the same scenario on the unmodified game (expected to fail) =="
    if GAME=$CONTROL_GAME "$PORT/tools/e2e.sh" >"$LOG/e2e-control.log" 2>&1; then
        echo "FAIL: the control leg passed; the package's ids are not its own" >&2
        exit 1
    fi
    grep -E "^(FAIL|EXIT):" "$LOG/e2e-control.log" | tail -2
fi

echo "PASS: default EXIT:0, the three selftests and the control leg exit non-zero"
echo "EXIT:0"
