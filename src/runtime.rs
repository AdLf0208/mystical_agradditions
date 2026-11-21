// The pure tier-6 crop rules, read from Mystical Agradditions 8.0.15
// (`lib/ModCrops.java`, `lib/ModCropTiers.java`,
// `block/InfusedFarmlandBlock.java`) and the parent Mystical Agriculture API
// (`MysticalCropBlock.canGrow`, `MysticalCropBlock.getDrops`,
// `CropTier.SIX`). This file is both the standalone Cargo library and the
// injected `game::mysticalagradditions` module; the game glue lives in
// `support.rs`.
//
// The harvest counts are here (`harvest`); the carried 26.3 loot tables are the
// content-only fallback for paths the native drop hook does not hear.

/// Vanilla `CropBlock.MAX_AGE` for the wheat template (8 ages, 0 through 7).
pub const MAX_AGE: u8 = 7;

/// `CropTier.SIX.setFarmland(ModBlocks.INSANIUM_FARMLAND)`.
pub const FARMLAND: &str = "mysticalagradditions:insanium_farmland";

/// The parent's `requiresEffectiveFarmland` common-config default
/// (`config/ModConfigs.java`): tier-6 crops only need the crux, not the
/// tier's farmland, unless the pack turns this on.
pub const REQUIRES_EFFECTIVE_FARMLAND: bool = false;

/// One tier-6 crop from `ModCrops.java`: its block, seed, essence and the
/// crux `ModCrops.onPostRegisterCrops` sets on it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Crop {
    /// The crop name in `ModCrops` (`nether_star`, ...).
    pub name: &'static str,
    /// The crop block (our namespace, see the deviation in `notes.md`).
    pub block: &'static str,
    /// The seeds item.
    pub seeds: &'static str,
    /// The essence the crop drops and the seed recipe uses.
    pub essence: &'static str,
    /// The crux block that must stand two blocks below the crop.
    pub crux: &'static str,
}

/// `ModCrops`' six tier-6 crops, in registration order.
pub const CROPS: [Crop; 6] = [
    Crop {
        name: "nether_star",
        block: "mysticalagradditions:nether_star_crop",
        seeds: "mysticalagradditions:nether_star_seeds",
        essence: "mysticalagradditions:nether_star_essence",
        crux: "mysticalagradditions:nether_star_crux",
    },
    Crop {
        name: "dragon_egg",
        block: "mysticalagradditions:dragon_egg_crop",
        seeds: "mysticalagradditions:dragon_egg_seeds",
        essence: "mysticalagradditions:dragon_egg_essence",
        crux: "mysticalagradditions:dragon_egg_crux",
    },
    Crop {
        name: "gaia_spirit",
        block: "mysticalagradditions:gaia_spirit_crop",
        seeds: "mysticalagradditions:gaia_spirit_seeds",
        essence: "mysticalagradditions:gaia_spirit_essence",
        crux: "mysticalagradditions:gaia_spirit_crux",
    },
    Crop {
        name: "awakened_draconium",
        block: "mysticalagradditions:awakened_draconium_crop",
        seeds: "mysticalagradditions:awakened_draconium_seeds",
        essence: "mysticalagradditions:awakened_draconium_essence",
        crux: "mysticalagradditions:awakened_draconium_crux",
    },
    Crop {
        name: "neutronium",
        block: "mysticalagradditions:neutronium_crop",
        seeds: "mysticalagradditions:neutronium_seeds",
        essence: "mysticalagradditions:neutronium_essence",
        crux: "mysticalagradditions:neutronium_crux",
    },
    Crop {
        name: "nitro_crystal",
        block: "mysticalagradditions:nitro_crystal_crop",
        seeds: "mysticalagradditions:nitro_crystal_seeds",
        essence: "mysticalagradditions:nitro_crystal_essence",
        crux: "mysticalagradditions:nitro_crystal_crux",
    },
];

impl Crop {
    /// The crop whose block is `block`, or `None` for any other block.
    #[must_use]
    pub fn by_block(block: &str) -> Option<Self> {
        CROPS.iter().copied().find(|crop| crop.block == block)
    }
}

/// A crop's `age` is ripe at the template's maximum; `CropBlock.isMaxAge`.
#[must_use]
pub fn is_ripe(age: u8) -> bool {
    age >= MAX_AGE
}

/// `MysticalCropBlock.canGrow` for a tier-6 crop: the block two below the
/// crop must be the crop's crux, and when `requires_effective_farmland` is on
/// the block directly below must be `insanium_farmland`. The required-biome
/// branch is empty for these six, so it is not modelled.
#[must_use]
pub fn can_grow(
    crop: Crop,
    below_two: &str,
    below: &str,
    requires_effective_farmland: bool,
) -> bool {
    if below_two != crop.crux {
        return false;
    }
    !requires_effective_farmland || below == FARMLAND
}

/// `CropTier.SIX.setSecondarySeedDrop(false)` (`lib/ModCropTiers.java`) makes
/// the tier's `Crop.getSecondaryChance` 0, so a ripe crop's essence and seed
/// counts never roll a second stack.
///
/// The stacks a broken crop leaves (`MysticalCropBlock.getDrops`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Harvest {
    /// The crop's essence, 0 below the ripe age.
    pub essence: u32,
    /// The crop's seeds, always one for tier 6.
    pub seeds: u32,
}

