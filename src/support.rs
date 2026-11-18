//! The game glue: the tier-6 crops' Part and the loot hook.
//!
//! Every decision here is [`crate::runtime`]'s; this module only reads the state and the
//! blocks around it through the level, and turns the result into a `Flow`, an `Option<bool>`
//! or a list of stacks. The Part is attached to the six crop blocks alone, so the game asks it
//! only about this mod's crops — the retired bundle's global helpers had to compare the
//! state's name themselves.

use std::sync::OnceLock;

use mod_api::{
    self, BlockKey, BlockPart, BlockPos, BlockState, Flow, Host, HostBlockStates,
    IsBonemealSuccessEvent, IsValidBonemealTargetEvent, ItemKey, ItemStack, LevelHost,
    LevelRandomHost, LevelSide, LevelWriteHost, LootDropsEvent, RandomTickEvent, Registrar,
    ServerHost,
};

use crate::runtime::{self, Crop};

/// The state property a crop's age is read from (vanilla `CropBlock.AGE`).
const AGE: &str = "age";

/// One crop of the table with the keys the game knows it by.
#[derive(Clone, Copy)]
struct Entry {
    crop: Crop,
    block: BlockKey,
    essence: ItemKey,
    seeds: ItemKey,
}

/// The six crops, resolved once at registration and indexed like `runtime::CROPS`.
static ENTRIES: OnceLock<[Entry; runtime::CROPS.len()]> = OnceLock::new();

/// Resolve the content's ids and attach the growth Part to every crop block.
///
/// All six blocks and eighteen items are declared by this same package, and a requested key
/// is checked after all declarations, so a missing one refuses the mod at load instead of
/// failing silently at the first random tick.
pub(super) fn register(r: &mut dyn Registrar) {
    let entries: [Entry; runtime::CROPS.len()] = std::array::from_fn(|index| {
        let crop = runtime::CROPS[index];
        let block = r.block_key(crop.block);
        let essence = r.item_key(crop.essence);
        let seeds = r.item_key(crop.seeds);
        Entry {
            crop,
            block,
            essence,
            seeds,
        }
    });
    for entry in entries {
        r.block_part(entry.block, CropPart);
    }
    let _ = ENTRIES.set(entries);
}

/// The table entry whose block is `state`, or `None` for a block that is not a tier-6 crop.
fn entry_for(state: BlockState) -> Option<Entry> {
    let block = state.block();
    ENTRIES
        .get()?
        .iter()
        .copied()
        .find(|entry| entry.block == block)
}

/// `MysticalCropBlock.canGrow` and the two bone-meal answers, attached to every crop.
struct CropPart;

#[mod_api::horizon_part]
impl BlockPart for CropPart {
    /// `MinecraftCropBlock.randomTick`'s gate: the wheat template's own tick only runs while
    /// the crop's crux stands two blocks below it. `Flow::Cancel` sets the hook's `handled`,
    /// so a gated crop holds its age as upstream's `canGrow` branch does.
    fn random_tick(&self, level: &mut dyn LevelWriteHost, event: &mut RandomTickEvent) -> Flow {
        let Some(entry) = entry_for(event.state) else {
            return Flow::Continue;
        };
        let BlockPos { x, y, z } = event.pos;
        if may_grow(level, entry.crop, [x, y, z]) {
            Flow::Continue
        } else {
            Flow::Cancel
        }
    }

    /// `MysticalCropBlock.isValidBonemealTarget`: `canGrow && !isMaxAge`. Without the crux the
    /// meal is not even a target, so it is not spent; a ripe crop refuses it and keeps it.
    fn is_valid_bonemeal_target(
        &self,
        level: LevelSide<'_>,
        event: &mut IsValidBonemealTargetEvent,
    ) -> Option<bool> {
        let entry = entry_for(event.state)?;
        let level: &dyn LevelHost = match level {
            LevelSide::Server(level) | LevelSide::Client(level) => level,
        };
        let age = age_of(level, event.state)?;
        let BlockPos { x, y, z } = event.pos;
        Some(!runtime::is_ripe(age) && may_grow(level, entry.crop, [x, y, z]))
    }

