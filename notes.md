# Mystical Agradditions → Horizon

Ported from **Mystical Agradditions 1.21.1-8.0.15**
(`BlakeBr0/MysticalAgradditions`, **MIT**), Minecraft Java 1.21.1 NeoForge,
read from `ports/_shared/upstream/mysticalagradditions` at commit
`fe4e81dea20458aa1959f5cfa8ef8354d2955aaa` (`Release 8.0.15`). The upstream
source and the jar were read for behaviour and assets only; the Rust is a
clean-room rewrite. The exact ATM10 jar is
`MysticalAgradditions-1.21.1-8.0.15.jar`, SHA-1
`be6e652de107065342aa3f98945cc5b0b3fa000c`, kept in
[`../_shared/carry-work/mysticalagradditions/`](../_shared/carry-work/mysticalagradditions/)
(the same file at `../_shared/licence-cache/MysticalAgradditions-1.21.1-8.0.15.jar`,
SHA-1 `be6e652de107065342aa3f98945cc5b0b3fa000c`, kept as the licence evidence).
Local-only until publishing is approved (ARCHITECTURE.md §8).

**Format (2026-11-18, 0.2.1 on 2026-11-21):** this port is one flat SDK `.hmod`
(`api = "0.2"`, version `0.2.1`). See
[`## Migration to the SDK format`](#migration-to-the-sdk-format-020-2026-11-18)
for the file map, the retired-injection → typed-hook table and the traps.
`src/runtime.rs` was **byte-identical** to the retired
`mixins/mysticalagradditions/runtime.rs` (sha256
`00bb7243bb0a00fb20558f83aba90200b47ffcbe9a25e08b73a9f862b81ec520`) through
0.2.0; **0.2.1 adds the mob-drop rules to it**, so that hash is now history and
the file's tests grew from 8 to 14 (the crate's total is 17 with the glue's
three). The sections on the retired `.hnmod` container (Slice 2's embedding, the
staging ladder) are kept as history; the SDK section says what replaced each
part.

## Approach (from the pin's `docs/modpacks.md`)

- **Class `content`, tier `logic`**, **add-on** (parent `mysticalagriculture`
  is `ported-partial`); provenance `ports/_shared/source-map/atm10-sources.csv`.
  This job is **slice 1**: the six tier-6 crop families (crop block, seeds,
  essence), their six crux blocks, insanium essence and insanium farmland
  carried as content, plus the growth/bone-meal logic that the pin can express
  without inventing API. No block entity, menu, screen, entity or renderer is
  built here; the coal/apple/paxel/ore/fluid/Tinkers families are gaps.
- **Licence:** MIT, read from the jar's `META-INF/neoforge.mods.toml` →
  **rank 0**. Ported now because its parent is ported and it is the next
  workable rank-0 add-on.
- **Carry-over vs agent port:** the crop/seed/essence/crux/farmland assets,
  the shared crop-stage and infused-farmland models (from the parent's MIT
  jar), the lang and the 26.3 loot tables/recipes/tags are carried; the crux
  gate and the bone-meal answer are the agent port. Growth is the **parent's
  mechanism** (the wheat template's own random tick), not a second engine.

## Slice 3 — the Wither drop (0.2.1, 2026-11-21)

Chosen from this port's own gap list, quoted:

> **Out (gaps, next slices):** … the Wither/Ender-Dragon drop handlers
> (`withering_soul`/`dragon_scale` are carried as recipe items without an
> acquisition path) …

Why it is the highest-value family left that fits the tier: class **content**,
tier **logic**, and this is the mod's one remaining server-event behaviour. The
two items were already carried and two carried recipes name them
(`nether_star_crux` uses `withering_soul`, `dragon_egg_seeds` and
`dragon_egg_crux` use `dragon_scale`), so without the handler those recipes were
dead in survival — a carried recipe with no acquisition path is exactly what the
parity rule (2026-11-20) forbids. No block entity, menu, screen, entity or
renderer is added.

### The upstream behaviour (8.0.15, `handler/MobDropsHandler.java`)

Read from `BlakeBr0/MysticalAgradditions` at `fe4e81dea20458aa1959f5cfa8ef8354d2955aaa`
(`Release 8.0.15`; file `handler/MobDropsHandler.java`):

- `onLivingDrops(LivingDropsEvent)` returns at once unless
  `level.getGameRules().getBoolean(RULE_DOMOBLOOT)`.
- `entity instanceof WitherBoss && Math.random() < witheringSoulChance` adds one
  `withering_soul` (`config/ModConfigs.java`: `witheringSoulChance` default
  **0.35**, 0..1).
- `entity instanceof EnderDragon && dragonScalesAmount > 0` adds
  `dragonScalesAmount` `dragon_scale` (`dragonScalesAmount` default **8**, 0..64).
- Each is `new ItemEntity(level, x, y, z, stack)`: vanilla's own velocity
  `(rand*0.2 - 0.1, 0.2, rand*0.2 - 0.1)` and ten-tick pickup delay.

### The rules and the tests

`src/runtime.rs` (new, after `harvest`):

- `MobLoot::{Enabled, Disabled}` for the gamerule answer (a two-variant enum, not
  a `bool` parameter), `MobDrops { withering_souls, dragon_scales }`,
  `mob_drops(kind, roll, loot) -> MobDrops`, and the constants
  `WITHERING_SOUL_CHANCE = 0.35`, `DRAGON_SCALES_AMOUNT = 8`, `WITHER`,
  `ENDER_DRAGON`, `WITHERING_SOUL`, `DRAGON_SCALE`.
- The roll is **strict**: `roll < 0.35` drops, `roll == 0.35` does not — the
  `Math.random() < chance` boundary, tested at 0.0/0.1/0.3499 and
  0.35/0.5/0.999.
- Six new tests: the two roll boundaries, the dragon's fixed eight, another mob
  (zombie, wither skeleton, player, armor stand) drops none of ours, `MobLoot::Disabled`
  drops nothing for either, and the constants name the carried ids and the jar's
  defaults.

`src/support.rs` (new glue): `on_living_drops` reads `minecraft:mob_drops`,
resolves the two `ItemKey`s once in `register`, resolves the entity and its
position, draws the roll for the Wither only (the rule ignores it for every other
kind, so no other death moves the level's stream), builds the two `ItemDrop`s
with vanilla's velocity and pickup delay, and appends them to the entity's own
drop list. `loot_from` maps the gamerule answer (only an explicit `false`
disables; an unreadable rule leaves the handler on) and has its own test.

### Red → green (verbatim)

The runtime tests, written first against a `todo!()` body:

```
---- runtime::tests::a_wither_leaves_one_soul_under_the_configured_chance stdout ----
thread 'runtime::tests::a_wither_leaves_one_soul_under_the_configured_chance' (2505373) panicked at src/runtime.rs:188:5:
not yet implemented
…
test result: FAILED. 11 passed; 5 failed; 0 ignored; 0 measured; 0 filtered out
```

Then the glue's own test (the migration's trap 11: the glue must fail on its own
before it is written):

```
---- support::tests::only_an_explicit_false_do_mob_loot_turns_the_handler_off stdout ----
thread 'support::tests::only_an_explicit_false_do_mob_loot_turns_the_handler_off' (2598612) panicked at src/support.rs:203:5:
not yet implemented
test result: FAILED. 16 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out
```

Green: **17 passed; 0 failed** (`v021-test.log`); clippy `-D warnings` exit 0 with
0 warnings (`v021-clippy.log`); `cargo fmt --check` clean (`v021-fmt.log`).

### What the pin actually does (measured, not assumed)

1. **`kind` is the namespaced entity id**: `minecraft:wither`, not `wither`.
2. **The gamerule is `mob_drops` at this pin**, not `doMobLoot`'s
   `do_mob_loot`: `/gamerule do_mob_loot false` answers *"Incorrect argument for
   command"*, `/gamerule mob_drops` answers *"Game rule mob_drops is currently set
   to true"*. The hook reads `minecraft:mob_drops`.
3. **`living_drops` fires for a `/kill` death** (and the dying mob still resolves
   through `host.entity`): 30 withers killed by the command left 9 souls — the
   jar's 35 % — and a zombie killed the same way left neither drop.
4. **The Ender Dragon's death never tells `living_drops`** at this pin. A probe
   that pushed eight scales from the hook's **first line** (no host read, no
   entity lookup, fresh build) left nothing for a dragon killed four blocks from
   the player, over 400 ticks. `living_death`/`living_death_post` already say the
   dragon "uses a separate death sequence and fires neither living death hook";
   the drop hook behaves the same. The alternatives were checked and rejected:
   `mob_killed` only hears player melee kills and cannot add to a drop list, and
   `entity_leave_level` also fires on chunk unload and dimension change, so it
   would duplicate scales.

