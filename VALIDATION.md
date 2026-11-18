# Validation — Mystical Agradditions

> **2026-11-12 (review repairs, PR #676).** The delivered bytes changed when the
> MIT notices were stamped into the carried content and `tools/package.sh` began
> running `tools/stamp_license.py` itself: content `.hmod` **73,306 B**
> `dc2dbd84…1a86` (173 files) and bundle **47,876 B** `134efc0e…ce7b`
> (12 entries). The tables below record the pre-repair run; `notes.md`,
> *Verification after the repairs*, has the fresh evidence.

Pin: Horizon `1d63e0a5a37a7a708eb0b32b49bf0dfeb28ed8a9`, horizon-mixins
`5a64af938ec86b00d53d16a408aabc0038fb3e57` (schema 6). Every build, test and
e2e ran through `ports/tools/build-slot.sh` with `CARGO_INCREMENTAL=0`; no
`--target-dir`, no bare cargo outside a lease.

Slice 1 (the six tier-6 families, cruxes, insanium farmland) was verified on
2026-11-09 and is unchanged. Slice 2 (the awakened-draconium line and the
embedded `.hnmod`) is the run recorded here.

On **2026-11-11** the port version was set to `0.1.0` (playbook §1.7: the
registry version, file and release carry the port's own number, never upstream's
`1.21.1-8.0.15`) in `content/horizon-mod.toml`, the mixin plan, `Cargo.toml`, the
carry generator and `tools/package.sh`. Rows 10, 11 and 15–17 below are the
re-run after that change; the code, hooks, ids and content are byte-identical and
the embedded scenario passed unchanged.

## Ladder

| # | Step | Command | Result |
|---|---|---|---|
| 1 | runtime red | `cargo test --locked --offline` (the two `harvest` tests, `todo!()` body) | **6 passed, 2 failed** — `not yet implemented` at `harvest` |
| 2 | runtime green | the same, implemented | **8 passed, 0 failed** (`standalone-fmt-clippy-test.log`) |
| 3 | fmt | `cargo fmt --all --check` | exit 0 |
| 4 | clippy | `cargo clippy --workspace --all-targets --locked --offline -- -D warnings` | exit 0, **0 warnings** |
| 5 | stage | `python3 tools/horizon.py stage` | `stage_changed: true`, **2 modules, 5 injections** (`embed-stage.log`) |
| 6 | check | `python3 tools/horizon.py check` | `cargo_exit: 0`, 0 warnings (`horizon-check.log`) |
| 7 | embedded tests | `python3 tools/horizon.py test` | **8 passed; 0 failed; 1240 filtered out** (`horizon-test.log`) |
| 8 | fast build | `python3 tools/horizon.py build` | `cargo_exit: 0`, 0 warnings (`embed-build.log`) |
| 9 | content carry | `python3 tools/carry_content.py --check` | **171 files, 0 pending** |
| 10 | `.hmod` | `cargo-horizon-mod build` in `content/` | **71,827 B**, SHA-256 `0a5cdcd77ca062157f081ab874bedbc98708cab248968237db939f3de296feb4`, 171 files, "no code: content only"; a second run reproduced the same bytes (`package-0.1.0.log`) |
| 11 | `.hnmod` | `tools/package.sh` (build → copy → package → check) | **45,205 B**, SHA-256 `f08aad3688521ea62ee35c575a42423ec605884eac138849decf66fbdf8888b0`, **10 entries**; `horizon-native.json` version **0.1.0**; a second run reproduced the same bytes; `check --kind native-mod` exit 0 (`package-0.1.0.log`) |
| 12 | e2e default | `build-slot.sh run --step e2e … -- bash tools/e2e-all.sh` | **`PASS` + `EXIT:0`** (`e2e-default.log`) |
| 13 | e2e default selftest | `SELFTEST=1` leg | **`FAIL` + `EXIT:1`** at the no-crux growth assertion (`e2e-selftest.log`) |
| 14 | e2e negative | `NEGATIVE=1` leg | **`FAIL` + `EXIT:1`** at the young-crop essence assertion (`e2e-negative.log`) |
| 15 | e2e embedded | `tools/e2e-embedded.sh`, leg 1 (`EMBEDDED=1 CONTROL=1`) | **`PASS` + `EXIT:0`** with no `--dev-mod`; the written cache file is 71,827 B and identical to `content/mysticalagradditions.hmod` (SHA-256 `0a5cdcd7…feb4`) (`e2e-embedded.log`) |
| 16 | e2e embedded selftest | the same driver, leg 2 (`EMBEDDED=1 SELFTEST=1`) | **`FAIL` + `EXIT:1`** (`e2e-embedded-selftest.log`) |
| 17 | checker | `python3 ports/tools/check-e2e-logs.py mysticalagradditions --strict` | **logs=5 ok=5**, missing-exit=0, bad-exit=0 |

## e2e default (abridged; full log in `../_shared/evidence/mysticalagradditions/`)

```
content mod loaded (no 'content mods not loaded')
registry PASS: 6 crops + 6 cruxes + insanium farmland
seed planting PASS: nether_star_crop[age=0] on insanium farmland; a stick places nothing
control PASS: random_tick_speed 0 keeps 0/0/3/0 for 300 ticks
growth PASS after … ticks: crux crops 3/2, no-crux 0, wrong-crux 3
crop with crux PASS: age 0 after bone meal, meal 16 -> 15
crop without crux PASS: age 0, meal kept at 15
wheat control PASS: bone meal grew vanilla wheat to age 3
{"scenario":"age=7",…,"drops":{"mysticalagradditions:nether_star_essence":1,"mysticalagradditions:nether_star_seeds":1}}
{"scenario":"age=0",…,"drops":{"mysticalagradditions:nether_star_seeds":1}}
== awakened draconium: seeds on farmland with its crux; speed 0 holds, then it ripens ==
mysticalagradditions:awakened_draconium_seeds on farmland -> mysticalagradditions:awakened_draconium_crop[age=0]
control PASS: random_tick_speed 0 keeps the awakened crop at age 0 for 100 ticks
growth PASS: the awakened crop grew from age 0 to 7 under random ticks
{"scenario":"awakened age=7",…,"drops":{"mysticalagradditions:awakened_draconium_essence":1,"mysticalagradditions:awakened_draconium_seeds":1}}
harvest PASS: awakened age 7 -> 1 essence + 1 seeds
farmland PASS: silk -> 1 farmland; plain -> dirt every time + 5 essence in 20
recipe PASS: nether_star_seeds, nether_star_crux, dragon_egg_crux and insanium_farmland craft; wrong-ingredient controls stay empty
unknown ids refused
PASS: …
EXIT:0
```

## e2e embedded (abridged; `e2e-embedded.log`)

```
== launch (offscreen renderer, The End, native bundle only (embedded content)) ==
== control: the same game with no embedded content file ==
  without the embedded file: no seed item, the crop block stayed minecraft:air
  embedded content: 71827 B at …/.horizon-cache/mysticalagradditions-embedded-content.hmod, identical to content/mysticalagradditions.hmod
  bundle entry mixins/mysticalagradditions/data/mysticalagradditions-content.hmod: 71827 B, identical
… the whole scenario, including the awakened line and the 1 essence + 1 seed drop …
embedded PASS: no --dev-mod; the bundle's data/ content supplied every id
PASS: …
EXIT:0
```

## Harness facts worth keeping

- The embedded helper writes its content on **every** launch, so a "relaunch
  without `--dev-mod`" control no longer proves absence; the no-content proof
  is an unusable `.horizon-cache` path (a directory at the helper's exact file
  name), which is what `CONTROL=1` does.
- A 4-pixel crop is not clickable through `ctl interact … up`; `look-at` the
  crop block then `use-item` applies the meal (the parent port's finding holds).
- `ctl break` in survival returns the drops; silk touch is applied with
  `ctl command "enchant @s minecraft:silk_touch"` after selecting the tool.
- The farmland drop's 25 % essence is a real roll: assert composition per break
  and "at least one in 20", not an exact count.
- The awakened plot needs its own water source; the growth loop rewrites
  `farmland[moisture=7]` each interval so a dry plot cannot stop the run.
