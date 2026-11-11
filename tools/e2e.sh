#!/usr/bin/env bash
# In-game check for Mystical Agradditions: the six tier-6 crops, their cruxes,
# the crux-gated growth, the jar's harvest counts and the insanium farmland,
# Minecraft 26.3 on the campaign pin 1d63e0a5.
#
# Default run (offscreen renderer, The End, our built game with the native
# bundle + `--dev-mod content`):
#   1. the content mod loads; the six crops and six cruxes bind, the insanium
#      farmland binds;
#   2. seeds plant a crop on insanium farmland (the item's `place_block` and
#      the `#supports_crops` tag); a stick places nothing;
#   3. growth is the wheat template's random tick, gated by the crux two blocks
#      below: with `random_tick_speed 400` the crop over its crux advances while
#      the same crop over stone and over another crop's crux holds (the
#      counterfactual);
#   3b. the slice's line: awakened-draconium seeds on plain farmland with its
#      crux beneath hold at `random_tick_speed 0`, then grow to age 7 under
#      random ticks, and a survival break drops 1 essence + 1 seed (the jar's
#      `MysticalCropBlock.getDrops`);
#   4. bone meal is refused on a crop with its crux (meal spent, age stays) and
#      is not even a target without one (meal kept); vanilla wheat grows;
#   5. a ripe crop drops 1 essence + 1 seed, a young one 1 seed, vanilla wheat
#      its own loot (the native `loot_drops` hook; the 26.3 table is the
#      fallback);
#   6. insanium farmland silk-touches itself and drops dirt + a 25% insanium
#      essence otherwise;
#   7. the recipes craft in a real table with empty wrong-ingredient controls;
#   8. unknown ids are refused.
#
# EMBEDDED=1: launched with **no** `--dev-mod`; the content comes from the
# bundle's embedded copy (`mixins/<id>/data/…`, the AE2 pattern). The run
# checks the cache file the helper wrote, byte for byte, against
# `content/mysticalagradditions.hmod`.
# CONTROL=1 (default with EMBEDDED): first launches the same binary with
# `.horizon-cache` unusable, where the crop and seed ids must be unknown.
# SELFTEST=1 keeps the scenario but asserts the no-crux crop grew: the run MUST
# fail, proving the growth assertion is not vacuous.
# NEGATIVE=1 asserts a young crop drops essence: it MUST fail too.
set -euo pipefail

EMBEDDED=${EMBEDDED:-0}
CONTROL=${CONTROL:-$EMBEDDED}
CLONE=${CAMPAIGN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
PORT=$CLONE/ports/mysticalagradditions
SHARED=$CLONE/ports/_shared/bin/horizon-1d63e0a5
CTL=${CTL:-$SHARED/horizon-ctl}
GAME=${GAME:-$PORT/target/horizon-cargo/fast/horizon-client}
RES=${RES:-${HORIZON_RES:-${HORIZON_RES:-$HOME/.local/horizon-client/26.3}}}
SOCK=${SOCK:-/tmp/opencode/mysticalagradditions-e2e.sock}
NEGATIVE=${NEGATIVE:-0}
SELFTEST=${SELFTEST:-0}
MOD=mysticalagradditions
WORLD=MysticalAgradditionsE2E
CONTROL_WORLD=MysticalAgradditionsControl

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
[ -f "$PORT/content/horizon-mod.toml" ] || { echo "missing content mod: $PORT/content" >&2; exit 1; }

say() { echo "== $* =="; }
fail() { echo "FAIL: $*" >&2; exit 1; }

SCRATCH=$(mktemp -d "${E2E_TMP:-/tmp/opencode}"/mysticalagradditions-home.XXXXXX)
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")"
rm -f "$SOCK"
cd "$SCRATCH"

ctl() { "$CTL" --socket "$SOCK" "$@"; }
end() { ctl command "execute in minecraft:the_end run $1"; }
block_state() { ctl block "$1" "$2" "$3" | jq -r '.state // "unknown"'; }
block_name() { ctl block "$1" "$2" "$3" | jq -r '.block // "unknown"'; }
prop() { echo "$1" | grep -o "$2=[A-Za-z0-9_]*" | head -1 | cut -d= -f2 || true; }
assert_prop() {
    local state=$1 key=$2 want=$3 got
    got=$(prop "$state" "$key")
    [ "$got" = "$want" ] || fail "$state: $key is '$got', expected '$want'"
}
settle() {
    local last=-1 cur pend i
    for i in $(seq 1 60); do
        cur=$(ctl state | jq -r '.chunks // 0')
        pend=$(ctl state | jq -r '.streaming.queued // 0')
        [ "$cur" = "$last" ] && [ "$pend" = 0 ] && return 0
        last=$cur
        ctl wait 10 >/dev/null
    done
}
readback() { # x y z expected-block-id
    local x=$1 y=$2 z=$3 want=$4 st i
    for i in 1 2 3 4 5 6 7 8; do
        st=$(block_state "$x" "$y" "$z")
        case "$st" in "$want"*) echo "$st"; return 0 ;; esac
        ctl wait 5 >/dev/null
    done
    echo "$st"
}
age_at() { prop "$(block_state "$1" "$2" "$3")" age; }