### In-game evidence (`../_shared/evidence/mysticalagradditions-e2e/`)

`e2e-default.log` (`PASS` + `EXIT:0`) records, after the crop/recipe legs:

```
== the Wither leaves a soul on its 35% roll and the Ender Dragon eight scales ==
withers summoned with mob_drops off: 5
gamerule PASS: mob_drops off left no withering soul
wither PASS: 9 withering souls from 30 kills (35% each)
differential PASS: a zombie left neither drop
dragon BLOCKED at this pin: one kill left 0 scales (living_drops is not dispatched for the dragon's death sequence)
```

The four fail-capable legs: `e2e-selftest.log` (`FAIL: SELFTEST: the no-crux crop
grew …` + `EXIT:1`), `e2e-negative.log` (`FAIL: the age-0 crop dropped 0 essence,
expected 1` + `EXIT:1`), `e2e-drops-selftest.log` (`FAIL: DROPS_SELFTEST: 30
withers left 9 souls …` + `EXIT:1`) and `e2e-control.log` (the same scenario on
the unmodified Nightly: `FAIL: setblock nether_star crux` + `EXIT:1`).
`check-e2e-logs.py mysticalagradditions-e2e --strict` → **logs=5 ok=5**.

The package's `uses.json` grows from 107 surface entries (4 hooks) to **152
(5 hooks)**: `living_drops` plus its `entity`/`kind`/`drops` fields, the
`GameRuleValue` read, `EntityRef::level`/`position`, `LevelRef::with_random`,
`RandomSource::next_double`, `ItemDrop::new` and `ItemStack::new`.

### Deviations and blocks this slice records

- **The roll's stream.** Upstream draws `Math.random()`, a global stream the pin
  does not expose; the port draws the server level's own `next_double()` for the
  Wither only. Same 0..1 uniform and the same 35 % chance; the draw moves the
  level's stream where upstream's did not.
- **The config is not ported.** `witheringSoulChance` and `dragonScalesAmount`
  are the jar's defaults as constants, as the port already does for
  `requiresEffectiveFarmland`.
- **The dragon half is `blocked(living_drops-ender-dragon)`**: `dragon_scale` is
  still carried without an acquisition path, so `dragon_egg_seeds` and
  `dragon_egg_crux` remain uncraftable in survival. The e2e asserts the gap (0
  scales) so it fails the day the pin starts telling the hook, and then the drop
  is ported and the assertion flips.
- **A harness trap worth keeping:** `launcher-game.sh` reuses a native build
  whose `horizon-mod.toml` is byte-identical, so a code-only change under an
  unchanged manifest runs the **old** binary (`--rebuild` is parsed but not
  used). This cost three probe runs: the game kept running a probe build and
  reported 4 souls per wither. Bumping the manifest forced
  `Compiling mysticalagradditions (1 of 1)`, and every later number is from that
  build.

### Coverage (parity rule, 2026-11-20)

