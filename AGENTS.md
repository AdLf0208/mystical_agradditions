# Working on a native Horizon mod — `mysticalagradditions`

> **SDK format (2026-11-18).** Horizon's mod-API merge (#16941) retired `.hnmod`.
> This port is **one flat `.hmod`**: `horizon-mod.toml` + `Cargo.toml` +
> `src/lib.rs` (one `impl mod_api::Hooks`) + `src/runtime.rs` + `src/support.rs`
> + `assets/` + `data/`. There is no `compatibility.json`, no `mixins/`, no
> `content/`, no `horizon-mixin.toml` and no `tools/horizon.py`; the retired tree
> is kept as evidence under
> `../_shared/evidence/mysticalagradditions/retired-hnmod-0.1.0/`.

Read `README.md` and `notes.md` (its `## Migration to the SDK format` section has
the file map, the hook table and the traps) before editing.

## Build it

The SDK is the gate: `cargo horizon-mod build` fetches `.horizon/sdk/` (pinned to
`0b14f8ac…`, gitignored) and builds the package; the **launcher** compiles the
native code into a game, which is not installed here.

```sh
cd ports/mysticalagradditions
CARGO_INCREMENTAL=0 cargo test                        # runtime + the glue's own test
CARGO_INCREMENTAL=0 cargo clippy --all-targets -- -D warnings
cargo fmt --check                                     # never `--all`: it formats the SDK
rm -f Cargo.lock                                      # the lock is packed and changes the artifact
CARGO_INCREMENTAL=0 cargo horizon-mod build            # -> target/horizon-mod/mysticalagradditions.hmod
cp target/horizon-mod/mysticalagradditions.hmod ./mysticalagradditions.hmod
cargo horizon-mod check mysticalagradditions.hmod
cargo horizon-mod fits mysticalagradditions.hmod --build nightly
python3 tools/carry_content.py --check                # the carried content still matches the jar
```

Every compile goes through the campaign slot runner, which is only a **slot
guard** here (it speaks the retired `tools/horizon.py` ladder, so it does not
drive these steps):

```sh
BUILD_LOCAL=1 ../tools/build-slot.sh run --job mysticalagradditions-sdk \
    --port ports/mysticalagradditions --step test -- \
    bash -c 'cd ports/mysticalagradditions && CARGO_INCREMENTAL=0 cargo test --offline'
```

## Rules that matter here

- `src/runtime.rs` is **byte-identical** to the retired `mixins/…/runtime.rs`
  (sha256 `00bb7243…c520`); never let `cargo fmt` rewrite it, and prove it with
  `cmp` and with `unzip -p <id>.hmod src/runtime.rs | sha256sum` after a build.
- The game-side glue lives in `src/support.rs`; it holds no rule of its own.
- `assets/` and `data/` are the package root now, written by
  `tools/carry_content.py` (the root `horizon-mod.toml` is the only manifest).
- `Cargo.lock` and `.horizon/` are gitignored and never delivered.
- Do not commit binaries, exported sources or Minecraft assets.
- Local-only until the licence review approves publishing (MIT, rank 0;
  ARCHITECTURE.md §8).

## Validate

`cargo test`, `cargo clippy --all-targets -- -D warnings`, `cargo fmt --check`,
`cargo horizon-mod build` twice (identical bytes), `check` and `fits` on the
delivered file, and — when a launcher-built game exists — `tools/e2e.sh` with
`GAME=` (`SELFTEST=1` must fail). Keep validation claims and supported revisions
honest: no in-game claim without a `horizon-ctl` transcript.