/// `MysticalCropBlock.getDrops` for a tier-6 crop: below the ripe age one seed
/// and no essence; at the ripe age one essence and one seed. The jar's
/// `crop = 2` / `seed = 2` branches need a non-zero
/// `Crop.getSecondaryChance`, which tier 6's `secondarySeedDrop = false`
/// rules out. Upstream's 10 % fertilized essence is out of this slice (the
/// parent's item is not carried).
#[must_use]
pub fn harvest(age: u8) -> Harvest {
    Harvest {
        essence: u32::from(is_ripe(age)),
        seeds: 1,
    }
}

/// `config/ModConfigs.java`'s `witheringSoulChance` (default 0.35): the chance a
/// killed Wither leaves one `withering_soul` (`MobDropsHandler.onLivingDrops`).
pub const WITHERING_SOUL_CHANCE: f64 = 0.35;

/// `config/ModConfigs.java`'s `dragonScalesAmount` (default 8): the stack an Ender
/// Dragon leaves (`MobDropsHandler.onLivingDrops`).
pub const DRAGON_SCALES_AMOUNT: u32 = 8;

/// `ModItems.WITHERING_SOUL`, the Wither's drop.
pub const WITHERING_SOUL: &str = "mysticalagradditions:withering_soul";

/// `ModItems.DRAGON_SCALE`, the Ender Dragon's drop.
pub const DRAGON_SCALE: &str = "mysticalagradditions:dragon_scale";

/// The Wither's entity id (`WitherBoss`), the only mob that rolls the soul.
pub const WITHER: &str = "minecraft:wither";

/// The Ender Dragon's entity id (`EnderDragon`), the only mob that leaves scales.
pub const ENDER_DRAGON: &str = "minecraft:ender_dragon";

/// The `do_mob_loot` gate `MobDropsHandler.onLivingDrops` returns on
/// (`level.getGameRules().getBoolean(GameRules.RULE_DOMOBLOOT)`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MobLoot {
    /// `do_mob_loot` is on: the handler runs.
    Enabled,
    /// `do_mob_loot` is off: the handler adds nothing.
    Disabled,
}

/// The extra stacks `MobDropsHandler.onLivingDrops` appends to a dying mob's own
/// drops.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct MobDrops {
    /// `withering_soul` stacks: one on a successful roll, none otherwise.
    pub withering_souls: u32,
    /// `dragon_scale` stacks: [`DRAGON_SCALES_AMOUNT`] for the dragon, none otherwise.
    pub dragon_scales: u32,
}

