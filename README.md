# Mystical Agradditions — a Horizon port

**Mystical Agradditions** is a Minecraft mod. An addon for Mystical Agriculture. This repository is a **port of it to [Horizon](https://github.com/horizon-rust/horizon)**, the Rust engine for Minecraft Java 26.3. It carries the complete source of the port plus the content files it ships, and installs as a single `.hmod` package.

Upstream: [BlakeBr0/MysticalAgradditions](https://github.com/BlakeBr0/MysticalAgradditions) — licence **MIT**.

| | |
|---|---|
| Upstream mod | Mystical Agradditions ([source](https://github.com/BlakeBr0/MysticalAgradditions)) |
| Ported to | Horizon 0b14f8a, Minecraft Java 26.3, mod API `0.2` |
| Package | `mysticalagradditions.hmod` (install it with the Horizon launcher) |
| Licence | **MIT** — the upstream mod's licence; see [Licence and credit](#licence-and-credit) |

## What this port implements

- **No 0.2.0 in-game run.** `horizon-launcher` is not installed here, so no
- Every slice-boundary gap listed above is **unchanged**: the four seed/crux
- **One new recorded difference:** the Part answers the bonemeal questions for
- **Reviewer:** licence notice not in the bundle
- **Reviewer:** description ends mid-sentence, 'nothing recorded yet', relative link
- **Reviewer:** registry artifact delivery

## Not yet ported

- **No 0.2.0 in-game run.** `horizon-launcher` is not installed here, so no
- Every slice-boundary gap listed above is **unchanged**: the four seed/crux
- **One new recorded difference:** the Part answers the bonemeal questions for

## Installing

1. Install the [Horizon launcher](https://github.com/horizon-rust/horizon/releases) (0.2.70 or newer).
2. Add `mysticalagradditions.hmod` to the instance's mods.
3. The package is pinned to a specific Horizon build; the launcher checks that pin.

## Licence and credit

Mystical Agradditions was created by its upstream authors; the code, models and assets in the original mod
remain theirs and are used here under **MIT**. The Rust in this repository is a clean-room
rewrite for Horizon, not a translation of the original source.

- `LICENSE` — the upstream licence text.
- `LICENSE-NOTICE.md` — what this port carries and where it came from.
- The upstream project: https://github.com/BlakeBr0/MysticalAgradditions

## Technical details

```
horizon-mod.toml   package manifest (id, version, api, [native] pin)
Cargo.toml         the crate; depends on `horizon-mod-api` from the fetched SDK
src/               lib.rs (the one `impl Hooks`), runtime.rs (pure logic + tests), glue
assets/ data/      the content the package ships
tools/             content generators and the e2e scenario
```

- Build: `cargo horizon-mod build` (packages; it does not compile against the game).
- Test: `cargo test`, `cargo clippy --all-targets -- -D warnings`.
- In-game: `ports/tools/launcher-game.sh run mysticalagradditions` in the campaign tree, or install the
  `.hmod` and play; the harness scenario is `tools/e2e.sh`.

This repository is generated from the campaign's port at `ports/mysticalagradditions/`; the port's own
`notes.md` is the full record (decisions, traps, evidence).