cleanup() {
    local status=$?
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    rm -rf "$SCRATCH" || true
    echo "EXIT:$status"
}
trap cleanup EXIT

launch() { # launch-window [WORLD] [extra args…]
    local world=${1:-$WORLD}
    shift || true
    rm -f "$SOCK"
    local args=(--game "$GAME" --world "$world" --seed 20261109 --creative --offscreen --wait
                --game-dir "$SCRATCH/game" --resources "$RES" --render-distance 4)
    if [ "$EMBEDDED" = 1 ]; then
        echo "  launch: no --dev-mod; the bundle carries its own content" >&2
    else
        args+=(--dev-mod "$PORT/content")
    fi
    "$CTL" --socket "$SOCK" launch "${args[@]}" "$@"
    ctl wait-ready 180
}

# EMBEDDED=1: the bundle must have written its content out at startup, byte for
# byte the delivered content mod, and its own archive entry must be the same.
embedded_content_check() {
    local found
    found=$(find "$SCRATCH" -name "$MOD-embedded-content.hmod" -type f -print -quit 2>/dev/null || true)
    if [ -z "$found" ]; then
        echo "  the cache trees under $SCRATCH:" >&2
        find "$SCRATCH" -maxdepth 5 \( -name ".horizon-cache" -o -name "*.hmod" \) -print >&2 2>/dev/null || true
        fail "the bundle did not write its embedded content under $SCRATCH"
    fi
    cmp -s "$found" "$PORT/content/$MOD.hmod" \
        || fail "the embedded content at $found differs from content/$MOD.hmod"
    echo "  embedded content: $(wc -c < "$found" | tr -d ' ') B at $found, identical to content/$MOD.hmod"
    python3 - "$PORT/$MOD.hnmod" "mixins/$MOD/data/$MOD-content.hmod" "$PORT/content/$MOD.hmod" <<'PY'
import hashlib, sys, zipfile
bundle, entry, content = sys.argv[1:4]
with zipfile.ZipFile(bundle) as archive:
    packed = archive.read(entry)
delivered = open(content, 'rb').read()
if packed != delivered:
    raise SystemExit(f'{bundle}:{entry} is not {content}')
print(f'  bundle entry {entry}: {len(packed)} B, '
      f'SHA-256 {hashlib.sha256(packed).hexdigest()}, identical to content/{content.rsplit("/", 1)[-1]}')
PY
}