| Jar family | State | Evidence / reason |
|---|---|---|
| 6 tier-6 crop blocks (ages 0..7) | tested | `registry PASS`; `growth PASS` (crux 1/1, no-crux 0, wrong-crux 3) |
| 6 seeds (items + planting) | tested | `seed planting PASS`: seeds place `*_crop[age=0]`, a stick places nothing |
| 6 essences / tier-6 harvest counts | tested | `loot PASS`: age 7 → 1 essence + 1 seed, age 0 → 0 + 1 |
| 6 crux blocks + the crux gate | tested | `registry PASS`; growth cells; `bone meal` spent only with a crux |
| bone-meal refusal | tested | `crop with crux PASS` (age 0, meal spent), `crop without crux PASS` (meal kept) |
| insanium farmland | tested | planting + `farmland PASS` (silk → itself; plain → dirt + 5 essence in 20) |
| insanium essence | tested | `farmland PASS` drops + `insanium_farmland` recipe |
| five carried recipes (`*_seeds`, `*_crux`, farmland) | tested | `recipe PASS`, each with a wrong-ingredient control left empty |
| Wither drop: `withering_soul` | **tested** | `wither PASS` 9/30, `gamerule PASS` (0 with `mob_drops` off), zombie differential 0 |
| Ender-Dragon drop: `dragon_scale` | **blocked(living_drops-ender-dragon)** | measured above; `e2e-default.log` asserts 0 |
| 6 essence-coal items + 6 coal blocks | not ported | the item's whole point is its burn time (`EssenceCoalItem.getBurnTime`); the content API has no fuel/burn-time declaration, so they would be inert |
| 6 essence apples | not ported | `EssenceAppleItem` effects + `essenceAppleDuration`; needs a consumable/effect component carry — next slice candidate |
| 6 paxels | not ported | per-stack tool stats (`break_speed`) are still a pending hook (ARCHITECTURE §3) |
| 4 seed/crux recipe families (botania/avaritia/draconicevolution/powah materials) | not ported | their materials live in unported mods |
| nether/end ores + configured/placed features + biome modifiers | not ported | worldgen carry; the mod's `c:*` ore tags are carried but no ore block is |
| 6 molten fluids + buckets | not ported | fluid registration + buckets; machines-tier work |
| insanium ingot/gemstone/nugget/block chain, `insanium_essence` recipe | not ported | needs the parent's `supremium_essence`, `prosperity_ingot`/`gemstone` and the `mysticalagriculture:infusion_crystals` tag; the parent port carries only inferium essence and prosperity ingot |
| essence→item recipes (`nether_star_shard`, `dragon_egg_chunk`, …) | not ported | use the parent's `*_essence` items by id and `cucumber` recipe types |
| Tinkers' material/casting/melting data | not ported | Tinkers is not in the registry |
| config (`fertilizableTier6Crops`, worldgen toggles, apple duration) | not ported | defaults baked as constants |
| creative tab | not ported | no tab registration carried |
| client tint (crop flower, farmland) | not ported | client half; would need a tint registration |
| farmland `fallOn` (never turns to dirt) | not ported — **now expressible** | the pin's `fall_on` (collect, v1, `LandingWrite`) landed after the 0.1.0 slice recorded this gap; next slice |

Skills: superpowers/using-superpowers,brainstorming,writing-plans,test-driven-development,systematic-debugging,verification-before-completion; BeautifulRust/rust-best-practices,rust-port

## Slice 1 — the six tier-6 crops

- **Crops** `mysticalagradditions:<name>_crop` (`nether_star`, `dragon_egg`,
  `gaia_spirit`, `awakened_draconium`, `neutronium`, `nitro_crystal`) on the
  `minecraft:wheat` template: `age` 0..7, the jar's 4-pixel outline with an
  empty collision, vanilla crop random tick.
- **Seeds/essences** `mysticalagradditions:<name>_seeds` (a plain item with
  `place_block`, as the parent port does) and `<name>_essence` items.
- **Cruxes** `mysticalagradditions:<name>_crux` on the `minecraft:stone`
  template, hardness 5.0 / blast 10.0, `requires_tool`, the jar's
  `mineable/pickaxe` + `needs_stone_tool` membership.
- **Insanium farmland** `mysticalagradditions:insanium_farmland` on the
  `minecraft:farmland` template, added to `#minecraft:supports_crops`,
  `#minecraft:grows_crops` and `#minecraft:mineable/shovel`.
- **Growth gate** (`random_tick`, API 33): while the crop's own crux is not two
  blocks below the crop, `handled` skips the wheat template's random tick. The
  parent's `requiresEffectiveFarmland` default is **false**; when true the
  block below must be `insanium_farmland` (`runtime::can_grow`).
- **Bone meal** (`is_valid_bonemeal_target` / `is_bonemeal_success`, API 72):
  a crop is a target only when it can grow and is under age 7, and the growth
  answer is always false — the jar's `isValidBonemealTarget`/`isBonemealSuccess`.
- **Drops** are content loot tables in the **26.3** singular typed shape:
  a ripe crop gives 1 essence + 1 seed, a young one 1 seed (tier 6's
  `secondarySeedDrop` is false, so there is no second roll). The farmland
  table gives itself with silk touch, else dirt + a 25% insanium essence.
- **Recipes:** the jar's `MEM/ESE/MEM` seed recipe for `nether_star` and
  `dragon_egg`; the `nether_star_crux` and `dragon_egg_crux` shaped recipes;
  insanium farmland (essence + farmland), with `#c:storage_blocks/diamond`
  supplied as a tag.

## Slice 2 — the awakened-draconium line and one embedded `.hnmod`

> **Historical (0.1.0).** The embedding described here is the retired AE2
> `content_root` pattern; the SDK package carries `assets/` and `data/` itself,
> so there is nothing to write out at start. The line's behaviour and its
> assertions still describe the slice and are unchanged.

Slice 2 adds no new crop family; it proves **one tier-6 line in full** and
makes the port **one installable file**:

