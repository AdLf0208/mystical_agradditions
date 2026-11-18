# Mystical Agradditions — upstream findings

Analysis only: the Rust is a clean-room rewrite. Sources read:
`BlakeBr0/MysticalAgradditions` at commit
`fe4e81dea20458aa1959f5cfa8ef8354d2955aaa` (`Release 8.0.15`, the ATM10
jar's build), and the parent `BlakeBr0/MysticalAgriculture` at
`f38a092852538905de72a999f462936b71181554` (`Release 8.0.29`, the parent port's
pin). The jar itself is
`MysticalAgradditions-1.21.1-8.0.15.jar`, SHA-1
`be6e652de107065342aa3f98945cc5b0b3fa000c`, SHA-256
`8876b360dedf006cd3bff26719fccc4b148d626fb8be1e7f5e427107826fb01e`
(`neoforge.mods.toml`: `license="MIT"`, modId `mysticalagradditions`, version
`8.0.15`, requires `cucumber` and `mysticalagriculture`).

## The jar's inventory (the artefact, not the name)

- **6 tier-6 crops**, registered into the parent's crop registry from
  `lib/ModCrops.java`: `nether_star`, `dragon_egg`, `gaia_spirit`,
  `awakened_draconium`, `neutronium`, `nitro_crystal`. Their blockstates and
  item models ship under `assets/mysticalagriculture/` (the parent's
  namespace); textures ship under `assets/mysticalagradditions/`.
- **6 crux blocks** in `init/ModBlocks.java` (`<crop>_crux`), plus the
  `insanium_farmland` (`block/InfusedFarmlandBlock.java`) and the tier-6
  `insanium_essence`.
- Also present, **not this slice**: insanium block/ingot/gemstone block and
  items, six essence-coal items + blocks, six essence apples, six paxels,
  nether/end inferium/prosperity ores + configured/placed features + biome
  modifiers, six molten fluids + buckets, Tinkers' material/casting/melting
  files, the Wither/Ender-Dragon drop handlers, the Patchouli book, the config.
- The seed crafting/infusion/reprocessor recipes and the crux recipes use
  parent recipe types/ingredients (`mysticalagriculture:crop_component`,
  `neoforge:conditions`, `mysticalagriculture:infusion`) that 26.3's content
  loader cannot parse; the seed material for four families is another mod's
  item (botania/avaritia/draconicevolution/powah).

## Behaviours extracted (and the rewrite)

| Upstream | Behaviour | This slice |
|---|---|---|
| `MysticalCropBlock.canGrow` | `crop.cruxBlock` non-null → `level.getBlockState(pos.below(2)).getBlock()` must be that crux | same, read from the level in `random_tick`/bone-meal helpers |
| `canGrow` | `requiresEffectiveFarmland` (parent default **false**) and non-inferium → block below must be the tier's farmland (`insanium_farmland`) | same gate, config default false; the runtime takes the flag |
| `canGrow` | required biomes, empty for these six | no-op |
| `randomTick` | `if (!canGrow) return; super.randomTick(...)` | the wheat template's own random tick runs only when the hook leaves `handled = false` |
| `isValidBonemealTarget` | `canGrow && super` (age < 7) | same, via `is_valid_bonemeal_target` |
| `isBonemealSuccess` | always `false` | same, via `is_bonemeal_success` |
| `getDrops` | age 7 → 1 essence, `Math.random() < chance` may make 2; secondary seed chance; 10% fertilized essence. Tier SIX's `secondarySeedDrop=false` → chance 0 | `runtime::harvest` answers age 7 → 1 essence + 1 seed, below → 1 seed; one `loot_drops` hook replaces the rolled table (the 26.3 table is the fallback). The 10% fertilized essence is a gap (the parent slice-1 port does not carry `fertilized_essence`) |
| `InfusedFarmlandBlock.getDrops` | silk touch → self; else dirt + `nextInt(100) < 25` → one tier essence | the same as a 26.3 loot table (`tool/can_silk_touch`, dirt, `random_chance 0.25`) |
| `InfusedFarmlandBlock.randomTick` | the vanilla farmland moisture rules | the `minecraft:farmland` template |
| `InfusedFarmlandBlock.fallOn` | fall damage, never turns to dirt | **not expressible** at the pin (no fall-on hook); the farmland template turns to dirt as vanilla — recorded gap |
| `InfusedFarmlandBlock.isFertile` | `moisture > 0` | the farmland template |
| `InfusedFarmlandBlock.getColor` | tier colour tint | no client tint registration — gap |
| `CropTier.SIX` | farmland `insanium_farmland`, essence `insanium_essence`, `secondarySeedDrop=false` | carried as data + runtime constants |

## The awakened-draconium line (slice 2's proof)

- `ModCrops.AWAKENED_DRACONIUM = new Crop(resource("awakened_draconium"),
  ModCropTiers.SIX, CropType.RESOURCE, tag("c:ingots/draconium_awakened"))`;
  `onPostRegisterCrops` sets its crux to
  `ModBlocks.AWAKENED_DRACONIUM_CRUX` (`lib/ModCrops.java`,
  `lib/ModCropTiers.java`). It is registered only when `draconicevolution` is
  loaded (upstream's `withRequiredMods`), so its seed material is not part of
  this campaign and its seed/crux recipes are not carried.
- `ModCropTiers.SIX` is `new CropTier(resource("6"), 6, …)` and its
  `onPostRegisterCrops` calls `setFarmland(INSANIUM_FARMLAND)`,
  `setEssence(INSANIUM_ESSENCE)` and **`setSecondarySeedDrop(false)`**.
  `Crop.getSecondaryChance` therefore returns 0 for every block below, so the
  jar's `crop = 2` and `seed = 2` branches are unreachable.
- `MysticalCropBlock.canGrow`: with a crux set, `level.getBlockState(pos.below(2))
  .getBlock()` must be that crux; `requiresEffectiveFarmland` is the parent's
  default `false`, so plain farmland is enough. `randomTick` returns before
  `super.randomTick` when `canGrow` is false.
- `MysticalCropBlock.getDrops`: below the max age one seed and no essence; at
  age 7 one essence and one seed (the tier-6 secondary chance is 0), plus the
  parent's 10 % `fertilized_essence` roll, which this slice omits.

## Deviations recorded up front

1. **Namespace.** Crops/seeds/essences are `mysticalagradditions:*` here, not
   the parent's `mysticalagriculture:*`: the pin has no parent registration
   surface and the parent port owns that namespace.
2. **Shared models.** The crop stage models (`mystical_resource_crop_0..7`)
   and the infused-farmland models are copied from the parent's MIT jar into
   our namespace, so the `.hmod` loads without the parent's content mod.
3. **Seed recipes.** The custom `seed/crafting` recipe is rewritten for the two
   families whose material exists here (`nether_star` with
   `minecraft:nether_star`, `dragon_egg` with the carried `dragon_scale`) as
   the jar's `MEM/ESE/MEM` shape with `minecraft:wheat_seeds` in the centre;
   the other four need unported mods and are gaps. The parent port made the
   same substitution for inferium.
4. **Crux recipes.** `nether_star_crux` and `dragon_egg_crux` are carried with
   `#c:storage_blocks/diamond` supplied as a tag; the other four need unported
   mods and are gaps.
5. **Loot tables** are authored in the 26.3 singular typed shape
   (`"condition": {"type": …}`, `"match_block"`), unlike the jar's 1.21.1 ones.
   Slice 2 moved the crop drops to `native_loot_drops` (the jar's code path);
   the table is the fallback for breaks the hook does not hear, so both paths
   carry the same tier-6 counts.
6. **Files read:** `lib/ModCrops.java`, `lib/ModCropTiers.java`,
   `block/InfusedFarmlandBlock.java`, `init/ModBlocks.java`,
   `init/ModItems.java`, `config/ModConfigs.java`, the loot/recipe/lang/assets
   files listed in `tools/carry_content.py`; parent
   `block/MysticalCropBlock.java`, `api/crop/Crop.java`,
   `api/crop/CropTier.java`, `config/ModConfigs.java`,
   `crafting/ingredient/CropComponentIngredient.java`.