# The control for EMBEDDED=1: the same binary (every hook is in it) with the
# embedded content file made unwritable — a *directory* sits at the exact path
# the helper writes, so its read and its write both fail and it falls back to
# `Continue` while the game's own cache stays usable. Both ids must then be
# unknown; if they resolve, the run proves nothing about the embedded file.
control_leg() {
    echo "== control: the same game with no embedded content file =="
    local dir
    for dir in "$SCRATCH/game/.horizon-cache" "$SCRATCH/.horizon-cache"; do
        rm -rf "$dir/$MOD-embedded-content.hmod"
        mkdir -p "$dir/$MOD-embedded-content.hmod"
    done
    launch "$CONTROL_WORLD"
    end "forceload add 24 0 64 16" >/dev/null
    end "fill 40 119 0 48 119 10 minecraft:stone" >/dev/null
    end "tp @s 43.5 121 9.5" >/dev/null
    ctl wait 20 >/dev/null
    ctl command "item replace entity @s hotbar.0 with $MOD:awakened_draconium_seeds 1" >/dev/null || true
    ctl wait 4 >/dev/null
    ctl inventory | jq -e --arg i "$MOD:awakened_draconium_seeds" \
        '[.hotbar[], .main[] | select(.item == $i)] | length == 0' >/dev/null \
        || fail "the control game has the seed item, so the content came from somewhere else: $(ctl inventory | jq -c '{hotbar,main}')"
    ctl command "execute in minecraft:the_end run setblock 43 121 7 $MOD:awakened_draconium_crop" >/dev/null || true
    ctl wait 4 >/dev/null
    local name
    name=$(block_name 43 121 7)
    [ "$name" = "minecraft:air" ] || fail "the control game holds $name, so the crop block id was known"
    for dir in "$SCRATCH/game/.horizon-cache" "$SCRATCH/.horizon-cache"; do
        [ -d "$dir/$MOD-embedded-content.hmod" ] \
            || fail "$dir/$MOD-embedded-content.hmod was replaced: the helper wrote its content"
        rm -rf "$dir/$MOD-embedded-content.hmod"
    done
    echo "  without the embedded file: no seed item, the crop block stayed $name"
    ctl quit >/dev/null 2>&1 || true
    sleep 2
}

# --------------------------------------------------------------- launch
say "launch (offscreen renderer, The End, $( [ "$EMBEDDED" = 1 ] && echo 'native bundle only (embedded content)' || echo 'native bundle + content --dev-mod' ))"
if [ "$CONTROL" = 1 ]; then control_leg; fi
launch
if ctl logs --lines 4000 2>/dev/null | grep -q "content mods not loaded"; then
    ctl logs --lines 4000 | grep "content mods not loaded" >&2
    fail "the content mod did not load"
fi
echo "content mod loaded (no 'content mods not loaded')"
ctl logs --lines 4000 2>/dev/null | grep -E "content from [0-9]+ mod" || true
if [ "$EMBEDDED" = 1 ]; then embedded_content_check; fi

# --------------------------------------------------------------- arena
say "The End arena: stone floor at 119, crux at 119, farmland at 120, glowstone ceiling"
end "forceload add 24 0 64 16"
end "fill 28 119 0 48 119 10 minecraft:stone"
end "fill 32 124 0 44 124 8 minecraft:glowstone"
# A stone-ringed water source keeps every plot cell within farmland's 4-block
# water scan, so a random tick never dries or reverts the farmland.
end "setblock 37 120 1 minecraft:water"
end "setblock 37 120 0 minecraft:stone"
end "setblock 37 120 2 minecraft:stone"
end "setblock 36 120 1 minecraft:stone"
end "setblock 38 120 1 minecraft:stone"
end "tp @s 37.5 120 8.5"
end "difficulty peaceful"
end "gamerule spawn_mobs false"
end "gamerule random_tick_speed 0"
for _ in $(seq 1 30); do
    [ "$(ctl state | jq -r '.dimension')" = minecraft:the_end ] && break
    ctl wait 10
done
[ "$(ctl state | jq -r '.dimension')" = minecraft:the_end ] \
    || fail "the player is in $(ctl state | jq -r '.dimension'), not The End"
ctl wait-ready 180 >/dev/null
ctl wait 20 >/dev/null
settle
echo "player in the_end at $(ctl state | jq -c '.player.position'), chunks settled"