- **The awakened-draconium line.** `awakened_draconium_seeds` plant their crop
  on plain farmland with `awakened_draconium_crux` two blocks below; the crop
  holds at `random_tick_speed 0`, grows 0→7 through the wheat template's random
  tick once the speed is raised, and a survival break drops exactly
  **1 awakened-draconium essence + 1 seed** (tier 6's `secondarySeedDrop` is
  false, so the jar's second-stack branches are unreachable). The e2e log
  records the planted crop, the speed-0 hold, the growth to age 7 and the
  drop JSON (`e2e-embedded.log`, `e2e-default.log`).
- **The harvest moved into code.** `runtime::harvest(age)` is the jar's
  `MysticalCropBlock.getDrops` (`lib/ModCropTiers.java` sets tier 6's secondary
  seed drop off): young → 1 seed, ripe → 1 essence + 1 seed. One `loot_drops`
  hook (API 75) replaces the rolled table for our crop; the 26.3 loot tables
  stay the content-only fallback for paths the hook does not hear. The 10 %
  fertilized-essence roll remains out of slice (the parent's item is not
  carried).
- **Content inside the `.hnmod` (the AE2 pattern).** The built
  `content/mysticalagradditions.hmod` travels at
  `mixins/mysticalagradditions/data/mysticalagradditions-content.hmod`;
  `embedded_content.rs` writes it to
  `.horizon-cache/mysticalagradditions-embedded-content.hmod` once and appends
  it to the dev-mod list from one `content_root` HEAD injection. One
  `mysticalagradditions.hnmod` now installs the blocks, items and behaviour, so
  the registry can list it (the old "two package files" deviation is gone).
  `tools/package.py` refuses a `data/` copy that differs from the built
  `.hmod`, and `tools/package.sh` builds → copies → packages → checks in that
  order.
- **e2e.** `tools/e2e-embedded.sh` stages and builds inside one lease, checks
  the staged `mods.rs` calls the helper and that the binary carries the content
  name, then runs `EMBEDDED=1 CONTROL=1` (no `--dev-mod`; an unusable
  `.horizon-cache` path makes the ids unknown) and `EMBEDDED=1 SELFTEST=1`
  (must exit non-zero). `tools/e2e-all.sh` keeps the default, selftest and
  negative legs. Five verdict logs are in the evidence directory.

### Deliberate deviations

- **Namespace.** Upstream registers crops/seeds/essences in
  `mysticalagriculture:` through the parent's crop registry. The pin has no
  parent-defined registration surface (ARCHITECTURE.md §3) and two packs cannot
  share a namespace (AGENT_MOD_STRUCTURE.md §6), so our ids live under
  `mysticalagradditions:` and the shared stage/farmland models are copied
  (MIT, parent jar) into our namespace so the `.hmod` loads alone.
- **Seed recipes.** The custom `mysticalagriculture:seed/crafting` recipe uses
  a `crop_component` ingredient (a custom type 26.3 cannot parse); the two
  families whose material exists here are rewritten as the jar's shape with
  `minecraft:wheat_seeds` in the centre, as the parent port did for inferium.
  The other four need botania/avaritia/draconicevolution/powah items.
- **Crux recipes.** Only `nether_star` and `dragon_egg` are craftable here;
  the other four name unported mods.
- **Client tint.** The crop flower and infused-farmland `tintindex` get no
  mod colour registration (the parent port has the same gap).
- **`fallOn`.** Upstream's insanium farmland never turns to dirt when fallen
  on; the farmland template does. There is no fall-on hook at the pin — gap.
- **Fertilized essence.** Upstream's 10% fertilized-essence drop is omitted:
  the parent slice-1 port does not carry `mysticalagriculture:fertilized_essence`.
  Tier 6's deterministic counts (1 essence + 1 seed) are unaffected.

## Slice boundary (what this port is)

**In:** the six tier-6 crop blocks, their seeds and essences, the six cruxes,
insanium essence and insanium farmland; the crux-gated random tick, the
bone-meal refusal, the jar's `getDrops` counts (`loot_drops`); the carried
26.3 loot tables for the crop and farmland; the seven recipes and the two tags
they need; **one embedded `.hnmod`** carrying the content.

**Out (gaps, next slices — Slice 3 above closes the Wither half):** the four other seed/crux recipes (unported mods);
`insanium_essence`'s own recipe (needs supremium essence + the infusion-crystal
tag); the insanium ingot/gemstone/nugget/block chain; the six essence-coal
items + blocks; six apples; six paxels; the four nether/end ores, their
configured/placed features and biome modifiers (worldgen); six molten fluids +
buckets; Tinkers' material/casting/melting data; the Wither/Ender-Dragon drop
handlers (`withering_soul`/`dragon_scale` are carried as recipe items without
an acquisition path); the config (`fertilizableTier6Crops`, worldgen toggles,
apple duration); Patchouli/Jade/JEI; the creative tab; the client tint; the
farmland `fallOn`; the 10% fertilized essence.

## Version

**0.2.1** is the current package: 0.2.0's SDK-format migration plus Slice 3's
Wither drop (`living_drops`) and the move to the 2026-11-20 nightly
`0a875da9…`. The **0.1.0** rows below describe the retired `.hnmod` container,
in which the content mod (`content/horizon-mod.toml`), the mixin plan
(`mixins/mysticalagradditions/horizon-mixin.toml`), the crate and the generators
all carried the port's own number rather than upstream `1.21.1-8.0.15`.
Playbook §1.7 still applies in one manifest: the registry entry, the file and the
release agree on `0.2.1`, and upstream's number stays only as provenance in
comments, `FINDINGS.md` and the jar names.

## Migration to the SDK format (0.2.0, 2026-11-18)

Migrated from the retired `.hnmod` container (Horizon's mod-API merge #16941,
launcher ≥ 0.2.70) to the flat SDK package at nightly
**`0b14f8acfd97fa2c750e42795249dcc981178ca4`** (2026-11-18) with mixins
**`e59da9094f0c2fdda6c627fe9eff22dec6a906f0`**, for game 26.3. The recipe's
origin is `ports/imfast/notes.md`; this port follows the family pattern of
`ports/mysticalagriculture` (its parent), which is a content+code package like
this one. The registry closed this port's former submission, **#906**, with the
2026-11-18 format purge, so **0.2.0 supersedes it** (see the changelog at the end
of this section).

**Done in this order:** the retired paths were **moved** to
`../_shared/evidence/mysticalagradditions/retired-hnmod-0.1.0/` **before** the
first `cargo horizon-mod build` (the packer refuses a tree holding retired
package paths), then `src/runtime.rs` was copied with `cp` and proved with
`cmp` + `sha256sum`, `cargo test` ran on the new crate **before any glue
existed** (8 passed), then the glue was written, its own test was watched to
fail on `todo!()`, and only then implemented.

### File map (old → new)

| Old `.hnmod` layout | New SDK package |
|---|---|
| `mixins/mysticalagradditions/horizon-mixin.toml` (2 `[[module]]`, 5 `[[injection]]`) | `horizon-mod.toml` (id/name/version/api/side/capabilities + `[native]` game/horizon/mixins) |
| `Cargo.toml` (`[lib] path = "mixins/…/runtime.rs"`, `[workspace] members = ["tools/audit"]`) | `Cargo.toml` (`[package]` name/version 0.2.0, one dependency: `horizon-mod-api` from `.horizon/sdk/`) |
| `mixins/mysticalagradditions/runtime.rs` (module + crate lib) | `src/runtime.rs` — **byte-identical** (`cmp`), `pub mod runtime;` at the crate root |
| `mixins/mysticalagradditions/support.rs` (`mysticalagradditions_state` module) | `src/support.rs` — the six crops' `BlockPart`, the loot hook body, the id table |
| `mixins/…/{random_tick,bonemeal_target,bonemeal_success,loot_drops,embedded_content}.rs` | methods of `impl Hooks` and of the Part; `embedded_content.rs` is gone |
| `content/` (`assets/`, `data/`, its own `horizon-mod.toml`, `mysticalagradditions.hmod`) | package root: `assets/` (118 files), `data/` (54), one manifest |
| `mixins/…/data/mysticalagradditions-content.hmod` + the `content_root` injection | **gone**: code and content are one package, so there is nothing to embed |
| `compatibility.json`, `rust-toolchain.toml`, `horizon-native.json` | **gone**: `[native]` in `horizon-mod.toml` is the pin; the launcher's toolchain builds it |
| `tools/horizon.py`, `tools/package.py`, `tools/package.sh`, `tools/test_stage.py`, `tools/test_template.py`, `tools/stamp_license.py`, `tools/audit/`, `.github/`, `PLAN.md`, `PLAN-EMBEDDED.md`, `tools/e2e-embedded.sh` | **retired** to the evidence folder; the SDK ladder is `cargo test` + `cargo horizon-mod build/check/fits` |
| `mysticalagradditions.hnmod` (47,876 B, `134efc0e…ce7b`) | `mysticalagradditions.hmod` (181 entries, 88,151 B) |