/// `MobDropsHandler.onLivingDrops` for a dying mob of `kind`, given the 0..1 `roll`
/// the handler draws for the Wither (`Math.random() < witheringSoulChance`) and the
/// `do_mob_loot` answer `loot`.
///
/// A Wither leaves one `withering_soul` when `roll` is under
/// [`WITHERING_SOUL_CHANCE`]; an Ender Dragon leaves [`DRAGON_SCALES_AMOUNT`]
/// `dragon_scale` with no roll at all; every other kind, and a disabled
/// `do_mob_loot`, adds nothing.
#[must_use]
pub fn mob_drops(kind: &str, roll: f64, loot: MobLoot) -> MobDrops {
    if loot == MobLoot::Disabled {
        return MobDrops::default();
    }
    MobDrops {
        withering_souls: u32::from(kind == WITHER && roll < WITHERING_SOUL_CHANCE),
        dragon_scales: if kind == ENDER_DRAGON {
            DRAGON_SCALES_AMOUNT
        } else {
            0
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_young_tier_six_crop_drops_one_seed_and_no_essence() {
        for age in 0..MAX_AGE {
            assert_eq!(
                harvest(age),
                Harvest {
                    essence: 0,
                    seeds: 1
                },
                "age {age}"
            );
        }
    }

    #[test]
    fn a_ripe_tier_six_crop_drops_one_essence_and_one_seed() {
        assert_eq!(
            harvest(MAX_AGE),
            Harvest {
                essence: 1,
                seeds: 1
            }
        );
    }

    #[test]
    fn the_six_crops_are_the_jars_tier_six_set() {
        let names: Vec<&str> = CROPS.iter().map(|crop| crop.name).collect();
        assert_eq!(
            names,
            [
                "nether_star",
                "dragon_egg",
                "gaia_spirit",
                "awakened_draconium",
                "neutronium",
                "nitro_crystal"
            ]
        );
        for crop in CROPS {
            assert_eq!(
                crop.block,
                format!("mysticalagradditions:{}_crop", crop.name)
            );
            assert_eq!(
                crop.seeds,
                format!("mysticalagradditions:{}_seeds", crop.name)
            );
            assert_eq!(
                crop.essence,
                format!("mysticalagradditions:{}_essence", crop.name)
            );
            assert_eq!(
                crop.crux,
                format!("mysticalagradditions:{}_crux", crop.name)
            );
        }
    }

    #[test]
    fn a_crop_block_names_its_crop_and_other_blocks_do_not() {
        for crop in CROPS {
            assert_eq!(Crop::by_block(crop.block), Some(crop));
        }
        assert_eq!(Crop::by_block("mysticalagradditions:inferium_crop"), None);
        assert_eq!(Crop::by_block("minecraft:wheat"), None);
    }

    #[test]
    fn only_age_seven_is_ripe() {
        for age in 0..MAX_AGE {
            assert!(!is_ripe(age), "age {age}");
        }
        assert!(is_ripe(MAX_AGE));
    }

    #[test]
    fn growth_needs_the_matching_crux_two_blocks_below() {
        let nether_star = Crop::by_block("mysticalagradditions:nether_star_crop").unwrap();
        let dragon_egg = Crop::by_block("mysticalagradditions:dragon_egg_crop").unwrap();
        assert!(can_grow(
            nether_star,
            nether_star.crux,
            "minecraft:farmland",
            REQUIRES_EFFECTIVE_FARMLAND
        ));
        assert!(!can_grow(
            nether_star,
            "minecraft:dirt",
            "minecraft:farmland",
            REQUIRES_EFFECTIVE_FARMLAND
        ));
        // A crux of another tier-6 crop is not this crop's crux.
        assert!(!can_grow(
            nether_star,
            dragon_egg.crux,
            "minecraft:farmland",
            REQUIRES_EFFECTIVE_FARMLAND
        ));
    }

    #[test]
    fn growth_does_not_need_insanium_farmland_by_default() {
        let crop = Crop::by_block("mysticalagradditions:dragon_egg_crop").unwrap();
        assert!(can_grow(
            crop,
            crop.crux,
            "minecraft:farmland",
            REQUIRES_EFFECTIVE_FARMLAND
        ));
        assert!(can_grow(
            crop,
            crop.crux,
            FARMLAND,
            REQUIRES_EFFECTIVE_FARMLAND
        ));
    }

    #[test]
    fn growth_needs_insanium_farmland_when_the_parent_config_asks() {
        let crop = Crop::by_block("mysticalagradditions:gaia_spirit_crop").unwrap();
        assert!(!can_grow(crop, crop.crux, "minecraft:farmland", true));
        assert!(can_grow(crop, crop.crux, FARMLAND, true));
        // The farmland gate never overrides a missing crux.
        assert!(!can_grow(crop, "minecraft:stone", FARMLAND, true));
    }

    #[test]
    fn a_wither_leaves_one_soul_under_the_configured_chance() {
        for roll in [0.0, 0.1, 0.3499] {
            assert_eq!(
                mob_drops(WITHER, roll, MobLoot::Enabled),
                MobDrops {
                    withering_souls: 1,
                    dragon_scales: 0
                },
                "roll {roll}"
            );
        }
    }

    #[test]
    fn a_wither_leaves_nothing_at_or_above_the_configured_chance() {
        // `Math.random() < chance` is strict, so a draw exactly at 0.35 is a miss.
        for roll in [WITHERING_SOUL_CHANCE, 0.5, 0.999] {
            assert_eq!(
                mob_drops(WITHER, roll, MobLoot::Enabled),
                MobDrops::default(),
                "roll {roll}"
            );
        }
    }

    #[test]
    fn an_ender_dragon_leaves_eight_scales_whatever_the_roll() {
        for roll in [0.0, WITHERING_SOUL_CHANCE, 0.999] {
            assert_eq!(
                mob_drops(ENDER_DRAGON, roll, MobLoot::Enabled),
                MobDrops {
                    withering_souls: 0,
                    dragon_scales: DRAGON_SCALES_AMOUNT
                },
                "roll {roll}"
            );
        }
        assert_eq!(
            DRAGON_SCALES_AMOUNT, 8,
            "the jar's dragonScalesAmount default"
        );
    }

    #[test]
    fn another_mob_leaves_none_of_our_drops() {
        for kind in [
            "minecraft:zombie",
            "minecraft:wither_skeleton",
            "minecraft:player",
            "minecraft:armor_stand",
        ] {
            assert_eq!(
                mob_drops(kind, 0.0, MobLoot::Enabled),
                MobDrops::default(),
                "{kind} with a successful roll"
            );
        }
    }

    #[test]
    fn do_mob_loot_off_adds_nothing_to_any_mob() {
        for kind in [WITHER, ENDER_DRAGON] {
            assert_eq!(
                mob_drops(kind, 0.0, MobLoot::Disabled),
                MobDrops::default(),
                "{kind} with the gamerule off"
            );
        }
    }

    #[test]
    fn the_drops_name_the_carried_items_and_the_jars_chance() {
        assert_eq!(WITHERING_SOUL, "mysticalagradditions:withering_soul");
        assert_eq!(DRAGON_SCALE, "mysticalagradditions:dragon_scale");
        assert_eq!(WITHER, "minecraft:wither");
        assert_eq!(ENDER_DRAGON, "minecraft:ender_dragon");
        assert_eq!(WITHERING_SOUL_CHANCE, 0.35, "witheringSoulChance default");
    }
}