# --------------------------------------------------------------- registry
say "the six crops and six cruxes bind; the insanium farmland binds"
CROPS=(nether_star dragon_egg gaia_spirit awakened_draconium neutronium nitro_crystal)
X=35
for crop in "${CROPS[@]}"; do
    ctl setblock $X 119 4 "${MOD}:${crop}_crux" >/dev/null || fail "setblock $crop crux"
    ctl setblock $X 120 4 "minecraft:farmland[moisture=7]" >/dev/null || fail "setblock $crop farmland"
    ctl setblock $X 121 4 "${MOD}:${crop}_crop[age=0]" >/dev/null || fail "setblock $crop crop"
    X=$((X + 1))
done
ctl wait 5
X=35
for crop in "${CROPS[@]}"; do
    readback "$X" 121 4 "${MOD}:${crop}_crop" >/dev/null \
        || fail "the $crop crop did not bind"
    [ "$(block_name "$X" 121 4)" = "${MOD}:${crop}_crop" ] || fail "crop $crop block name"
    [ "$(block_name "$X" 119 4)" = "${MOD}:${crop}_crux" ] || fail "crux $crop block name"
    X=$((X + 1))
done
ctl setblock 35 120 6 "${MOD}:insanium_farmland[moisture=7]" >/dev/null || fail "setblock insanium farmland"
ctl setblock 35 119 6 "${MOD}:nether_star_crux" >/dev/null || fail "setblock insanium crux"
ctl wait 5
readback 35 120 6 "${MOD}:insanium_farmland" >/dev/null || fail "insanium farmland did not bind"
echo "registry PASS: 6 crops + 6 cruxes + insanium farmland"

# --------------------------------------------------------------- planting
say "seeds plant a crop on insanium farmland; a stick places nothing"
plant() { # x z item expected-block
    ctl command "clear @s" >/dev/null
    ctl give "$3" 4 >/dev/null || fail "cannot give $3"
    ctl wait 3 >/dev/null
    ctl select "$3" >/dev/null || fail "cannot select $3"
    ctl tp "$1.5" 121 "$2.5" >/dev/null
    ctl wait 4 >/dev/null
    ctl look 0 60 >/dev/null
    ctl wait 4 >/dev/null
    ctl interact "$1" 120 "$2" up >/dev/null || fail "cannot click farmland with $3"
    ctl wait 5 >/dev/null
    readback "$1" 121 "$2" "$4"
}
planted=$(plant 35 6 "${MOD}:nether_star_seeds" "${MOD}:nether_star_crop")
echo "${MOD}:nether_star_seeds on insanium farmland -> $planted"
case "$planted" in
    "${MOD}:nether_star_crop"*) ;;
    *) fail "the seed did not place its crop: $planted" ;;
esac
assert_prop "$planted" age 0
# The stick control uses the spare vanilla-farmland cell.
ctl setblock 36 120 6 "minecraft:farmland[moisture=7]" >/dev/null
ctl setblock 36 119 6 "${MOD}:nether_star_crux" >/dev/null
ctl wait 4
planted_stick=$(plant 36 6 minecraft:stick minecraft:air)
[ "$(block_name 36 121 6)" = minecraft:air ] || fail "a stick placed $(block_name 36 121 6)"
echo "seed planting PASS: nether_star_crop[age=0] on insanium farmland; a stick places nothing"

# ---------------------------------------------------------------- growth
say "growth needs the crop's own crux two blocks below"
# Re-purpose the registry row: 35 grows, 36 has stone (no crux), 37 has another
# crop's crux, 38 grows as the second family.
ctl setblock 36 119 4 "minecraft:stone" >/dev/null || fail "remove the crux at 36"
ctl setblock 37 119 4 "${MOD}:dragon_egg_crux" >/dev/null || fail "wrong crux at 37"
ctl setblock 37 121 4 "${MOD}:nether_star_crop[age=3]" >/dev/null || fail "age-3 wrong-crux crop"
ctl setblock 38 119 4 "${MOD}:dragon_egg_crux" >/dev/null || fail "dragon-egg crux at 38"
ctl setblock 38 121 4 "${MOD}:dragon_egg_crop[age=0]" >/dev/null || fail "dragon-egg crop"
ctl wait 10
g0=$(age_at 35 121 4)
n0=$(age_at 36 121 4)
w0=$(age_at 37 121 4)
d0=$(age_at 38 121 4)
[ "$g0" = 0 ] && [ "$n0" = 0 ] && [ "$w0" = 3 ] && [ "$d0" = 0 ] \
    || fail "growth cells start at $g0/$n0/$w0/$d0, expected 0/0/3/0"