**Kept and updated:** `tools/carry_content.py` (now writes `assets/` + `data/` at
the package root, emits the SDK's `block` field, and no longer writes a
manifest), `tools/craft_check.py`, `tools/e2e.sh` (launcher-built `GAME=`,
optional `CONTROL_GAME=`, `SELFTEST=1`/`NEGATIVE=1` kept), `tools/e2e-all.sh`,
`notes.md`, `FINDINGS.md`, `VALIDATION.md`, `LICENSE`, `LICENSE-NOTICE.md`,
`AGENTS.md` (rewritten for the SDK ladder) and a new `README.md`.

### Manifest field map

| Old | New |
|---|---|
| two manifests (`horizon-mixin.toml` + `content/horizon-mod.toml`) | one `horizon-mod.toml` |
| `[mod] id` / content `id` | `id = "mysticalagradditions"` (also the resource namespace) |
| `[mod] version = "0.1.0"` | `version = "0.2.0"` (a resubmission is always a new version) |
| `[mod] priority = 100` | gone; per-hook ordering is `#[listener(priority = …)]`, and this port needs none |
| `[compatibility] horizon_revision = 1d63e0a5…` | `[native] horizon = 0b14f8ac…` |
| the bundle's mixins revision `5a64af93…` | `[native] mixins = e59da9094f0c…` |
| content `api = "0.2"`, `side`, `capabilities` | the same three fields, now for one package (`side = "both"`, `capabilities = ["registries"]`) |
| `[[module]]` × 2, `[[injection]]` × 5 | `src/`, one `impl Hooks`, one `BlockPart` |
| — | `[native] game = "26.3"`; `license`, `homepage`, `issues` are **not** manifest fields (the packer strips them) |

### The wire: every old injection and module, and where it went

| Old `.hnmod` | New place | Mapping |
|---|---|---|
| `[[module]] runtime` (`runtime.rs`) | `pub mod runtime` | unchanged file, byte for byte |
| `[[module]] state` (`support.rs`) | `mod support` | the glue is an ordinary module now; no `//!`/`#![…]` restriction |
| `[[injection]] embedded-content`, `content_root` HEAD, `embedded_content.rs` | **none** | the SDK `.hmod` carries `assets/` + `data/`; there is no write-out and no `--dev-mod` |
| `[[injection]] loot-drops` (`loot_drops` 75, HEAD, `drops: &mut Vec<ItemStack>`) | `Hooks::loot_drops` (`event.context.block`, `event.drops`) | the broken block is `(pos, state)` on the context; the six crops are matched by `state.block()` |
| `[[injection]] random-tick` (`random_tick` 33, HEAD, `handled: &mut bool`) | `BlockPart::random_tick` → `Flow::Cancel` | the SDK dispatches it per block (`parts(...).block_value(state)`); `Cancel` sets the old `handled` |
| `[[injection]] bonemeal-target` (`is_valid_bonemeal_target` 72, HEAD, `valid: &mut Option<bool>`) | `BlockPart::is_valid_bonemeal_target` → `Option<bool>` | same rule: `!is_ripe(age) && can_grow` |
| `[[injection]] bonemeal-success` (`is_bonemeal_success` 72, HEAD, `success: &mut bool`) | `BlockPart::is_bonemeal_success` sets `event.success = false` | always false, as the jar |

Glue API map (old `support.rs` → SDK):

| Old | New |
|---|---|
| `level.registry.state(state)?.name`, `Crop::by_block(&name)` | `state.block()` against the six `BlockKey`s resolved in `register` (`entry_for`) |
| `level.registry.state(state)?.properties.get("age")` | `LevelHost::state_string(state)` in the Part; `BlockState::property(&host.block_states(), "age")` in the loot hook |
| `level.world.loaded(x, z)` + `level.world.block(x, y, z)` | `LevelHost::block_state(pos)` + `state_block(state)`; an unloaded or out-of-height read answers air, which is no crop's crux |
| `ItemStack::new(crop.essence, n)` (infallible) | `ItemStack::new(item_key, n) -> Option<ItemStack>` (fallible, keyed by `ItemKey`) |
| `crop.essence` / `crop.seeds` (ids) | `Registrar::item_key(id)` resolved once per crop into the `OnceLock` table |

The rules (the six-crop table, `can_grow`, `is_ripe`, `harvest`) stay in
`src/runtime.rs` and are unit-tested there; `src/support.rs` decides nothing.

### Content map and the carried-file diff

`content/assets/` → `assets/` (118 files) and `content/data/` → `data/`
(54 files) by `cp -a`, then `diff -r` against the retired copy:
**118 assets and 48 of the 54 data files are byte-identical**; the only six
differences are the six seed item declarations
(`data/mysticalagradditions/horizon/item/*_seeds.json`), whose schema field
`"place_block"` became **`"block"`** in the SDK content API (the 0.1.0 spelling
is refused at build). `python3 tools/carry_content.py --check` → **170 files, 0
pending**, jar SHA-1 `be6e652d…000c`; the two remaining data files are the
licence copies (`data/mysticalagradditions/license/{license,notice}.txt`) the
0.1.0 package already carried, unchanged.

### Build and check (the ladder for an SDK package)

Every command ran in a `ports/tools/build-slot.sh` lease with `BUILD_LOCAL=1`
(the job `mysticalagradditions-sdk`), **directly in the port** with
`CARGO_INCREMENTAL=0` — the runner is a slot guard here, because it speaks the
retired `tools/horizon.py` ladder and does not drive these steps. No staging, no
`--target-dir`.

```sh
CARGO_INCREMENTAL=0 cargo test --offline              # 8 passed before the glue, 10 after
CARGO_INCREMENTAL=0 cargo clippy --all-targets -- -D warnings
cargo fmt --check                                     # not `--all`
rm -f Cargo.lock
CARGO_INCREMENTAL=0 cargo horizon-mod build             # -> target/horizon-mod/mysticalagradditions.hmod
cp target/horizon-mod/mysticalagradditions.hmod ./mysticalagradditions.hmod
cargo horizon-mod check mysticalagradditions.hmod
cargo horizon-mod fits mysticalagradditions.hmod --build nightly
```

`check` output:

