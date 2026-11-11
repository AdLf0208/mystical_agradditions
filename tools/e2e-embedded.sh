#!/usr/bin/env bash
# The embedded-content proof for one `.hnmod`, run inside a slot lease:
#
#   ports/tools/build-slot.sh run --job maa-embed-e2e --port ports/mysticalagradditions \
#       --step e2e -- bash tools/e2e-embedded.sh
#
# It stages and builds this port explicitly (the runner's implicit rebuild hides
# its output and once left another port's binary in the shared slot), proves the
# built game carries *this* bundle's embedded content, then runs two legs:
#
# Leg 1 (EMBEDDED=1, CONTROL=1): no `--dev-mod`; the content comes from the
# bundle's embedded copy, the control makes that file unwritable and requires the
# ids to be unknown. Must end `PASS` + `EXIT:0`.
# Leg 2 (EMBEDDED=1, SELFTEST=1): the same scenario asserting the no-crux crop
# grew. Must end `FAIL` + `EXIT:1`, proving the scenario can fail.
set -uo pipefail
PORT=$(cd "$(dirname "$0")/.." && pwd)
CAMPAIGN=$(cd "$PORT/../.." && pwd)
PIN=${HORIZON:-$CAMPAIGN/ports/_shared/pins/horizon-1d63e0a}
LOG=$CAMPAIGN/ports/_shared/evidence/mysticalagradditions
MOD=mysticalagradditions
cd "$PORT"
mkdir -p "$LOG"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "mixins/$MOD/data/$MOD-content.hmod" ] || fail "no embedded content; run tools/package.sh"
cmp -s "mixins/$MOD/data/$MOD-content.hmod" "content/$MOD.hmod" \
    || fail "mixins/$MOD/data/$MOD-content.hmod is not the built content/$MOD.hmod"

echo "== stage ($(date -u +%H:%M:%S)) =="
stage_json=$(python3 tools/horizon.py stage --horizon "$PIN") || fail "stage"
echo "$stage_json" | tee "$LOG/embed-stage.log"
stage=$(printf '%s' "$stage_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["stage"])') \
    || fail "no stage path in the stage report"
grep -q "mysticalagradditions_embedded_content" \
        "$stage/crates/horizon-client/src/game/mods.rs" \
    || fail "the staged mods.rs does not call the embedded-content helper"
echo "staged mods.rs calls mysticalagradditions_embedded_content"

echo "== build ($(date -u +%H:%M:%S)) =="
CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS_FULL:-2} python3 tools/horizon.py build --horizon "$PIN" \
    | tee "$LOG/embed-build.log" || fail "build"
bin=$PORT/target/horizon-cargo/fast/horizon-client
[ -x "$bin" ] || fail "no game binary at $bin"
# `strings | grep -q` would make grep's early exit SIGPIPE strings, and pipefail
# would report that as a missing string: write the list out first.
strings "$bin" > "$LOG/embed-build-strings.txt" || true
grep -q "mysticalagradditions-embedded-content" "$LOG/embed-build-strings.txt" \
    || fail "the built game does not embed this port's content ($bin)"
echo "built game embeds mysticalagradditions-content.hmod ($(stat -c %s "$bin") B, $(date -u +%H:%M:%S))"

echo "== leg 1: embedded content + unusable-file control =="
EMBEDDED=1 CONTROL=1 tools/e2e.sh 2>&1 | tee "$LOG/e2e-embedded.log"
main=${PIPESTATUS[0]}

echo "== leg 2: selftest (must fail) =="
EMBEDDED=1 CONTROL=0 SELFTEST=1 tools/e2e.sh 2>&1 | tee "$LOG/e2e-embedded-selftest.log"
selftest=${PIPESTATUS[0]}

echo "embedded_leg_exit=$main selftest_leg_exit=$selftest"
[ "$main" -eq 0 ] || exit "$main"
[ "$selftest" -ne 0 ] || { echo "FAIL: the selftest leg passed" >&2; exit 1; }
echo "EXIT:0"
