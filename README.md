# mysticalagradditions (Horizon port)

A Horizon port of [mysticalagradditions](BlakeBr0/MysticalAgradditions) — MIT.

**Status: first slices.** What is below is what the port actually does today.

## Implemented so far

- Crops** `mysticalagradditions:<name>_crop` (`nether_star`, `dragon_egg`,
- `gaia_spirit`, `awakened_draconium`, `neutronium`, `nitro_crystal`) on the
- `minecraft:wheat` template: `age` 0..7, the jar's 4-pixel outline with an
- empty collision, vanilla crop random tick.
- Seeds/essences** `mysticalagradditions:<name>_seeds` (a plain item with
- `place_block`, as the parent port does) and `<name>_essence` items.
- Cruxes** `mysticalagradditions:<name>_crux` on the `minecraft:stone`
- template, hardness 5.0 / blast 10.0, `requires_tool`, the jar's

## Not yet ported

- nothing recorded yet

## Install

Build the bundle with a native-mod capable launcher, or add the file from the
registry once it is listed. Pinned to Horizon `1d63e0a` and horizon-mixins
`5a64af93` for game 26.3.

## Build from source

```sh
cargo test
python3 tools/horizon.py check --horizon <horizon checkout>
python3 tools/horizon.py build --horizon <horizon checkout>
python3 tools/package.py
```

## Credits and licence

Original mod: BlakeBr0/MysticalAgradditions. Port: AdLf0208. Licence: MIT — see [LICENSE](LICENSE);
the original notices are preserved.