```
mysticalagradditions 0.2.0 (native-mod, format native-1/0b14f8acfd97fa2c750e42795249dcc981178ca4/e59da9094f0c2fdda6c627fe9eff22dec6a906f0, for 26.3)
  88151 bytes, SHA-256 a72ce05bd12aa642e974460ff1cd9749bf8174957b994b3f9138c6680739d3cd, unsigned
  native source: unsandboxed; not executed by the registry check. Compile and test against the exact pinned Horizon and Mixins revisions before review.
```

`fits` output:

```
Mystical Agradditions:
0b14f8a  made for
```

The archive's 181 entries: `horizon-mod.toml`, `Cargo.toml`, `LICENSE`,
`LICENSE-NOTICE.md`, `README.md`, `src/{lib,runtime,support}.rs`,
`uses.json`, `assets/…` (118) and `data/…` (54). **No `Cargo.lock`**, and
`unzip -p mysticalagradditions.hmod src/runtime.rs | sha256sum` is
`00bb7243…c520`, the retired file byte for byte.

`uses.json` is the migration's best summary: **107 surface entries** — the four
hooks (`random_tick`, `is_valid_bonemeal_target`, `is_bonemeal_success`,
`loot_drops`) plus their 13 fields, three `BlockPart` methods (the three above
under their Part), `Hooks::register`/`Hooks::loot_drops`, the two registrar calls
(`block_key`, `item_key`) and `Registrar::block_part`, four level reads
(`block_state`, `state_block`, `state_string`, `block_states`), the
`BlockPos`/`BlockState`/`ItemStack` handles, both macros (`horizon_mod`,
`horizon_part`) and the `registries` capability.

### Traps this migration hit (new to this port)

1. **`random_tick` is a `BlockPart` method at the SDK, not a `Hooks` method.**
   The retired plan injected it globally; here `dispatch_random_tick` looks the
   part up by the block it is attached to (`parts(...).block_value(state)`), so
   the crux gate must be a Part on each of the six crops, and `Flow::Cancel` is
   what becomes the old `handled = true`.
2. **`LevelSide` has no `host()` accessor.** `is_valid_bonemeal_target` is handed
   a `LevelSide<'_>`; the `&dyn LevelHost` comes from matching
   `LevelSide::Server(level) | LevelSide::Client(level)`. `level.host()` does not
   compile.
3. **`event.pos` is `BlockPos { x, y, z }`, not `[i32; 3]`.** `runtime::can_grow`
   takes positions nowhere, but the Part passes `[x, y, z]`, so destructure
   `let BlockPos { x, y, z } = event.pos;` before calling in.
4. **A `LevelHost` is not a `Host`.** In a Part the metadata path is unavailable:
   neighbour names come from `LevelHost::block_state(pos)` +
   `state_block(state)`, and the `HostBlockStates`/`BlockMetadata` pair only
   works in the loot hook, where the host is a `ServerHost`.
5. **The loot hook cannot read `age` by position**: the block is already gone
   when it fires, so read `BlockState::property` from the event's state; in the
   Part the readable form is `state_string` (the same split the parent port hit).
6. **The content schema renamed an item's `place_block` to `block`.** Six seed
   declarations were refused otherwise; `tools/carry_content.py` now emits
   `block`, and that is the only carried-file difference from the 0.1.0 tree.
7. **One Part type can serve all six crops.** The game dispatches a part only for
   the block it was attached to, so the Part resolves its crop from the resolved
   `BlockKey` table (`entry_for`) instead of six near-identical structs; the
   `Crop` it then hands to the runtime carries the crux id the gate compares.
8. **`Registrar::block_part(r.block_key(id), part)` is a double `&mut`**: bind the
   key first (trap 15 of the recipe; the same applies to `item_key`).
9. **`runtime::CROPS.len()` as the table's array length** keeps the id table and
   the runtime table in lockstep: a seventh crop cannot be added to one without
   the other, and `std::array::from_fn` fills it in the runtime's order.
10. **`build-slot.sh` is a guard only for an SDK package.** It does not drive
    `cargo horizon-mod`; `BUILD_LOCAL=1` keeps the 21 MB `.horizon/sdk` out of a
    pointless remote sync, and the port's own `target/` (not a slot cache) takes
    the compile.