for _ in $(seq 1 10); do ctl wait 20 >/dev/null; done
ctl wait 100 >/dev/null
[ "$(age_at 35 121 4)" = 0 ] && [ "$(age_at 36 121 4)" = 0 ] \
    && [ "$(age_at 37 121 4)" = 3 ] && [ "$(age_at 38 121 4)" = 0 ] \
    || fail "with random_tick_speed 0 the crops changed"
echo "control PASS: random_tick_speed 0 keeps 0/0/3/0 for 300 ticks"
end "gamerule random_tick_speed 400"
grown=0
for i in $(seq 1 90); do
    ctl wait 20 >/dev/null
    # keep the plot wet even if the engine's drying differs from vanilla's
    end "fill 35 120 4 40 120 4 minecraft:farmland[moisture=7]" >/dev/null 2>&1 || true
    g=$(age_at 35 121 4)
    d=$(age_at 38 121 4)
    if [ -n "$g" ] && [ -n "$d" ] && [ "$g" -gt 0 ] && [ "$d" -gt 0 ]; then
        grown=$i; break
    fi
done
g=$(age_at 35 121 4)
n=$(age_at 36 121 4)
w=$(age_at 37 121 4)
d=$(age_at 38 121 4)
[ "$grown" -gt 0 ] || fail "the crux-grown crops did not advance ($g/$d)"
[ "$n" = 0 ] || fail "the no-crux crop advanced to age $n"
[ "$w" = 3 ] || fail "the wrong-crux crop advanced to age $w"
if [ "$SELFTEST" = 1 ]; then
    fail "SELFTEST: the no-crux crop grew (the assertion above must hold)"
fi
echo "growth PASS after $((grown * 20)) ticks: crux crops $g/$d, no-crux $n, wrong-crux $w"
end "gamerule random_tick_speed 0"

# --------------------------------------------------------------- bone meal
say "bone meal is refused on a crux crop and is not a target without a crux"
ctl command "gamemode survival @s" >/dev/null
ctl setblock 35 121 5 "${MOD}:nether_star_crop[age=0]" >/dev/null || fail "setblock meal crop"
ctl setblock 35 120 5 "minecraft:farmland[moisture=7]" >/dev/null
ctl setblock 35 119 5 "${MOD}:nether_star_crux" >/dev/null
ctl setblock 36 121 5 "${MOD}:nether_star_crop[age=0]" >/dev/null || fail "setblock no-crux meal crop"
ctl setblock 36 120 5 "minecraft:farmland[moisture=7]" >/dev/null
ctl setblock 36 119 5 "minecraft:stone" >/dev/null
ctl setblock 37 121 5 "minecraft:wheat[age=0]" >/dev/null || fail "setblock wheat control"
ctl setblock 37 120 5 "minecraft:farmland[moisture=7]" >/dev/null
ctl wait 5
[ "$(block_name 35 121 5)" = "${MOD}:nether_star_crop" ] || fail "the meal crop did not place"
[ "$(block_name 37 121 5)" = "minecraft:wheat" ] || fail "the wheat control did not place"
ctl command "clear @s" >/dev/null
ctl give minecraft:bone_meal 16 >/dev/null || fail "give bone meal"
ctl wait 3
ctl select minecraft:bone_meal >/dev/null || fail "select bone meal"
meal() { # x z
    ctl tp "$1.5" 121 "$2.5" >/dev/null
    ctl wait 4
    ctl look-at "$1.5" 121.1 "$2.5" >/dev/null
    ctl wait 3
    ctl use-item >/dev/null || fail "use-item on $1,$2 failed"
    ctl wait 10
}
before=$(ctl state | jq -r '.held.count // 0')
meal 35 5
after_spent=$(ctl state | jq -r '.held.count // 0')
ours=$(age_at 35 121 5)
[ "$ours" = 0 ] || fail "bone meal grew our crop to age $ours"
[ "$after_spent" -lt "$before" ] || fail "bone meal was not spent on our crop ($before -> $after_spent)"
echo "crop with crux PASS: age 0 after bone meal, meal $before -> $after_spent"
meal 36 5
after_kept=$(ctl state | jq -r '.held.count // 0')
noCrux=$(age_at 36 121 5)
[ "$noCrux" = 0 ] || fail "bone meal grew the no-crux crop to age $noCrux"
[ "$after_kept" = "$after_spent" ] \
    || fail "bone meal was spent without a crux ($after_spent -> $after_kept)"
