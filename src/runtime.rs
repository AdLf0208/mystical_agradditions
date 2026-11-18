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
}