    /// `MysticalCropBlock.isBonemealSuccess` is always false: a meal spent on a target crop
    /// never advances it.
    fn is_bonemeal_success(
        &self,
        _level: &mut dyn LevelRandomHost,
        event: &mut IsBonemealSuccessEvent,
    ) {
        event.success = false;
    }
}

/// `MysticalCropBlock.canGrow` for the crop at `pos`: the crux two blocks below, plus the
/// tier's farmland when the parent's `requiresEffectiveFarmland` asks for it.
///
/// An unloaded or out-of-height read answers air, which is no crop's crux, so a crop over an
/// unloaded column simply does not grow.
fn may_grow(level: &dyn LevelHost, crop: Crop, [x, y, z]: [i32; 3]) -> bool {
    let below_two = block_name(level, [x, y - 2, z]);
    let below = block_name(level, [x, y - 1, z]);
    runtime::can_grow(
        crop,
        &below_two,
        &below,
        runtime::REQUIRES_EFFECTIVE_FARMLAND,
    )
}

/// The block at `pos` as a registry name; an unreadable state is the empty string, which no
/// crop's crux or farmland matches.
fn block_name(level: &dyn LevelHost, pos: [i32; 3]) -> String {
    level
        .block_state(pos)
        .and_then(|state| level.state_block(state))
        .unwrap_or_default()
        .to_owned()
}

/// The `age` of the crop `state` carries, read from the level's serialized state.
fn age_of(level: &dyn LevelHost, state: BlockState) -> Option<u8> {
    age_in(&level.state_string(state)?)
}

/// The `age` in a serialized state (`mysticalagradditions:nether_star_crop[age=3]`), or `None`
/// for another block or a state without one.
fn age_in(text: &str) -> Option<u8> {
    let (name, properties) = text.split_once('[')?;
    if !runtime::CROPS.iter().any(|crop| crop.block == name) {
        return None;
    }
    properties
        .strip_suffix(']')?
        .split(',')
        .find_map(|entry| entry.strip_prefix(AGE)?.strip_prefix('='))
        .and_then(|age| age.parse().ok())
}

/// `MysticalCropBlock.getDrops` for a broken crop: replace the rolled list with the jar's own
/// essence and seeds. Tier 6's counts are deterministic (`CropTier.SIX` turns the secondary
/// seed drop off), so nothing is drawn from the level's random stream.
pub(super) fn on_loot_drops(host: &mut dyn ServerHost, event: &mut LootDropsEvent<'_>) {
    let Some((_, state)) = event.context.block else {
        return;
    };
    let Some(entry) = entry_for(state) else {
        return;
    };
    let Some(age) = age_of_state(host, state) else {
        return;
    };
    let harvest = runtime::harvest(age);

    let drops = &mut *event.drops;
    drops.clear();
    push(drops, entry.essence, harvest.essence);
    push(drops, entry.seeds, harvest.seeds);
}

/// Push `count` of `item` when the tier drops any.
fn push(drops: &mut Vec<ItemStack>, item: ItemKey, count: u32) {
    if count == 0 {
        return;
    }
    if let Some(stack) = ItemStack::new(item, count) {
        drops.push(stack);
    }
}

/// The crop's `age`, read from the host's own state table (the loot hook is given the state
/// itself, and the block is already gone from the world).
fn age_of_state(host: &dyn Host, state: BlockState) -> Option<u8> {
    let metadata = host.block_states();
    state.property(&metadata, AGE).ok().flatten()?.parse().ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_age_is_read_from_a_tier_six_crop_state() {
        assert_eq!(
            age_in("mysticalagradditions:nether_star_crop[age=3]"),
            Some(3)
        );
        assert_eq!(
            age_in("mysticalagradditions:awakened_draconium_crop[age=7]"),
            Some(7)
        );
    }

    #[test]
    fn another_block_or_a_stateless_one_is_not_ours() {
        assert_eq!(age_in("minecraft:wheat[age=7]"), None);
        assert_eq!(age_in("mysticalagriculture:inferium_crop[age=2]"), None);
        assert_eq!(age_in("mysticalagradditions:nether_star_crop"), None);
        assert_eq!(age_in("mysticalagradditions:nether_star_crux[age=1]"), None);
    }
}