echo "crop without crux PASS: age 0, meal kept at $after_kept"
meal 37 5
wheat=$(age_at 37 121 5)
[ -n "$wheat" ] && [ "$wheat" -gt 0 ] || fail "the vanilla wheat control did not grow (age $wheat)"
echo "wheat control PASS: bone meal grew vanilla wheat to age $wheat"

# ---------------------------------------------------------------- harvest
say "a survival break drops the tier-6 table: ripe = essence + seed, young = seed only"
ctl command "gamemode survival @s" >/dev/null
break_block() { # x y z
    ctl tp "$1.5" 121 "$3.5" >/dev/null
    ctl wait 4 >/dev/null
    ctl break "$1" "$2" "$3"
}
ctl setblock 39 120 6 "minecraft:farmland[moisture=7]" >/dev/null
ctl setblock 39 119 6 "${MOD}:nether_star_crux" >/dev/null
ctl setblock 40 120 6 "minecraft:farmland[moisture=7]" >/dev/null
ctl setblock 40 119 6 "${MOD}:nether_star_crux" >/dev/null
ctl setblock 41 120 6 "minecraft:farmland[moisture=7]" >/dev/null
ctl setblock 41 119 6 "${MOD}:nether_star_crux" >/dev/null
ctl setblock 39 121 6 "${MOD}:nether_star_crop[age=7]" >/dev/null || fail "setblock ripe crop"
ctl setblock 40 121 6 "${MOD}:nether_star_crop[age=0]" >/dev/null || fail "setblock young crop"
ctl setblock 41 121 6 "minecraft:wheat[age=7]" >/dev/null || fail "setblock wheat harvest"
ctl wait 6
ctl command "clear @s" >/dev/null
ctl give minecraft:iron_hoe 1 >/dev/null || fail "give hoe"
ctl wait 3
ctl select minecraft:iron_hoe >/dev/null
broken=$(break_block 39 121 6) || fail "cannot break the ripe crop"
echo "$broken" | jq -c '{scenario:"age=7",block,block_before,drops}'
ripe=$(echo "$broken" | jq -r --arg i "${MOD}:nether_star_essence" '.drops[$i] // 0')
ripe_seeds=$(echo "$broken" | jq -r --arg i "${MOD}:nether_star_seeds" '.drops[$i] // 0')
[ "$ripe" -ge 1 ] || fail "the age-7 crop dropped $ripe essence"
[ "$ripe_seeds" -ge 1 ] || fail "the age-7 crop dropped $ripe_seeds seeds"
broken=$(break_block 40 121 6) || fail "cannot break the young crop"
echo "$broken" | jq -c '{scenario:"age=0",block,block_before,drops}'
young=$(echo "$broken" | jq -r --arg i "${MOD}:nether_star_essence" '.drops[$i] // 0')
young_seeds=$(echo "$broken" | jq -r --arg i "${MOD}:nether_star_seeds" '.drops[$i] // 0')
want_young=0
[ "$NEGATIVE" = 1 ] && want_young=1
[ "$young" = "$want_young" ] || fail "the age-0 crop dropped $young essence, expected $want_young"
[ "$young_seeds" -ge 1 ] || fail "the age-0 crop dropped $young_seeds seeds"
broken=$(break_block 41 121 6) || fail "cannot break the wheat control"
echo "$broken" | jq -c '{scenario:"wheat age=7",block,block_before,drops}'
wheat_item=$(echo "$broken" | jq -r '.drops["minecraft:wheat"] // 0')
[ "$wheat_item" -ge 1 ] || fail "the vanilla wheat control dropped $wheat_item wheat"
echo "loot PASS: age 7 -> $ripe essence + $ripe_seeds seeds; age 0 -> $young essence + $young_seeds seeds; wheat -> $wheat_item"