11. **The glue needs a test of its own or the red step is invisible.** The eight
    runtime tests stayed green while the glue was a `todo!()`; the crate's own
    test of the age parser (`src/support.rs`'s two tests) is what failed on
    `todo!()` and then passed, so the "glue red → green" step is real evidence
    rather than a claim.

### Gaps (what this migration cannot claim)

- **No 0.2.0 in-game run.** `horizon-launcher` is not installed here, so no
  `0b14f8a` client exists to build the package into; `tools/e2e.sh` was adapted
  to the launcher-built game (`GAME=`, optional `CONTROL_GAME=`, the
  `SELFTEST=1`/`NEGATIVE=1` legs kept) and has **not** been run. The 0.1.0
  `horizon-ctl` transcripts in the evidence folder remain the behaviour's proof
  for a `runtime.rs` that did not change, and no `ported` status may be claimed
  from them alone.
- Every slice-boundary gap listed above was **unchanged in 0.2.0**; 0.2.1
  (Slice 3) closes the Wither half of the drop-handler gap and leaves the rest:
  the four seed/crux recipe families whose materials live in unported mods,
  `insanium_essence`'s own recipe, the insanium ingot/gemstone/nugget/block
  chain, the essence-coal items, the apples, the paxels, the nether/end ores and
  their worldgen, the six molten fluids, the Tinkers' data, the **Ender-Dragon
  half** of the drop handlers (`blocked(living_drops-ender-dragon)`), the config,
  the creative tab, the client tint, the farmland `fallOn` and the 10% fertilized
  essence.
- **One new recorded difference:** the Part answers the bonemeal questions for
  *every* declared crop block at once (the old helper compared names itself), and
  a state that is not one of the six now leaves the answer at `None`/`Continue`
  instead of the old early return — same behaviour, one lookup instead of six
  name comparisons.

### Migration verification (evidence in `../_shared/evidence/mysticalagradditions/sdk-*.log`)

| Check | Command | Result |
|---|---|---|
| Runtime tests in the new crate, **before the glue** | `cargo test --offline` | **8 passed**, 0 failed (`sdk-test.log`'s first run; the crate held only `pub mod runtime;`) |
| The glue red | `cargo test --offline` with `age_in` = `todo!()` | **8 passed, 2 failed** — both glue tests panicked on `not yet implemented: parse the age of a tier-6 crop state` (`sdk-test-red-glue.log`) |
| Tests after the glue | `cargo test --offline` | **10 passed**, 0 failed (`sdk-test.log`) |
| Lints | `cargo clippy --all-targets --offline -- -D warnings` | exit 0, **0 warnings** (`sdk-clippy.log`) |
| Formatting | `cargo fmt --check` | clean (`sdk-fmt.log`) |
| Package | `rm -f Cargo.lock && cargo horizon-mod build` | `target/horizon-mod/mysticalagradditions.hmod`, exit 0 (`sdk-build.log`) |
| Registry check | `cargo horizon-mod check mysticalagradditions.hmod` | `mysticalagradditions 0.2.0 (native-mod, format native-1/0b14f8a…/e59da90…, for 26.3)`, **88,151 B**, sha256 `a72ce05b…d3cd`, **exit 0** (`sdk-check.log`) |
| Fits the pinned build | `cargo horizon-mod fits … --build nightly` | `0b14f8a  made for`, exit 0 (`sdk-fits.log`) |
| Same package twice | `cargo horizon-mod build` again | 88,151 B, `a72ce05b…d3cd` both times, `cmp` identical (`sdk-build-second.log`, `sdk-sha256.txt`) |
| `runtime.rs` untouched | `cmp` + `unzip -p … src/runtime.rs \| sha256sum` | `00bb7243…c520` = the retired file (`sdk-runtime-sha256.txt`) |
| Carried content | `python3 tools/carry_content.py --check` | **170 files, 0 pending**, jar sha1 `be6e652d…` (`sdk-carry-check.log`) |
| Carried files vs the retired tree | `diff -rq` (extracted 0.1.0 `.hmod`) | 166 identical, the six seed declarations carry `block` instead of `place_block` (`sdk-content-diff.log`) |
| Package entries | `unzip -l` | **181** entries: 5 root docs, `Cargo.toml`, 3 `src/`, `uses.json`, 118 `assets/`, 54 `data/`; no `Cargo.lock` (`sdk-entries.txt`) |
| What it uses | `unzip -p … uses.json` | **107** surface entries, 4 hooks (`sdk-uses.json`, `sdk-uses-summary.txt`) |
| Skills line | `python3 ports/tools/check-skills.py --notes ports/mysticalagradditions --strict` | see the report; the line is in this file |

Skills: superpowers/using-superpowers,brainstorming,writing-plans,test-driven-development,systematic-debugging,verification-before-completion; BeautifulRust/rust-best-practices,rust-port

### Changelog for the resubmission (supersedes #906)

> Supersedes **#906**, closed on 2026-11-18 because Horizon retired the `.hnmod`
> container (#17941). 0.2.0 is the flat SDK package: `api = "0.2"`, `[native]`
> pinned to nightly `0b14f8acfd97fa2c750e42795249dcc981178ca4` and mixins
> `e59da9094f0c2fdda6c627fe9eff22dec6a906f0`, for 26.3. The five old injections
> became four typed hooks — `random_tick`, `is_valid_bonemeal_target`,
> `is_bonemeal_success` (all three `BlockPart` methods on the six crops) and
> `loot_drops` — plus two `Registrar` calls that resolve the content's ids; the
> content half now travels in the same package instead of an embedded `.hmod`,
> so one install carries the blocks, items, recipes, loot and behaviour. The
> six seed item declarations use the SDK's `block` field instead of the retired
> `place_block`. `src/runtime.rs` and its 8 tests are unchanged, byte for byte.
> Package: 181 entries, **88,151 B**, sha256
> `a72ce05bd12aa642e974460ff1cd9749bf8174957b994b3f9138c6680739d3cd`; a second
> build is byte-identical; `check` and `fits` exit 0. No 0.2.0 in-game run: the
> launcher is not installed here.

## Verification

> The 0.1.0 rows below describe the **retired `.hnmod` ladder** and are kept as
> history; the SDK package's own ladder, evidence and gaps are in
> [`## Migration to the SDK format`](#migration-to-the-sdk-format-020-2026-11-18)
> above. Nothing here is a 0.2.0 in-game claim.

Pin `1d63e0a5a37a7a708eb0b32b49bf0dfeb28ed8a9` / horizon-mixins
`5a64af938ec86b00d53d16a408aabc0038fb3e57`; every build/test/e2e step through
`ports/tools/build-slot.sh` with `CARGO_INCREMENTAL=0`. Evidence:
[`../_shared/evidence/mysticalagradditions/`](../_shared/evidence/mysticalagradditions/).

| Step | Command | Result |
|---|---|---|
| runtime tests (standalone) | `cargo test --locked --offline` | **8 passed**, 0 failed (`standalone-fmt-clippy-test.log`); the two `harvest` tests were red first (`todo!()`, 6 passed / 2 failed), then green |
| fmt + clippy | `cargo fmt --all --check`; `cargo clippy --workspace --all-targets --locked --offline -- -D warnings` | both exit 0, **0 warnings** (`standalone-fmt-clippy-test.log`) |
| stage | `python3 tools/horizon.py stage --horizon …/pins/horizon-1d63e0a` | `status ok`, `stage_changed: true`, **2 modules, 5 injections** (`embed-stage.log`) |
| check | `python3 tools/horizon.py check --horizon …` | `cargo_exit: 0`, **0 warnings** (`horizon-check.log`, `horizon-check-cargo.log`) |
| embedded tests | `python3 tools/horizon.py test --horizon …` | **8 passed; 0 failed; 1240 filtered out** (`horizon-test.log`, `horizon-test-cargo.log`) |
| fast build | `python3 tools/horizon.py build --horizon …` | `cargo_exit: 0`, **0 warnings**, 36 m in the cold slot (`embed-build.log`, `horizon-build-cargo.log`) |
| content carry | `python3 tools/carry_content.py --check` | **171 files, 0 pending**, addon SHA-1 `be6e652d…` |
| content `.hmod` | `cargo-horizon-mod build` in `content/` | exit 0, **71,827 B**, SHA-256 `0a5cdcd7…feb4`, **171 files**, "no code"; reproducible on a second run (`package-0.1.0.log`) |
| native `.hnmod` | `tools/package.sh` → `tools/package.py` | **45,205 B**, SHA-256 `f08aad36…88b0`, **10 entries** incl. `mixins/…/data/mysticalagradditions-content.hmod` (71,827 B, byte-identical); `horizon-native.json` reports **`mysticalagradditions 0.1.0`**; reproducible on a second run; `check --kind native-mod` exit 0 |
| e2e (default) | `build-slot.sh run --step e2e … -- bash tools/e2e-all.sh` | **`PASS` + `EXIT:0`**: six crops bind, crux growth 3/2 vs no-crux 0/wrong-crux 3, **awakened line speed-0 hold → age 7 → 1 essence + 1 seed**, bone meal, ripe 1/1, young 0/1, farmland 5 essence in 20, recipes, unknown ids (`e2e-default.log`) |
| e2e (default selftest) | `SELFTEST=1 …` | **exit 1** at the no-crux growth assertion (`e2e-selftest.log`) |
| e2e (negative) | `NEGATIVE=1 …` | **exit 1** at the young-crop essence assertion (`e2e-negative.log`) |
| e2e (embedded) | `build-slot.sh run --step e2e … -- bash tools/e2e-embedded.sh` | **`PASS` + `EXIT:0`** with no `--dev-mod`; the control (unusable cache file) knows no seed/crop id; the cache file is byte-identical to `content/mysticalagradditions.hmod` (71,827 B, SHA-256 `0a5cdcd7…feb4`); the awakened line holds at speed 0, grows 0→7, drops 1 essence + 1 seed (`e2e-embedded.log`) |
| e2e (embedded selftest) | leg 2 of the same driver | **exit 1** (`e2e-embedded-selftest.log`) |
| checker | `python3 ports/tools/check-e2e-logs.py mysticalagradditions --strict` | **5/5 ok**, missing-exit 0, bad-exit 0 |
| gates | `check-skills.py --notes`, `upstream_ready.py` | skills PASS; `upstream_ready` still blocks on the campaign ledger status and the registry parent list (orchestrator/upstream, outside this port — see the report) |

> **2026-11-12 (review repairs).** The two artifact rows above and the embedded
> leg's byte count predate the licence stamping: the delivered files are the
> content `.hmod` **73,306 B** `dc2dbd84…1a86` (173 files, includes
> `data/mysticalagradditions/license/`) and the bundle **47,876 B**
> `134efc0e…ce7b` (12 entries). See *Verification after the repairs* below.

Skills: superpowers/using-superpowers,writing-plans,test-driven-development,systematic-debugging,verification-before-completion; BeautifulRust/rust-best-practices,rust-port

## Review repairs (PR #676, 2026-11-11) — review items and what changed


Each item below is quoted from `ports/_shared/horizon-mods/reviews/pr-*-mysticalagradditions.md` (the review is the specification), with what this repair did about it.

- **Reviewer:** licence notice not in the bundle
  **Repair:** `tools/package.py` now ships the repository `LICENSE` and `LICENSE-NOTICE.md` as `mixins/<id>/LICENSE` / `mixins/<id>/LICENSE-NOTICE.md`, and the carried `.hmod` carries `data/mysticalagradditions/license/{license,notice}.txt` (`tools/stamp_license.py`). The LICENSE now carries `Copyright 2018 BlakeBr0`.
- **Reviewer:** description ends mid-sentence, 'nothing recorded yet', relative link
  **Repair:** Rewritten from this file: complete sentences, the fertilized-essence exclusion and the four missing integration recipe families are listed, and the parent requirement (Mystical Agriculture) is stated. The link is absolute.
- **Reviewer:** registry artifact delivery
  **Repair:** **Staging (orchestrator, not ours)**: the artifact is not in registry release/staging as `<sha256>.<ext>`; the orchestrator answers it with `horizon-mods#686` (no write access to the registry's releases). Every repackaged artifact below has a fresh sha256 for that re-push, and the author release must be re-uploaded from the port repository.

### Verification after the repairs (2026-11-12)

Every step in a `ports/tools/build-slot.sh` lease with `CARGO_INCREMENTAL=0`.
`tools/package.sh` now runs `tools/stamp_license.py` before the build, so a
rebuild cannot produce a `.hmod` without the MIT notices (before this repair the
stamping was a manual step; the tree's `content/` did not carry the files).

| Check | Result |
|---|---|
| `tools/package.sh` twice (`--step package`) | both runs: content `mysticalagradditions.hmod` **73,306 B** `dc2dbd84…1a86`, 173 files, and `mysticalagradditions.hnmod` **47,876 B** `134efc0e…ce7b`, 12 entries; `cmp` identical on both artifacts |
| embedded copy | `cmp content/mysticalagradditions.hmod mixins/mysticalagradditions/data/mysticalagradditions-content.hmod` → identical |
| notices in **both** archives | outer `.hnmod`: `mixins/mysticalagradditions/LICENSE` (1,111 B, `Copyright 2018 BlakeBr0`) + `LICENSE-NOTICE.md` (882 B); embedded `.hmod`: `data/mysticalagradditions/license/{license,notice}.txt` |
| `registry.toml` | `file = "mysticalagradditions.hnmod"` exists beside it; `sha256 = 134efc0e…ce7b` = `sha256sum` of that file |
| runtime | `cargo test --locked --offline` **8 passed**, 0 failed; clippy `-D warnings` clean; `cargo fmt --all --check` clean |
| ladder | `stage` → `check` → `test` → `build`, `cargo_exit 0` each, **0 warnings**; embedded tests `game::mysticalagradditions::tests` **8 passed**, 1240 filtered out |
| e2e, default | `e2e-repair.log`: **`PASS` + `EXIT:0`** — 6 crops + 6 cruxes + farmland bind, seed planting, crux/no-crux/wrong-crux growth, the awakened-draconium line 0→7 and 1 essence + 1 seed, bone meal, ripe/young drops, farmland, recipes, unknown ids |
| e2e, fail-capable | `e2e-repair-selftest.log`: **`FAIL` + `EXIT:1`** — `SELFTEST: the no-crux crop grew (the assertion above must hold)` |
| e2e, embedded bundle (fresh) | `e2e-embedded.log`: **`PASS` + `EXIT:0`** with no `--dev-mod`; the cache file is **73,306 B** and identical to `content/mysticalagradditions.hmod`; the unusable-cache control knows no id; `e2e-embedded-selftest.log`: **`FAIL` + `EXIT:1`** |
| log audit | `check-e2e-logs.py mysticalagradditions --strict` exit 0, **7/7** logs ok |
| skills gate | `check-skills.py --notes ports/mysticalagradditions` → `SKILLS GATE: PASS` |
| upstream gate | `upstream_ready.py mysticalagradditions` → **exit 1**: add-on whose required parent `mysticalagriculture` is not in the registry. Outside this port — it needs the parent's upstream merge; do not submit this entry before that. |

The reviewer's three items are therefore: notices in both archives (and stamped
by the packager), the description complete and disclosing the real scope
(fertilized essence excluded, the four integration seed/crux recipe families
missing, absolute upstream link), and the registry file/hash being the artifact
actually delivered by this tree. The staging failure itself is the orchestrator's
`horizon-mods#686` — it needs the artifact uploaded to the registry's release
storage, which this port cannot do.

Skills: superpowers/using-superpowers,systematic-debugging,verification-before-completion; BeautifulRust/rust-best-practices