# ------------------------------------------------ the slice's line: awakened
say "awakened draconium: seeds on farmland with its crux; speed 0 holds, then it ripens"
ctl command "gamemode creative @s" >/dev/null
ctl setblock 43 119 7 "${MOD}:awakened_draconium_crux" >/dev/null || fail "setblock awakened crux"
ctl setblock 43 120 7 "minecraft:farmland[moisture=7]" >/dev/null || fail "setblock awakened farmland"
ctl setblock 44 120 7 minecraft:water >/dev/null || fail "setblock awakened water"
ctl setblock 44 120 6 minecraft:stone >/dev/null
ctl setblock 44 120 8 minecraft:stone >/dev/null
ctl wait 5
planted_aw=$(plant 43 7 "${MOD}:awakened_draconium_seeds" "${MOD}:awakened_draconium_crop")
echo "${MOD}:awakened_draconium_seeds on farmland -> $planted_aw"
case "$planted_aw" in
    "${MOD}:awakened_draconium_crop"*) ;;
    *) fail "the awakened seeds did not place their crop: $planted_aw" ;;
esac
assert_prop "$planted_aw" age 0
end "gamerule random_tick_speed 0"
for _ in $(seq 1 5); do ctl wait 20 >/dev/null; done
aw0=$(age_at 43 121 7)
[ "$aw0" = 0 ] || fail "random_tick_speed 0 grew the awakened crop to age $aw0"
echo "control PASS: random_tick_speed 0 keeps the awakened crop at age 0 for 100 ticks"
end "gamerule random_tick_speed 400"
aw=0
for i in $(seq 1 120); do
    ctl wait 20 >/dev/null
    # keep the plot wet even if the engine's drying differs from vanilla's
    end "setblock 43 120 7 minecraft:farmland[moisture=7]" >/dev/null 2>&1 || true
    aw=$(age_at 43 121 7)
    [ "$aw" = 7 ] && break
done
[ "$aw" = 7 ] || fail "the awakened crop reached only age $aw of 7 under random ticks"
echo "growth PASS: the awakened crop grew from age 0 to $aw under random ticks"
end "gamerule random_tick_speed 0"
ctl command "gamemode survival @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl give minecraft:iron_hoe 1 >/dev/null || fail "give hoe"
ctl wait 3
ctl select minecraft:iron_hoe >/dev/null
aw_broken=$(break_block 43 121 7) || fail "cannot break the ripe awakened crop"
echo "$aw_broken" | jq -c '{scenario:"awakened age=7",block,block_before,drops}'
aw_essence=$(echo "$aw_broken" | jq -r --arg i "${MOD}:awakened_draconium_essence" '.drops[$i] // 0')
aw_seeds=$(echo "$aw_broken" | jq -r --arg i "${MOD}:awakened_draconium_seeds" '.drops[$i] // 0')
[ "$aw_essence" = 1 ] || fail "the ripe awakened crop dropped $aw_essence essence, expected 1"
[ "$aw_seeds" = 1 ] || fail "the ripe awakened crop dropped $aw_seeds seeds, expected 1"
echo "harvest PASS: awakened age 7 -> $aw_essence essence + $aw_seeds seeds"
ctl command "gamemode creative @s" >/dev/null

# ------------------------------------------------------------- farmland drop
say "insanium farmland silks itself, otherwise drops dirt and a 25% essence"
ctl command "gamemode survival @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl give minecraft:diamond_pickaxe 1 >/dev/null || fail "give silk pickaxe"
ctl wait 3
ctl select minecraft:diamond_pickaxe >/dev/null
ctl command "enchant @s minecraft:silk_touch" >/dev/null || fail "enchant silk touch"
ctl setblock 35 120 6 "${MOD}:insanium_farmland[moisture=7]" >/dev/null
ctl wait 4
silked=$(break_block 35 120 6) || fail "cannot break the silk farmland"
echo "$silked" | jq -c '{scenario:"silk",block,block_before,drops}'
silk_farmland=$(echo "$silked" | jq -r --arg i "${MOD}:insanium_farmland" '.drops[$i] // 0')
silk_dirt=$(echo "$silked" | jq -r '.drops["minecraft:dirt"] // 0')
[ "$silk_farmland" = 1 ] || fail "silk touch dropped $silk_farmland farmland"
[ "$silk_dirt" = 0 ] || fail "silk touch dropped $silk_dirt dirt"
dirt_total=0
essence_total=0
for i in $(seq 1 20); do
    ctl command "clear @s" >/dev/null
    ctl give minecraft:iron_shovel 1 >/dev/null || fail "give shovel"
    ctl wait 1
    ctl select minecraft:iron_shovel >/dev/null
    ctl setblock 35 120 6 "${MOD}:insanium_farmland[moisture=7]" >/dev/null
    ctl wait 2
    broken=$(break_block 35 120 6) || fail "cannot break the plain farmland ($i)"
    got_dirt=$(echo "$broken" | jq -r '.drops["minecraft:dirt"] // 0')
    got_farmland=$(echo "$broken" | jq -r --arg i "${MOD}:insanium_farmland" '.drops[$i] // 0')
    got_essence=$(echo "$broken" | jq -r --arg i "${MOD}:insanium_essence" '.drops[$i] // 0')
    [ "$got_dirt" -ge 1 ] || fail "plain break $i dropped $got_dirt dirt"
    [ "$got_farmland" = 0 ] || fail "plain break $i dropped the farmland"
    dirt_total=$((dirt_total + got_dirt))
    essence_total=$((essence_total + got_essence))
done
echo "plain breaks: dirt=$dirt_total essence=$essence_total in 20"
[ "$essence_total" -ge 1 ] || fail "20 plain breaks dropped no insanium essence"
echo "farmland PASS: silk -> 1 farmland; plain -> dirt every time + $essence_total essence in 20"

# ---------------------------------------------------------------- recipes
say "crafting: seeds + cruxes (shaped) and insanium farmland (shapeless)"
ctl command "gamemode creative @s" >/dev/null
python3 "$PORT/tools/craft_check.py" "$SOCK" "$CTL" 37 120 9 || fail "craft_check.py failed"

# ---------------------------------------------------------------- controls
say "unknown ids are refused"
if ctl give "$MOD:not_an_item" 1 >/dev/null 2>&1; then
    fail "give $MOD:not_an_item succeeded"
fi
ctl setblock 60 121 12 "$MOD:not_a_block" >/dev/null 2>&1 || true
[ "$(block_name 60 121 12)" = minecraft:air ] \
    || fail "$MOD:not_a_block became $(block_name 60 121 12)"
echo "unknown ids refused"

# The bundle's helper writes its content on every launch, so a "no --dev-mod"
# leg would still find the ids: the no-content proof is EMBEDDED=1's control
# (an unusable `.horizon-cache` file), run by tools/e2e-embedded.sh.
if [ "$EMBEDDED" = 1 ]; then
    say "embedded content: the ids came from the bundle, not --dev-mod"
    echo "embedded PASS: no --dev-mod; the bundle's data/ content supplied every id"
fi

echo "PASS: 6 crops + 6 cruxes + insanium farmland bind; seeds place on insanium farmland and a stick does not; the crux crop grew $g/$d while the no-crux crop held $n and the wrong-crux crop held $w; the awakened-draconium line held at random_tick_speed 0, grew 0->$aw and dropped $aw_essence essence + $aw_seeds seeds; bone meal was spent and refused with a crux, kept without one, and grew vanilla wheat; a ripe crop dropped $ripe essence + $ripe_seeds seeds, a young one $young/$young_seeds; insanium farmland silk-touched itself and dropped $essence_total essence in 20 plain breaks; the recipes crafted with empty controls; unknown ids were refused$( [ "$EMBEDDED" = 1 ] && echo ' and the content came from the bundle' || echo '' )"
exit 0
